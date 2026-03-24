package com.example.matter_home.chip

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.ParcelUuid
import android.util.Log
import chip.platform.BleCallback
import java.util.UUID
import kotlin.coroutines.resume
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull

/**
 * Manages BLE scanning and GATT connection for Matter device commissioning.
 *
 * Ported from CHIPTool's BluetoothManager.kt.
 * Key design: all GATT events are forwarded to the CHIP platform's internal
 * [BluetoothGattCallback] (obtained via [chip.platform.AndroidBleManager.callback]).
 * This keeps our code thin and lets the CHIP C++ layer own the BLE protocol.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class BleConnectionManager : BleCallback {

    companion object {
        private const val TAG = "BleConnectionManager"
        private const val MATTER_BLE_UUID = "0000FFF6-0000-1000-8000-00805F9B34FB"
        private const val BLE_SCAN_TIMEOUT_MS = 10_000L
    }

    private val adapter: BluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
    private var bleGatt: BluetoothGatt? = null

    /** Connection ID assigned by [chip.platform.AndroidBleManager.addConnection]. */
    var connectionId: Int = 0
        private set

    // ── BleCallback (called by CHIP platform on BLE lifecycle events) ─────────

    override fun onCloseBleComplete(connId: Int) {
        Log.d(TAG, "onCloseBleComplete connId=$connId")
        connectionId = 0
    }

    override fun onNotifyChipConnectionClosed(connId: Int) {
        Log.d(TAG, "onNotifyChipConnectionClosed connId=$connId")
        bleGatt?.close()
        connectionId = 0
    }

    // ── BLE scan ─────────────────────────────────────────────────────────────

    /**
     * Scans BLE for a Matter device whose service-data encodes [discriminator].
     * Returns null on timeout.
     */
    suspend fun findDevice(
        context: Context,
        discriminator: Int,
        isShortDiscriminator: Boolean = false,
        timeoutMs: Long = BLE_SCAN_TIMEOUT_MS,
    ): BluetoothDevice? {
        if (!adapter.isEnabled) {
            @Suppress("DEPRECATION")
            adapter.enable()
        }
        val scanner = adapter.bluetoothLeScanner ?: run {
            Log.e(TAG, "BLE scanner unavailable")
            return null
        }
        return withTimeoutOrNull(timeoutMs) {
            callbackFlow {
                val scanCb = object : ScanCallback() {
                    override fun onScanResult(callbackType: Int, result: ScanResult) {
                        trySend(result.device)
                    }
                    override fun onScanFailed(errorCode: Int) {
                        Log.e(TAG, "BLE scan failed: $errorCode")
                    }
                }
                val serviceUuid = ParcelUuid(UUID.fromString(MATTER_BLE_UUID))
                val filter = ScanFilter.Builder()
                    .setServiceData(serviceUuid,
                        matterServiceData(discriminator),
                        matterServiceDataMask(isShortDiscriminator))
                    .build()
                val settings = ScanSettings.Builder()
                    .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                    .build()
                Log.i(TAG, "BLE scan started – discriminator=$discriminator")
                scanner.startScan(listOf(filter), settings, scanCb)
                awaitClose { scanner.stopScan(scanCb) }
            }.first()
        }
    }

    // ── GATT connection ───────────────────────────────────────────────────────

    /**
     * Connects to [device], discovers services, negotiates MTU, then registers
     * the GATT connection with the CHIP platform.
     * Returns the [BluetoothGatt] on success or null on failure.
     */
    suspend fun connect(context: Context, device: BluetoothDevice): BluetoothGatt? =
        suspendCancellableCoroutine { cont ->
            val gattCallback = buildGattCallback(context, cont)
            Log.i(TAG, "GATT connecting to ${device.address}")
            bleGatt = device.connectGatt(context, false, gattCallback,
                BluetoothDevice.TRANSPORT_LE)
            // Register connection + set our BleCallback so the platform can call us back.
            val platform = ChipClient.getPlatform()
            connectionId = platform.bleManager.addConnection(bleGatt)
            platform.bleManager.setBleCallback(this)
            cont.invokeOnCancellation { bleGatt?.disconnect() }
        }

    // ── GATT callback ─────────────────────────────────────────────────────────

    private enum class GattState { INIT, DISCOVER_SERVICES, REQUEST_MTU }

    private fun buildGattCallback(
        context: Context,
        cont: CancellableContinuation<BluetoothGatt?>,
    ): BluetoothGattCallback {
        return object : BluetoothGattCallback() {
            // CHIP platform's internal callback – forward everything to it.
            private val chipCb: BluetoothGattCallback
                get() = ChipClient.getPlatform().bleManager.callback

            private var state = GattState.INIT

            override fun onConnectionStateChange(gatt: BluetoothGatt?, status: Int, newState: Int) {
                chipCb.onConnectionStateChange(gatt, status, newState)
                if (newState == BluetoothProfile.STATE_CONNECTED &&
                    status == BluetoothGatt.GATT_SUCCESS
                ) {
                    Log.i(TAG, "GATT connected – discovering services")
                    state = GattState.DISCOVER_SERVICES
                    gatt?.discoverServices()
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    Log.w(TAG, "GATT disconnected status=$status")
                    if (cont.isActive) cont.resume(null)
                }
            }

            override fun onServicesDiscovered(gatt: BluetoothGatt?, status: Int) {
                chipCb.onServicesDiscovered(gatt, status)
                if (state != GattState.DISCOVER_SERVICES) return
                Log.i(TAG, "GATT services discovered – requesting MTU 247")
                state = GattState.REQUEST_MTU
                gatt?.requestMtu(247)
            }

            override fun onMtuChanged(gatt: BluetoothGatt?, mtu: Int, status: Int) {
                chipCb.onMtuChanged(gatt, mtu, status)
                if (state != GattState.REQUEST_MTU) return
                Log.i(TAG, "MTU=$mtu – GATT ready")
                if (cont.isActive) cont.resume(gatt)
            }

            override fun onCharacteristicChanged(
                gatt: BluetoothGatt, char: android.bluetooth.BluetoothGattCharacteristic,
            ) = chipCb.onCharacteristicChanged(gatt, char)

            override fun onCharacteristicRead(
                gatt: BluetoothGatt, char: android.bluetooth.BluetoothGattCharacteristic, status: Int,
            ) = chipCb.onCharacteristicRead(gatt, char, status)

            override fun onCharacteristicWrite(
                gatt: BluetoothGatt, char: android.bluetooth.BluetoothGattCharacteristic, status: Int,
            ) = chipCb.onCharacteristicWrite(gatt, char, status)

            override fun onDescriptorWrite(
                gatt: BluetoothGatt, desc: android.bluetooth.BluetoothGattDescriptor, status: Int,
            ) = chipCb.onDescriptorWrite(gatt, desc, status)

            override fun onDescriptorRead(
                gatt: BluetoothGatt, desc: android.bluetooth.BluetoothGattDescriptor, status: Int,
            ) = chipCb.onDescriptorRead(gatt, desc, status)

            override fun onReadRemoteRssi(gatt: BluetoothGatt, rssi: Int, status: Int) =
                chipCb.onReadRemoteRssi(gatt, rssi, status)

            override fun onReliableWriteCompleted(gatt: BluetoothGatt, status: Int) =
                chipCb.onReliableWriteCompleted(gatt, status)
        }
    }

    // ── BLE service-data encoding ─────────────────────────────────────────────
    // Matches the Matter spec §5.4.2.5 BLE advertisement payload.

    private fun matterServiceData(discriminator: Int): ByteArray {
        val version = 0
        val vDisc   = ((version and 0xf) shl 12) or (discriminator and 0xfff)
        return byteArrayOf(0, (vDisc and 0xff).toByte(), (vDisc shr 8).toByte())
    }

    private fun matterServiceDataMask(isShort: Boolean): ByteArray {
        val discMask = if (isShort) 0x00.toByte() else 0xff.toByte()
        return byteArrayOf(0xff.toByte(), discMask, 0xff.toByte())
    }
}
