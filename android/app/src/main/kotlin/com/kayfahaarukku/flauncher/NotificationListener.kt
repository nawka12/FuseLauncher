package com.kayfahaarukku.flauncher

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import android.content.ComponentName

class NotificationListener : NotificationListenerService() {
    companion object {
        private const val TAG = "NotificationListener"
        var instance: NotificationListener? = null
        private val listeners = mutableListOf<(String, Boolean) -> Unit>()
        
        fun addListener(listener: (String, Boolean) -> Unit) {
            Log.d(TAG, "Adding listener")
            listeners.add(listener)
        }
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
    }
    
    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "onListenerConnected")
        requestRebind(ComponentName(this, NotificationListener::class.java))
        
        // Notify about existing notifications
        activeNotifications?.forEach { sbn ->
            if (!sbn.isOngoing) {
                Log.d(TAG, "Initial notification: ${sbn.packageName}")
                listeners.forEach { it(sbn.packageName, true) }
            }
        }
    }
    
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        Log.d(TAG, "Notification posted: ${sbn.packageName}")
        if (!sbn.isOngoing) {
            listeners.forEach { it(sbn.packageName, true) }
        }
    }
    
    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        Log.d(TAG, "Notification removed: ${sbn.packageName}")
        if (!sbn.isOngoing) {
            listeners.forEach { it(sbn.packageName, false) }
        }
    }
    
    fun clearNotificationsForPackage(packageName: String) {
        Log.d(TAG, "Clearing notifications for: $packageName")
        try {
            activeNotifications?.filter { 
                it.packageName == packageName && !it.isOngoing 
            }?.forEach { sbn ->
                cancelNotification(sbn.key)
            }
            // Notify listeners that notifications were cleared
            listeners.forEach { it(packageName, false) }
        } catch (e: Exception) {
            Log.e(TAG, "Error clearing notifications: ${e.message}")
        }
    }
}
