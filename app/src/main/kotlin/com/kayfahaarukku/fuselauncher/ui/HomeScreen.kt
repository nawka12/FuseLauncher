package com.kayfahaarukku.fuselauncher.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyGridState
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Sort
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.TabRowDefaults.tabIndicatorOffset
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.lerp
import androidx.compose.ui.unit.sp
import com.kayfahaarukku.fuselauncher.apps.LauncherApp
import com.kayfahaarukku.fuselauncher.data.AppLayoutType
import com.kayfahaarukku.fuselauncher.data.Folder
import kotlin.math.absoluteValue
import kotlin.math.roundToInt
import androidx.compose.ui.util.lerp
import kotlinx.coroutines.launch

/**
 * The drawer: a single scrolling column of "Pinned Apps", "Folders" and the
 * A-Z sections, an index strip down the right, and the search bar at whichever
 * end the user chose.
 *
 * Pinned apps are full-width rows like any other, not a separate icon strip -
 * they read as the top of one list rather than a second widget.
 */
@Composable
fun AppsPane(
    state: HomeState,
    prefs: Prefs,
    hiddenMode: HiddenMode,
    iconFor: (LauncherApp) -> ImageBitmap?,
    onLaunch: (LauncherApp) -> Unit,
    onLongPress: (LauncherApp) -> Unit,
    onShowNotifications: (LauncherApp) -> Unit,
    onToggleHidden: (LauncherApp) -> Unit,
    onOpenFolder: (Folder) -> Unit,
    onFolderLongPress: (Folder) -> Unit,
    onSearch: (String) -> Unit,
    onSort: () -> Unit,
    onSettings: () -> Unit,
    onSwipeRight: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val listState = rememberLazyListState()
    val gridState = rememberLazyGridState()
    val scope = rememberCoroutineScope()
    var hintLetter by remember { mutableStateOf<String?>(null) }
    var hintVisible by remember { mutableStateOf(false) }

    val jumpTargets = remember(state.sections, state.pinned, state.folders, prefs.layout) {
        indexTargets(state, prefs)
    }

    fun jumpTo(letter: String) {
        hintLetter = letter
        val target = jumpTargets[letter] ?: return
        scope.launch {
            if (prefs.layout == AppLayoutType.GRID) gridState.scrollToItem(target)
            else listState.scrollToItem(target)
        }
    }

    Column(
        modifier
            .fillMaxSize()
            .observeRightSwipes(enabled = hiddenMode == HiddenMode.OFF, onSwipeRight = onSwipeRight)
    ) {
        if (prefs.searchBarAtTop) {
            SearchBar(state.query, hiddenMode, onSearch, onSort, onSettings)
        }

        Box(Modifier.weight(1f)) {
            Row(Modifier.fillMaxSize()) {
                Box(Modifier.weight(1f)) {
                    if (prefs.layout == AppLayoutType.GRID) {
                        AppsGrid(
                            state, prefs, hiddenMode, gridState, iconFor,
                            onLaunch, onLongPress, onToggleHidden,
                            onOpenFolder, onFolderLongPress,
                        )
                    } else {
                        AppsList(
                            state, prefs, hiddenMode, listState, iconFor,
                            onLaunch, onLongPress, onShowNotifications, onToggleHidden,
                            onOpenFolder, onFolderLongPress,
                        )
                    }
                }

                if (state.query.isEmpty() && state.indexLetters.size > 1) {
                    AlphabetIndexBar(
                        letters = state.indexLetters,
                        onSelected = ::jumpTo,
                        onDragging = { hintVisible = it },
                        modifier = Modifier.padding(vertical = 8.dp),
                    )
                }
            }

            SectionHint(
                letter = hintLetter,
                visible = hintVisible,
                modifier = Modifier.align(Alignment.CenterEnd).padding(end = 44.dp),
            )
        }

        if (!prefs.searchBarAtTop) {
            SearchBar(state.query, hiddenMode, onSearch, onSort, onSettings)
        }
    }
}

