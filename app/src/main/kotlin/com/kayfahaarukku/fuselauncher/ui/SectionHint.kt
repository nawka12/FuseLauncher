package com.kayfahaarukku.fuselauncher.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Big letter badge shown while the index strip is being dragged. It sits away
 * from the strip so the finger doing the dragging never covers it.
 */
@Composable
fun SectionHint(letter: String?, visible: Boolean, modifier: Modifier = Modifier) {
    AnimatedVisibility(
        visible = visible && !letter.isNullOrEmpty(),
        enter = fadeIn(),
        exit = fadeOut(),
        modifier = modifier,
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(64.dp)
                .background(Color.Black.copy(alpha = 0.6f), RoundedCornerShape(18.dp)),
        ) {
            Text(
                letter.orEmpty(),
                color = Color.White,
                fontSize = 32.sp,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}
