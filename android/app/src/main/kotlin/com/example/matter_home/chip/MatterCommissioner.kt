package com.example.matter_home.chip

import android.bluetooth.BluetoothGatt
import android.content.Context
import android.util.Log
import chip.devicecontroller.CommissionParameters
import chip.devicecontroller.NetworkCredentials
import matter.onboardingpayload.OnboardingPayload
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/** Thrown when commissioning fails. */
class CommissioningException(val errorCode: Long, message: String) : Exception(message)

/**
 * Orchestrates the full Matter commissioning flow and emits plain-text progress
 * events via [onEvent] at every meaningful step:
 *   • BLE scanning / GATT connect / MTU negotiation
 *   • Every CHIP SDK stage callback (ArmFailSafe, WifiNetworkEnable, …)
 *   • Device info (VID / PID) once read from the device
 *   • Final success / failure
 */
object MatterCommissioner {

    private const val TAG = "MatterCommissioner"
    const val STATUS_PAIRING_SUCCESS = 0L

    // ── BLE commissioning ────────────────────────────────────────────────────

    suspend fun commission(
        context: Context,
        payload: OnboardingPayload,
        wifiSsid: String?,
        wifiPassword: String?,
        threadDatasetTlv: ByteArray?,
        nodeId: Long,
        onEvent: (String) -> Unit,
    ): Long {
        val ble = BleConnectionManager()

        // 1 ── BLE scan ────────────────────────────────────────────────────────
        onEvent("🔍 BLE scanning… (discriminator=${payload.discriminator})")
        val device = ble.findDevice(
            context              = context,
            discriminator        = payload.discriminator,
            isShortDiscriminator = payload.hasShortDiscriminator,
        ) ?: throw CommissioningException(
            -1,
            "BLE scan timed out – device not found (discriminator=${payload.discriminator})"
        )
        onEvent("📡 Found device ${device.address}")

        // 2 ── GATT connect ────────────────────────────────────────────────────
        onEvent("🔗 GATT connecting to ${device.address}…")
        val gatt: BluetoothGatt = ble.connect(context, device)
            ?: throw CommissioningException(-2, "GATT connection failed to ${device.address}")
        onEvent("✓ BLE connected (MTU negotiated)")

        // 3 ── Network credentials ─────────────────────────────────────────────
        val networkCreds: NetworkCredentials? = when {
            wifiSsid != null -> {
                onEvent("📶 Using Wi-Fi SSID: $wifiSsid")
                NetworkCredentials.forWiFi(
                    NetworkCredentials.WiFiCredentials(wifiSsid, wifiPassword ?: "")
                )
            }
            threadDatasetTlv != null -> {
                onEvent("🧵 Using Thread operational dataset (${threadDatasetTlv.size} bytes)")
                NetworkCredentials.forThread(
                    NetworkCredentials.ThreadCredentials(threadDatasetTlv)
                )
            }
            else -> {
                onEvent("🌐 No network credentials – Ethernet device")
                null
            }
        }

        // 4 ── CHIP pairing ────────────────────────────────────────────────────
        onEvent("⚙ Starting CHIP commissioning (PASE)…")
        val commissionedNodeId = pairViaBle(
            context  = context,
            gatt     = gatt,
            connId   = ble.connectionId,
            nodeId   = nodeId,
            pinCode  = payload.setupPinCode,
            network  = networkCreds,
            onEvent  = onEvent,
        )

        onEvent("🎉 Done! Node 0x${commissionedNodeId.toULong().toString(16).padStart(16,'0').uppercase()}")
        return commissionedNodeId
    }

    // ── IP commissioning ─────────────────────────────────────────────────────

    suspend fun commissionViaIp(
        context: Context,
        ipAddress: String,
        port: Int = 5540,
        discriminator: Int,
        setupPinCode: Long,
        nodeId: Long,
        onEvent: (String) -> Unit = {},
    ): Long {
        val params = CommissionParameters.Builder()
            .setCsrNonce(null)
            .setICDRegistrationInfo(null)
            .build()
        onEvent("🌐 Commissioning via IP $ipAddress:$port…")
        onEvent("⚙ Starting CHIP commissioning (PASE)…")
        return pairViaIp(context, ipAddress, port, discriminator, setupPinCode, nodeId, params, onEvent)
    }

    // ── Private: BLE pairing ──────────────────────────────────────────────────

