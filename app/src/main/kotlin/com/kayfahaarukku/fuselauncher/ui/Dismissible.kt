package com.kayfahaarukku.fuselauncher.ui

import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.SwipeToDismissBoxState
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.input.pointer.util.addPointerInputChange
import kotlin.math.abs
import kotlin.math.sign

/** Flutter's `_kMinFlingVelocity` and `_kMinFlingVelocityDelta`, in dp/s. */
private const val MIN_FLING_VELOCITY = 700f
private const val MIN_FLING_VELOCITY_DELTA = 400f

/**
 * Whether a released swipe dismisses, by Flutter's Dismissible rules.
 *
 * [extent] is how far it travelled as a signed fraction of the width, and the
 * velocities are dp/s. A fling only counts when it is fast and clearly flatter
 * than it is steep, and then its direction alone decides; anything else has to
 * have been dragged past [threshold].
 */
fun dismisses(extent: Float, vx: Float, vy: Float, threshold: Float): Boolean {
    val fling = abs(vx) >= MIN_FLING_VELOCITY && abs(vx) - abs(vy) >= MIN_FLING_VELOCITY_DELTA
    return if (fling) sign(vx) == sign(extent) else abs(extent) > threshold
}

/**
 * A SwipeToDismissBox state that only lets go when Flutter's Dismissible would.
 *
 * Material dismisses on 56dp of travel or a 125dp/s sideways flick and never
 * looks at vertical speed, so a scroll that drifts sideways enough for a row to
 * catch it sails through both. Dismissible wanted [threshold] of the width, or
 * a fling of 700dp/s that is 400dp/s flatter than it is steep. The box keeps
 * its own animation; this vetoes the settles Flutter would not have made.
 *
 * The box does not hand out the release velocity, so the returned modifier has
 * to go on it to watch the gesture. It only observes, on the Initial pass, so
 * the release is recorded before the box settles on it.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun rememberDismissibleState(
    threshold: Float,
    confirmValueChange: (SwipeToDismissBoxValue) -> Boolean = { true },
): Pair<SwipeToDismissBoxState, Modifier> {
    val release = remember { BooleanArray(1) }
    val state = rememberSwipeToDismissBoxState(
        confirmValueChange = {
            it == SwipeToDismissBoxValue.Settled || (release[0] && confirmValueChange(it))
        },
        positionalThreshold = { it * threshold },
    )
    val watch = Modifier.pointerInput(threshold) {
        val tracker = VelocityTracker()
        awaitEachGesture {
            val down = awaitFirstDown(requireUnconsumed = false, pass = PointerEventPass.Initial)
            tracker.resetTracking()
            tracker.addPointerInputChange(down)
            var last = down
            while (last.pressed) {
                last = awaitPointerEvent(PointerEventPass.Initial)
                    .changes.firstOrNull { it.id == down.id } ?: break
                tracker.addPointerInputChange(last)
            }
            val velocity = tracker.calculateVelocity()
            release[0] = dismisses(
                extent = (last.position.x - down.position.x) / size.width,
                vx = velocity.x.toDp().value,
                vy = velocity.y.toDp().value,
                threshold = threshold,
            )
        }
    }
    return state to watch
}
