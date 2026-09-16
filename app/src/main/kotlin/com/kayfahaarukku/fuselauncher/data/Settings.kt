package com.kayfahaarukku.fuselauncher.data

import android.content.Context
import androidx.core.content.edit
import com.kayfahaarukku.fuselauncher.apps.AppListSortType
import com.kayfahaarukku.fuselauncher.apps.PinnedAppsSortType
import org.json.JSONArray
import org.json.JSONObject

enum class AppLayoutType { LIST, GRID }

/**
 * Everything the launcher remembers, in one plain SharedPreferences file.
 *
 * On first run this pulls the Flutter build's preferences across so an upgrade
 * keeps pinned apps, hidden apps, sort choices and the widget layout. The
 * Flutter keys are left in place: migration is idempotent, and leaving them
 * means a user who reinstalls the old build is not left with nothing.
 */
class Settings(context: Context) {

    private val prefs = context.getSharedPreferences("fuselauncher", Context.MODE_PRIVATE)

    init {
        if (!prefs.getBoolean(KEY_MIGRATED, false)) {
            migrateFrom(FlutterPrefs(context))
            prefs.edit { putBoolean(KEY_MIGRATED, true) }
        }
    }

    // -- app list ----------------------------------------------------------

    /** Package names in pin order. */
    var pinnedApps: List<String>
        get() = prefs.getString(KEY_PINNED, null).orderedKeys()
        set(value) = prefs.edit { putString(KEY_PINNED, value.toIndexedJson()) }

    var hiddenApps: Set<String>
        get() = prefs.getStringSet(KEY_HIDDEN, emptySet()) ?: emptySet()
        set(value) = prefs.edit { putStringSet(KEY_HIDDEN, value) }

    var appListSort: AppListSortType
        get() = prefs.enumOr(KEY_APP_SORT, AppListSortType.ALPHABETICAL_ASC)
        set(value) = prefs.edit { putString(KEY_APP_SORT, value.name) }

    var pinnedSort: PinnedAppsSortType
        get() = prefs.enumOr(KEY_PINNED_SORT, PinnedAppsSortType.USAGE)
        set(value) = prefs.edit { putString(KEY_PINNED_SORT, value.name) }

    var layout: AppLayoutType
        get() = prefs.enumOr(KEY_LAYOUT, AppLayoutType.LIST)
        set(value) = prefs.edit { putString(KEY_LAYOUT, value.name) }

    /** Clamped to what the grid actually renders. */
    var gridColumns: Int
        get() = prefs.getInt(KEY_GRID_COLUMNS, 4).coerceIn(2, 6)
        set(value) = prefs.edit { putInt(KEY_GRID_COLUMNS, value.coerceIn(2, 6)) }

    // -- chrome ------------------------------------------------------------

    var searchBarAtTop: Boolean
        get() = prefs.getBoolean(KEY_SEARCH_TOP, false)
        set(value) = prefs.edit { putBoolean(KEY_SEARCH_TOP, value) }

    var showNotificationBadges: Boolean
        get() = prefs.getBoolean(KEY_BADGES, true)
        set(value) = prefs.edit { putBoolean(KEY_BADGES, value) }

    var showNotificationPreviews: Boolean
        get() = prefs.getBoolean(KEY_PREVIEWS, true)
        set(value) = prefs.edit { putBoolean(KEY_PREVIEWS, value) }

    // -- widgets -----------------------------------------------------------

    /** AppWidget ids, in the order the user dragged them into. */
    var widgetOrder: List<Int>
        get() = prefs.getString(KEY_WIDGET_ORDER, null)
            ?.let { runCatching { JSONArray(it).ints() }.getOrNull() }
            ?: emptyList()
        set(value) = prefs.edit {
            putString(KEY_WIDGET_ORDER, JSONArray().apply { value.forEach { put(it) } }.toString())
        }

