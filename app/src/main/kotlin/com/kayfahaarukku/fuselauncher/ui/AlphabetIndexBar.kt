package com.kayfahaarukku.fuselauncher.ui

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
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** Index entry for the top of the list - pinned apps and folders, which have no letter. */
const val TOP_INDEX_LETTER = "★"

/** Room the strip needs on the right of the list. */
val INDEX_BAR_WIDTH = 28.dp

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

                awaitPointerEventScope {
                    while (true) {
                        val down = awaitPointerEvent().changes.firstOrNull { it.pressed }
                            ?: continue
                        onDragging(true)
                        active = letterAt(down.position.y).also {
                            haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                            onSelected(it)
                        }

                        var id = down.id
                        while (true) {
                            val change = awaitPointerEvent().changes
                                .firstOrNull { it.id == id } ?: break
                            if (!change.pressed) break
                            change.consume()
                            id = change.id
                            val letter = letterAt(change.position.y)
                            if (letter != active) {
                                active = letter
                                haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                onSelected(letter)
                            }
                        }
                        onDragging(false)
                        active = null
                    }
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
