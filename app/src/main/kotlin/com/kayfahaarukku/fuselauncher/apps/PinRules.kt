package com.kayfahaarukku.fuselauncher.apps

/** Outcome of asking to pin or unpin an app. */
sealed interface PinResult {
    data class Changed(val pinned: List<String>) : PinResult
    data class Refused(val message: String) : PinResult
}

/**
 * Pin order is the user's, so a new pin goes on the end rather than sorting
 * itself in. Hidden apps are refused: the drawer would not show the pin, and a
 * pin pointing at nothing is worse than no pin.
 */
object PinRules {

    const val MAX_PINNED = 10

    fun toggle(
        current: List<String>,
        packageName: String,
        isHidden: Boolean,
        max: Int = MAX_PINNED,
    ): PinResult = when {
        packageName in current -> PinResult.Changed(current - packageName)
        isHidden -> PinResult.Refused("Hidden apps cannot be pinned")
        current.size >= max -> PinResult.Refused("Maximum $max apps can be pinned")
        else -> PinResult.Changed(current + packageName)
    }
}
