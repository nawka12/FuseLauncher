package com.kayfahaarukku.fuselauncher.ui

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kayfahaarukku.fuselauncher.data.Folder

private val Amber = Color(0xFFFFC107)

/** Folder in the grid layout, sized to match an app cell beside it. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun FolderGridCell(
    folder: Folder,
    onClick: () -> Unit,
    onLongClick: () -> Unit,
    modifier: Modifier = Modifier,
) = Column(
    horizontalAlignment = Alignment.CenterHorizontally,
    modifier = modifier
        .clip(RoundedCornerShape(12.dp))
        .tileClickable(onClick = onClick, onLongClick = onLongClick)
        .padding(vertical = 8.dp, horizontal = 2.dp),
) {
    Box(
        Modifier
            .size(56.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(Amber.copy(alpha = 0.1f)),
        contentAlignment = Alignment.Center,
    ) {
        Icon(Icons.Filled.Folder, null, tint = Amber, modifier = Modifier.size(32.dp))
    }
    Text(
        folder.name,
        style = Wallpaper.style(MaterialTheme.typography.labelMedium.copy(fontSize = 13.sp)),
        textAlign = TextAlign.Center,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        modifier = Modifier.padding(top = 8.dp),
    )
}
