package com.kayfahaarukku.fuselauncher.ui

import android.content.Intent
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.pager.HorizontalPager
import com.kayfahaarukku.fuselauncher.ui.HomeTab
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.kayfahaarukku.fuselauncher.apps.DoubleSwipe
import com.kayfahaarukku.fuselauncher.apps.LauncherApp
import com.kayfahaarukku.fuselauncher.data.Folder
import com.kayfahaarukku.fuselauncher.notifications.AppNotification
import kotlinx.coroutines.launch

/** Modal layered over the drawer; only one is ever open. */
private sealed interface Overlay {
    data class Options(val app: LauncherApp) : Overlay
    data object Sort : Overlay
    data class MoveToFolder(val app: LauncherApp) : Overlay
    data class NewFolder(val app: LauncherApp?) : Overlay
    data class RenameFolder(val folder: Folder) : Overlay
    data class DeleteFolder(val folder: Folder) : Overlay
    data object AddWidget : Overlay
    data object RemoveAllWidgets : Overlay
    data class Notifications(val app: LauncherApp) : Overlay
}

@Composable
fun LauncherRoot(
    viewModel: HomeViewModel,
    versionName: String,
    versionCode: Long,
    onAuthenticate: suspend () -> Boolean,
    onChangeWallpaper: () -> Unit,
    hasNotificationAccess: () -> Boolean,
    onRequestNotificationAccess: () -> Unit,
    onLaunchIntent: (Intent) -> Unit,
    onBindWidget: (String) -> Unit,
    onOpenNotification: (String) -> Unit,
    onDismissNotification: (String) -> Unit,
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val prefs by viewModel.prefs.collectAsStateWithLifecycle()
    val screen by viewModel.screen.collectAsStateWithLifecycle()
    val tab by viewModel.tab.collectAsStateWithLifecycle()
    val hiddenMode by viewModel.hiddenMode.collectAsStateWithLifecycle()
    val openFolder by viewModel.openFolder.collectAsStateWithLifecycle()
    val widgets by viewModel.widgets.collectAsStateWithLifecycle()
    val widgetHeights by viewModel.widgetHeights.collectAsStateWithLifecycle()
    val reordering by viewModel.reorderingWidgets.collectAsStateWithLifecycle()

    var overlay by remember { mutableStateOf<Overlay?>(null) }
    val hiddenAppsSwipe = remember { DoubleSwipe() }
    val pagerState = rememberPagerState(initialPage = tab.ordinal) { HomeTab.entries.size }

    // Two-way sync. The pager drives the tab off settledPage so a half-finished
    // drag does not flip it, and the tab drives the pager only when they have
    // actually diverged, which keeps the two effects from chasing each other.
    LaunchedEffect(pagerState.settledPage) {
        viewModel.tab.value = HomeTab.entries[pagerState.settledPage]
    }
    LaunchedEffect(tab) {
        if (pagerState.currentPage != tab.ordinal) pagerState.animateScrollToPage(tab.ordinal)
    }
    val snackbars = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    fun notify(message: String) = scope.launch { snackbars.showSnackbar(message) }

    // Back unwinds one layer at a time and never leaves the launcher: on the
    // bare drawer there is nowhere to go, so it is simply swallowed.
    BackHandler(enabled = true) {
        when {
            overlay != null -> overlay = null
            openFolder != null -> viewModel.openFolder.value = null
            screen != Screen.HOME -> viewModel.screen.value =
                if (screen == Screen.ABOUT) Screen.SETTINGS else Screen.HOME
            hiddenMode != HiddenMode.OFF -> {
                viewModel.hiddenMode.value = HiddenMode.OFF
                viewModel.search("")
            }
            state.query.isNotEmpty() -> viewModel.search("")
            tab != HomeTab.APPS -> viewModel.tab.value = HomeTab.APPS
            else -> Unit
        }
    }

    // Settings and About slide and fade the way the Flutter build's page
    // transitions did; going back runs the same motion in reverse.
    AnimatedContent(
        targetState = screen,
        transitionSpec = {
            val forward = targetState.ordinal > initialState.ordinal
            val offset = if (forward) 1 else -1
            (
                slideInHorizontally(tween(PAGE_MS)) { it / 4 * offset } +
                    fadeIn(tween(PAGE_MS))
                ) togetherWith (
                slideOutHorizontally(tween(PAGE_MS)) { it / 4 * -offset } +
                    fadeOut(tween(PAGE_MS))
                )
        },
        label = "screen",
    ) { current ->
    when (current) {
        Screen.SETTINGS -> SettingsScreen(
            state = SettingsState(
                searchBarAtTop = prefs.searchBarAtTop,
                layout = prefs.layout,
                gridColumns = prefs.gridColumns,
                showNotificationBadges = prefs.showBadges,
                showNotificationPreviews = prefs.showPreviews,
                hiddenAppCount = state.hidden.size,
                notificationAccess = hasNotificationAccess(),
            ),
            onSearchBarAtTop = viewModel::setSearchBarAtTop,
            onLayout = viewModel::setLayout,
            onGridColumns = viewModel::setGridColumns,
            onBadges = viewModel::setShowBadges,
            onPreviews = viewModel::setShowPreviews,
            onRequestNotificationAccess = onRequestNotificationAccess,
            onManageHidden = {
                viewModel.screen.value = Screen.HOME
                viewModel.hiddenMode.value = HiddenMode.SELECTING
            },
            onChangeWallpaper = onChangeWallpaper,
            onAbout = { viewModel.screen.value = Screen.ABOUT },
            onBack = { viewModel.screen.value = Screen.HOME },
        )

        Screen.ABOUT -> AboutScreen(
            versionName = versionName,
            versionCode = versionCode,
            onBack = { viewModel.screen.value = Screen.SETTINGS },
        )

        Screen.HOME -> Box(Modifier.fillMaxSize()) {
            Column(Modifier.fillMaxSize()) {
                when (hiddenMode) {
                    HiddenMode.OFF -> HomeTabs(
                        position = pagerState.currentPage + pagerState.currentPageOffsetFraction,
                    ) { viewModel.tab.value = it }

                    // Finishing the selection needs authentication, so a
                    // passer-by cannot reveal the list by tapping Done.
                    HiddenMode.SELECTING -> HiddenModeBar("Select apps to hide", "Done") {
                        scope.launch {
                            if (onAuthenticate()) {
                                viewModel.hiddenMode.value = HiddenMode.VIEWING
                                viewModel.search("")
                            }
                        }
                    }

                    HiddenMode.VIEWING -> HiddenModeBar("Hidden apps", "Edit") {
                        viewModel.hiddenMode.value = HiddenMode.SELECTING
                        viewModel.search("")
                    }
                }

                val folder = openFolder
                when {
                    folder != null -> FolderPane(
                        folder = folder,
                        apps = viewModel.appsIn(folder),
                        notifications = state.notifications,
                        prefs = prefs,
                        iconFor = viewModel::icon,
                        onLaunch = viewModel::launch,
                        onLongPress = { overlay = Overlay.Options(it) },
                        onBack = { viewModel.openFolder.value = null },
                        onRename = { overlay = Overlay.RenameFolder(folder) },
                        onDelete = { overlay = Overlay.DeleteFolder(folder) },
                        modifier = Modifier.weight(1f),
                    )

                    // Choosing or viewing hidden apps is a mode, not a tab:
                    // there is no widgets page to swipe to from it.
                    hiddenMode != HiddenMode.OFF -> AppsPane(
                        state = state,
                        prefs = prefs,
                        hiddenMode = hiddenMode,
                        iconFor = viewModel::icon,
                        onLaunch = viewModel::launch,
                        onLongPress = { overlay = Overlay.Options(it) },
                        onShowNotifications = { overlay = Overlay.Notifications(it) },
                        onToggleHidden = { app ->
                            viewModel.setHidden(app, app.packageName !in state.hidden)
                        },
                        onOpenFolder = { viewModel.openFolder.value = it },
                        onFolderLongPress = { overlay = Overlay.RenameFolder(it) },
                        onSearch = viewModel::search,
                        onSort = { overlay = Overlay.Sort },
                        onSettings = { viewModel.screen.value = Screen.SETTINGS },
                        onSwipeRight = {},
                        modifier = Modifier.weight(1f),
                    )

                    else -> {
                        HorizontalPager(
                            state = pagerState,
                            beyondViewportPageCount = 1,
                            modifier = Modifier.weight(1f),
                        ) { page ->
                            if (page == HomeTab.APPS.ordinal) {
                                AppsPane(
                                    state = state,
                                    prefs = prefs,
                                    hiddenMode = hiddenMode,
                                    iconFor = viewModel::icon,
                                    onLaunch = viewModel::launch,
                                    onLongPress = { overlay = Overlay.Options(it) },
                                    onShowNotifications = { overlay = Overlay.Notifications(it) },
                                    onToggleHidden = { app ->
                                        viewModel.setHidden(app, app.packageName !in state.hidden)
                                    },
                                    onOpenFolder = { viewModel.openFolder.value = it },
                                    onFolderLongPress = { overlay = Overlay.RenameFolder(it) },
                                    onSearch = viewModel::search,
                                    onSort = { overlay = Overlay.Sort },
                                    onSettings = { viewModel.screen.value = Screen.SETTINGS },
                                    onSwipeRight = {
                                        // Two quick swipes, then authenticate:
                                        // the hidden list should not open by
                                        // brushing the screen once.
                                        if (hiddenAppsSwipe.onSwipe(System.currentTimeMillis())) {
                                            scope.launch {
                                                if (onAuthenticate()) {
                                                    viewModel.hiddenMode.value = HiddenMode.VIEWING
                                                    viewModel.search("")
                                                }
                                            }
                                        }
                                    },
                                )
                            } else {
                                WidgetsPane(
                                    widgets = widgets,
                                    heights = widgetHeights,
                                    reordering = reordering,
                                    viewFor = viewModel::widgetView,
                                    defaultHeightFor = viewModel::defaultWidgetHeight,
                                    onResize = viewModel::resizeWidget,
                                    onMove = viewModel::moveWidget,
                                    onRemove = viewModel::removeWidget,
                                    onStartReorder = { viewModel.reorderingWidgets.value = true },
                                    onDoneReorder = { viewModel.reorderingWidgets.value = false },
                                    onRemoveAll = { overlay = Overlay.RemoveAllWidgets },
                                    onAdd = { overlay = Overlay.AddWidget },
                                )
                            }
                        }
                    }
                }
            }

            SnackbarHost(snackbars, Modifier.align(Alignment.BottomCenter).padding(bottom = 96.dp))
        }
    }
    }

    when (val current = overlay) {
        null -> Unit

        is Overlay.Options -> AppOptionsSheet(
            app = current.app,
            icon = viewModel.icon(current.app),
            isPinned = viewModel.isPinned(current.app),
            isHidden = current.app.packageName in state.hidden,
            isSystemApp = viewModel.isSystemApp(current.app),
            inFolder = viewModel.folderOf(current.app)?.name,
            onDismiss = { overlay = null },
            onAction = { action ->
                val app = current.app
                overlay = null
                when (action) {
                    AppAction.TogglePin -> viewModel.togglePin(app)?.let(::notify)
                    AppAction.Hide -> viewModel.setHidden(app, true)
                    AppAction.Unhide -> viewModel.setHidden(app, false)
                    AppAction.AppInfo -> viewModel.openAppInfo(app)
                    AppAction.Uninstall ->
                        viewModel.uninstallIntent(app)?.let(onLaunchIntent)
                            ?: notify("Work profile apps must be removed from settings")
                    AppAction.MoveToFolder -> overlay = Overlay.MoveToFolder(app)
                    AppAction.RemoveFromFolder -> viewModel.removeFromFolder(app)
                }
            },
        )

        is Overlay.Sort -> SortSheet(
            appListSort = prefs.appListSort,
            pinnedSort = prefs.pinnedSort,
            onAppListSort = viewModel::setAppListSort,
            onPinnedSort = viewModel::setPinnedSort,
            onDismiss = { overlay = null },
        )

        is Overlay.MoveToFolder -> MoveToFolderSheet(
            folders = viewModel.allFolders(),
            onPick = { folder ->
                viewModel.addToFolder(current.app, folder)
                overlay = null
            },
            onCreateNew = { overlay = Overlay.NewFolder(current.app) },
            onDismiss = { overlay = null },
        )

        is Overlay.NewFolder -> FolderNameDialog(
            title = "New folder",
            onConfirm = { name ->
                viewModel.createFolder(name, current.app)
                overlay = null
            },
            onDismiss = { overlay = null },
        )

        is Overlay.RenameFolder -> FolderNameDialog(
            title = "Rename folder",
            initial = current.folder.name,
            onConfirm = { name ->
                viewModel.renameFolder(current.folder, name)
                overlay = null
            },
            onDismiss = { overlay = null },
        )

        is Overlay.DeleteFolder -> ConfirmDialog(
            title = "Delete folder",
            message = "Apps in \"${current.folder.name}\" go back to the main list.",
            confirmLabel = "Delete",
            onConfirm = {
                viewModel.deleteFolder(current.folder)
                overlay = null
            },
            onDismiss = { overlay = null },
        )

        is Overlay.RemoveAllWidgets -> ConfirmDialog(
            title = "Clear All Widgets",
            message = "Are you sure you want to remove all widgets?",
            confirmLabel = "Remove",
            onConfirm = {
                viewModel.removeAllWidgets()
                overlay = null
            },
            onDismiss = { overlay = null },
        )

        is Overlay.Notifications -> NotificationPopup(
            appName = current.app.label,
            icon = viewModel.icon(current.app),
            notifications = state.notifications[current.app.packageName].orEmpty(),
            onOpen = { notification ->
                overlay = null
                onOpenNotification(notification.key)
            },
            onDismissNotification = { onDismissNotification(it.key) },
            onDismiss = { overlay = null },
        )

        is Overlay.AddWidget -> AddWidgetSheet(
            providers = remember { viewModel.availableWidgets() },
            onPick = { provider ->
                overlay = null
                onBindWidget(provider.provider)
            },
            onDismiss = { overlay = null },
        )
    }

    LaunchedEffect(tab) {
        if (tab == HomeTab.WIDGETS) viewModel.refreshWidgets()
    }
}

