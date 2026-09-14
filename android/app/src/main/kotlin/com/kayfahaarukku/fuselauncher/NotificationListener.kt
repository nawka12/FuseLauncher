package com.kayfahaarukku.fuselauncher

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import android.content.ComponentName

/** Notifications the launcher shows a preview for: user-visible, dismissible ones. */
private fun StatusBarNotification.isPreviewable(): Boolean =
    !isOngoing && (notification.flags and Notification.FLAG_GROUP_SUMMARY) == 0

private fun StatusBarNotification.toMap(): Map<String, Any?> {
    val extras = notification.extras
    return mapOf(
        "packageName" to packageName,
        "key" to key,
        "title" to extras.getCharSequence(Notification.EXTRA_TITLE)?.toString(),
        "text" to (extras.getCharSequence(Notification.EXTRA_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_BIG_TEXT))?.toString(),
        "postTime" to postTime
    )
}

class NotificationListener : NotificationListenerService() {
    companion object {
        private const val TAG = "NotificationListener"
        var instance: NotificationListener? = null
        private var onChanged: (() -> Unit)? = null

        /** Set, not added: the engine is reconfigured on every activity restart. */
        fun setListener(listener: (() -> Unit)?) {
            onChanged = listener
        }

        /** Everything currently posted. The whole set every time, so Dart never
         *  has to keep its own tally in sync with posts, updates and dismissals. */
        fun snapshot(): List<Map<String, Any?>> =
            instance?.activeNotifications
                ?.filter { it.isPreviewable() }
                ?.map { it.toMap() }
                ?: emptyList()
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "onCreate")
        instance = this
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "onDestroy")
        instance = null
        onChanged?.invoke()
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "onListenerConnected")
        requestRebind(ComponentName(this, NotificationListener::class.java))
        onChanged?.invoke()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        onChanged?.invoke()
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        onChanged?.invoke()
    }

    /** The activity sends the tap action itself: a PendingIntent fired from a
     *  service has no foreground standing, so the target activity never starts. */
    fun notificationFor(key: String): StatusBarNotification? =
        activeNotifications?.firstOrNull { it.key == key }

    fun dismiss(key: String) {
        try {
            cancelNotification(key)
        } catch (e: Exception) {
            Log.e(TAG, "Error dismissing notification: ${e.message}")
        }
    }
}