    private suspend fun pairViaBle(
        context: Context,
        gatt: BluetoothGatt,
        connId: Int,
        nodeId: Long,
        pinCode: Long,
        network: NetworkCredentials?,
        onEvent: (String) -> Unit,
    ): Long = suspendCancellableCoroutine { cont ->
        val controller = ChipClient.getController()
        val params = CommissionParameters.Builder()
            .setCsrNonce(null)
            .setNetworkCredentials(network)
            .setICDRegistrationInfo(null)
            .build()

        controller.setCompletionListener(object : GenericChipDeviceListener() {
            override fun onStatusUpdate(status: Int) {
                onEvent("ℹ Status: $status")
            }

            override fun onCommissioningStageStart(nodeId: Long, stage: String) {
                onEvent("▶ Stage: $stage")
            }

            override fun onCommissioningStatusUpdate(nodeId: Long, stage: String, errorCode: Long) {
                if (errorCode == 0L) onEvent("  ✓ $stage")
                else                 onEvent("  ✗ $stage (error $errorCode)")
            }

            override fun onReadCommissioningInfo(
                vendorId: Int, productId: Int,
                wifiEndpointId: Int, threadEndpointId: Int,
            ) {
                onEvent(
                    "📋 Device info: " +
                    "VID=0x${vendorId.toString(16).uppercase().padStart(4,'0')} " +
                    "PID=0x${productId.toString(16).uppercase().padStart(4,'0')} " +
                    "wifi-ep=$wifiEndpointId thread-ep=$threadEndpointId"
                )
            }

            override fun onCommissioningComplete(returnedNodeId: Long, errorCode: Long) {
                if (!cont.isActive) return
                if (errorCode == STATUS_PAIRING_SUCCESS) {
                    cont.resume(returnedNodeId)
                } else {
                    onEvent("✗ Commissioning failed (errorCode=$errorCode)")
                    cont.resumeWithException(
                        CommissioningException(errorCode, "Commission failed: errorCode=$errorCode")
                    )
                }
            }

            override fun onError(error: Throwable?) {
                if (!cont.isActive) return
                onEvent("✗ Error: ${error?.message}")
                cont.resumeWithException(
                    error ?: CommissioningException(-3, "Commission error")
                )
            }
        })

        Log.i(TAG, "pairDeviceThroughBLE nodeId=$nodeId connId=$connId")
        controller.pairDeviceThroughBLE(gatt, connId, nodeId, pinCode, params)
    }

    // ── Private: IP pairing ───────────────────────────────────────────────────

    private suspend fun pairViaIp(
        context: Context,
        address: String,
        port: Int,
        discriminator: Int,
        pinCode: Long,
        nodeId: Long,
        params: CommissionParameters,
        onEvent: (String) -> Unit,
    ): Long = suspendCancellableCoroutine { cont ->
        val controller = ChipClient.getController()
        controller.setCompletionListener(object : GenericChipDeviceListener() {
            override fun onStatusUpdate(status: Int) {
                onEvent("ℹ Status: $status")
            }
            override fun onCommissioningStageStart(nodeId: Long, stage: String) {
                onEvent("▶ Stage: $stage")
            }
            override fun onCommissioningStatusUpdate(nodeId: Long, stage: String, errorCode: Long) {
                if (errorCode == 0L) onEvent("  ✓ $stage")
                else                 onEvent("  ✗ $stage (error $errorCode)")
            }
            override fun onReadCommissioningInfo(vendorId: Int, productId: Int, wifiEndpointId: Int, threadEndpointId: Int) {
                onEvent("📋 Device: VID=0x${vendorId.toString(16).uppercase().padStart(4,'0')} PID=0x${productId.toString(16).uppercase().padStart(4,'0')}")
            }
            override fun onCommissioningComplete(returnedNodeId: Long, errorCode: Long) {
                if (!cont.isActive) return
                if (errorCode == STATUS_PAIRING_SUCCESS) cont.resume(returnedNodeId)
                else {
                    onEvent("✗ Commissioning failed (errorCode=$errorCode)")
                    cont.resumeWithException(
                        CommissioningException(errorCode, "IP commission failed: errorCode=$errorCode")
                    )
                }
            }
            override fun onError(error: Throwable?) {
                if (!cont.isActive) return
                onEvent("✗ Error: ${error?.message}")
                cont.resumeWithException(error ?: CommissioningException(-4, "IP commission error"))
            }
        })
        Log.i(TAG, "pairDeviceWithAddress nodeId=$nodeId addr=$address port=$port")
        controller.pairDeviceWithAddress(nodeId, address, port, discriminator, pinCode, params)
    }
}