    /** widgetId -> pixel height the user resized it to. */
    var widgetHeights: Map<Int, Int>
        get() = prefs.getString(KEY_WIDGET_HEIGHTS, null)
            ?.let { raw ->
                runCatching {
                    val obj = JSONObject(raw)
                    obj.keys().asSequence().associate { it.toInt() to obj.getInt(it) }
                }.getOrNull()
            } ?: emptyMap()
        set(value) = prefs.edit {
            putString(KEY_WIDGET_HEIGHTS, JSONObject().apply {
                value.forEach { (id, h) -> put(id.toString(), h) }
            }.toString())
        }

    // -- usage -------------------------------------------------------------

    var usageCounts: Map<String, Int>
        get() = prefs.getString(KEY_USAGE, null).toIntMap()
        set(value) = prefs.edit { putString(KEY_USAGE, value.toJson()) }

    var tieOrders: Map<String, Int>
        get() = prefs.getString(KEY_TIE_ORDER, null).toIntMap()
        set(value) = prefs.edit { putString(KEY_TIE_ORDER, value.toJson()) }

    var tieCounter: Int
        get() = prefs.getInt(KEY_TIE_COUNTER, 0)
        set(value) = prefs.edit { putInt(KEY_TIE_COUNTER, value) }

    /**
     * Which folder an app sat in before it was hidden, so unhiding can put it
     * back. Keyed by package; the value is a folder row id.
     */
    fun rememberHiddenFolder(packageName: String, folderId: Long) {
        val map = hiddenFolderMap().toMutableMap()
        map[packageName] = folderId
        writeHiddenFolderMap(map)
    }

    /** Returns the remembered folder and drops the entry. */
    fun forgetHiddenFolder(packageName: String): Long? {
        val map = hiddenFolderMap().toMutableMap()
        val folderId = map.remove(packageName)
        writeHiddenFolderMap(map)
        return folderId
    }

    private fun hiddenFolderMap(): Map<String, Long> =
        prefs.getString(KEY_HIDDEN_FOLDERS, null)?.let { raw ->
            runCatching {
                val obj = JSONObject(raw)
                obj.keys().asSequence().associateWith { obj.getLong(it) }
            }.getOrNull()
        } ?: emptyMap()

    private fun writeHiddenFolderMap(map: Map<String, Long>) = prefs.edit {
        putString(
            KEY_HIDDEN_FOLDERS,
            JSONObject().apply { map.forEach { (k, v) -> put(k, v) } }.toString(),
        )
    }

    // -- migration ---------------------------------------------------------

    private fun migrateFrom(old: FlutterPrefs) {
        if (!old.hasData()) return
        prefs.edit {
            old.getString("pinned_apps_data")?.let { putString(KEY_PINNED, it) }
            old.getStringList("hidden_apps")?.let { putStringSet(KEY_HIDDEN, it.toSet()) }
            old.getString("app_usage_counts")?.let { putString(KEY_USAGE, it) }
            old.getString("tie_order")?.let { putString(KEY_TIE_ORDER, it) }
            putInt(KEY_TIE_COUNTER, old.getInt("tie_order_counter", 0))
            putBoolean(KEY_SEARCH_TOP, old.getBoolean("isSearchBarAtTop", false))
            putBoolean(KEY_BADGES, old.getBoolean("show_notification_badges", true))
            putBoolean(KEY_PREVIEWS, old.getBoolean("show_notification_previews", true))
            putInt(KEY_GRID_COLUMNS, old.getInt("app_grid_columns", 4))

            // Dart wrote enums as "AppListSortType.usage"; keep the tail only.
            old.getString("app_list_sort_type")?.let {
                putString(KEY_APP_SORT, appListSortFromDart(it).name)
            }
            old.getString("pinned_sort_type")?.let {
                putString(KEY_PINNED_SORT, pinnedSortFromDart(it).name)
            }
            // Layout was stored as the Dart enum's index: 0 list, 1 grid.
            putString(
                KEY_LAYOUT,
                if (old.getInt("app_layout_type", 0) == 1) AppLayoutType.GRID.name
                else AppLayoutType.LIST.name
            )

            old.getStringList("widget_order")?.let { ids ->
                putString(
                    KEY_WIDGET_ORDER,
                    JSONArray().apply { ids.mapNotNull(String::toIntOrNull).forEach { put(it) } }
                        .toString()
                )
            }
            old.getString("hidden_app_folder_map")?.let { raw ->
                // Dart wrote the folder ids as strings; store them as numbers.
                runCatching {
                    val source = JSONObject(raw)
                    val out = JSONObject()
                    source.keys().forEach { key ->
                        source.optString(key).toLongOrNull()?.let { out.put(key, it) }
                    }
                    putString(KEY_HIDDEN_FOLDERS, out.toString())
                }
            }
            old.getString("widget_sizes")?.let { raw ->
                // [{widgetId, width, height}, ...] -> {widgetId: height}
                runCatching {
                    val array = JSONArray(raw)
                    val heights = JSONObject()
                    for (i in 0 until array.length()) {
                        val entry = array.optJSONObject(i) ?: continue
                        heights.put(entry.getInt("widgetId").toString(), entry.getInt("height"))
                    }
                    putString(KEY_WIDGET_HEIGHTS, heights.toString())
                }
            }
        }
    }

