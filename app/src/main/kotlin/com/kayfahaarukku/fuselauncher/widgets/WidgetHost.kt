package com.kayfahaarukku.fuselauncher.widgets

import android.app.Activity
import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetHostView
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProviderInfo
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Drawable
import android.view.Gravity
import android.widget.FrameLayout
import android.os.Build
import android.util.SizeF
import android.view.ViewGroup

data class WidgetProvider(
    val label: String,
    val appName: String,
    val provider: String,
    val minWidth: Int,
    val minHeight: Int,
) {
    val packageName: String get() = provider.substringBefore('/')
}

data class HostedWidget(
    val widgetId: Int,
    val label: String,
    val info: AppWidgetProviderInfo,
)

/**
 * Hosts third-party app widgets.
 *
 * The host id must not change between releases: it is the handle the system
 * keys bound widget ids to, so a new one would orphan every widget the user has
 * already placed. Views are cached per widget id because AppWidgetHost.createView
 * inflates a remote layout, which is far too expensive to redo while scrolling.
 */
class WidgetHost(private val context: Context) {

    private val manager = AppWidgetManager.getInstance(context)
    private val host = AppWidgetHost(context, HOST_ID)
    private val views = mutableMapOf<Int, AppWidgetHostView>()

    fun startListening() = host.startListening()

    fun stopListening() = host.stopListening()

    /** Widget ids this host has bound, in no particular order. */
    fun boundWidgetIds(): List<Int> = host.appWidgetIds?.toList().orEmpty()

    fun hostedWidgets(): List<HostedWidget> = boundWidgetIds().mapNotNull { id ->
        manager.getAppWidgetInfo(id)?.let {
            HostedWidget(id, it.loadLabel(context.packageManager).orEmpty(), it)
        }
    }

    fun availableProviders(): List<WidgetProvider> = manager.installedProviders.map { info ->
        WidgetProvider(
            label = info.loadLabel(context.packageManager).orEmpty(),
            appName = runCatching {
                context.packageManager.getApplicationLabel(
                    context.packageManager.getApplicationInfo(info.provider.packageName, 0)
                ).toString()
            }.getOrDefault(info.provider.packageName),
            provider = info.provider.flattenToString(),
            minWidth = info.minWidth,
            minHeight = info.minHeight,
        )
    }.sortedBy { it.appName.lowercase() }

    fun previewImage(provider: WidgetProvider): Drawable? {
        val info = manager.installedProviders
            .firstOrNull { it.provider.flattenToString() == provider.provider } ?: return null
        return runCatching { info.loadPreviewImage(context, 0) ?: info.loadIcon(context, 0) }
            .getOrNull()
    }

    /**
     * Returns the hosted view for [widgetId] at [heightPx], inflating it on
     * first use. Feed this straight to Compose's AndroidView.
     *
     * The view needs an explicit pixel height, not WRAP_CONTENT: left to wrap,
     * a widget paints only its minimum and leaves the rest of the row empty.
     * updateAppWidgetSize then tells the widget what it actually got, so its
     * RemoteViews pick the layout for that size rather than the smallest one.
     */
    fun view(widgetId: Int, heightPx: Int): AppWidgetHostView? {
        val info = manager.getAppWidgetInfo(widgetId) ?: return null
        val view = views.getOrPut(widgetId) {
            host.createView(context, widgetId, info).apply { setAppWidget(widgetId, info) }
        }
        applySize(view, heightPx)
        return view
    }

    private fun applySize(view: AppWidgetHostView, heightPx: Int) {
        val params = view.layoutParams
        if (params == null || params.height != heightPx) {
            view.layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                heightPx,
                Gravity.TOP,
            )
        }
        val density = context.resources.displayMetrics.density
        val widthDp = (context.resources.displayMetrics.widthPixels / density).toInt()
        val heightDp = (heightPx / density).toInt()
        resize(widgetId = view.appWidgetId, widthDp = widthDp, heightDp = heightDp)
    }

    /** Sizes in dp. Widgets lay themselves out from this, so keep it current. */
    fun resize(widgetId: Int, widthDp: Int, heightDp: Int) {
        val view = views[widgetId] ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            view.updateAppWidgetSize(
                android.os.Bundle.EMPTY,
                listOf(SizeF(widthDp.toFloat(), heightDp.toFloat())),
            )
        } else {
            @Suppress("DEPRECATION")
            view.updateAppWidgetSize(null, widthDp, heightDp, widthDp, heightDp)
        }
    }

    /**
     * How tall a freshly added widget should be.
     *
     * minHeight is the smallest the widget will accept, in pixels, and is often
     * far shorter than anything useful - the Apple Music widget declares 30dp.
     * A single-column list has the width to spare, so the default is generous
     * and the user can shrink it.
     */
    fun defaultHeightPx(info: AppWidgetProviderInfo): Int {
        val density = context.resources.displayMetrics.density
        val floor = (DEFAULT_MIN_HEIGHT_DP * density).toInt()
        return maxOf(info.minHeight, floor)
    }

    /**
     * Allocates an id and binds [provider] to it. Returns the id when the bind
     * succeeded outright; otherwise the caller must launch [bindPermissionIntent]
     * and only keep the id if the user allows it.
     */
    fun bind(provider: String): BindResult {
        val component = ComponentName.unflattenFromString(provider)
            ?: return BindResult.Failed
        val widgetId = host.allocateAppWidgetId()
        return if (manager.bindAppWidgetIdIfAllowed(widgetId, component)) {
            BindResult.Bound(widgetId, configureIntent(widgetId))
        } else {
            BindResult.NeedsPermission(widgetId, bindPermissionIntent(widgetId, component))
        }
    }

    /** Some widgets insist on a setup screen before they will render anything. */
    fun configureIntent(widgetId: Int): Intent? {
        val info = manager.getAppWidgetInfo(widgetId) ?: return null
        val configure = info.configure ?: return null
        return Intent(AppWidgetManager.ACTION_APPWIDGET_CONFIGURE).apply {
            component = configure
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
        }
    }

    private fun bindPermissionIntent(widgetId: Int, component: ComponentName) =
        Intent(AppWidgetManager.ACTION_APPWIDGET_BIND).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_PROVIDER, component)
        }

    fun remove(widgetId: Int) {
        views.remove(widgetId)
        host.deleteAppWidgetId(widgetId)
    }

    /** Frees ids the user never finished binding, so they do not leak on cancel. */
    fun releaseUnbound(widgetId: Int) {
        if (manager.getAppWidgetInfo(widgetId) == null) host.deleteAppWidgetId(widgetId)
    }

    sealed interface BindResult {
        data class Bound(val widgetId: Int, val configure: Intent?) : BindResult
        data class NeedsPermission(val widgetId: Int, val intent: Intent) : BindResult
        data object Failed : BindResult
    }

    companion object {
        /**
         * Carried over from the Flutter build. Changing it orphans every widget
         * users have already placed.
         */
        const val HOST_ID = 442

        /** Shortest a widget is shown at before the user resizes it. */
        const val DEFAULT_MIN_HEIGHT_DP = 110
    }
}

/** Convenience for the Activity-scoped bind flow. */
fun Activity.startWidgetIntent(intent: Intent, requestCode: Int) =
    startActivityForResult(intent, requestCode)
