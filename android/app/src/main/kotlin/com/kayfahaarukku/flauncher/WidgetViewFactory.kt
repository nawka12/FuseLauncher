package com.kayfahaarukku.flauncher

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import android.view.ViewGroup
import android.view.Gravity
import android.appwidget.AppWidgetHostView
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class WidgetViewFactory(private val activity: MainActivity) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context?, viewId: Int, args: Any?): PlatformView {
        return WidgetPlatformView(context!!, viewId, args as? Map<String?, Any?>, activity)
    }
}

class WidgetPlatformView(
    private val context: Context,
    private val id: Int,
    private val creationParams: Map<String?, Any?>?,
    private val activity: MainActivity
) : PlatformView {
    private val container: FrameLayout = FrameLayout(context)

    init {
        setupWidget()
    }

    private fun setupWidget() {
        val widgetId = creationParams?.get("widgetId") as? Int ?: return
        val density = context.resources.displayMetrics.density
        val width = ViewGroup.LayoutParams.MATCH_PARENT
        val rawHeight = creationParams?.get("height") as? Int ?: return
        val height = (rawHeight * density).toInt()
        
        val widgetView = activity.getWidgetView(widgetId)
        
        widgetView?.let { view ->
            (view.parent as? ViewGroup)?.removeView(view)
            
            container.setPadding(0, 0, 0, 0)
            container.layoutParams = FrameLayout.LayoutParams(
                width,
                height
            )
            container.setBackgroundColor(android.graphics.Color.TRANSPARENT)
            
            view.layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                height,
                Gravity.TOP
            ).apply {
                setMargins(0, 0, 0, 0)
            }
            
            container.addView(view)
        }
    }

    override fun getView(): View = container

    override fun dispose() {
        container.removeAllViews()
    }
} 