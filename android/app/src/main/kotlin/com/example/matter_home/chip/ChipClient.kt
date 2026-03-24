package com.example.matter_home.chip

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import chip.devicecontroller.ChipDeviceController
import chip.devicecontroller.ControllerParams
import chip.devicecontroller.DeviceAttestationDelegate
import chip.devicecontroller.GetConnectedDeviceCallbackJni.GetConnectedDeviceCallback
import chip.platform.AndroidBleManager
import chip.platform.AndroidChipPlatform
import chip.platform.AndroidNfcCommissioningManager
import chip.platform.ChipMdnsCallbackImpl
import chip.platform.DiagnosticDataProviderImpl
import chip.platform.NsdManagerServiceBrowser
import chip.platform.NsdManagerServiceResolver
import chip.platform.PreferencesConfigurationManager
import chip.platform.PreferencesKeyValueStoreManager
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * Singleton CHIP SDK entry point, ported from CHIPTool's ChipClient.kt.
 *
 * Lifecycle:
 *  - Call [init] once in Application.onCreate() or MainActivity.onCreate().
 *  - [isAvailable] is false when running with the chip-stub (simulation mode).
 */
object ChipClient {
    private const val TAG = "ChipClient"

    /** Vendor ID used when creating the fabric.  0xFFF4 = CHIP test VID. */
    const val VENDOR_ID = 0xFFF4

    private lateinit var _controller: ChipDeviceController
    private lateinit var _platform: AndroidChipPlatform

    /** True when the real CHIPController.aar is loaded. */
    var isAvailable: Boolean = false
        private set

    // ── Initialisation ───────────────────────────────────────────────────────

    /**
     * Initialises the CHIP platform. Safe to call multiple times.
     * Throws nothing – on failure [isAvailable] stays false.
     */
    fun init(context: Context) {
        if (isAvailable) return
        try {
            ChipDeviceController.loadJni()      // loads the native .so
            _platform = AndroidChipPlatform(
                AndroidBleManager(context),
                AndroidNfcCommissioningManager(),
                PreferencesKeyValueStoreManager(context),
                PreferencesConfigurationManager(context),
                NsdManagerServiceResolver(
                    context,
                    NsdManagerServiceResolver.NsdManagerResolverAvailState(),
                ),
                NsdManagerServiceBrowser(context),
                ChipMdnsCallbackImpl(),
                DiagnosticDataProviderImpl(context),
            )
            _controller = ChipDeviceController(
                ControllerParams.newBuilder()
                    .setControllerVendorId(VENDOR_ID)
                    .setEnableServerInteractions(true)
                    // Skip PAA/DAC certificate chain validation against the test trust store.
                    // This allows commissioning real commercial devices whose PAA certs are not
                    // in the SDK's built-in test store.
                    // For production: remove this flag and supply the real PAA trust store via
                    // setAttestationTrustStoreDelegate().
                    .setSkipAttestationCertificateValidation(true)
                    .build(),
            )
            // Permissive attestation delegate.
            // continueCommissioning MUST be posted to the main thread to avoid
            // a reentrant JNI deadlock (same pattern as CHIPTool's DeviceProvisioningFragment).
            val mainHandler = Handler(Looper.getMainLooper())
            _controller.setDeviceAttestationDelegate(
                600,
                DeviceAttestationDelegate { devicePtr, _, errorCode ->
                    Log.w(TAG, "DeviceAttestationDelegate errorCode=$errorCode – continuing")
                    mainHandler.post {
                        _controller.continueCommissioning(devicePtr, true)
                    }
                },
            )
            isAvailable = true
            Log.i(TAG, "CHIP SDK initialised – fabric 0x${_controller.compressedFabricId.toULong().toString(16)}")
        } catch (e: Exception) {
            Log.w(TAG, "CHIP SDK not available (${e.javaClass.simpleName}): simulation mode")
            isAvailable = false
        }
    }

    // ── Accessors ────────────────────────────────────────────────────────────

    /** Returns the [ChipDeviceController] or throws [IllegalStateException] if not initialised. */
    fun getController(): ChipDeviceController {
        check(isAvailable) { "CHIP SDK is not available" }
        return _controller
    }

    fun getPlatform(): AndroidChipPlatform {
        check(isAvailable) { "CHIP SDK is not available" }
        return _platform
    }

    val fabricId: Long
        get() = if (isAvailable) _controller.compressedFabricId else 0L

    // ── CASE session helper ──────────────────────────────────────────────────

    /**
     * Establishes a CASE session with [nodeId] and returns the native device
     * pointer.  Suspends until connected or throws on failure.
     */
    suspend fun getConnectedDevicePointer(context: Context, nodeId: Long): Long =
        suspendCancellableCoroutine { cont ->
            getController().getConnectedDevicePointer(
                nodeId,
                object : GetConnectedDeviceCallback {
                    override fun onDeviceConnected(devicePointer: Long) {
                        Log.d(TAG, "CASE session established for nodeId=$nodeId")
                        cont.resume(devicePointer)
                    }

                    override fun onConnectionFailure(nodeId: Long, error: Exception) {
                        Log.e(TAG, "CASE session failed for nodeId=$nodeId", error)
                        cont.resumeWithException(error)
                    }
                },
            )
        }
}