@Composable
private fun AppsList(
    state: HomeState,
    prefs: Prefs,
    hiddenMode: HiddenMode,
    listState: LazyListState,
    iconFor: (LauncherApp) -> ImageBitmap?,
    onLaunch: (LauncherApp) -> Unit,
    onLongPress: (LauncherApp) -> Unit,
    onShowNotifications: (LauncherApp) -> Unit,
    onToggleHidden: (LauncherApp) -> Unit,
    onOpenFolder: (Folder) -> Unit,
    onFolderLongPress: (Folder) -> Unit,
) = LazyColumn(state = listState) {

    fun LazyListScope.appRows(apps: List<LauncherApp>, pinnedRun: Boolean) =
        items(apps, key = { if (pinnedRun) "p-${it.key}" else it.key }) { app ->
            AppListRow(
                app = app,
                icon = iconFor(app),
                notifications = state.notifications[app.packageName].orEmpty(),
                showPreviews = prefs.showPreviews,
                showBadges = prefs.showBadges,
                isPinned = pinnedRun,
                selected = if (hiddenMode == HiddenMode.SELECTING) {
                    app.packageName in state.hidden
                } else null,
                onClick = {
                    if (hiddenMode == HiddenMode.SELECTING) onToggleHidden(app) else onLaunch(app)
                },
                onLongClick = { onLongPress(app) },
                onPreviewClick = { onShowNotifications(app) },
            )
        }

    if (state.pinned.isNotEmpty()) {
        item(key = "h-pinned") { SectionHeader("Pinned Apps") }
        appRows(state.pinned, pinnedRun = true)
        if (state.folders.isNotEmpty()) item(key = "d-pinned") { SectionDivider() }
    }

    if (state.folders.isNotEmpty()) {
        item(key = "h-folders") { SectionHeader("Folders") }
        items(state.folders, key = { "f-${it.id}" }) { folder ->
            FolderListRow(folder, { onOpenFolder(folder) }, { onFolderLongPress(folder) })
        }
        item(key = "d-folders") { SectionDivider() }
    }

    state.sections.forEach { section ->
        if (section.letter.isNotEmpty()) {
            item(key = "h-${section.letter}") { SectionHeader(section.letter) }
        }
        appRows(section.apps, pinnedRun = false)
    }

    item { Spacer(Modifier.height(16.dp)) }
}

@Composable
private fun AppsGrid(
    state: HomeState,
    prefs: Prefs,
    hiddenMode: HiddenMode,
    gridState: LazyGridState,
    iconFor: (LauncherApp) -> ImageBitmap?,
    onLaunch: (LauncherApp) -> Unit,
    onLongPress: (LauncherApp) -> Unit,
    onToggleHidden: (LauncherApp) -> Unit,
    onOpenFolder: (Folder) -> Unit,
    onFolderLongPress: (Folder) -> Unit,
) = LazyVerticalGrid(
    columns = GridCells.Fixed(prefs.gridColumns),
    state = gridState,
    contentPadding = PaddingValues(horizontal = 8.dp),
) {
    if (state.pinned.isNotEmpty()) {
        item(key = "h-pinned", span = { GridItemSpan(maxLineSpan) }) {
            SectionHeader("Pinned Apps")
        }
        items(state.pinned, key = { "p-${it.key}" }) { app ->
            AppGridCell(
                app = app,
                icon = iconFor(app),
                notificationCount = state.notifications[app.packageName].orEmpty().size,
                showBadges = prefs.showBadges,
                selected = null,
                onClick = { onLaunch(app) },
                onLongClick = { onLongPress(app) },
            )
        }
    }

    if (state.folders.isNotEmpty()) {
        item(key = "h-folders", span = { GridItemSpan(maxLineSpan) }) {
            SectionHeader("Folders")
        }
        items(state.folders, key = { "f-${it.id}" }) { folder ->
            FolderGridCell(folder, { onOpenFolder(folder) }, { onFolderLongPress(folder) })
        }
    }

    state.sections.forEach { section ->
        if (section.letter.isNotEmpty()) {
            item(key = "h-${section.letter}", span = { GridItemSpan(maxLineSpan) }) {
                SectionHeader(section.letter)
            }
        }
        items(section.apps, key = { it.key }) { app ->
            AppGridCell(
                app = app,
                icon = iconFor(app),
                notificationCount = state.notifications[app.packageName].orEmpty().size,
                showBadges = prefs.showBadges,
                selected = if (hiddenMode == HiddenMode.SELECTING) {
                    app.packageName in state.hidden
                } else null,
                onClick = {
                    if (hiddenMode == HiddenMode.SELECTING) onToggleHidden(app) else onLaunch(app)
                },
                onLongClick = { onLongPress(app) },
            )
        }
    }

    item(span = { GridItemSpan(maxLineSpan) }) { Spacer(Modifier.height(16.dp)) }
}

