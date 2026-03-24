package chip.devicecontroller

import chip.ChipSdkStubException

// ── ControllerParams ────────────────────────────────────────────────────────

class ControllerParams private constructor() {
    companion object {
        @JvmStatic fun newBuilder(): Builder = throw ChipSdkStubException()
    }

    class Builder {
        fun setControllerVendorId(vendorId: Int): Builder = throw ChipSdkStubException()
        fun setEnableServerInteractions(enable: Boolean): Builder = throw ChipSdkStubException()
        fun setSkipAttestationCertificateValidation(skip: Boolean): Builder = throw ChipSdkStubException()
        fun build(): ControllerParams = throw ChipSdkStubException()
    }
}

// ── NetworkCredentials ───────────────────────────────────────────────────────

class NetworkCredentials private constructor() {
    companion object {
        @JvmStatic fun forWiFi(wifi: WiFiCredentials): NetworkCredentials = throw ChipSdkStubException()
        @JvmStatic fun forThread(thread: ThreadCredentials): NetworkCredentials = throw ChipSdkStubException()
    }

    class WiFiCredentials(val ssid: String, val password: String)
    class ThreadCredentials(val operationalDataset: ByteArray)
}
// ── CommissionParameters ─────────────────────────────────────────────────────

class CommissionParameters private constructor() {
    class Builder {
        fun setCsrNonce(nonce: ByteArray?): Builder = throw ChipSdkStubException()
        fun setNetworkCredentials(creds: NetworkCredentials?): Builder = throw ChipSdkStubException()
        fun setICDRegistrationInfo(info: ICDRegistrationInfo?): Builder = throw ChipSdkStubException()
        fun build(): CommissionParameters = throw ChipSdkStubException()
    }
}

// ── Setup payload ────────────────────────────────────────────────────────────
// Moved to matter.onboardingpayload in SDK v1.4+.  Stubs live there now.

// ── ICD types ────────────────────────────────────────────────────────────────

class ICDDeviceInfo

class ICDRegistrationInfo private constructor() {
    companion object {
        @JvmStatic fun createForDeferredConfiguration(): ICDRegistrationInfo? = throw ChipSdkStubException()
    }
}

class ICDClientInfo

interface ICDCheckInDelegate {
    fun onCheckInComplete(info: ICDClientInfo)
    fun onKeyRefreshNeeded(info: ICDClientInfo): ByteArray?
    fun onKeyRefreshDone(errorCode: Long)
}

// ── Attestation ──────────────────────────────────────────────────────────────

class AttestationInfo

fun interface DeviceAttestationDelegate {
    fun onDeviceAttestationCompleted(
        devicePtr: Long,
        attestationInfo: AttestationInfo,
        errorCode: Long,
    )
}

// ── GetConnectedDeviceCallback ────────────────────────────────────────────────

class GetConnectedDeviceCallbackJni {
    interface GetConnectedDeviceCallback {
        fun onDeviceConnected(devicePointer: Long)
        fun onConnectionFailure(nodeId: Long, error: Exception)
    }
}
