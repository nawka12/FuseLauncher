package com.kayfahaarukku.fuselauncher.apps

import com.kayfahaarukku.fuselauncher.data.Folder
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

    @Test
    fun `folders follow the app sort, and under usage their most-used member`() {
        val folders = listOf(
            Folder(1, "work", listOf("mail", "docs")),
            Folder(2, "Games", listOf("chess")),
            Folder(3, "empty", emptyList()),
            Folder(4, "Alpha", emptyList()),
        )
        val byUsage = listOf("chess", "docs", "mail").map(::app)

        assertEquals(
            listOf("Alpha", "empty", "Games", "work"),
            sortFolders(folders, AppListSortType.ALPHABETICAL_ASC) { byUsage }.map { it.name },
        )
        assertEquals(
            listOf("work", "Games", "empty", "Alpha"),
            sortFolders(folders, AppListSortType.ALPHABETICAL_DESC) { byUsage }.map { it.name },
        )
        assertEquals(
            listOf("Games", "work", "Alpha", "empty"),
            sortFolders(folders, AppListSortType.USAGE) { byUsage }.map { it.name },
        )
    }
}
