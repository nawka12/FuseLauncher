Status information:
[New]: Newly discovered bug
[Broken]: Have tried to fix, but still not working
[Half-working]: Some aspect of it are fixed, but some are still broken
[Fixed]: Bugs has been squashed
[Wontfix]: Will not fix the bug.

[New] Sorting switch fall-through causes wrong order in app sections
- Files: lib/app_sections.dart
- Description: In AppSectionManager.createSections, missing break statements in the switch make alphabeticalAsc fall into alphabeticalDesc and then usage, resulting in Z→A order and mismatched section headers when alphabetical sorting is selected.
- Repro: Set app list sort to A→Z and observe list/grid renders Z→A and header behavior is inconsistent.

[New] Section index calculation ignores current sortType in scroll listeners
- Files: lib/layouts/app_list_view.dart, lib/layouts/app_grid_view.dart
- Description: Scroll listeners call AppSectionManager.createSections without passing the active sortType, so section headers/haptics are computed using default alphabetical sort, not the user's selected sort.
- Repro: Set sort to Z→A or usage; scroll and notice sticky headers/haptics do not match visible sectioning.

[Wontfix] Missing import for Uint8List causes compile error
- Files: lib/app_package_manager.dart
- Description: File references Uint8List but does not import dart:typed_data, leading to a compile-time error.
- Repro: Run a build; analyzer reports undefined identifier Uint8List in app_package_manager.dart.

[New] MIUI detection logic inverted; triggers on non-Xiaomi devices
- Files: android/app/src/main/kotlin/com/kayfahaarukku/fuselauncher/AppQueryHelper.kt
- Description: isMIUI() negates manufacturer checks, returning true for non-Xiaomi/Redmi devices and false for Xiaomi/Redmi when MIUI property exists. Dual-app query path can run incorrectly.
- Repro: On non-Xiaomi device, isMIUI() returns true leading to redundant queries and potential duplicates.

[New] Widget size unit mismatch between Flutter and Android
- Files: lib/widget_manager.dart, android/app/src/main/kotlin/com/kayfahaarukku/fuselauncher/MainActivity.kt
- Description: Flutter sends logical pixel width/height to updateWidgetSize; Android forwards these ints directly to updateAppWidgetSize (expects dp), causing widgets to render at incorrect sizes on various densities.
- Repro: Add a widget and resize; sizes appear inconsistent across devices with different DPI.

[New] Potential crash: force-unwrapped flutterEngine in onBackPressed
- Files: android/app/src/main/kotlin/com/kayfahaarukku/fuselauncher/MainActivity.kt
- Description: Uses flutterEngine?.dartExecutor?.binaryMessenger!!; if flutterEngine is null, app crashes when back is pressed before engine ready.
- Repro: Trigger onBackPressed very early during app startup on some devices; observe crash.

[Wontfix] Fragile reliance on non-standard installed_apps MethodChannel methods
- Files: lib/app_package_manager.dart, pubspec.yaml (installed_apps git ref)
- Description: Code invokes channel methods like getAppInfo and isAppInstalled on 'installed_apps' channel that may not exist or may change in the git master fork, leading to runtime failures.
- Repro: If the dependency updates or is replaced with pub.dev release, calls throw PlatformException/notImplemented.

[Wontfix] Inconsistent spec: selecting apps to hide claims to exclude system apps but does not
- Files: lib/layouts/app_list_view.dart
- Description: Comment indicates "show all apps except system apps" when selecting to hide, but code uses the full widget.apps list without filtering. If widget.apps includes system apps, they will appear in the selection list.
- Repro: Ensure widget.apps contains system apps; enable "select apps to hide"; system apps appear in the list.

[New] Some times the app crashes during or after uninstalling an app.