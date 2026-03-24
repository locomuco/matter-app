package matter.onboardingpayload

import chip.ChipSdkStubException

data class OnboardingPayload(
    val setupPinCode: Long = 0L,
    val discriminator: Int = 0,
    val vendorId: Int = 0,
    val productId: Int = 0,
    val version: Int = 0,
    val hasShortDiscriminator: Boolean = false,
    val discoveryCapabilities: Set<DiscoveryCapability> = emptySet(),
)

enum class DiscoveryCapability { SOFT_AP, BLE, ON_NETWORK, WIFI_PAF, NFC }

class OnboardingPayloadParser {
    fun parseQrCode(code: String): OnboardingPayload = throw ChipSdkStubException()
    fun parseManualPairingCode(code: String): OnboardingPayload = throw ChipSdkStubException()
}
