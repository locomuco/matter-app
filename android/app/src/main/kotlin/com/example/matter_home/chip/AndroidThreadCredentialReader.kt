package com.example.matter_home.chip

import android.app.Activity
import android.content.Intent
import android.util.Log
import com.google.android.gms.threadnetwork.ThreadNetwork
import com.google.android.gms.threadnetwork.ThreadNetworkCredentials
import io.flutter.plugin.common.MethodChannel

/**
 * Reads Thread Network credentials from the Android credential store.
 *
 * getAllCredentials() only returns credentials our app has been explicitly
 * granted access to. getPreferredCredentials() launches the system consent UI
 * so the user can pick which Thread network to share — this is the correct
 * first-time flow.
 */
object AndroidThreadCredentialReader {

    private const val TAG         = "AndroidThreadCreds"
    const val REQUEST_CODE        = 1001

    /** Pending result from a getPreferredCredentials() flow. */
    private var pendingResult: MethodChannel.Result? = null

    /**
     * Launches the Android Thread credential picker.
     * The result arrives asynchronously via [onActivityResult].
     */
    fun requestPreferredCredentials(activity: Activity, result: MethodChannel.Result) {
        pendingResult = result
        Log.d(TAG, "Calling getPreferredCredentials()…")
        ThreadNetwork.getClient(activity)
            .preferredCredentials
            .addOnSuccessListener { intentSenderResult ->
                Log.d(TAG, "Got IntentSender — launching credential picker")
                try {
                    activity.startIntentSenderForResult(
                        intentSenderResult.intentSender,
                        REQUEST_CODE, null, 0, 0, 0,
                    )
                } catch (e: Exception) {
                    Log.e(TAG, "startIntentSenderForResult failed: ${e.message}", e)
                    pendingResult?.error("THREAD_CREDS_ERROR", e.message, null)
                    pendingResult = null
                }
            }
            .addOnFailureListener { e ->
                Log.w(TAG, "getPreferredCredentials failed: ${e.javaClass.simpleName}: ${e.message}")
                pendingResult?.error("THREAD_CREDS_ERROR", e.message, null)
                pendingResult = null
            }
    }

    /**
     * Call this from [Activity.onActivityResult] when requestCode == REQUEST_CODE.
     * Extracts the credentials from the Intent and forwards the hex dataset
     * to the waiting Flutter result.
     */
    fun onActivityResult(resultCode: Int, data: Intent?) {
        val result = pendingResult ?: return
        pendingResult = null

        if (resultCode != Activity.RESULT_OK || data == null) {
            Log.d(TAG, "Credential picker cancelled or denied (resultCode=$resultCode)")
            result.success("") // empty = cancelled
            return
        }

        try {
            val creds = ThreadNetworkCredentials.fromIntentSenderResultData(data)
            val hex   = creds.activeOperationalDataset
                .joinToString("") { "%02x".format(it) }
            Log.i(TAG, "Received credentials, dataset length=${creds.activeOperationalDataset.size}")
            result.success(hex)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to extract credentials: ${e.message}", e)
            result.error("THREAD_CREDS_ERROR", e.message, null)
        }
    }
}
