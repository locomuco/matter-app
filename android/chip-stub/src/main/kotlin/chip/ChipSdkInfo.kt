package chip

/**
 * Marker object present ONLY in the stub library.
 * MatterBridge calls ChipClient.init(); if that succeeds without throwing,
 * the real SDK is loaded (this class is absent). If it throws StubException,
 * simulation mode is activated.
 *
 * The real CHIPController.aar does NOT contain this class.
 */
object ChipSdkInfo {
    const val IS_STUB = true
    const val VERSION = "stub-1.0"
}

/** Thrown by every stub method to signal that the real SDK is absent. */
class ChipSdkStubException(msg: String = "CHIP SDK stub – real AAR not present") :
    RuntimeException(msg)
