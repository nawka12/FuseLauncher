package com.kayfahaarukku.fuselauncher.apps

import android.content.Context
import android.content.Intent
import android.content.pm.LauncherApps
import android.graphics.drawable.Drawable
import android.os.Process
import android.os.UserHandle
import android.os.UserManager
import androidx.compose.runtime.Immutable

@Immutable
data class LauncherApp(
    val packageName: String,
    val componentName: String,
    val label: String,
    /** null means the current user - keeps the type free of Android for tests. */
    val user: UserHandle? = null,
    /**
     * What pins, hidden apps, folders and usage counts store for this app. The
     * current user's copy is its bare package name, exactly what Flutter stored,
     * so migrated data still means the same app. A clone or work-profile copy
     * has the same package name, so its id adds the profile: "com.whatsapp@11".
     */
    val id: String = packageName,
) {
    val key: String get() = "$componentName@${user?.hashCode() ?: 0}"

    fun userOrCurrent(): UserHandle = user ?: Process.myUserHandle()
}

/**
 * [LauncherApp.id] for one copy of [packageName]: bare for the current user,
 * which is what Flutter stored, or with a clone's or work copy's profile serial.
 */
fun appId(packageName: String, profileSerial: Long?): String =
    if (profileSerial == null) packageName else "$packageName@$profileSerial"

/**
 * The installed app list, straight from LauncherApps.
 *
 * LauncherApps is the API the system intends launchers to use: it already
 * excludes apps with no launcher entry, spans work profiles, and hands back
 * icons the system has cached, so there is no local name/icon table to keep in
 * sync with package installs.
 */
class AppRepository(private val context: Context) {

    private val launcherApps =
        context.getSystemService(Context.LAUNCHER_APPS_SERVICE) as LauncherApps
    private val packageManager = context.packageManager
    private val userManager = context.getSystemService(UserManager::class.java)

    fun loadApps(): List<LauncherApp> {
        val excluded = otherLaunchers() + context.packageName
        val me = Process.myUserHandle()
        return launcherApps.profiles.flatMap { user ->
            // A serial number, not the user id: ids are reused once a profile
            // is removed, serials never are, so a stale entry cannot come back
            // attached to some new profile's app.
            val serial = if (user == me) null else userManager.getSerialNumberForUser(user)
            launcherApps.getActivityList(null, user).map { activity ->
                val packageName = activity.applicationInfo.packageName
                LauncherApp(
                    packageName = packageName,
                    componentName = activity.componentName.flattenToString(),
                    label = activity.label.toString(),
                    user = user,
                    id = appId(packageName, serial),
                )
            }
        }.filterNot { it.packageName in excluded }
    }

    fun icon(app: LauncherApp): Drawable? =
        launcherApps.getActivityList(app.packageName, app.userOrCurrent())
            .firstOrNull { it.componentName.flattenToString() == app.componentName }
            ?.getBadgedIcon(0)

    /**
     * Packages whose drawer entry is itself a home screen - other launchers, and
     * us. Matching on CATEGORY_HOME alone would also catch home stubs that have
     * no drawer entry of their own, like Settings' FallbackHome, so only
     * components answering to both categories count.
     */
    fun otherLaunchers(): Set<String> {
        val homes = packageManager
            .queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME), 0)
            .map { it.activityInfo.packageName to it.activityInfo.name }
            .toSet()
        return packageManager
            .queryIntentActivities(
                Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER), 0
            )
            .filter { (it.activityInfo.packageName to it.activityInfo.name) in homes }
            .map { it.activityInfo.packageName }
            .toSet()
    }

    fun launch(app: LauncherApp) {
        launcherApps.startMainActivity(
            android.content.ComponentName.unflattenFromString(app.componentName),
            app.userOrCurrent(),
            null,
            null,
        )
    }

    fun openAppInfo(app: LauncherApp) {
        launcherApps.startAppDetailsActivity(
            android.content.ComponentName.unflattenFromString(app.componentName),
            app.userOrCurrent(),
            null,
            null,
        )
    }

    /** System apps cannot be uninstalled, so the sheet hides the option. */
    fun isSystemApp(app: LauncherApp): Boolean = runCatching {
        val flags = packageManager.getApplicationInfo(app.packageName, 0).flags
        (flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0 ||
            (flags and android.content.pm.ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
    }.getOrDefault(true)

    /** Uninstall is a system dialog; only offer it for the current user's apps. */
    fun uninstallIntent(app: LauncherApp): Intent? =
        if (app.userOrCurrent() != Process.myUserHandle()) null
        else Intent(Intent.ACTION_DELETE, android.net.Uri.parse("package:${app.packageName}"))

    /** Fires [onChange] whenever a package is added, removed or updated. */
    fun observePackages(onChange: () -> Unit): AutoCloseable {
        val callback = object : LauncherApps.Callback() {
            override fun onPackageAdded(packageName: String?, user: UserHandle?) = onChange()
            override fun onPackageRemoved(packageName: String?, user: UserHandle?) = onChange()
            override fun onPackageChanged(packageName: String?, user: UserHandle?) = onChange()
            override fun onPackagesAvailable(
                names: Array<out String>?, user: UserHandle?, replacing: Boolean
            ) = onChange()

            override fun onPackagesUnavailable(
                names: Array<out String>?, user: UserHandle?, replacing: Boolean
            ) = onChange()
        }
        launcherApps.registerCallback(callback)
        return AutoCloseable { launcherApps.unregisterCallback(callback) }
    }
}
