package com.kayfahaarukku.fuselauncher.apps

import org.junit.Assert.assertEquals
import org.junit.Test

private fun app(name: String) = LauncherApp(
    packageName = name.lowercase(),
    componentName = "${name.lowercase()}/.Main",
    label = name,
)

class AppSectionsTest {

    @Test
    fun `groups alphabetically by first letter, case-insensitively sorted`() {
        val apps = listOf("banana", "Apple", "avocado", "Cherry").map(::app)

        val sections = createSections(apps, AppListSortType.ALPHABETICAL_ASC)

        assertEquals(listOf("A", "B", "C"), sections.map { it.letter })
        assertEquals(listOf("Apple", "avocado"), sections[0].apps.map { it.label })
    }

    @Test
    fun `descending sort reverses the sections too`() {
        val apps = listOf("Apple", "Banana", "Cherry").map(::app)

        val sections = createSections(apps, AppListSortType.ALPHABETICAL_DESC)

        assertEquals(listOf("C", "B", "A"), sections.map { it.letter })
    }

    @Test
    fun `usage order is one unlabelled run, left in the order given`() {
        val apps = listOf("Zebra", "Apple").map(::app)

        val sections = createSections(apps, AppListSortType.USAGE)

        assertEquals(1, sections.size)
        assertEquals("", sections[0].letter)
        assertEquals(listOf("Zebra", "Apple"), sections[0].apps.map { it.label })
    }

    @Test
    fun `apps with no name fall into the hash section`() {
        val sections = createSections(listOf(app("")), AppListSortType.ALPHABETICAL_ASC)
        assertEquals(listOf("#"), sections.map { it.letter })
    }
}
