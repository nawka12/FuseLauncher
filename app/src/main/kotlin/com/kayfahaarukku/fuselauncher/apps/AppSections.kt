package com.kayfahaarukku.fuselauncher.apps

import com.kayfahaarukku.fuselauncher.data.Folder

data class AppSection(val letter: String, val apps: List<LauncherApp>)

/**
 * Groups a sorted list into the A-Z sections the list view and the index strip
 * share. Usage order has no meaningful letters, so it stays one unlabelled run.
 */
fun createSections(
    apps: List<LauncherApp>,
    sortType: AppListSortType = AppListSortType.ALPHABETICAL_ASC,
): List<AppSection> {
    if (sortType == AppListSortType.USAGE) return listOf(AppSection("", apps))

    val sorted = when (sortType) {
        AppListSortType.ALPHABETICAL_DESC -> apps.sortedByDescending { it.label.lowercase() }
        else -> apps.sortedBy { it.label.lowercase() }
    }

    return sorted
        .groupBy { it.label.firstOrNull()?.uppercase() ?: "#" }
        .map { (letter, group) -> AppSection(letter, group) }
}

/**
 * Folders follow the app list's sort, as they did on Flutter: by name, or under
 * usage by their most-used member, with empty folders last and by name.
 */
fun sortFolders(
    folders: List<Folder>,
    sortType: AppListSortType,
    usageOrder: () -> List<LauncherApp>,
): List<Folder> = when (sortType) {
    AppListSortType.ALPHABETICAL_ASC -> folders.sortedBy { it.name.lowercase() }
    AppListSortType.ALPHABETICAL_DESC -> folders.sortedByDescending { it.name.lowercase() }
    AppListSortType.USAGE -> {
        val rank = HashMap<String, Int>()
        usageOrder().forEachIndexed { i, app -> rank.putIfAbsent(app.id, i) }
        folders.sortedWith(
            compareBy<Folder> { folder ->
                folder.packageNames.minOfOrNull { rank[it] ?: Int.MAX_VALUE } ?: Int.MAX_VALUE
            }.thenBy { it.name.lowercase() }
        )
    }
}
