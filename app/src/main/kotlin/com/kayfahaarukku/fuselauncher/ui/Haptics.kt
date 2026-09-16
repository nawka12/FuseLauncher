package com.kayfahaarukku.fuselauncher.ui

import android.view.HapticFeedbackConstants
import android.view.View
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalView

/**
 * The two effects the Flutter build used, named after the Dart calls and sent
 * as the constants its Android engine actually sent: PlatformPlugin maps
 * selectionClick to CLOCK_TICK and heavyImpact to CONTEXT_CLICK.
 *
 * Compose's own HapticFeedback cannot reach either. At this version it offers
 * exactly two types, LongPress and TextHandleMove, which land on LONG_PRESS
 * and TEXT_HANDLE_MOVE - so the port picked the nearest thing rather than the
 * right one. TEXT_HANDLE_MOVE is meant for dragging a text cursor, it is a
 * softer effect than a picker tick, and a fair few ROMs leave it silent, which
 * is why the strip could feel like it had lost its haptics altogether.
 *
 * Both constants are under minSdk here - CLOCK_TICK is API 21, CONTEXT_CLICK
 * API 23 - so neither needs the version guard the engine carries.
 */
fun View.selectionClick() {
    performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
}

fun View.heavyImpact() {
    performHapticFeedback(HapticFeedbackConstants.CONTEXT_CLICK)
}

/**
 * Click and long-press for a drawer tile, carrying the tick Material gave the
 * Flutter build for free.
 *
 * Its rows were ListTiles and its grid cells InkWells, and both route a long
 * press through InkResponse, which calls Feedback.forLongPress before the
 * callback unless enableFeedback is turned off - HapticFeedback.vibrate on
 * Android, so LONG_PRESS. Compose's combinedClickable does nothing of the kind
 * at this version, so long-pressing an app came back silent.
 *
 * One wrapper rather than a tick at each of the four tiles, so the next one
 * added cannot quietly miss it.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun Modifier.tileClickable(onClick: () -> Unit, onLongClick: () -> Unit): Modifier {
    val view = LocalView.current
    return combinedClickable(
        onClick = onClick,
        onLongClick = {
            view.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
            onLongClick()
        },
    )
}
