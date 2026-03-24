package com.example.matter_home.chip

import matter.onboardingpayload.OnboardingPayload
import matter.onboardingpayload.OnboardingPayloadParser

/**
 * Parses a Matter QR-code string ("MT:…") or an 11-digit manual pairing code
 * into an [OnboardingPayload] containing the discriminator and setup PIN.
 */
object SetupPayloadHelper {

    fun parse(raw: String): OnboardingPayload {
        val stripped = raw.trim()
        val parser = OnboardingPayloadParser()
        return try {
            if (stripped.startsWith("MT:", ignoreCase = true)) {
                parser.parseQrCode(stripped)
            } else {
                parser.parseManualPairingCode(stripped)
            }
        } catch (e: Exception) {
            throw IllegalArgumentException("Invalid Matter setup payload: $stripped", e)
        }
    }
}
