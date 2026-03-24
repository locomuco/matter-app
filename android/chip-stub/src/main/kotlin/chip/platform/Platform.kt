package chip.platform

import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.content.Context
import chip.ChipSdkStubException

// ── BleCallback ──────────────────────────────────────────────────────────────

interface BleCallback {
    fun onCloseBleComplete(connId: Int)
    fun onNotifyChipConnectionClosed(connId: Int)
}

// ── AndroidBleManager ────────────────────────────────────────────────────────

/** Owned by AndroidChipPlatform; wraps Android BLE stack for the CHIP transport. */
class AndroidBleManager(context: Context) {
    /** Registers a GATT connection and returns an integer connId. */
    fun addConnection(gatt: BluetoothGatt?): Int = throw ChipSdkStubException()

    /** Supplies the BleCallback that receives close/disconnect events. */
    fun setBleCallback(callback: BleCallback): Unit = throw ChipSdkStubException()

    /** Internal GATT callback; delegate all GATT events to this from your GattCallback. */
    val callback: BluetoothGattCallback get() = throw ChipSdkStubException()
}

// ── Platform platform ────────────────────────────────────────────────────────

class AndroidNfcCommissioningManager

class PreferencesKeyValueStoreManager(context: Context)

class PreferencesConfigurationManager(context: Context)

class NsdManagerServiceResolver(
    context: Context,
    availState: NsdManagerResolverAvailState,
) {
    class NsdManagerResolverAvailState
}

class NsdManagerServiceBrowser(context: Context)

class ChipMdnsCallbackImpl

class DiagnosticDataProviderImpl(context: Context)

// ── AndroidChipPlatform ──────────────────────────────────────────────────────

class AndroidChipPlatform(
    val bleManager: AndroidBleManager,
    nfcManager: AndroidNfcCommissioningManager,
    keyValueStore: PreferencesKeyValueStoreManager,
    configManager: PreferencesConfigurationManager,
    serviceResolver: NsdManagerServiceResolver,
    serviceBrowser: NsdManagerServiceBrowser,
    mdnsCallback: ChipMdnsCallbackImpl,
    diagnosticProvider: DiagnosticDataProviderImpl,
) {
    init { throw ChipSdkStubException() }
}
