package com.kayfahaarukku.fuselauncher.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Apps
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.kayfahaarukku.fuselauncher.notifications.AppNotification
import com.kayfahaarukku.fuselauncher.notifications.shortAgo

private val TextColor = Color.White
private val SubtleColor = Color.White.copy(alpha = 0.7f)
private val DividerColor = Color.White.copy(alpha = 0.12f)

/**
 * Every notification an app is currently showing.
 *
 * Tapping a row fires that notification's own action and swiping it away
 * clears it, the way pulling down the shade would. Colours are the Flutter
 * build's fixed greys rather than the Material scheme, which tints surfaces
 * towards the primary colour and reads as the wrong grey next to the original.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationPopup(
    appName: String,
    icon: ImageBitmap?,
    notifications: List<AppNotification>,
    onOpen: (AppNotification) -> Unit,
    onDismissNotification: (AppNotification) -> Unit,
    onDismiss: () -> Unit,
) {
    // A copy: the caller's list is replaced wholesale on the next snapshot from
    // the shade, so a row swiped here should stay gone until then.
    var items by remember(notifications) { mutableStateOf(notifications) }
    val maxHeight = LocalConfiguration.current.screenHeightDp.dp * 0.7f

    LaunchedEffect(items) {
        if (items.isEmpty()) onDismiss()
    }

    Dialog(onDismissRequest = onDismiss) {
        Column(
            Modifier
                .padding(horizontal = 8.dp)
                .clip(RoundedCornerShape(20.dp))
                .background(PopupSurface)
                .heightIn(max = maxHeight),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 20.dp, top = 20.dp, end = 20.dp, bottom = 16.dp),
            ) {
                if (icon != null) {
                    Image(
                        bitmap = icon,
                        contentDescription = null,
                        modifier = Modifier.size(40.dp).clip(RoundedCornerShape(10.dp)),
                    )
                } else {
                    Box(
                        Modifier
                            .size(40.dp)
                            .clip(RoundedCornerShape(10.dp))
                            .background(Color(0xFF424242)),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(Icons.Filled.Apps, null, tint = TextColor, modifier = Modifier.size(22.dp))
                    }
                }
                Spacer(Modifier.width(15.dp))
                Column(Modifier.weight(1f)) {
                    Text(
                        appName,
                        color = TextColor,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(
                        "${items.size} notification${if (items.size == 1) "" else "s"}",
                        color = SubtleColor,
                        fontSize = 14.sp,
                    )
                }
            }

            PopupDivider()

            LazyColumn {
                items(items, key = { it.key }) { notification ->
                    val dismissState = rememberSwipeToDismissBoxState()

                    LaunchedEffect(dismissState.currentValue) {
                        if (dismissState.currentValue != SwipeToDismissBoxValue.Settled) {
                            onDismissNotification(notification)
                            items = items - notification
                        }
                    }

                    SwipeToDismissBox(
                        state = dismissState,
                        backgroundContent = {
                            Row(
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier
                                    .fillMaxSize()
                                    .background(BadgeRed.copy(alpha = 0.7f))
                                    .padding(horizontal = 24.dp),
                            ) {
                                Icon(Icons.Filled.Clear, "Dismiss", tint = Color.White)
                                Icon(Icons.Filled.Clear, "Dismiss", tint = Color.White)
                            }
                        },
                    ) {
                        NotificationRow(notification, appName) { onOpen(notification) }
                    }
                    PopupDivider()
                }
            }
        }
    }
}

@Composable
private fun PopupDivider() = Box(
    Modifier.fillMaxWidth().height(1.dp).background(DividerColor)
)

@Composable
private fun NotificationRow(
    notification: AppNotification,
    appName: String,
    onClick: () -> Unit,
) = Column(
    Modifier
        .fillMaxWidth()
        .background(PopupSurface)
        .clickable(onClick = onClick)
        .padding(horizontal = 20.dp, vertical = 8.dp),
) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(
            notification.title.ifEmpty { appName },
            color = TextColor,
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        Spacer(Modifier.width(8.dp))
        Text(shortAgo(notification.postTime), color = SubtleColor, fontSize = 12.sp)
    }
    if (notification.text.isNotEmpty()) {
        Text(
            notification.text,
            color = SubtleColor,
            fontSize = 14.sp,
            modifier = Modifier.padding(top = 4.dp),
        )
    }
}
