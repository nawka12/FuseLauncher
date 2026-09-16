package com.kayfahaarukku.fuselauncher.ui

import android.app.Application
import android.appwidget.AppWidgetHostView
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.kayfahaarukku.fuselauncher.apps.AppListSortType
import com.kayfahaarukku.fuselauncher.apps.AppRepository
import com.kayfahaarukku.fuselauncher.apps.AppSection
import com.kayfahaarukku.fuselauncher.apps.LauncherApp
import com.kayfahaarukku.fuselauncher.apps.PinRules
import com.kayfahaarukku.fuselauncher.apps.PinResult
import com.kayfahaarukku.fuselauncher.apps.PinnedAppsSortType
import com.kayfahaarukku.fuselauncher.apps.UsageTracker
import com.kayfahaarukku.fuselauncher.apps.createSections
import com.kayfahaarukku.fuselauncher.apps.searchApps
import com.kayfahaarukku.fuselauncher.data.AppLayoutType
import com.kayfahaarukku.fuselauncher.data.Folder
import com.kayfahaarukku.fuselauncher.data.FolderStore
import com.kayfahaarukku.fuselauncher.data.Settings
import com.kayfahaarukku.fuselauncher.notifications.AppNotification
import com.kayfahaarukku.fuselauncher.notifications.NotificationListener
import com.kayfahaarukku.fuselauncher.widgets.HostedWidget
import com.kayfahaarukku.fuselauncher.widgets.WidgetHost
import com.kayfahaarukku.fuselauncher.widgets.WidgetProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

enum class Screen { HOME, SETTINGS, ABOUT }

enum class HomeTab { APPS, WIDGETS }

/** Hidden apps are reachable in two steps: pick which to hide, then view them. */
enum class HiddenMode { OFF, SELECTING, VIEWING }

data class HomeState(
    val sections: List<AppSection> = emptyList(),
    val pinned: List<LauncherApp> = emptyList(),
    val folders: List<Folder> = emptyList(),
    val notifications: Map<String, List<AppNotification>> = emptyMap(),
    val query: String = "",
    val hidden: Set<String> = emptySet(),
    val loading: Boolean = true,
) {
    /** Letters the index strip may show; a leading star covers pinned and folders. */
    val indexLetters: List<String>
        get() = buildList {
            if (pinned.isNotEmpty() || folders.isNotEmpty()) add(TOP_INDEX_LETTER)
            addAll(sections.map { it.letter }.filter { it.isNotEmpty() })
        }
}

data class Prefs(
    val layout: AppLayoutType = AppLayoutType.LIST,
    val gridColumns: Int = 4,
    val searchBarAtTop: Boolean = false,
    val showBadges: Boolean = true,
    val showPreviews: Boolean = true,
    val appListSort: AppListSortType = AppListSortType.ALPHABETICAL_ASC,
    val pinnedSort: PinnedAppsSortType = PinnedAppsSortType.USAGE,
)

class HomeViewModel(app: Application) : AndroidViewModel(app) {

    private val repository = AppRepository(app)
    private val settings = Settings(app)
    private val usage = UsageTracker(settings)
    private val folderStore = FolderStore(app)
    private val widgetHost = WidgetHost(app)

    private val allApps = MutableStateFlow<List<LauncherApp>>(emptyList())
    private val query = MutableStateFlow("")
    private val folders = MutableStateFlow<List<Folder>>(emptyList())
    private val hidden = MutableStateFlow(settings.hiddenApps)

    /**
     * Pinned packages as a flow, not a read off Settings inside the combine.
     * StateFlow drops equal values, so reloading an unchanged app list emits
     * nothing and a pin written only to Settings would never reach the UI.
     */
    private val pinned = MutableStateFlow(settings.pinnedApps)
    private val loading = MutableStateFlow(true)

