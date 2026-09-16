package com.kayfahaarukku.fuselauncher.ui

import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.changedToUp
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.abs

/** Index entry for the top of the list - pinned apps and folders, which have no letter. */
const val TOP_INDEX_LETTER = "★"

/** Room the strip needs on the right of the list. */
val INDEX_BAR_WIDTH = 28.dp

/** Which way a touch has committed, once it has moved far enough to tell. */
enum class TouchAxis { UNDECIDED, HORIZONTAL, VERTICAL }

/**
 * Classifies a touch by how far it has travelled from where it landed: the axis
 * that is winning takes it, and nothing is decided inside slop.
 *
 * This is the job Flutter's gesture arena did for the old build. There, the
 * list's vertical drag and the pane's horizontal one competed for every touch
 * and exactly one won - whichever cleared its slop first - so a sideways swipe
 * could never also scroll. Compose has no arena, so both the strip and the list
 * ask this instead, and they answer the same way.
 */
fun touchAxis(dx: Float, dy: Float, slop: Float): TouchAxis = when {
    abs(dx) > slop && abs(dx) > abs(dy) -> TouchAxis.HORIZONTAL
    abs(dy) > slop -> TouchAxis.VERTICAL
    else -> TouchAxis.UNDECIDED
}

/**
 * Index strip down the right edge: tap or drag a letter to jump to that
 * section. It only lists sections the list really has, so no entry can point
 * at nothing.
 *
 * Press and drag are one gesture handler rather than a tap detector beside a
 * drag detector, which would both claim the same press and fire twice.
 */
@Composable
fun AlphabetIndexBar(
    letters: List<String>,
    onSelected: (String) -> Unit,
    onDragging: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
) {
    var active by remember { mutableStateOf<String?>(null) }
    var height by remember { mutableFloatStateOf(0f) }
    val haptics = LocalHapticFeedback.current

    Column(
        verticalArrangement = Arrangement.SpaceEvenly,
        modifier = modifier
            .width(INDEX_BAR_WIDTH)
            .fillMaxHeight()
            .onSizeChanged { height = it.height.toFloat() }
            .pointerInput(letters, height) {
                if (letters.isEmpty() || height <= 0f) return@pointerInput

                fun letterAt(y: Float): String {
                    val index = ((y / height) * letters.size).toInt()
                    return letters[index.coerceIn(0, letters.lastIndex)]
                }

                fun select(letter: String) {
                    if (letter == active) return
                    active = letter
                    haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                    onSelected(letter)
                }

                awaitEachGesture {
                    val down = awaitFirstDown(requireUnconsumed = false)
                    var dragging = false

                    while (true) {
                        val change = awaitPointerEvent().changes
                            .firstOrNull { it.id == down.id } ?: break

                        if (!dragging) {
                            val travel = change.position - down.position
                            when (touchAxis(travel.x, travel.y, viewConfiguration.touchSlop)) {
                                TouchAxis.HORIZONTAL -> break
                                TouchAxis.UNDECIDED -> {
                                    // Lifted in place is a tap - but only a
                                    // real lift. The system hands Back to
                                    // itself by cancelling, and a cancel
                                    // arrives here looking exactly like a
                                    // lift: same position, pressed false. The
                                    // one thing it carries is the consumed
                                    // flag, which is what changedToUp() rules
                                    // out. Reading `pressed` alone jumped the
                                    // list on every Back swipe that started on
                                    // the strip, and the strip is 28dp of the
                                    // 20dp the system watches for Back.
                                    if (change.changedToUp()) {
                                        select(letterAt(change.position.y))
                                        break
                                    }
                                    if (!change.pressed) break
                                    continue
                                }
                                TouchAxis.VERTICAL -> {
                                    dragging = true
                                    onDragging(true)
                                }
                            }
                        }

                        if (!change.pressed) break
                        change.consume()
                        select(letterAt(change.position.y))
                    }

                    if (dragging) onDragging(false)
                    active = null
                }
            },
    ) {
        letters.forEach { letter ->
            Text(
                letter,
                textAlign = TextAlign.Center,
                style = Wallpaper.style(
                    MaterialTheme.typography.labelSmall.copy(
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold,
                    ),
                    if (letter == active) Wallpaper.content else Wallpaper.contentMuted,
                ),
                modifier = Modifier.width(INDEX_BAR_WIDTH),
            )
        }
    }
}
