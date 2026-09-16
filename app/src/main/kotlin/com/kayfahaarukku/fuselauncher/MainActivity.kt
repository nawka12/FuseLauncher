package com.kayfahaarukku.fuselauncher

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.union
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.core.content.pm.PackageInfoCompat
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.lifecycleScope
import com.kayfahaarukku.fuselauncher.data.Biometrics
import com.kayfahaarukku.fuselauncher.notifications.NotificationListener
import com.kayfahaarukku.fuselauncher.ui.FuseTheme
import com.kayfahaarukku.fuselauncher.ui.HomeTab
import com.kayfahaarukku.fuselauncher.ui.HomeViewModel
import com.kayfahaarukku.fuselauncher.ui.LauncherRoot
import com.kayfahaarukku.fuselauncher.ui.Screen
import com.kayfahaarukku.fuselauncher.ui.Wallpaper
import com.kayfahaarukku.fuselauncher.widgets.WidgetHost

/**
 * FragmentActivity rather than ComponentActivity: BiometricPrompt needs a
 * fragment host to survive configuration changes mid-prompt.
 */
class MainActivity : FragmentActivity() {

    private val viewModel: HomeViewModel by viewModels()

    /** Set while a bind or configure round trip is in flight, so a cancel can free the id. */
    private var pendingWidgetId: Int? = null

    private val bindWidget = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        val widgetId = pendingWidgetId
        if (result.resultCode == RESULT_OK && widgetId != null) {
            val configure = viewModel.configureIntent(widgetId)
            if (configure != null) {
                configureWidget.launch(configure)
                return@registerForActivityResult
            }
        }
        finishWidget(result.resultCode == RESULT_OK)
    }

    private val configureWidget = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        finishWidget(result.resultCode == RESULT_OK)
    }

    private val uninstall = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { viewModel.refresh() }

    override fun onCreate(savedInstanceState: Bundle?) {
        preferHighestRefreshRate()
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)

        val info = packageManager.getPackageInfo(packageName, 0)

        setContent {
            FuseTheme {
                Surface(
                    color = Color.Transparent,
                    modifier = Modifier.fillMaxSize(),
                ) {
                    // Scrim first, edge to edge; the content insets itself.
                    // The IME joins the system bars in that inset, so a search
                    // bar pinned to the bottom rides above the keyboard instead
                    // of sitting behind it.
                    Box(
                        Modifier
                            .fillMaxSize()
                            .background(Wallpaper.scrim)
                            .windowInsetsPadding(
                                WindowInsets.systemBars.union(WindowInsets.ime)
                            ),
                    ) {
                        LauncherRoot(
                            viewModel = viewModel,
                            versionName = info.versionName.orEmpty(),
                            versionCode = PackageInfoCompat.getLongVersionCode(info),
                            onAuthenticate = { Biometrics.authenticate(this@MainActivity) },
                            onChangeWallpaper = ::changeWallpaper,
                            hasNotificationAccess = ::hasNotificationAccess,
                            onRequestNotificationAccess = ::requestNotificationAccess,
                            onLaunchIntent = { uninstall.launch(it) },
                            onBindWidget = ::startWidgetBind,
                            onOpenNotification = ::openNotification,
                            onDismissNotification = {
                                NotificationListener.instance?.dismiss(it)
                            },
                        )
                    }
                }
            }
        }
    }

    override fun onStart() {
        super.onStart()
        viewModel.startWidgetHost()
        viewModel.refreshWidgets()
    }

    override fun onStop() {
        super.onStop()
        viewModel.stopWidgetHost()
    }

    override fun onResume() {
        super.onResume()
        // An app may have been installed or removed while we were away.
        viewModel.refresh()
    }

    /** HOME pressed while already here: unwind back to the plain drawer. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        viewModel.screen.value = Screen.HOME
        viewModel.tab.value = HomeTab.APPS
        viewModel.openFolder.value = null
        viewModel.reorderingWidgets.value = false
        viewModel.search("")
    }

    private fun startWidgetBind(provider: String) {
        when (val result = viewModel.bindWidget(provider)) {
            is WidgetHost.BindResult.Bound -> {
                pendingWidgetId = result.widgetId
                if (result.configure != null) {
                    configureWidget.launch(result.configure)
                } else {
                    finishWidget(true)
                }
            }

            is WidgetHost.BindResult.NeedsPermission -> {
                pendingWidgetId = result.widgetId
                bindWidget.launch(result.intent)
            }

            WidgetHost.BindResult.Failed -> Unit
        }
    }

    /** Keeps the new widget, or releases the id the user backed out of. */
    private fun finishWidget(kept: Boolean) {
        val widgetId = pendingWidgetId ?: return
        pendingWidgetId = null
        if (kept) {
            viewModel.refreshWidgets()
        } else {
            viewModel.releaseUnboundWidget(widgetId)
        }
    }

    /** Matches the highest mode the panel supports, so scrolling is not capped at 60Hz. */
    private fun preferHighestRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        val supported = display?.supportedModes ?: return
        val maxRate = supported.maxOfOrNull { it.refreshRate } ?: return
        window.attributes = window.attributes.also { attributes ->
            attributes.preferredRefreshRate = maxRate
            attributes.preferredDisplayModeId =
                supported.firstOrNull { it.refreshRate == maxRate }?.modeId ?: 0
        }
    }

    /**
     * Never asked for automatically: prompting on start threw the user into
     * system settings every single time they pressed home. Settings offers it
     * instead, showing whether it is already granted.
     */
    fun hasNotificationAccess(): Boolean =
        Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
            ?.contains("$packageName/${NotificationListener::class.java.name}") == true

    fun requestNotificationAccess() {
        runCatching { startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)) }
    }

    /**
     * Fires a notification's own tap action, like tapping it in the shade,
     * minus the shade's auto-dismiss. Sent from the activity and with
     * background starts allowed, or the target is silently dropped on
     * Android 10 and up.
     */
    private fun openNotification(key: String) {
        val intent = NotificationListener.instance
            ?.notificationFor(key)
            ?.notification
            ?.contentIntent ?: return
        runCatching {
            val options = android.app.ActivityOptions.makeBasic()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                options.pendingIntentBackgroundActivityStartMode =
                    android.app.ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
            }
            intent.send(this, 0, null, null, null, null, options.toBundle())
        }
    }

    private fun changeWallpaper() {
        runCatching {
            startActivity(
                Intent.createChooser(Intent(Intent.ACTION_SET_WALLPAPER), "Select Wallpaper")
            )
        }
    }
}
