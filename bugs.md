Status information:
[New]: Newly discovered bug
[Broken]: Have tried to fix, but still not working
[Half-working]: Some aspect of it are fixed, but some are still broken
[Fixed]: Bugs has been squashed
[Wontfix]: Will not fix the bug.

[Fixed] Deleting a folder did nothing until the launcher was restarted
- Files: lib/layouts/app_list_view.dart, lib/layouts/app_grid_view.dart
- Description: The delete handler ran inside the folder options bottom sheet, whose `context` was popped before the confirmation dialog was answered. The row was deleted from the database, then `if (!context.mounted) return;` bailed out before `onFoldersChanged()`, so the UI never reloaded. Now uses the State's context for the dialog and drops the stale guard (`_loadFolders` already checks `mounted`).
- Regression test: test/widget_test.dart deletes a folder and asserts it leaves the list.

[Fixed] Wallpaper flickered when navigating between screens
- Files: lib/main.dart, lib/settings_page.dart, lib/about_page.dart, android/app/src/main/res/values-night/styles.xml
- Description: Three causes. (1) Android's default page transition paints an opaque `colorScheme.surface` behind the outgoing route, flashing over the translucent window; now overridden with `FadeForwardsPageTransitionsBuilder(backgroundColor: Colors.transparent)`. (2) Every page carried its own 50% dim, so two of them stacked mid-transition; the dim now lives once in `MaterialApp.builder` and all scaffolds are transparent. (3) `values-night` overrode `Theme.Transparent` with an opaque white window background, hiding the wallpaper entirely in dark mode; the override is gone so it falls back to the transparent day style.

[Half-working] Some times the app crashes during or after uninstalling an app
- Files: lib/main.dart
- Description: `_loadApps` called `setState` before checking `mounted`, so the `resumed` lifecycle callback fired after the activity was torn down could throw. Guarded. The uninstall handler and the `resumed` callback still both kick off a background refresh; if crashes persist, look there next.

[Fixed] Sorting switch fall-through causes wrong order in app sections
- Files: lib/app_sections.dart
- Description: The `break` statements are present; alphabetical sorts no longer fall through.

[Fixed] Section index calculation ignores current sortType in scroll listeners
- Files: lib/layouts/app_list_view.dart, lib/layouts/app_grid_view.dart
- Description: Both scroll listeners pass `sortType: widget.sortType` to `AppSectionManager.createSections`.

[Fixed] MIUI detection logic inverted; triggers on non-Xiaomi devices
- Files: android/app/src/main/kotlin/com/kayfahaarukku/fuselauncher/AppQueryHelper.kt (deleted)
- Description: The dual-app branch queried the identical intent a second time and deduplicated it away, so it was a no-op. The whole `com.kayfahaarukku.fuselauncher/apps` channel it served was never invoked from Dart (the app uses the `installed_apps` plugin), so the channel and AppQueryHelper are gone.

[Fixed] Widget size unit mismatch between Flutter and Android
- Files: lib/widget_manager.dart, android/app/src/main/kotlin/com/kayfahaarukku/fuselauncher/MainActivity.kt
- Description: `updateWidgetSize` divides by `displayMetrics.density` before calling `updateAppWidgetSize`.

[Fixed] Potential crash: force-unwrapped flutterEngine in onBackPressed
- Files: android/app/src/main/kotlin/com/kayfahaarukku/fuselauncher/MainActivity.kt
- Description: `onBackPressed` null-checks the binary messenger and falls back to `super.onBackPressed()`.

[Wontfix] Missing import for Uint8List causes compile error
- Files: lib/app_package_manager.dart
- Description: `package:flutter/services.dart` re-exports `dart:typed_data`, so this compiles. Not a real bug.

[Wontfix] Fragile reliance on non-standard installed_apps MethodChannel methods
- Files: lib/app_package_manager.dart, pubspec.yaml (installed_apps git ref)
- Description: Code invokes channel methods like getAppInfo and isAppInstalled on 'installed_apps' channel that may not exist or may change in the git master fork, leading to runtime failures.
- Repro: If the dependency updates or is replaced with pub.dev release, calls throw PlatformException/notImplemented.

[Wontfix] Inconsistent spec: selecting apps to hide claims to exclude system apps but does not
- Files: lib/layouts/app_list_view.dart
- Description: Comment indicates "show all apps except system apps" when selecting to hide, but code uses the full widget.apps list without filtering. If widget.apps includes system apps, they will appear in the selection list.
- Repro: Ensure widget.apps contains system apps; enable "select apps to hide"; system apps appear in the list.

[New] Back navigation goes through a Kotlin round-trip and a global mutable
- Files: android/.../MainActivity.kt, lib/navigation_state.dart, lib/main.dart, lib/settings_page.dart, lib/about_page.dart
- Description: `onBackPressed` is overridden in Kotlin, asks Dart for `NavigationState.currentScreen` (a global static string kept in sync by hand on every push/pop), then either pops natively or hands back to Dart. Every page also needs `PopScope(canPop: false)` to work around it, and the manifest never opts into `enableOnBackInvokedCallback`, so predictive back is off. Flutter's own Navigator plus `PopScope` would do all of this. Left alone because it needs on-device testing to change safely.
