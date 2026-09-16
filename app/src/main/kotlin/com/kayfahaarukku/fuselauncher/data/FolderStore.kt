package com.kayfahaarukku.fuselauncher.data

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import org.json.JSONArray

data class Folder(
    val id: Long,
    val name: String,
    val packageNames: List<String>,
)

/**
 * Folders, still in the database sqflite created.
 *
 * Opening the Flutter-era file in place is the whole migration: the schema is
 * three columns and the rows are already right. The old `apps` table was only
 * an icon/name cache, which LauncherApps supplies directly, so it is dropped on
 * first open rather than carried over.
 */
class FolderStore(context: Context) {

    private val helper = object : SQLiteOpenHelper(context, DB_NAME, null, DB_VERSION) {
        override fun onCreate(db: SQLiteDatabase) = createFolders(db)

        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
            createFolders(db)
            db.execSQL("DROP TABLE IF EXISTS apps")
        }

        // Flutter shipped DB versions above ours; never destroy the user's folders.
        override fun onDowngrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
            createFolders(db)
            db.execSQL("DROP TABLE IF EXISTS apps")
        }

        private fun createFolders(db: SQLiteDatabase) = db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS folders(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                app_packages TEXT NOT NULL
            )
            """.trimIndent()
        )
    }

    fun all(): List<Folder> = helper.readableDatabase
        .query("folders", null, null, null, null, null, "id ASC")
        .use { cursor ->
            buildList {
                while (cursor.moveToNext()) {
                    add(
                        Folder(
                            id = cursor.getLong(cursor.getColumnIndexOrThrow("id")),
                            name = cursor.getString(cursor.getColumnIndexOrThrow("name")),
                            packageNames = decodePackages(
                                cursor.getString(cursor.getColumnIndexOrThrow("app_packages"))
                            ),
                        )
                    )
                }
            }
        }

    fun insert(name: String, packageNames: List<String>): Long =
        helper.writableDatabase.insert("folders", null, contentValues(name, packageNames))

    fun update(folder: Folder) {
        helper.writableDatabase.update(
            "folders",
            contentValues(folder.name, folder.packageNames),
            "id = ?",
            arrayOf(folder.id.toString()),
        )
    }

    fun delete(id: Long) {
        helper.writableDatabase.delete("folders", "id = ?", arrayOf(id.toString()))
    }

    private fun contentValues(name: String, packageNames: List<String>) =
        android.content.ContentValues().apply {
            put("name", name)
            put("app_packages", encodePackages(packageNames))
        }

    companion object {
        // Same filename and version sqflite used, so existing folders are simply
        // there and no upgrade path fires on an in-place migration.
        private const val DB_NAME = "fuselauncher.db"
        private const val DB_VERSION = 4

        /** Dart stored the list as a JSON string inside the column. */
        fun decodePackages(raw: String?): List<String> {
            if (raw.isNullOrBlank()) return emptyList()
            return runCatching {
                val array = JSONArray(raw)
                (0 until array.length()).mapNotNull { array.optString(it).takeIf(String::isNotEmpty) }
            }.getOrDefault(emptyList())
        }

        fun encodePackages(packageNames: List<String>): String =
            JSONArray().apply { packageNames.forEach { put(it) } }.toString()
    }
}
