package com.kayfahaarukku.fuselauncher.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The reference numbers come from Flutter's own FrictionSimulation at a drag of
 * 0.135: dx(t) = v0 * 0.135^t, and finalX - x0 = -v0 / ln(0.135). If these
 * drift, the drawer stopped flinging like the build it was ported from.
 */
class BouncingFrictionTest {

    @Test
    fun `velocity decays by the drag every second`() {
        assertEquals(135f, BouncingFriction.velocityAt(1000f, 1f), 0.01f)
        assertEquals(18.225f, BouncingFriction.velocityAt(1000f, 2f), 0.01f)
    }

    @Test
    fun `a flick carries half its velocity`() {
        // -1000 / ln(0.135)
        assertEquals(499.38f, BouncingFriction.totalDistance(1000f), 0.01f)
    }

    @Test
    fun `scrolling the other way keeps its sign`() {
        assertEquals(-499.38f, BouncingFriction.totalDistance(-1000f), 0.01f)
        assertEquals(-135f, BouncingFriction.velocityAt(-1000f, 1f), 0.01f)
    }

    @Test
    fun `distance starts at nothing and tends to the total`() {
        assertEquals(0f, BouncingFriction.distanceAt(1000f, 0f), 0.01f)
        assertEquals(431.96f, BouncingFriction.distanceAt(1000f, 1f), 0.01f)
        assertEquals(
            BouncingFriction.totalDistance(1000f),
            BouncingFriction.distanceAt(1000f, 20f),
            0.5f,
        )
    }

    @Test
    fun `a fling runs until it drops under the stop velocity`() {
        val duration = BouncingFriction.durationSeconds(1000f)

        assertEquals(1.9536f, duration, 0.001f)
        assertEquals(
            BouncingFriction.STOP_VELOCITY,
            BouncingFriction.velocityAt(1000f, duration),
            0.01f,
        )
    }

    /** A flick faster than the last one has to go further, at every speed. */
    @Test
    fun `distance and duration rise with velocity`() {
        var previousDistance = 0f
        var previousDuration = 0f
        for (velocity in 100..5000 step 100) {
            val distance = BouncingFriction.totalDistance(velocity.toFloat())
            val duration = BouncingFriction.durationSeconds(velocity.toFloat())
            assertTrue(distance > previousDistance)
            assertTrue(duration > previousDuration)
            previousDistance = distance
            previousDuration = duration
        }
    }

    /** Nothing to animate below the tolerance; Flutter returns no simulation. */
    @Test
    fun `a nudge under the stop velocity takes no time`() {
        assertEquals(0f, BouncingFriction.durationSeconds(20f), 0f)
        assertEquals(0f, BouncingFriction.durationSeconds(-5f), 0f)
    }
}
