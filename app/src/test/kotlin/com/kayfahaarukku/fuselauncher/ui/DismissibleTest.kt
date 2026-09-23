package com.kayfahaarukku.fuselauncher.ui

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Flutter's Dismissible: 700dp/s, 400dp/s flatter than steep, or the threshold. */
class DismissibleTest {

    /** The bug: a scroll caught by a row, let go with a little sideways speed. */
    @Test
    fun `a steep flick with some sideways drift does not dismiss`() {
        assertFalse(dismisses(extent = 0.05f, vx = 300f, vy = -2000f, threshold = 0.25f))
        assertFalse(dismisses(extent = 0.05f, vx = 900f, vy = -1200f, threshold = 0.25f))
    }

    @Test
    fun `a flat fast fling dismisses from a short drag`() {
        assertTrue(dismisses(extent = 0.05f, vx = 900f, vy = 100f, threshold = 0.25f))
    }

    @Test
    fun `a fling back the other way springs back even past the threshold`() {
        assertFalse(dismisses(extent = 0.5f, vx = -900f, vy = 0f, threshold = 0.25f))
    }

    @Test
    fun `a slow release goes by distance`() {
        assertFalse(dismisses(extent = 0.2f, vx = 100f, vy = 0f, threshold = 0.25f))
        assertTrue(dismisses(extent = 0.3f, vx = 100f, vy = 0f, threshold = 0.25f))
        assertTrue(dismisses(extent = -0.5f, vx = 0f, vy = 0f, threshold = 0.4f))
    }
}
