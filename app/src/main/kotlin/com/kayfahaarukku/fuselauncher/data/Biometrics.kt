package com.kayfahaarukku.fuselauncher.data

import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.fragment.app.FragmentActivity
import kotlin.coroutines.resume
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * Guards the hidden-apps list.
 *
 * DEVICE_CREDENTIAL is allowed alongside biometrics, matching the Flutter
 * build: a user with no fingerprint enrolled can still reach their hidden apps
 * with the device PIN. When the device can do neither, this returns true rather
 * than locking the user out of their own list for good.
 */
object Biometrics {

    private const val ALLOWED =
        BiometricManager.Authenticators.BIOMETRIC_WEAK or
            BiometricManager.Authenticators.DEVICE_CREDENTIAL

    fun available(activity: FragmentActivity): Boolean =
        BiometricManager.from(activity).canAuthenticate(ALLOWED) ==
            BiometricManager.BIOMETRIC_SUCCESS

    suspend fun authenticate(
        activity: FragmentActivity,
        reason: String = "Authenticate to view hidden apps",
    ): Boolean {
        if (!available(activity)) return true

        return suspendCancellableCoroutine { continuation ->
            val prompt = BiometricPrompt(
                activity,
                androidx.core.content.ContextCompat.getMainExecutor(activity),
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(
                        result: BiometricPrompt.AuthenticationResult
                    ) {
                        if (continuation.isActive) continuation.resume(true)
                    }

                    /** Fires for cancel and for lockout alike; both mean "no". */
                    override fun onAuthenticationError(code: Int, message: CharSequence) {
                        if (continuation.isActive) continuation.resume(false)
                    }
                },
            )
            prompt.authenticate(
                BiometricPrompt.PromptInfo.Builder()
                    .setTitle("Hidden apps")
                    .setSubtitle(reason)
                    .setAllowedAuthenticators(ALLOWED)
                    .build()
            )
            continuation.invokeOnCancellation { prompt.cancelAuthentication() }
        }
    }
}
