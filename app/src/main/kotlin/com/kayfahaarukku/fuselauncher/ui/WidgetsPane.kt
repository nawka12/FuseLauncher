package com.kayfahaarukku.fuselauncher.ui

import android.appwidget.AppWidgetHostView
import android.view.ViewGroup
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.DeleteSweep
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.Reorder
import androidx.compose.material.icons.filled.UnfoldLess
import androidx.compose.material.icons.filled.UnfoldMore
import androidx.compose.material.icons.filled.Widgets
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.kayfahaarukku.fuselauncher.widgets.HostedWidget
import com.kayfahaarukku.fuselauncher.widgets.WidgetProvider

private val Purple = Color(0xFF6750A4)

/**
 * The widgets tab: hosted widgets in the order the user arranged them, an add
 * button in the corner, and a long-press menu for reordering or clearing.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun WidgetsPane(
    widgets: List<HostedWidget>,
    heights: Map<Int, Int>,
    reordering: Boolean,
    viewFor: (Int, Int) -> AppWidgetHostView?,
    defaultHeightFor: (HostedWidget) -> Int,
    onResize: (Int, Int) -> Unit,
    onMove: (Int, Int) -> Unit,
    onRemove: (Int) -> Unit,
    onStartReorder: () -> Unit,
    onDoneReorder: () -> Unit,
    onRemoveAll: () -> Unit,
    onAdd: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var menuOpen by remember { mutableStateOf(false) }
    val haptics = LocalHapticFeedback.current

    Box(
        modifier
            .fillMaxSize()
            .combinedClickable(
                enabled = widgets.isNotEmpty() && !reordering,
                indication = null,
                interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() },
                onClick = {},
                onLongClick = {
                    haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                    menuOpen = true
                },
            ),
    ) {
        Column(Modifier.fillMaxSize()) {
            if (reordering) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
                ) {
                    Text(
                        "Reorder Widgets",
                        style = Wallpaper.style(MaterialTheme.typography.titleMedium),
                        modifier = Modifier.weight(1f),
                    )
                    TextButton(onClick = onDoneReorder) {
                        Text("Done", style = Wallpaper.style(MaterialTheme.typography.labelLarge))
                    }
                }
            }

            if (widgets.isEmpty()) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            "No widgets added",
                            style = Wallpaper.style(
                                MaterialTheme.typography.bodyLarge.copy(fontSize = 16.sp)
                            ),
                        )
                        Spacer(Modifier.height(16.dp))
                        Button(onClick = onAdd) { Text("Add Widget") }
                    }
                }
                return@Column
            }

            LazyColumn(
                contentPadding = PaddingValues(16.dp).let {
                    PaddingValues(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 96.dp)
                },
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                itemsIndexed(widgets, key = { _, w -> w.widgetId }) { index, widget ->
                    WidgetCard(
                        widget = widget,
                        heightPx = heights[widget.widgetId],
                        defaultHeightFor = defaultHeightFor,
                        reordering = reordering,
                        canMoveUp = index > 0,
                        canMoveDown = index < widgets.lastIndex,
                        viewFor = viewFor,
                        onResize = { onResize(widget.widgetId, it) },
                        onMoveUp = { onMove(index, index - 1) },
                        onMoveDown = { onMove(index, index + 1) },
                        onRemove = { onRemove(widget.widgetId) },
                    )
                }
            }
        }

        if (!reordering) {
            FloatingActionButton(
                onClick = onAdd,
                containerColor = Purple,
                contentColor = Color.White,
                modifier = Modifier.align(Alignment.BottomEnd).padding(16.dp),
            ) {
                Icon(Icons.Filled.Add, contentDescription = "Add widget")
            }
        }
    }

    if (menuOpen) {
        WidgetsMenuSheet(
            onReorder = { menuOpen = false; onStartReorder() },
            onRemoveAll = { menuOpen = false; onRemoveAll() },
            onDismiss = { menuOpen = false },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun WidgetsMenuSheet(
    onReorder: () -> Unit,
    onRemoveAll: () -> Unit,
    onDismiss: () -> Unit,
) = ModalBottomSheet(onDismissRequest = onDismiss) {
    Column(Modifier.navigationBarsPadding()) {
        ListItem(
            headlineContent = { Text("Reorder Widgets") },
            leadingContent = { Icon(Icons.Filled.Reorder, null) },
            colors = ListItemDefaults.colors(containerColor = Color.Transparent),
            modifier = Modifier.clickable(onClick = onReorder),
        )
        ListItem(
            headlineContent = { Text("Remove All Widgets") },
            leadingContent = {
                Icon(Icons.Filled.DeleteSweep, null, tint = Color(0xFFE53935))
            },
            colors = ListItemDefaults.colors(containerColor = Color.Transparent),
            modifier = Modifier.clickable(onClick = onRemoveAll),
        )
    }
}

@Composable
private fun WidgetCard(
    widget: HostedWidget,
    heightPx: Int?,
    defaultHeightFor: (HostedWidget) -> Int,
    reordering: Boolean,
    canMoveUp: Boolean,
    canMoveDown: Boolean,
    viewFor: (Int, Int) -> AppWidgetHostView?,
    onResize: (Int) -> Unit,
    onMoveUp: () -> Unit,
    onMoveDown: () -> Unit,
    onRemove: () -> Unit,
) {
    val density = LocalDensity.current
    val height = heightPx ?: defaultHeightFor(widget)
    val heightDp = with(density) { height.toDp() }

    Column {
        Box(
            Modifier
                .fillMaxWidth()
                .height(heightDp)
                .clip(RoundedCornerShape(10.dp))
                .background(Color.White.copy(alpha = 0.1f)),
        ) {
            // Host views are cached and reused across scrolls, so one may still
            // be attached to the container it had last time. Detach it first or
            // AndroidView throws on the second bind. The height goes to the view
            // itself as well, or the widget paints only its minimum.
            AndroidView(
                factory = { context ->
                    val host = viewFor(widget.widgetId, height)
                    (host?.parent as? ViewGroup)?.removeView(host)
                    host ?: android.widget.FrameLayout(context)
                },
                update = { viewFor(widget.widgetId, height) },
                modifier = Modifier.fillMaxSize(),
            )
        }

        // Controls sit under the widget, not over it: widgets are mostly dark,
        // and a translucent overlay on a dark widget is unreadable as well as
        // being in the way of what it is controlling.
        if (reordering) {
            Row(
                horizontalArrangement = Arrangement.End,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 4.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(Color.Black.copy(alpha = 0.75f)),
            ) {
                ControlButton(Icons.Filled.KeyboardArrowUp, "Move up", canMoveUp, onClick = onMoveUp)
                ControlButton(
                    Icons.Filled.KeyboardArrowDown, "Move down", canMoveDown,
                    onClick = onMoveDown,
                )
                ControlButton(Icons.Filled.UnfoldLess, "Shorter", true) {
                    onResize(height - RESIZE_STEP_PX)
                }
                ControlButton(Icons.Filled.UnfoldMore, "Taller", true) {
                    onResize(height + RESIZE_STEP_PX)
                }
                ControlButton(Icons.Filled.Close, "Remove", true, tint = Color(0xFFFF8A80)) {
                    onRemove()
                }
            }
        }
    }
}

@Composable
private fun ControlButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    enabled: Boolean,
    tint: Color = Color.White,
    onClick: () -> Unit,
) = IconButton(onClick = onClick, enabled = enabled) {
    Icon(
        icon,
        contentDescription = label,
        tint = if (enabled) tint else Color.White.copy(alpha = 0.3f),
    )
}

// ponytail: buttons, not drag-and-drop. Compose has no reorderable list; swap
// in a drag gesture if reordering long lists gets tedious.
private const val RESIZE_STEP_PX = 120

/** Picker for a new widget, searchable by app or widget name. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddWidgetSheet(
    providers: List<WidgetProvider>,
    onPick: (WidgetProvider) -> Unit,
    onDismiss: () -> Unit,
) {
    var query by remember { mutableStateOf("") }
    val matches = remember(providers, query) {
        if (query.isBlank()) providers
        else providers.filter {
            it.label.contains(query, ignoreCase = true) ||
                it.appName.contains(query, ignoreCase = true)
        }
    }

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(Modifier.navigationBarsPadding().heightIn(max = 560.dp)) {
            OutlinedTextField(
                value = query,
                onValueChange = { query = it },
                label = { Text("Search widgets") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
            )
            LazyColumn {
                items(matches, key = { it.provider }) { provider ->
                    ListItem(
                        headlineContent = { Text(provider.label.ifBlank { provider.appName }) },
                        supportingContent = {
                            Text("${provider.appName} · ${provider.minWidth}×${provider.minHeight}")
                        },
                        leadingContent = { Icon(Icons.Filled.Widgets, null) },
                        colors = ListItemDefaults.colors(containerColor = Color.Transparent),
                        modifier = Modifier.clickable { onPick(provider) },
                    )
                }
            }
        }
    }
}
