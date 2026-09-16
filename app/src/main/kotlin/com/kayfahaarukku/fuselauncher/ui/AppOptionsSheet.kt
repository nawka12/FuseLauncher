package com.kayfahaarukku.fuselauncher.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.PushPin
import androidx.compose.material.icons.outlined.FolderOff
import androidx.compose.material.icons.outlined.FolderOpen
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.PushPin
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.kayfahaarukku.fuselauncher.apps.LauncherApp

/** What the long-press sheet can do to an app. */
sealed interface AppAction {
    data object TogglePin : AppAction
    data object Hide : AppAction
    data object Unhide : AppAction
    data object Uninstall : AppAction
    data object AppInfo : AppAction
    data object MoveToFolder : AppAction
    data object RemoveFromFolder : AppAction
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AppOptionsSheet(
    app: LauncherApp,
    icon: ImageBitmap?,
    isPinned: Boolean,
    isHidden: Boolean,
    isSystemApp: Boolean,
    inFolder: String?,
    onAction: (AppAction) -> Unit,
    onDismiss: () -> Unit,
) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(Modifier.navigationBarsPadding()) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp),
            ) {
                if (icon != null) {
                    Image(
                        bitmap = icon,
                        contentDescription = null,
                        modifier = Modifier.size(40.dp).clip(RoundedCornerShape(8.dp)),
                    )
                } else {
                    Spacer(Modifier.size(40.dp))
                }
                Spacer(Modifier.width(15.dp))
                Column(Modifier.weight(1f)) {
                    Text(
                        app.label,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(
                        app.packageName,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }

            if (isHidden) {
                SheetItem(Icons.Outlined.Visibility, "Unhide app") { onAction(AppAction.Unhide) }
            }

            // Hiding a pinned app would leave a pin pointing at something the
            // drawer no longer shows, so pinning is offered only while visible.
            if (!isHidden) {
                SheetItem(
                    if (isPinned) Icons.Filled.PushPin else Icons.Outlined.PushPin,
                    if (isPinned) "Unpin" else "Pin to top",
                ) { onAction(AppAction.TogglePin) }

                SheetItem(Icons.Outlined.VisibilityOff, "Hide app") { onAction(AppAction.Hide) }
            }

            if (!isSystemApp) {
                SheetItem(Icons.Filled.Delete, "Uninstall", Color(0xFFE53935)) {
                    onAction(AppAction.Uninstall)
                }
            }

            SheetItem(Icons.Outlined.Info, "App info") { onAction(AppAction.AppInfo) }

            if (inFolder != null) {
                SheetItem(Icons.Outlined.FolderOff, "Remove from $inFolder") {
                    onAction(AppAction.RemoveFromFolder)
                }
            } else if (!isHidden) {
                SheetItem(Icons.Outlined.FolderOpen, "Move to folder") {
                    onAction(AppAction.MoveToFolder)
                }
            }
        }
    }
}

@Composable
private fun SheetItem(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    tint: Color = MaterialTheme.colorScheme.onSurface,
    onClick: () -> Unit,
) = ListItem(
    headlineContent = { Text(label) },
    leadingContent = { Icon(icon, contentDescription = null, tint = tint) },
    colors = ListItemDefaults.colors(containerColor = Color.Transparent),
    modifier = Modifier.clickable(onClick = onClick),
)
