package com.kayfahaarukku.fuselauncher.apps

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DoubleSwipeTest {

    @Test
    fun `one swipe does not open anything`() {
        assertFalse(DoubleSwipe().onSwipe(0))
    }

    @Test
    fun `a second swipe inside the window opens it`() {
        val gesture = DoubleSwipe()

        assertFalse(gesture.onSwipe(0))
        assertTrue(gesture.onSwipe(400))
    }

    @Test
    fun `a second swipe after the window does not`() {
        val gesture = DoubleSwipe()

        assertFalse(gesture.onSwipe(0))
        assertFalse(gesture.onSwipe(900))
    }

    /** A slow drumroll must not eventually add up to a pair. */
    @Test
    fun `spaced out swipes never accumulate`() {
        val gesture = DoubleSwipe()

        repeat(5) { assertFalse(gesture.onSwipe(it * 1_000L)) }
    }

    /** Firing consumes the pair, so the next swipe starts over. */
    @Test
    fun `a third swipe right after opening does not open again`() {
        val gesture = DoubleSwipe()

        gesture.onSwipe(0)
        assertTrue(gesture.onSwipe(200))
        assertFalse(gesture.onSwipe(300))
        assertTrue(gesture.onSwipe(400))
    }

    @Test
    fun `reset forgets a pending first swipe`() {
        val gesture = DoubleSwipe()

        gesture.onSwipe(0)
        gesture.reset()
        assertFalse(gesture.onSwipe(100))
    }
}
