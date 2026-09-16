package com.kayfahaarukku.fuselauncher.notifications

import android.app.Notification
import android.content.ComponentName
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/** One notification an app is currently showing. */
data class AppNotification(
    val packageName: String,
    val key: String,
    val title: String,
    val text: String,
    val postTime: Long,
) {
    val hasPreview: Boolean get() = title.isNotEmpty() || text.isNotEmpty()
}

/** Notifications the launcher previews: user-visible, dismissible ones. */
private fun StatusBarNotification.isPreviewable(): Boolean =
    !isOngoing && (notification.flags and Notification.FLAG_GROUP_SUMMARY) == 0

private fun StatusBarNotification.toAppNotification(): AppNotification {
    val extras = notification.extras
    return AppNotification(
        packageName = packageName,
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
        publish()
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        requestRebind(ComponentName(this, NotificationListener::class.java))
        publish()
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

        private val _byPackage = MutableStateFlow<Map<String, List<AppNotification>>>(emptyMap())

        /**
         * Every posted notification, grouped by app and newest first. The whole
         * set is republished on each change, so nothing has to keep a running
         * tally in sync with posts, updates and dismissals.
         */
        val byPackage: StateFlow<Map<String, List<AppNotification>>> = _byPackage

        private fun publish() {
            _byPackage.value = group(
                runCatching { instance?.activeNotifications?.toList() }.getOrNull().orEmpty()
            )
        }

        fun group(raw: List<StatusBarNotification>): Map<String, List<AppNotification>> = raw
            .filter { it.isPreviewable() }
            .map { it.toAppNotification() }
            .groupBy { it.packageName }
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
