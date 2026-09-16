package com.kayfahaarukku.fuselauncher.data

import android.content.Context
import android.content.SharedPreferences
import android.util.Base64
import java.io.ByteArrayInputStream
import java.io.InputStream
import java.io.ObjectInputStream
import java.io.ObjectStreamClass

/**
 * Reads the preferences the Flutter build wrote, so upgrading users keep their
 * pinned apps, hidden apps, sort order and widget layout.
 *
 * shared_preferences stores everything in one XML file under a "flutter." key
 * prefix. Scalars land as their natural type, but a doubles and string lists
 * are tagged strings: LIST_PREFIX followed by base64 of a Java-serialised
 * ArrayList<String>. Decoding is restricted to string lists, exactly as the
 * plugin does, so a tampered pref cannot instantiate arbitrary classes.
 */
class FlutterPrefs(private val prefs: SharedPreferences) {

    constructor(context: Context) : this(
        context.getSharedPreferences(FILE_NAME, Context.MODE_PRIVATE)
    )

    fun getString(key: String): String? = prefs.getString(PREFIX + key, null)

    fun getBoolean(key: String, default: Boolean): Boolean =
        prefs.getBoolean(PREFIX + key, default)

    fun getInt(key: String, default: Int): Int = prefs.getInt(PREFIX + key, default)

    fun getDouble(key: String): Double? =
        prefs.getString(PREFIX + key, null)
            ?.takeIf { it.startsWith(DOUBLE_PREFIX) }
            ?.substring(DOUBLE_PREFIX.length)
            ?.toDoubleOrNull()

    fun getStringList(key: String): List<String>? {
        val raw = prefs.getString(PREFIX + key, null) ?: return null
        if (!raw.startsWith(LIST_PREFIX)) return null
        return decodeList(raw.substring(LIST_PREFIX.length))
    }

    /** True when there is Flutter-era data worth migrating. */
    fun hasData(): Boolean = prefs.all.keys.any { it.startsWith(PREFIX) }

    /** Call once the native store owns the data, so the next launch skips migration. */
    fun clear() {
        prefs.edit().apply {
            prefs.all.keys.filter { it.startsWith(PREFIX) }.forEach { remove(it) }
        }.apply()
    }

    companion object {
        const val FILE_NAME = "FlutterSharedPreferences"
        const val PREFIX = "flutter."

        // Verbatim from shared_preferences_android; changing either breaks reads.
        const val LIST_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu"
        const val DOUBLE_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu"

        fun decodeList(base64: String): List<String>? =
            runCatching { decodeListBytes(Base64.decode(base64, 0)) }.getOrNull()

        /** The serialisation half, split out so it is testable off-device. */
        fun decodeListBytes(bytes: ByteArray): List<String>? = try {
            StringListInputStream(ByteArrayInputStream(bytes)).use {
                @Suppress("UNCHECKED_CAST")
                (it.readObject() as List<String>)
            }
        } catch (e: Exception) {
            null
        }
    }
}

/** Only string lists may be deserialised - anything else is an injected pref. */
private class StringListInputStream(input: InputStream) : ObjectInputStream(input) {
    override fun resolveClass(desc: ObjectStreamClass?): Class<*>? {
        val allowed = setOf(
            "java.util.Arrays\$ArrayList",
            "java.util.ArrayList",
            "java.lang.String",
            "[Ljava.lang.String;"
        )
        val name = desc?.name
        if (name != null && name !in allowed) throw ClassNotFoundException(name)
        return super.resolveClass(desc)
    }
}