    companion object {
        private const val KEY_MIGRATED = "migrated_from_flutter"
        private const val KEY_PINNED = "pinned_apps_data"
        private const val KEY_HIDDEN = "hidden_apps"
        private const val KEY_APP_SORT = "app_list_sort_type"
        private const val KEY_PINNED_SORT = "pinned_sort_type"
        private const val KEY_LAYOUT = "app_layout_type"
        private const val KEY_GRID_COLUMNS = "app_grid_columns"
        private const val KEY_SEARCH_TOP = "search_bar_at_top"
        private const val KEY_BADGES = "show_notification_badges"
        private const val KEY_PREVIEWS = "show_notification_previews"
        private const val KEY_WIDGET_ORDER = "widget_order"
        private const val KEY_WIDGET_HEIGHTS = "widget_heights"
        private const val KEY_USAGE = "app_usage_counts"
        private const val KEY_TIE_ORDER = "tie_order"
        private const val KEY_TIE_COUNTER = "tie_order_counter"
        private const val KEY_HIDDEN_FOLDERS = "hidden_app_folder_map"

        fun appListSortFromDart(value: String) = when (value.substringAfterLast('.')) {
            "usage" -> AppListSortType.USAGE
            "alphabeticalDesc" -> AppListSortType.ALPHABETICAL_DESC
            else -> AppListSortType.ALPHABETICAL_ASC
        }

        fun pinnedSortFromDart(value: String) = when (value.substringAfterLast('.')) {
            "alphabeticalAsc" -> PinnedAppsSortType.ALPHABETICAL_ASC
            "alphabeticalDesc" -> PinnedAppsSortType.ALPHABETICAL_DESC
            else -> PinnedAppsSortType.USAGE
        }

        /** {"com.a": 1, "com.b": 0} -> [com.b, com.a]. Same shape Dart wrote. */
        fun String?.orderedKeys(): List<String> {
            val raw = this ?: return emptyList()
            return runCatching {
                val obj = JSONObject(raw)
                obj.keys().asSequence()
                    .sortedBy { obj.optInt(it, Int.MAX_VALUE) }
                    .toList()
            }.getOrDefault(emptyList())
        }

        fun List<String>.toIndexedJson(): String =
            JSONObject().apply { forEachIndexed { i, pkg -> put(pkg, i) } }.toString()

        fun String?.toIntMap(): Map<String, Int> {
            val raw = this ?: return emptyMap()
            return runCatching {
                val obj = JSONObject(raw)
                obj.keys().asSequence().associateWith { obj.getInt(it) }
            }.getOrDefault(emptyMap())
        }

        fun Map<String, Int>.toJson(): String =
            JSONObject().apply { forEach { (k, v) -> put(k, v) } }.toString()

        private fun JSONArray.ints() = (0 until length()).map { getInt(it) }

        private inline fun <reified T : Enum<T>> android.content.SharedPreferences.enumOr(
            key: String,
            default: T
        ): T = getString(key, null)
            ?.let { name -> enumValues<T>().firstOrNull { it.name == name } }
            ?: default
    }
}
