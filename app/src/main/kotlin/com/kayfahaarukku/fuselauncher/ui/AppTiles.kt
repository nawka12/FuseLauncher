package com.kayfahaarukku.fuselauncher.ui

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Apps
import androidx.compose.material.icons.filled.CheckBox
import androidx.compose.material.icons.filled.CheckBoxOutlineBlank
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.PushPin
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kayfahaarukku.fuselauncher.apps.LauncherApp
import com.kayfahaarukku.fuselauncher.data.Folder
import com.kayfahaarukku.fuselauncher.notifications.AppNotification
import com.kayfahaarukku.fuselauncher.notifications.shortAgo

/** Row metrics, kept together because the list and folder rows must agree. */
private val ICON = 56.dp
private val ICON_CORNER = 12.dp
private val ROW_PADDING_H = 16.dp
private val ROW_PADDING_V = 4.dp
private val Amber = Color(0xFFFFC107)

@Composable
fun AppIcon(icon: ImageBitmap?, label: String, size: androidx.compose.ui.unit.Dp = ICON) {
    if (icon != null) {
        Image(
            bitmap = icon,
            contentDescription = label,
            contentScale = ContentScale.Crop,
            modifier = Modifier.size(size).clip(RoundedCornerShape(ICON_CORNER)),
        )
    } else {
        Box(
            Modifier
                .size(size)
                .clip(RoundedCornerShape(ICON_CORNER))
                .background(Color(0xFF424242)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Filled.Apps, null, tint = Wallpaper.contentMuted, modifier = Modifier.size(28.dp))
        }
    }
}

/**
 * Unread count, red, overhanging the icon's top-right corner.
 *
 * The height is fixed rather than left to the text: a 12sp line box is taller
 * than it is wide, which turned the circle into an egg. Width has a matching
 * minimum so one digit is round, and only a longer count stretches it.
 */
@Composable
private fun NotificationBadge(count: Int, modifier: Modifier = Modifier) = Box(
    modifier
        .offset(x = 6.dp, y = (-6).dp)
        .height(BADGE_SIZE)
        .defaultMinSize(minWidth = BADGE_SIZE)
        .clip(CircleShape)
        .background(BadgeRed)
        .padding(horizontal = 4.dp),
    contentAlignment = Alignment.Center,
) {
    Text(
        if (count > 99) "99+" else count.toString(),
        color = Color.White,
        fontSize = 12.sp,
        lineHeight = 12.sp,
        fontWeight = FontWeight.SemiBold,
        maxLines = 1,
    )
}

private val BADGE_SIZE = 20.dp

/**
 * A row in the app list.
 *
 * Three shapes in one: a plain app, an app with a notification preview under
 * its name, and a tick box while the user is choosing what to hide.
 */
