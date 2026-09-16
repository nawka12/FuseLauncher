package com.kayfahaarukku.fuselauncher.apps

/**
 * Matches [query] against app names and orders hits by how well they match:
 * exact name, then name prefix, then a word prefix ("X" finds "ibisPaint X"),
 * then anywhere in the name. Ties keep the incoming order, so the user's sort
 * setting still decides within a tier.
 */
fun searchApps(apps: List<LauncherApp>, query: String): List<LauncherApp> {
    if (query.isEmpty()) return apps
    val needle = query.lowercase()
    return apps.asSequence()
        .mapIndexedNotNull { index, app ->
            rank(app.label.lowercase(), needle)?.let { it to index }
        }
        .sortedWith(compareBy({ it.first }, { it.second }))
        .map { apps[it.second] }
        .toList()
}

private fun rank(name: String, query: String): Int? {
    if (name == query) return 0
    if (name.startsWith(query)) return 1
    var at = name.indexOf(query)
    if (at < 0) return null
    // A word start counts as a prefix match: "x" should find "ibisPaint X".
    while (at > 0) {
        if (!name[at - 1].isWordChar()) return 2
        at = name.indexOf(query, at + 1)
        if (at < 0) break
    }
    return 3
}

private fun Char.isWordChar(): Boolean = this in '0'..'9' || this in 'a'..'z' || this == '_'
