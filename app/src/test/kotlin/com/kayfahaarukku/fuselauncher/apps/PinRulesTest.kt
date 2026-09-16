package com.kayfahaarukku.fuselauncher.apps

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PinRulesTest {

    private fun pinned(result: PinResult) = (result as PinResult.Changed).pinned

    @Test
    fun `a new pin goes on the end, keeping the user's order`() {
        val result = PinRules.toggle(listOf("com.a", "com.b"), "com.c", isHidden = false)

        assertEquals(listOf("com.a", "com.b", "com.c"), pinned(result))
    }

    @Test
    fun `pinning an already pinned app unpins it`() {
        val result = PinRules.toggle(listOf("com.a", "com.b"), "com.a", isHidden = false)

        assertEquals(listOf("com.b"), pinned(result))
    }

    @Test
    fun `a hidden app cannot be pinned`() {
        val result = PinRules.toggle(listOf("com.a"), "com.b", isHidden = true)

        assertTrue(result is PinResult.Refused)
    }

    /** Unpinning stays available once full, or the list could never shrink. */
    @Test
    fun `the limit blocks new pins but not unpinning`() {
        val full = (1..PinRules.MAX_PINNED).map { "com.app$it" }

        assertTrue(PinRules.toggle(full, "com.extra", isHidden = false) is PinResult.Refused)
        assertEquals(
            PinRules.MAX_PINNED - 1,
            pinned(PinRules.toggle(full, "com.app1", isHidden = false)).size,
        )
    }

    /** A hidden app that is somehow already pinned must still be removable. */
    @Test
    fun `unpinning a hidden app is allowed`() {
        val result = PinRules.toggle(listOf("com.a"), "com.a", isHidden = true)

        assertEquals(emptyList<String>(), pinned(result))
    }
}
