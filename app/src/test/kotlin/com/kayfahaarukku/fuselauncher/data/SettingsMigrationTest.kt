package com.kayfahaarukku.fuselauncher.data

import com.kayfahaarukku.fuselauncher.apps.AppListSortType
import com.kayfahaarukku.fuselauncher.apps.PinnedAppsSortType
import com.kayfahaarukku.fuselauncher.data.Settings.Companion.orderedKeys
import com.kayfahaarukku.fuselauncher.data.Settings.Companion.toIndexedJson
import com.kayfahaarukku.fuselauncher.data.Settings.Companion.toIntMap
import com.kayfahaarukku.fuselauncher.data.Settings.Companion.toJson
import org.junit.Assert.assertEquals
import org.junit.Test

class SettingsMigrationTest {

    @Test
    fun `pinned apps keep the order Dart stored them in`() {
        // Dart wrote {package: index}; order comes from the value, not key order.
        val stored = """{"com.c":2,"com.a":0,"com.b":1}"""

        assertEquals(listOf("com.a", "com.b", "com.c"), stored.orderedKeys())
    }

    @Test
    fun `pinned order round trips through our own writer`() {
        val order = listOf("com.x", "com.y", "com.z")

        assertEquals(order, order.toIndexedJson().orderedKeys())
    }

    @Test
    fun `malformed pinned data yields no pins rather than crashing`() {
        assertEquals(emptyList<String>(), "not json".orderedKeys())
        assertEquals(emptyList<String>(), null.orderedKeys())
    }

    @Test
    fun `usage counts round trip`() {
        val counts = mapOf("com.a" to 42, "com.b" to 5)

        assertEquals(counts, counts.toJson().toIntMap())
    }

    @Test
    fun `dart enum strings map onto the Kotlin enums`() {
        assertEquals(
            AppListSortType.USAGE,
            Settings.appListSortFromDart("AppListSortType.usage"),
        )
        assertEquals(
            AppListSortType.ALPHABETICAL_DESC,
            Settings.appListSortFromDart("AppListSortType.alphabeticalDesc"),
        )
        assertEquals(
            PinnedAppsSortType.ALPHABETICAL_ASC,
            Settings.pinnedSortFromDart("PinnedAppsSortType.alphabeticalAsc"),
        )
        // Anything unrecognised falls back to the Dart build's own defaults.
        assertEquals(
            AppListSortType.ALPHABETICAL_ASC,
            Settings.appListSortFromDart("garbage"),
        )
        assertEquals(PinnedAppsSortType.USAGE, Settings.pinnedSortFromDart("garbage"))
    }

    @Test
    fun `folder package lists survive the json column`() {
        val packages = listOf("com.a", "com.b")

        assertEquals(packages, FolderStore.decodePackages(FolderStore.encodePackages(packages)))
        assertEquals(emptyList<String>(), FolderStore.decodePackages(null))
        assertEquals(emptyList<String>(), FolderStore.decodePackages("junk"))
    }
}
