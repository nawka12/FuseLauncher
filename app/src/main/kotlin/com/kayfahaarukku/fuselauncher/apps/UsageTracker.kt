package com.kayfahaarukku.fuselauncher.apps

import com.kayfahaarukku.fuselauncher.data.Settings
import kotlin.math.roundToInt

/**
 * Ranks apps by how often they are launched, with every other app decaying a
 * little on each launch so the order tracks recent habit rather than lifetime
 * totals. Counts settle at a floor of 5; the order apps arrive at that floor is
 * recorded so the tail stays stable instead of reshuffling alphabetically.
 */
class UsageTracker(private val settings: Settings) {

    fun recordLaunch(packageName: String) {
        val counts = settings.usageCounts.toMutableMap()
        counts[packageName] = ((counts[packageName] ?: 0) + 1).coerceAtMost(MAX_HISTORY)

        for (key in counts.keys.toList()) {
            if (key == packageName) continue
            counts[key] = ((counts.getValue(key) * DECAY).roundToInt()).coerceAtLeast(FLOOR)
        }

        val tieOrders = settings.tieOrders.toMutableMap()
        var counter = settings.tieCounter
        counts.forEach { (pkg, count) ->
            if (count == FLOOR && pkg !in tieOrders) tieOrders[pkg] = counter++
        }

        settings.usageCounts = counts
        settings.tieOrders = tieOrders
        settings.tieCounter = counter
    }

    fun sorted(apps: List<LauncherApp>, sortType: AppListSortType): List<LauncherApp> =
        when (sortType) {
            AppListSortType.ALPHABETICAL_ASC -> apps.sortedBy { it.label.lowercase() }
            AppListSortType.ALPHABETICAL_DESC -> apps.sortedByDescending { it.label.lowercase() }
            AppListSortType.USAGE -> apps.sortedWith(byUsage())
        }

    fun sortedPinned(apps: List<LauncherApp>, sortType: PinnedAppsSortType): List<LauncherApp> =
        when (sortType) {
            PinnedAppsSortType.ALPHABETICAL_ASC -> apps.sortedBy { it.label.lowercase() }
            PinnedAppsSortType.ALPHABETICAL_DESC -> apps.sortedByDescending { it.label.lowercase() }
            PinnedAppsSortType.USAGE -> apps.sortedWith(byUsage())
        }

    /** Most used first; apps resting on the floor keep the order they got there. */
    private fun byUsage(): Comparator<LauncherApp> {
        val counts = settings.usageCounts
        val tieOrders = settings.tieOrders
        fun count(app: LauncherApp) = counts[app.packageName] ?: 0
        return Comparator { a, b ->
            val byCount = count(b).compareTo(count(a))
            if (byCount != 0) return@Comparator byCount
            if (count(a) == FLOOR) {
                val byTie = (tieOrders[a.packageName] ?: NO_TIE)
                    .compareTo(tieOrders[b.packageName] ?: NO_TIE)
                if (byTie != 0) return@Comparator byTie
            }
            a.label.lowercase().compareTo(b.label.lowercase())
        }
    }

    companion object {
        const val MAX_HISTORY = 100
        const val FLOOR = 5
        const val DECAY = 0.98
        private const val NO_TIE = 999_999
    }
}
