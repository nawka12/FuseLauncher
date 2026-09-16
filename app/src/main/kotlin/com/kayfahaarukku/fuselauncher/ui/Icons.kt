package com.kayfahaarukku.fuselauncher.ui

import android.graphics.drawable.Drawable
import androidx.collection.LruCache
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.core.graphics.drawable.toBitmap

/**
 * Rasterised app icons, kept small and bounded.
 *
 * The system caches the Drawables, but turning one into an ImageBitmap on every
 * recomposition would allocate a bitmap per frame while scrolling, so the
 * results are held here instead.
 */
object IconCache {

    private const val SIZE_PX = 144
    private val cache = LruCache<String, ImageBitmap>(300)

    fun get(key: String, load: () -> Drawable?): ImageBitmap? = cache[key] ?: run {
        val bitmap = load()?.toBitmap(SIZE_PX, SIZE_PX)?.asImageBitmap()
        bitmap?.also { cache.put(key, it) }
    }
}
