package com.kayfahaarukku.fuselauncher.apps

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