/**
 * Search bar, with sort and settings tucked inside it rather than beside it.
 * Once there is text to clear, the clear button takes their place.
 */
@Composable
private fun SearchBar(
    query: String,
    hiddenMode: HiddenMode,
    onSearch: (String) -> Unit,
    onSort: () -> Unit,
    onSettings: () -> Unit,
) = Box(Modifier.padding(horizontal = 20.dp, vertical = 12.dp)) {
    TextField(
        value = query,
        onValueChange = onSearch,
        textStyle = TextStyle(fontSize = 16.sp, color = Color.White),
        placeholder = {
            Text(
                when (hiddenMode) {
                    HiddenMode.SELECTING -> "Search apps to hide..."
                    HiddenMode.VIEWING -> "Search hidden apps..."
                    HiddenMode.OFF -> "Search apps..."
                },
                fontSize = 16.sp,
                color = Color.White.copy(alpha = 0.5f),
            )
        },
        leadingIcon = {
            Icon(
                Icons.Filled.Search,
                contentDescription = null,
                tint = Color.White.copy(alpha = 0.7f),
                modifier = Modifier.size(22.dp),
            )
        },
        trailingIcon = {
            when {
                query.isNotEmpty() -> IconButton(onClick = { onSearch("") }) {
                    Icon(
                        Icons.Filled.Clear,
                        "Clear",
                        tint = Color.White.copy(alpha = 0.7f),
                        modifier = Modifier.size(22.dp),
                    )
                }

                hiddenMode == HiddenMode.OFF -> Row {
                    IconButton(onClick = onSort) {
                        Icon(
                            Icons.Filled.Sort,
                            "Sort",
                            tint = Color.White.copy(alpha = 0.7f),
                            modifier = Modifier.size(22.dp),
                        )
                    }
                    IconButton(onClick = onSettings) {
                        Icon(
                            Icons.Filled.Settings,
                            "Settings",
                            tint = Color.White.copy(alpha = 0.7f),
                            modifier = Modifier.size(22.dp),
                        )
                    }
                }
            }
        },
        singleLine = true,
        shape = RoundedCornerShape(16.dp),
        colors = TextFieldDefaults.colors(
            focusedContainerColor = SEARCH_FILL,
            unfocusedContainerColor = SEARCH_FILL,
            focusedIndicatorColor = Color.Transparent,
            unfocusedIndicatorColor = Color.Transparent,
            cursorColor = Color.White,
        ),
        modifier = Modifier.fillMaxWidth(),
    )
}

private val SEARCH_FILL = Color(0xFF2D2D2D)

/**
 * Tab strip above the two panes: a translucent pill with a lighter selection.
 *
 * [position] is the pager's fractional page, so the highlight travels with the
 * drag rather than snapping once the page settles.
 */
