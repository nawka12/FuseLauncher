package com.kayfahaarukku.flauncher

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.graphics.drawable.Drawable
import android.os.Build

object AppQueryHelper {
    fun getLauncherActivities(context: Context): List<ResolveInfo> {
        val pm = context.packageManager
        val intent = Intent(Intent.ACTION_MAIN)
        intent.addCategory(Intent.CATEGORY_LAUNCHER)
        
        // Use MATCH_ALL for Android M and above, GET_UNINSTALLED_PACKAGES for older versions
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PackageManager.MATCH_ALL or PackageManager.GET_DISABLED_COMPONENTS
        } else {
            PackageManager.GET_UNINSTALLED_PACKAGES or PackageManager.GET_DISABLED_COMPONENTS
        }
        
        // Get all activities that can handle the launcher intent
        val activities = pm.queryIntentActivities(intent, flags)
            .filter { it.activityInfo.packageName != "com.kayfahaarukku.flauncher" }
        
        // For Xiaomi/MIUI devices, also check for dual apps
        if (isMIUI()) {
            val dualAppIntent = Intent(Intent.ACTION_MAIN)
            dualAppIntent.addCategory(Intent.CATEGORY_LAUNCHER)
            dualAppIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            
            val dualApps = pm.queryIntentActivities(dualAppIntent, flags)
                .filter { it.activityInfo.packageName != "com.kayfahaarukku.flauncher" }
            
            // Combine regular and dual apps, removing duplicates based on component name
            return (activities + dualApps).distinctBy { 
                "${it.activityInfo.packageName}/${it.activityInfo.name}"
            }
        }
        
        return activities
    }

    fun getAppIcon(context: Context, packageName: String): Drawable? {
        return try {
            val pm = context.packageManager
            pm.getApplicationIcon(packageName)
        } catch (e: Exception) {
            null
        }
    }

    fun getAppLabel(context: Context, packageName: String): String {
        return try {
            val pm = context.packageManager
            val appInfo = pm.getApplicationInfo(packageName, PackageManager.GET_UNINSTALLED_PACKAGES)
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            packageName
        }
    }

    private fun isMIUI(): Boolean {
        return !Build.MANUFACTURER.equals("Xiaomi", ignoreCase = true) &&
               !Build.MANUFACTURER.equals("Redmi", ignoreCase = true) &&
               getSystemProperty("ro.miui.ui.version.name", "").isNotEmpty()
    }

    private fun getSystemProperty(key: String, defaultValue: String): String {
        try {
            val clazz = Class.forName("android.os.SystemProperties")
            val method = clazz.getDeclaredMethod("get", String::class.java, String::class.java)
            return method.invoke(null, key, defaultValue) as String
        } catch (e: Exception) {
            return defaultValue
        }
    }
} 