package com.kayfahaarukku.fuselauncher.apps

import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Test

private fun app(name: String) = LauncherApp(
    packageName = name.lowercase().replace(' ', '.'),
    componentName = "${name.lowercase().replace(' ', '.')}/.Main",
    label = name,
)

class AppSearchTest {

    @Test
    fun `ranks exact, prefix and word-start matches above substrings`() {
        val apps = listOf("ibisPaint X", "KernelSU Next", "myXL", "Sandbox", "Termux", "X")
            .map(::app)

        assertEquals(
            listOf("X", "ibisPaint X", "KernelSU Next", "myXL", "Sandbox", "Termux"),
            searchApps(apps, "x").map { it.label },
        )
    }

    @Test
    fun `name prefix beats word start, and non-matches drop out`() {
        val apps = listOf("ibisPaint X", "Xodo", "Termux", "Clock").map(::app)

        assertEquals(
            listOf("Xodo", "ibisPaint X", "Termux"),
            searchApps(apps, "x").map { it.label },
        )
    }

    @Test
    fun `empty query returns the list untouched`() {
        val apps = listOf("B", "A").map(::app)
        assertSame(apps, searchApps(apps, ""))
    }
}
