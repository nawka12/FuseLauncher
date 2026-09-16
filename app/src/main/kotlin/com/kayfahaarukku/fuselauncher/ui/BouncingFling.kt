package com.kayfahaarukku.fuselauncher.ui

import androidx.compose.animation.core.AnimationState
import androidx.compose.animation.core.FloatDecayAnimationSpec
import androidx.compose.animation.core.animateDecay
import androidx.compose.animation.core.generateDecayAnimationSpec
import androidx.compose.foundation.gestures.FlingBehavior
import androidx.compose.foundation.gestures.ScrollScope
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import kotlin.math.abs
import kotlin.math.exp
import kotlin.math.ln

/**
 * iOS scroll friction, which is what the Flutter build flung on: the drawer
 * scrolled under BouncingScrollPhysics, and its ballistic phase is a plain
 * FrictionSimulation at a drag of 0.135.
 *
 * Velocity decays as v(t) = v0 * 0.135^t, t in seconds. The 0.135 is
 * UIScrollView's 0.998 deceleration rate compounded over a thousand
 * milliseconds, which is where Flutter takes it from. Compose flings on
 * Android's spline instead, which holds speed longer and then stops short, so
 * the same flick lands somewhere else entirely - the thing that felt wrong.
 *
 * Distances here are physical pixels where Flutter counted logical ones. The
 * decay is a time constant and does not care; [STOP_VELOCITY] would, except
 * that Flutter's tolerance of 1/(0.05 * dpr) logical pixels per second is a
 * flat 20 physical pixels per second once multiplied back up, at any density.
 */
object BouncingFriction {

    /** UIScrollView.decelerationRate .normal, as 0.998^1000. */
    const val DRAG = 0.135f

    /** Below this a fling is over, matching Flutter's scroll tolerance. */
    const val STOP_VELOCITY = 20f

    private val dragLog = ln(DRAG)

    /** Flutter's FrictionSimulation.dx. */
    fun velocityAt(velocity: Float, seconds: Float): Float =
        velocity * exp(dragLog * seconds)

    /** How far the fling has carried by [seconds] - Flutter's x, less its start. */
    fun distanceAt(velocity: Float, seconds: Float): Float =
        velocity * (exp(dragLog * seconds) - 1f) / dragLog

    /** The whole fling, Flutter's finalX. */
    fun totalDistance(velocity: Float): Float = -velocity / dragLog

    /** When it drops under [STOP_VELOCITY] and Flutter calls it settled. */
    fun durationSeconds(velocity: Float): Float =
        if (abs(velocity) <= STOP_VELOCITY) 0f
        else ln(STOP_VELOCITY / abs(velocity)) / dragLog
}

/** [BouncingFriction] in the shape Compose can animate. */
private object BouncingDecaySpec : FloatDecayAnimationSpec {

    override val absVelocityThreshold = BouncingFriction.STOP_VELOCITY

    override fun getValueFromNanos(playTimeNanos: Long, start: Float, startVelocity: Float) =
        start + BouncingFriction.distanceAt(startVelocity, playTimeNanos.toSeconds())

    override fun getVelocityFromNanos(playTimeNanos: Long, start: Float, startVelocity: Float) =
        BouncingFriction.velocityAt(startVelocity, playTimeNanos.toSeconds())

    override fun getDurationNanos(start: Float, startVelocity: Float) =
        (BouncingFriction.durationSeconds(startVelocity) * 1_000_000_000f).toLong()

    override fun getTargetValue(start: Float, startVelocity: Float) =
        start + BouncingFriction.totalDistance(startVelocity)
}

private fun Long.toSeconds() = this / 1_000_000_000f

/**
 * A fling that decelerates the way the Flutter build's did.
 *
 * It gives up as soon as the list stops taking the whole delta, which is what
 * happens at the top and bottom: Compose's stretch overscroll is left to play
 * the edge, rather than this animating on against something that cannot move.
 */
@Composable
fun rememberBouncingFling(): FlingBehavior = remember {
    object : FlingBehavior {
        private val decay = BouncingDecaySpec.generateDecayAnimationSpec<Float>()

        override suspend fun ScrollScope.performFling(initialVelocity: Float): Float {
            if (abs(initialVelocity) <= BouncingFriction.STOP_VELOCITY) return initialVelocity

            var lastValue = 0f
            var remaining = initialVelocity
            AnimationState(initialValue = 0f, initialVelocity = initialVelocity)
                .animateDecay(decay) {
                    val delta = value - lastValue
                    val consumed = scrollBy(delta)
                    lastValue = value
                    remaining = velocity
                    if (abs(delta - consumed) > 0.5f) cancelAnimation()
                }
            return remaining
        }
    }
}