@Composable
private fun HiddenModeBar(title: String, action: String, onAction: () -> Unit) = Row(
    verticalAlignment = Alignment.CenterVertically,
    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp),
) {
    Text(
        title,
        style = Wallpaper.style(MaterialTheme.typography.titleMedium),
        modifier = Modifier.weight(1f),
    )
    TextButton(onClick = onAction) {
        Text(action, style = Wallpaper.style(MaterialTheme.typography.labelLarge))
    }
}

/** An opened folder: its apps in a grid, with rename and delete in the bar. */
@Composable
private fun FolderPane(
    folder: Folder,
    apps: List<LauncherApp>,
    notifications: Map<String, List<AppNotification>>,
    prefs: Prefs,
    iconFor: (LauncherApp) -> androidx.compose.ui.graphics.ImageBitmap?,
    onLaunch: (LauncherApp) -> Unit,
    onLongPress: (LauncherApp) -> Unit,
    onBack: () -> Unit,
    onRename: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier,
) = Column(modifier.fillMaxSize()) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp),
    ) {
        IconButton(onClick = onBack) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back", tint = Wallpaper.content)
        }
        Text(
            folder.name,
            style = Wallpaper.style(MaterialTheme.typography.titleMedium),
            modifier = Modifier.weight(1f),
        )
        TextButton(onClick = onRename) {
            Text("Rename", style = Wallpaper.style(MaterialTheme.typography.labelLarge))
        }
        TextButton(onClick = onDelete) {
            Text("Delete", style = Wallpaper.style(MaterialTheme.typography.labelLarge))
        }
    }

    LazyVerticalGrid(
        columns = GridCells.Fixed(prefs.gridColumns),
        contentPadding = PaddingValues(16.dp),
    ) {
        items(apps, key = { it.key }) { app ->
            AppGridCell(
                app = app,
                icon = iconFor(app),
                notificationCount = notifications[app.packageName].orEmpty().size,
                showBadges = prefs.showBadges,
                selected = null,
                onClick = { onLaunch(app) },
                onLongClick = { onLongPress(app) },
            )
        }
    }
}


/** Matches the Flutter build's forward page transition. */
private const val PAGE_MS = 300