    /**
     * Settings mirrored into a flow. Reading them straight off SharedPreferences
     * would never recompose, so every write goes to both.
     */
    private val _prefs = MutableStateFlow(
        Prefs(
            layout = settings.layout,
            gridColumns = settings.gridColumns,
            searchBarAtTop = settings.searchBarAtTop,
            showBadges = settings.showNotificationBadges,
            showPreviews = settings.showNotificationPreviews,
            appListSort = settings.appListSort,
            pinnedSort = settings.pinnedSort,
        )
    )
    val prefs: StateFlow<Prefs> = _prefs

    val screen = MutableStateFlow(Screen.HOME)
    val tab = MutableStateFlow(HomeTab.APPS)
    val hiddenMode = MutableStateFlow(HiddenMode.OFF)
    val openFolder = MutableStateFlow<Folder?>(null)

    private val _widgets = MutableStateFlow<List<HostedWidget>>(emptyList())
    val widgets: StateFlow<List<HostedWidget>> = _widgets
    val widgetHeights = MutableStateFlow(settings.widgetHeights)
    val reorderingWidgets = MutableStateFlow(false)

    private val packages = repository.observePackages { refresh() }

    /** Grouped so the outer combine stays inside its five-flow limit. */
    private data class AppInputs(
        val apps: List<LauncherApp>,
        val query: String,
        val folders: List<Folder>,
        val hidden: Set<String>,
        val pinned: List<String>,
    )

    private val appInputs = combine(allApps, query, folders, hidden, pinned, ::AppInputs)