@Composable
fun HomeTabs(position: Float, onSelect: (HomeTab) -> Unit) {
    val settled = position.roundToInt().coerceIn(0, HomeTab.entries.lastIndex)

    Box(
        Modifier
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(Color.White.copy(alpha = 0.1f)),
    ) {
        TabRow(
            selectedTabIndex = settled,
            containerColor = Color.Transparent,
            contentColor = Color.White,
            indicator = { positions ->
                val from = position.toInt().coerceIn(0, positions.lastIndex)
                val to = (from + 1).coerceAtMost(positions.lastIndex)
                val progress = position - from

                Box(
                    Modifier
                        .wrapContentSize(Alignment.BottomStart)
                        .offset(x = lerp(positions[from].left, positions[to].left, progress))
                        .width(lerp(positions[from].width, positions[to].width, progress))
                        .fillMaxHeight()
                        .padding(2.dp)
                        .clip(RoundedCornerShape(10.dp))
                        .background(Color.White.copy(alpha = 0.2f))
                )
            },
            divider = {},
        ) {
            HomeTab.entries.forEach { entry ->
                Tab(
                    selected = entry.ordinal == settled,
                    onClick = { onSelect(entry) },
                    text = {
                        Text(
                            if (entry == HomeTab.APPS) "Apps" else "Widgets",
                            textAlign = TextAlign.Center,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Medium,
                            // Fades between the two as the pager moves, so the
                            // label brightens in step with the highlight.
                            color = Color.White.copy(
                                alpha = lerp(
                                    0.5f, 1f,
                                    (1f - (position - entry.ordinal).absoluteValue).coerceIn(0f, 1f),
                                )
                            ),
                        )
                    },
                )
            }
        }
    }
}

/**
 * First list index for each index-strip letter. The grid packs several apps
 * into a row, so its item indices are not the list's.
 */
private fun indexTargets(state: HomeState, prefs: Prefs): Map<String, Int> {
    val targets = mutableMapOf<String, Int>()
    var index = 0
    val grid = prefs.layout == AppLayoutType.GRID
    val columns = prefs.gridColumns

    fun rowsFor(count: Int) = if (grid) (count + columns - 1) / columns else count

    if (state.pinned.isNotEmpty()) {
        targets[TOP_INDEX_LETTER] = 0
        index += 1 + rowsFor(state.pinned.size)
        if (!grid && state.folders.isNotEmpty()) index++ // divider
    }
    if (state.folders.isNotEmpty()) {
        targets.putIfAbsent(TOP_INDEX_LETTER, index)
        index += 1 + rowsFor(state.folders.size)
        if (!grid) index++ // divider
    }

    state.sections.forEach { section ->
        if (section.letter.isNotEmpty()) {
            targets[section.letter] = index
            index++
        }
        index += rowsFor(section.apps.size)
    }
    return targets
}


/**
 * Reports a rightward drag across a fifth of the width, watching the Initial
 * pass and never consuming: the pager and the rows' own swipe handlers must
 * still see every event, so this can only observe.
 */
private fun Modifier.observeRightSwipes(
    enabled: Boolean,
    threshold: Float = 0.2f,
    onSwipeRight: () -> Unit,
): Modifier = this.pointerInput(enabled) {
    if (!enabled) return@pointerInput
    awaitPointerEventScope {
        while (true) {
            var pointerId = awaitPointerEvent(PointerEventPass.Initial)
                .changes.firstOrNull { it.pressed }?.id ?: continue
            var travelled = 0f
            var fired = false
            while (true) {
                val change = awaitPointerEvent(PointerEventPass.Initial)
                    .changes.firstOrNull { it.id == pointerId } ?: break
                if (!change.pressed) break
                travelled += change.position.x - change.previousPosition.x
                if (!fired && travelled > size.width * threshold) {
                    fired = true
                    onSwipeRight()
                }
            }
        }
    }
}