@OptIn(ExperimentalFoundationApi::class, ExperimentalMaterial3Api::class)
@Composable
fun AppListRow(
    app: LauncherApp,
    icon: ImageBitmap?,
    notifications: List<AppNotification>,
    showPreviews: Boolean,
    showBadges: Boolean,
    isPinned: Boolean,
    selected: Boolean?,
    onClick: () -> Unit,
    onLongClick: () -> Unit,
    onPreviewClick: () -> Unit,
) {
    val preview = remember(notifications, showPreviews, selected) {
        if (showPreviews && selected == null) notifications.firstOrNull { it.hasPreview } else null
    }

    val row: @Composable () -> Unit = {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .tileClickable(onClick = onClick, onLongClick = onLongClick)
            .padding(horizontal = ROW_PADDING_H, vertical = ROW_PADDING_V),
    ) {
        Box {
            AppIcon(icon, app.label)
            if (showBadges && notifications.isNotEmpty() && selected == null) {
                NotificationBadge(notifications.size, Modifier.align(Alignment.TopEnd))
            }
        }

        Spacer(Modifier.width(16.dp))

        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.Bottom) {
                Text(
                    app.label,
                    style = Wallpaper.style(
                        MaterialTheme.typography.bodyLarge.copy(
                            fontSize = 17.sp,
                            fontWeight = FontWeight.Medium,
                        )
                    ),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false),
                )
                if (preview != null) {
                    Text(
                        " · ${shortAgo(preview.postTime)}",
                        style = Wallpaper.style(
                            MaterialTheme.typography.bodySmall.copy(fontSize = 13.sp),
                            Wallpaper.contentMuted,
                        ),
                        maxLines = 1,
                    )
                }
            }

            if (preview != null) {
                if (preview.title.isNotEmpty()) {
                    Text(
                        preview.title,
                        style = Wallpaper.style(
                            MaterialTheme.typography.bodyMedium.copy(
                                fontSize = 14.sp,
                                fontWeight = FontWeight.Medium,
                            )
                        ),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                if (preview.text.isNotEmpty()) {
                    Text(
                        preview.text,
                        style = Wallpaper.style(
                            MaterialTheme.typography.bodySmall.copy(fontSize = 13.sp),
                            Wallpaper.contentMuted,
                        ),
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }

        when {
            selected != null -> Icon(
                if (selected) Icons.Filled.CheckBox else Icons.Filled.CheckBoxOutlineBlank,
                contentDescription = if (selected) "Hidden" else "Visible",
                tint = if (selected) MaterialTheme.colorScheme.primary else Wallpaper.contentMuted,
                modifier = Modifier.size(28.dp),
            )

            preview != null -> IconButton(onClick = onPreviewClick) {
                Icon(
                    Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = "Show notifications",
                    tint = Wallpaper.contentMuted,
                )
            }

            isPinned -> Icon(
                Icons.Filled.PushPin,
                contentDescription = "Pinned",
                tint = Wallpaper.contentMuted,
                modifier = Modifier.size(22.dp),
            )
        }
    }
    }

    if (preview == null) {
        row()
        return
    }

    // Opening the list is the whole action, so the row springs back rather than
    // leaving the list. Only the rightward direction is enabled, which leaves
    // leftward drags to the pager underneath.
    val dismissState = rememberSwipeToDismissBoxState(
        confirmValueChange = { value ->
            if (value == SwipeToDismissBoxValue.StartToEnd) onPreviewClick()
            false
        },
    )

    SwipeToDismissBox(
        state = dismissState,
        enableDismissFromEndToStart = false,
        backgroundContent = {
            Box(
                Modifier.fillMaxSize().padding(start = 28.dp),
                contentAlignment = Alignment.CenterStart,
            ) {
                Icon(
                    Icons.Filled.Notifications,
                    contentDescription = "Show notifications",
                    tint = Wallpaper.contentMuted,
                    modifier = Modifier.size(22.dp),
                )
            }
        },
    ) {
        row()
    }
}

/** Folder row: amber tile, name, and how many apps are inside. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun FolderListRow(
    folder: Folder,
    onClick: () -> Unit,
    onLongClick: () -> Unit,
) = Row(
    verticalAlignment = Alignment.CenterVertically,
    modifier = Modifier
        .fillMaxWidth()
        .tileClickable(onClick = onClick, onLongClick = onLongClick)
        .padding(horizontal = ROW_PADDING_H, vertical = ROW_PADDING_V),
) {
    Box(
        Modifier
            .size(ICON)
            .clip(RoundedCornerShape(ICON_CORNER))
            .background(Amber.copy(alpha = 0.1f)),
        contentAlignment = Alignment.Center,
    ) {
        Icon(Icons.Filled.Folder, null, tint = Amber, modifier = Modifier.size(32.dp))
    }

    Spacer(Modifier.width(16.dp))

    Column(Modifier.weight(1f)) {
        Text(
            folder.name,
            style = Wallpaper.style(
                MaterialTheme.typography.bodyLarge.copy(
                    fontSize = 17.sp,
                    fontWeight = FontWeight.Medium,
                )
            ),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        val count = folder.packageNames.size
        Text(
            "$count app${if (count == 1) "" else "s"}",
            style = Wallpaper.style(
                MaterialTheme.typography.bodyMedium.copy(fontSize = 14.sp),
                Wallpaper.contentMuted,
            ),
        )
    }
}

/** Header above a run of rows: "Pinned Apps", "Folders", or a single letter. */
@Composable
fun SectionHeader(title: String) = Text(
    title,
    style = Wallpaper.style(
        MaterialTheme.typography.titleLarge.copy(
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
        )
    ),
    modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp),
)

/** Thin rule between the pinned, folder and app runs. */
@Composable
fun SectionDivider() = Box(
    Modifier
        .fillMaxWidth()
        .padding(vertical = 4.dp)
        .height(1.dp)
        .background(Color.White.copy(alpha = 0.15f))
)

/** Cell in the grid layout: icon above a single-line name. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun AppGridCell(
    app: LauncherApp,
    icon: ImageBitmap?,
    notificationCount: Int,
    showBadges: Boolean,
    selected: Boolean?,
    onClick: () -> Unit,
    onLongClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Top,
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .tileClickable(onClick = onClick, onLongClick = onLongClick)
            .padding(vertical = 8.dp, horizontal = 2.dp),
    ) {
        Box {
            AppIcon(icon, app.label, size = 56.dp)
            when {
                selected != null -> Icon(
                    if (selected) Icons.Filled.CheckBox else Icons.Filled.CheckBoxOutlineBlank,
                    contentDescription = null,
                    tint = if (selected) MaterialTheme.colorScheme.primary else Wallpaper.contentMuted,
                    modifier = Modifier.align(Alignment.TopEnd).size(22.dp),
                )

                showBadges && notificationCount > 0 ->
                    NotificationBadge(notificationCount, Modifier.align(Alignment.TopEnd))
            }
        }
        Text(
            app.label,
            style = Wallpaper.style(
                MaterialTheme.typography.labelMedium.copy(fontSize = 13.sp)
            ),
            textAlign = TextAlign.Center,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(top = 8.dp),
        )
    }
}