    val state: StateFlow<HomeState> =
        combine(
            appInputs, NotificationListener.byPackage, hiddenMode, _prefs, loading,
        ) { inputs, notifications, mode, preferences, isLoading ->
            // Hiding-related modes work over the hidden set; normal browsing
            // excludes it. Folder members stay out of the main list too, so an
            // app never appears in both places.
            val inFolders = inputs.folders.flatMap { it.packageNames }.toSet()
            val visible = when (mode) {
                HiddenMode.VIEWING -> inputs.apps.filter { it.packageName in inputs.hidden }
                HiddenMode.SELECTING -> inputs.apps
                HiddenMode.OFF -> inputs.apps.filterNot {
                    it.packageName in inputs.hidden || it.packageName in inFolders
                }
            }

            val matched = searchApps(usage.sorted(visible, preferences.appListSort), inputs.query)
            val showsTopRow = mode == HiddenMode.OFF && inputs.query.isEmpty()

            HomeState(
                // A search result is one ranked run, not A-Z groups.
                sections = if (inputs.query.isEmpty()) {
                    createSections(matched, preferences.appListSort)
                } else {
                    listOf(AppSection("", matched))
                },
                pinned = if (showsTopRow) {
                    usage.sortedPinned(
                        inputs.pinned.mapNotNull { pkg ->
                            inputs.apps.firstOrNull {
                                it.packageName == pkg && it.packageName !in inputs.hidden
                            }
                        },
                        preferences.pinnedSort,
                    )
                } else {
                    emptyList()
                },
                folders = if (showsTopRow) inputs.folders else emptyList(),
                notifications = notifications,
                query = inputs.query,
                hidden = inputs.hidden,
                loading = isLoading,
            )
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), HomeState())

    init {
        refresh()
    }

    // -- loading -----------------------------------------------------------

    fun refresh() = viewModelScope.launch {
        val loaded = withContext(Dispatchers.IO) { repository.loadApps() }
        val folderList = withContext(Dispatchers.IO) { folderStore.all() }
        allApps.value = loaded
        folders.value = folderList
        hidden.value = settings.hiddenApps
        pinned.value = settings.pinnedApps
        loading.value = false
    }

    fun refreshWidgets() = viewModelScope.launch {
        val hosted = withContext(Dispatchers.IO) { widgetHost.hostedWidgets() }
        // Saved order first, then anything bound since.
        val order = settings.widgetOrder
        _widgets.value = hosted.sortedBy {
            order.indexOf(it.widgetId).takeIf { i -> i >= 0 } ?: Int.MAX_VALUE
        }
    }

    // -- apps --------------------------------------------------------------

    fun search(text: String) {
        query.value = text
    }

    fun launch(app: LauncherApp) {
        usage.recordLaunch(app.packageName)
        repository.launch(app)
    }

    fun openAppInfo(app: LauncherApp) = repository.openAppInfo(app)

    fun uninstallIntent(app: LauncherApp) = repository.uninstallIntent(app)

    fun isSystemApp(app: LauncherApp) = repository.isSystemApp(app)

    fun icon(app: LauncherApp) = IconCache.get(app.key) { repository.icon(app) }

    fun isPinned(app: LauncherApp) = app.packageName in pinned.value

    /** Returns a message when the pin could not be added, null on success. */
    fun togglePin(app: LauncherApp): String? =
        when (
            val result = PinRules.toggle(
                current = pinned.value,
                packageName = app.packageName,
                isHidden = app.packageName in hidden.value,
            )
        ) {
            is PinResult.Changed -> {
                setPinned(result.pinned)
                null
            }

            is PinResult.Refused -> result.message
        }

    private fun setPinned(packages: List<String>) {
        settings.pinnedApps = packages
        pinned.value = packages
    }

    /**
     * Hiding removes the pin and takes the app out of its folder, remembering
     * both so unhiding can put the folder membership back. The pin is not
     * restored: the Flutter build made the user pin it again deliberately.
     */
    fun setHidden(app: LauncherApp, hide: Boolean) = viewModelScope.launch {
        val pkg = app.packageName
        if (hide) {
            settings.hiddenApps = settings.hiddenApps + pkg
            hidden.value = settings.hiddenApps
            setPinned(pinned.value - pkg)
            withContext(Dispatchers.IO) {
                folderStore.all().firstOrNull { pkg in it.packageNames }?.let { folder ->
                    settings.rememberHiddenFolder(pkg, folder.id)
                    folderStore.update(folder.copy(packageNames = folder.packageNames - pkg))
                }
            }
        } else {
            settings.hiddenApps = settings.hiddenApps - pkg
            hidden.value = settings.hiddenApps
            withContext(Dispatchers.IO) {
                settings.forgetHiddenFolder(pkg)?.let { folderId ->
                    folderStore.all().firstOrNull { it.id == folderId }?.let { folder ->
                        folderStore.update(folder.copy(packageNames = folder.packageNames + pkg))
                    }
                }
            }
        }
        refresh()
    }

    // -- folders -----------------------------------------------------------

    /** Every folder, regardless of what the drawer is currently filtered to. */
    fun allFolders(): List<Folder> = folders.value

    fun folderOf(app: LauncherApp): Folder? =
        folders.value.firstOrNull { app.packageName in it.packageNames }

    fun appsIn(folder: Folder): List<LauncherApp> =
        folder.packageNames.mapNotNull { pkg -> allApps.value.firstOrNull { it.packageName == pkg } }

    fun createFolder(name: String, firstApp: LauncherApp?) = viewModelScope.launch {
        withContext(Dispatchers.IO) {
            folderStore.insert(name, listOfNotNull(firstApp?.packageName))
        }
        refresh()
    }

    fun renameFolder(folder: Folder, name: String) = viewModelScope.launch {
        withContext(Dispatchers.IO) { folderStore.update(folder.copy(name = name)) }
        refresh()
    }

    fun deleteFolder(folder: Folder) = viewModelScope.launch {
        withContext(Dispatchers.IO) { folderStore.delete(folder.id) }
        openFolder.value = null
        refresh()
    }

    fun addToFolder(app: LauncherApp, folder: Folder) = viewModelScope.launch {
        withContext(Dispatchers.IO) {
            // An app belongs to one folder; drop it from any other first.
            folderStore.all().forEach { existing ->
                if (app.packageName in existing.packageNames && existing.id != folder.id) {
                    folderStore.update(
                        existing.copy(packageNames = existing.packageNames - app.packageName)
                    )
                }
            }
            folderStore.update(
                folder.copy(packageNames = folder.packageNames + app.packageName)
            )
        }
        refresh()
    }

    fun removeFromFolder(app: LauncherApp) = viewModelScope.launch {
        withContext(Dispatchers.IO) {
            folderStore.all().firstOrNull { app.packageName in it.packageNames }?.let { folder ->
                folderStore.update(
                    folder.copy(packageNames = folder.packageNames - app.packageName)
                )
            }
        }
        refresh()
    }

    // -- widgets -----------------------------------------------------------

    fun availableWidgets(): List<WidgetProvider> = widgetHost.availableProviders()

    fun widgetView(widgetId: Int, heightPx: Int): AppWidgetHostView? =
        widgetHost.view(widgetId, heightPx)

    fun defaultWidgetHeight(widget: HostedWidget): Int =
        widgetHost.defaultHeightPx(widget.info)

    fun bindWidget(provider: String) = widgetHost.bind(provider)

    fun configureIntent(widgetId: Int) = widgetHost.configureIntent(widgetId)

    fun releaseUnboundWidget(widgetId: Int) = widgetHost.releaseUnbound(widgetId)

    fun removeWidget(widgetId: Int) {
        widgetHost.remove(widgetId)
        settings.widgetOrder = settings.widgetOrder - widgetId
        settings.widgetHeights = settings.widgetHeights - widgetId
        widgetHeights.value = settings.widgetHeights
        refreshWidgets()
    }

    fun removeAllWidgets() {
        _widgets.value.forEach { widgetHost.remove(it.widgetId) }
        settings.widgetOrder = emptyList()
        settings.widgetHeights = emptyMap()
        widgetHeights.value = emptyMap()
        reorderingWidgets.value = false
        refreshWidgets()
    }

    fun moveWidget(from: Int, to: Int) {
        val current = _widgets.value.toMutableList()
        if (from !in current.indices || to !in current.indices) return
        current.add(to, current.removeAt(from))
        _widgets.value = current
        settings.widgetOrder = current.map { it.widgetId }
    }

    fun resizeWidget(widgetId: Int, heightPx: Int) {
        val clamped = heightPx.coerceIn(MIN_WIDGET_HEIGHT_PX, MAX_WIDGET_HEIGHT_PX)
        settings.widgetHeights = settings.widgetHeights + (widgetId to clamped)
        widgetHeights.value = settings.widgetHeights
    }

    fun startWidgetHost() = widgetHost.startListening()

    fun stopWidgetHost() = widgetHost.stopListening()

    // -- preferences -------------------------------------------------------

    fun setLayout(layout: AppLayoutType) {
        settings.layout = layout
        _prefs.value = _prefs.value.copy(layout = layout)
    }

    fun setGridColumns(columns: Int) {
        settings.gridColumns = columns
        _prefs.value = _prefs.value.copy(gridColumns = settings.gridColumns)
    }

    fun setSearchBarAtTop(atTop: Boolean) {
        settings.searchBarAtTop = atTop
        _prefs.value = _prefs.value.copy(searchBarAtTop = atTop)
    }

    fun setShowBadges(show: Boolean) {
        settings.showNotificationBadges = show
        _prefs.value = _prefs.value.copy(showBadges = show)
    }

    fun setShowPreviews(show: Boolean) {
        settings.showNotificationPreviews = show
        _prefs.value = _prefs.value.copy(showPreviews = show)
    }

    fun setAppListSort(sort: AppListSortType) {
        settings.appListSort = sort
        _prefs.value = _prefs.value.copy(appListSort = sort)
    }

    fun setPinnedSort(sort: PinnedAppsSortType) {
        settings.pinnedSort = sort
        _prefs.value = _prefs.value.copy(pinnedSort = sort)
    }

    override fun onCleared() {
        super.onCleared()
        packages.close()
    }

    companion object {
        const val MIN_WIDGET_HEIGHT_PX = 120
        const val MAX_WIDGET_HEIGHT_PX = 1600
    }
}
