package com.kayfahaarukku.fuselauncher.ui

import org.junit.Assert.assertEquals
import org.junit.Test

private const val SLOP = 12f

class TouchAxisTest {

    @Test
    fun `a press that has not moved is still undecided`() {
        assertEquals(TouchAxis.UNDECIDED, touchAxis(0f, 0f, SLOP))
    }

    @Test
    fun `a wobble inside slop commits to nothing`() {
        assertEquals(TouchAxis.UNDECIDED, touchAxis(4f, -6f, SLOP))
    }

    @Test
    fun `travelling up or down is vertical`() {
        assertEquals(TouchAxis.VERTICAL, touchAxis(2f, 40f, SLOP))
        assertEquals(TouchAxis.VERTICAL, touchAxis(2f, -40f, SLOP))
    }

    /** The one that started this: a Back swipe off the right edge. */
    @Test
    fun `swiping sideways is horizontal`() {
        assertEquals(TouchAxis.HORIZONTAL, touchAxis(-60f, 3f, SLOP))
    }

    /** What the gesture arena used to settle: the bigger axis takes it. */
    @Test
    fun `a diagonal goes to whichever axis is winning`() {
        assertEquals(TouchAxis.HORIZONTAL, touchAxis(-50f, 20f, SLOP))
        assertEquals(TouchAxis.VERTICAL, touchAxis(-20f, 50f, SLOP))
    }

    /** Sideways past slop stays sideways even once it has drifted down too. */
    @Test
    fun `a long sideways swipe that also drifts stays horizontal`() {
        assertEquals(TouchAxis.HORIZONTAL, touchAxis(-200f, 60f, SLOP))
    }
}
