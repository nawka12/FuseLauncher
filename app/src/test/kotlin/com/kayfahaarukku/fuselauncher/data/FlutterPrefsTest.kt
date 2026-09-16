package com.kayfahaarukku.fuselauncher.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.io.ByteArrayOutputStream
import java.io.ObjectOutputStream
import java.io.Serializable

private fun serialize(value: Serializable): ByteArray =
    ByteArrayOutputStream().also { out ->
        ObjectOutputStream(out).use { it.writeObject(value) }
    }.toByteArray()

class FlutterPrefsTest {

    @Test
    fun `reads back the string list shape shared_preferences writes`() {
        val bytes = serialize(ArrayList(listOf("com.a", "com.b", "com.c")))

        assertEquals(listOf("com.a", "com.b", "com.c"), FlutterPrefs.decodeListBytes(bytes))
    }

    @Test
    fun `an empty list survives the round trip`() {
        assertEquals(emptyList<String>(), FlutterPrefs.decodeListBytes(serialize(ArrayList<String>())))
    }

    /** A tampered pref must not be able to instantiate arbitrary classes. */
    @Test
    fun `refuses to deserialise anything but a string list`() {
        assertNull(FlutterPrefsTest.decodeSmuggled())
    }

    @Test
    fun `garbage decodes to null rather than throwing`() {
        assertNull(FlutterPrefs.decodeListBytes(byteArrayOf(1, 2, 3)))
    }

    companion object {
        fun decodeSmuggled(): List<String>? =
            FlutterPrefs.decodeListBytes(serialize(java.util.HashMap<String, String>()))
    }
}
