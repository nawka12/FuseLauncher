package com.kayfahaarukku.fuselauncher.notifications

import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.UserHandle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/** One notification an app is currently showing. */
data class AppNotification(
    val packageName: String,
    /** A cloned or work-profile copy of an app posts as its own user. */
    val user: UserHandle,
    val key: String,
    val title: String,
    val text: String,
    val postTime: Long,
) {
    val hasPreview: Boolean get() = title.isNotEmpty() || text.isNotEmpty()
}

/** One installed copy of an app: its package, and the user it runs as. */
typealias AppKey = Pair<String, UserHandle>

/** Notifications the launcher previews: user-visible, dismissible ones. */
private fun StatusBarNotification.isPreviewable(): Boolean =
    !isOngoing && (notification.flags and Notification.FLAG_GROUP_SUMMARY) == 0

/**
 * The user whose copy of the app this notification belongs to. One posted to
 * every user at once (USER_ALL, a negative id, which some system apps use)
 * would match no tile, so it goes to the user of the app that posted it, as
 * its uid says - the tile it sat on before notifications were keyed by user.
 */
@Suppress("DEPRECATION") // getUser() hides USER_ALL behind a UserHandle; the id shows it
private val StatusBarNotification.owner: UserHandle
    get() = if (userId >= 0) user else UserHandle.getUserHandleForUid(uid)

private fun StatusBarNotification.toAppNotification(): AppNotification {
    val extras = notification.extras
    return AppNotification(
        packageName = packageName,
        user = owner,
        key = key,
        title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty(),
        text = (extras.getCharSequence(Notification.EXTRA_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_BIG_TEXT))?.toString().orEmpty(),
        postTime = postTime,
    )
}

class NotificationListener : NotificationListenerService() {

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        connected = false
        publish()
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        connected = true
        publish()
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        connected = false
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) = publish()

    override fun onNotificationRemoved(sbn: StatusBarNotification) = publish()

    fun notificationFor(key: String): StatusBarNotification? =
        runCatching { activeNotifications?.firstOrNull { it.key == key } }.getOrNull()

    fun dismiss(key: String) {
        runCatching { cancelNotification(key) }
            .onFailure { Log.e(TAG, "Error dismissing notification: ${it.message}") }
        publish()
    }

    companion object {
        private const val TAG = "NotificationListener"

        var instance: NotificationListener? = null
            private set

        /** Whether the system has the listener bound and delivering right now. */
        @Volatile
        var connected = false
            private set

        /**
         * Makes the system bind the listener again after it was dropped. MIUI
         * drops it when it kills or freezes the launcher, and Android never
         * binds it back by itself, so badges went blank until something did.
         *
         * requestRebind() cannot do this: it only undoes requestUnbind(), and
         * the system ignores it for a listener dropped any other way. Turning
         * the component off and on is a package change, which makes the system
         * rebind the package's enabled listeners. The Flutter build did this on
         * every start; this does it only when the listener is actually gone.
         */
        fun rebind(context: Context) {
            val component = ComponentName(context, NotificationListener::class.java)
            val packageManager = context.packageManager
            runCatching {
                packageManager.setComponentEnabledSetting(
                    component,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP,
                )
                packageManager.setComponentEnabledSetting(
                    component,
                    PackageManager.COMPONENT_ENABLED_STATE_DEFAULT,
                    PackageManager.DONT_KILL_APP,
                )
            }.onFailure { Log.e(TAG, "Error rebinding listener: ${it.message}") }
        }

        private val _byApp = MutableStateFlow<Map<AppKey, List<AppNotification>>>(emptyMap())

        /**
         * Every posted notification, grouped by app and newest first. The whole
         * set is republished on each change, so nothing has to keep a running
         * tally in sync with posts, updates and dismissals.
         *
         * Keyed by user as well as package: an app clone (Xiaomi's Dual Apps,
         * Android's app cloning) or a work-profile copy has the same package
         * name, and keying on that alone showed each copy the other's messages.
         */
        val byApp: StateFlow<Map<AppKey, List<AppNotification>>> = _byApp

        private fun publish() {
            _byApp.value = group(
                runCatching { instance?.activeNotifications?.toList() }.getOrNull().orEmpty()
            )
        }

        fun group(raw: List<StatusBarNotification>): Map<AppKey, List<AppNotification>> = raw
            .filter { it.isPreviewable() }
            .map { it.toAppNotification() }
            .groupBy { it.packageName to it.user }
            .mapValues { (_, list) -> list.sortedByDescending { it.postTime } }
    }
}

/** "now", "49m", "10h", "3d" - the age suffix shown after the app name. */
fun shortAgo(postTime: Long, now: Long = System.currentTimeMillis()): String {
    val seconds = (now - postTime) / 1000
    return when {
        seconds < 60 -> "now"
        seconds < 3600 -> "${seconds / 60}m"
        seconds < 86_400 -> "${seconds / 3600}h"
        else -> "${seconds / 86_400}d"
    }
}
