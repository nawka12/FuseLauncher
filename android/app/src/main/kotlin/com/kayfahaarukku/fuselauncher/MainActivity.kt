package com.kayfahaarukku.fuselauncher

import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProviderInfo
import android.appwidget.AppWidgetHostView
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode.transparent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import android.provider.Settings
import android.graphics.Bitmap
import java.io.ByteArrayOutputStream
import android.graphics.drawable.BitmapDrawable
import android.graphics.Canvas
import android.util.Log
import android.content.pm.PackageManager
import io.flutter.plugins.GeneratedPluginRegistrant

fun android.graphics.drawable.Drawable.toBitmap(): Bitmap {
    if (this is BitmapDrawable) {
        return this.bitmap
    }
    
    val bitmap = Bitmap.createBitmap(
        intrinsicWidth.coerceAtLeast(1),
        intrinsicHeight.coerceAtLeast(1),
        Bitmap.Config.ARGB_8888
    )
    val canvas = Canvas(bitmap)
    setBounds(0, 0, canvas.width, canvas.height)
    draw(canvas)
    return bitmap
}

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.kayfahaarukku.fuselauncher/widgets"
    private val REQUEST_PICK_APPWIDGET = 9
    private val REQUEST_CREATE_APPWIDGET = 5
    private val APPWIDGET_HOST_ID = 442
    private val NOTIFICATION_LISTENER_SETTINGS = 1001
    private var widgetHost: AppWidgetHost? = null
    internal var widgetManager: AppWidgetManager? = null
    private val widgetViews = mutableMapOf<Int, AppWidgetHostView>()

    override fun onCreate(savedInstanceState: Bundle?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.attributes = window.attributes.also { 
                val display = window.context.display
                if (display != null) {
                    val maxRate = display.supportedModes.maxOf { it.refreshRate }
                    it.preferredRefreshRate = maxRate
                    it.preferredDisplayModeId = display.supportedModes.firstOrNull { mode ->
                        mode.refreshRate == maxRate
                    }?.modeId ?: 0
                }
            }
        }
        intent.putExtra("background_mode", transparent.toString())
        super.onCreate(savedInstanceState)
        widgetManager = AppWidgetManager.getInstance(this)
        widgetHost = AppWidgetHost(this, APPWIDGET_HOST_ID)
        widgetHost?.startListening()

        // Add Z to A sorting option
        val sortOptions = listOf(
            "usage" to "Sort by Usage",
            "alphabeticalAsc" to "Sort A to Z",
            "alphabeticalDesc" to "Sort Z to A"
        )
    }

    private fun createWidgetView(appWidgetId: Int, provider: AppWidgetProviderInfo): AppWidgetHostView? {
        val widgetView = widgetHost?.createView(this, appWidgetId, provider)
        if (widgetView != null) {
            val density = resources.displayMetrics.density
            val width = ViewGroup.LayoutParams.MATCH_PARENT
            val height = (provider.minHeight * density).toInt()
            
            widgetView.setPadding(16, 16, 16, 16)
            widgetView.layoutParams = ViewGroup.LayoutParams(width, height)
            widgetView.setBackgroundColor(android.graphics.Color.TRANSPARENT)
            widgetViews[appWidgetId] = widgetView
        }
        return widgetView
    }

    fun getWidgetView(widgetId: Int): AppWidgetHostView? {
        return widgetViews[widgetId] ?: run {
            val provider = widgetManager?.getAppWidgetInfo(widgetId)
            if (provider != null) {
                createWidgetView(widgetId, provider)
            } else {
                null
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (resultCode == RESULT_OK) {
            if (requestCode == REQUEST_CREATE_APPWIDGET || requestCode == REQUEST_PICK_APPWIDGET) {
                val appWidgetId = data?.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1) ?: -1
                if (appWidgetId != -1) {
                    val provider = widgetManager?.getAppWidgetInfo(appWidgetId)
                    if (provider != null) {
                        createWidgetView(appWidgetId, provider)
                    }
                }
            }
        } else if (resultCode == RESULT_CANCELED) {
            if (data != null) {
                val appWidgetId = data.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1)
                if (appWidgetId != -1) {
                    widgetHost?.deleteAppWidgetId(appWidgetId)
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        widgetHost?.stopListening()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        
        // Register platform view factory
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory("android_widget_view", WidgetViewFactory(this))

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getWidgetList" -> {
                    val widgets = widgetManager?.installedProviders?.map {
                        mapOf(
                            "label" to it.loadLabel(packageManager),
                            "provider" to it.provider.flattenToString(),
                            "minWidth" to it.minWidth,
                            "minHeight" to it.minHeight,
                            "previewImage" to it.previewImage?.toString(),
                            "appName" to packageManager.getApplicationLabel(
                                packageManager.getApplicationInfo(it.provider.packageName, 0)
                            ).toString()
                        )
                    }
                    result.success(widgets)
                }
                "getAddedWidgets" -> {
                    val host = widgetHost
                    if (host != null) {
                        val addedWidgets = host.appWidgetIds?.map { widgetId ->
                            val provider = widgetManager?.getAppWidgetInfo(widgetId)
                            if (provider != null) {
                                val widgetView = widgetViews[widgetId] ?: createWidgetView(widgetId, provider)
                                
                                val previewBase64 = if (provider.previewImage != 0) {
                                    try {
                                        val drawable = packageManager.getDrawable(provider.provider.packageName, provider.previewImage, null)
                                        if (drawable != null) {
                                            val bitmap = drawable.toBitmap()
                                            val stream = ByteArrayOutputStream()
                                            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                                            android.util.Base64.encodeToString(stream.toByteArray(), android.util.Base64.NO_WRAP)
                                        } else ""
                                    } catch (e: Exception) {
                                        ""
                                    }
                                } else ""
                                
                                mapOf(
                                    "label" to provider.loadLabel(packageManager),
                                    "provider" to provider.provider.flattenToString(),
                                    "minWidth" to provider.minWidth,
                                    "minHeight" to provider.minHeight,
                                    "previewImage" to previewBase64,
                                    "widgetId" to widgetId,
                                    "appName" to packageManager.getApplicationLabel(
                                        packageManager.getApplicationInfo(provider.provider.packageName, 0)
                                    ).toString(),
                                    "packageName" to provider.provider.packageName
                                )
                            } else null
                        }?.filterNotNull() ?: emptyList()
                        result.success(addedWidgets)
                    } else {
                        result.success(emptyList<Map<String, Any>>())
                    }
                }
                "addWidget" -> {
                    val provider = call.argument<String>("provider")
                    if (provider != null) {
                        val component = ComponentName.unflattenFromString(provider)
                        if (component != null) {
                            val appWidgetId = widgetHost?.allocateAppWidgetId() ?: -1
                            
                            if (appWidgetId != -1 && widgetManager?.bindAppWidgetIdIfAllowed(appWidgetId, component) == true) {
                                val configureIntent = Intent(AppWidgetManager.ACTION_APPWIDGET_CONFIGURE)
                                configureIntent.component = component
                                configureIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                                startActivityForResult(configureIntent, REQUEST_CREATE_APPWIDGET)
                                result.success(true)
                            } else {
                                val bindIntent = Intent(AppWidgetManager.ACTION_APPWIDGET_BIND)
                                bindIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                                bindIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_PROVIDER, component)
                                startActivityForResult(bindIntent, REQUEST_PICK_APPWIDGET)
                                result.success(true)
                            }
                        } else {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "removeWidget" -> {
                    handleRemoveWidget(call, result)
                }
                "updateWidgetSize" -> {
                    val widgetId = call.argument<Int>("widgetId")
                    val width = call.argument<Int>("width")
                    val height = call.argument<Int>("height")
                    
                    if (widgetId != null && width != null && height != null) {
                        val widgetView = widgetViews[widgetId]
                        widgetView?.updateAppWidgetSize(null, width, height, width, height)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.kayfahaarukku.fuselauncher/apps")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getApps" -> {
                        val apps = AppQueryHelper.getLauncherActivities(this).map { resolveInfo ->
                            val packageName = resolveInfo.activityInfo.packageName
                            mapOf(
                                "name" to AppQueryHelper.getAppLabel(this, packageName),
                                "packageName" to packageName,
                                "icon" to AppQueryHelper.getAppIcon(this, packageName)?.let { drawable ->
                                    val bitmap = drawable.toBitmap()
                                    ByteArrayOutputStream().use { stream ->
                                        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                                        stream.toByteArray()
                                    }
                                }
                            )
                        }
                        result.success(apps)
                    }
                    "openAppSettings" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName != null) {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                            intent.data = Uri.parse("package:$packageName")
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.error("INVALID_PACKAGE", "Package name is null", null)
                        }
                    }
                    "launchApp" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName != null) {
                            val intent = packageManager.getLaunchIntentForPackage(packageName)
                            if (intent != null) {
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                                intent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                                intent.addFlags(Intent.FLAG_ACTIVITY_NO_HISTORY)
                                startActivity(intent)
                                NotificationListener.instance?.clearNotificationsForPackage(packageName)
                                result.success(true)
                            } else {
                                result.success(false)
                            }
                        } else {
                            result.success(false)
                        }
                    }
                    "clearStack" -> {
                        clearStack()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.kayfahaarukku.fuselauncher/notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestNotificationAccess" -> {
                        Log.d("MainActivity", "Requesting notification access")
                        if (!isNotificationServiceEnabled()) {
                            startActivityForResult(
                                Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS),
                                NOTIFICATION_LISTENER_SETTINGS
                            )
                        }
                        toggleNotificationListenerService()
                        result.success(isNotificationServiceEnabled())
                    }
                    "getCurrentNotifications" -> {
                        NotificationListener.instance?.let { listener ->
                            val notifications = mutableMapOf<String, Int>()
                            listener.activeNotifications?.forEach { sbn ->
                                if (!sbn.isOngoing) {
                                    notifications[sbn.packageName] = 
                                        (notifications[sbn.packageName] ?: 0) + 1
                                }
                            }
                            result.success(notifications)
                        } ?: result.success(mapOf<String, Int>())
                    }
                    else -> result.notImplemented()
                }
            }
            
        NotificationListener.addListener { packageName, isPosted ->
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.kayfahaarukku.fuselauncher/notifications")
                .invokeMethod(
                    if (isPosted) "onNotificationPosted" else "onNotificationRemoved",
                    mapOf("packageName" to packageName)
                )
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.kayfahaarukku.fuselauncher/system")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "changeWallpaper" -> {
                        try {
                            val intent = Intent(Intent.ACTION_SET_WALLPAPER)
                            startActivity(Intent.createChooser(intent, "Select Wallpaper"))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", "Failed to launch wallpaper picker", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    fun removeWidgetView(widgetId: Int) {
        widgetViews.remove(widgetId)
    }

    private fun handleRemoveWidget(call: MethodCall, result: Result) {
        try {
            val widgetId = call.argument<Int>("widgetId")
            if (widgetId != null) {
                removeWidgetView(widgetId)
                widgetHost?.deleteAppWidgetId(widgetId)
                result.success(true)
            } else {
                result.success(false)
            }
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        val enabled = flat?.contains(packageName + "/" + NotificationListener::class.java.name) == true
        Log.d("MainActivity", "Notification service enabled: $enabled")
        return enabled
    }

    private fun toggleNotificationListenerService() {
        val packageManager = packageManager
        packageManager.setComponentEnabledSetting(
            ComponentName(this, NotificationListener::class.java),
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP
        )
        packageManager.setComponentEnabledSetting(
            ComponentName(this, NotificationListener::class.java),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP
        )
    }

    private fun clearStack() {
        val intent = Intent(this, MainActivity::class.java)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        startActivity(intent)
    }

    override fun onBackPressed() {
        val channel = MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger!!, "com.kayfahaarukku.fuselauncher/system")
        channel.invokeMethod("getNavigationState", null, object : MethodChannel.Result {
            override fun success(result: Any?) {
                when (result as? String) {
                    "settings", "about" -> {
                        // Allow back button for settings and about pages
                        super@MainActivity.onBackPressed()
                    }
                    else -> {
                        // For main screen or any other state, handle in Flutter
                        channel.invokeMethod("onBackPressed", null, object : MethodChannel.Result {
                            override fun success(result: Any?) {
                                // Flutter handled the back press, do nothing
                            }
                            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                                // On error, do nothing
                            }
                            override fun notImplemented() {
                                // Method not implemented, do nothing
                            }
                        })
                    }
                }
            }
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                // On error, do nothing
            }
            override fun notImplemented() {
                // Method not implemented, do nothing
            }
        })
    }
}