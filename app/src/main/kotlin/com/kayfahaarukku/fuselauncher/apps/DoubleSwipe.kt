package com.kayfahaarukku.fuselauncher.apps

/**
 * Two right-swipes in quick succession, which is how the hidden apps list is
 * reached. One swipe arms it; a second inside the window opens the list.
 *
 * Deliberately awkward: the list is meant to be hard to reach by accident, and
 * a single swipe would fire constantly while browsing.
 */
class DoubleSwipe(private val windowMs: Long = WINDOW_MS) {

    private var lastSwipeAt: Long? = null
    private var armed = false

    /** Returns true when this swipe completes the pair. */
    fun onSwipe(nowMs: Long): Boolean {
        val previous = lastSwipeAt
        lastSwipeAt = nowMs
        val withinWindow = previous != null && nowMs - previous < windowMs
        if (withinWindow && armed) {
            armed = false
            return true
        }
        // A late swipe starts a fresh pair rather than counting as the second.
        armed = true
        return false
    }

    fun reset() {
        lastSwipeAt = null
        armed = false
    }

    companion object {
        const val WINDOW_MS = 500L
    }
}
