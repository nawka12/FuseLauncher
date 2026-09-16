# FuseLauncher

A modern Android launcher, in Kotlin and Jetpack Compose.

```bash
./gradlew installDebug
```

Requires JDK 17 and Android SDK 36. Everything else comes from Gradle.

## Relationship to the Flutter version

FuseLauncher was written in Flutter through 1.4.0. This branch is the Kotlin
rewrite; the Dart sources are on `main` up to commit `4aa5c62` if you need to
compare behaviour.

Debug builds install as `com.kayfahaarukku.fuselauncher.native`, labelled
"Fuse Native", so they can sit beside an installed Flutter build while you
compare the two. Both declare `CATEGORY_HOME`, so Android asks which to use the
first time you press home after installing. Release builds use the real
application id.

**The side-by-side debug build cannot test the migration.** A different
application id is a different sandbox: there is no `FlutterSharedPreferences`
file or `fuselauncher.db` to read. To exercise it, drop `applicationIdSuffix`
from the debug build type and install over the real app - on a spare device,
since that replaces the launcher.

## What is here

| Area | State |
|---|---|
| App list from `LauncherApps`, other launchers filtered out | done |
| Search ranking, A-Z sections, usage decay + tie order | ported, unit tested |
| Settings store + one-time migration off Flutter's prefs | done, unit tested |
| List and grid layouts, 2-6 columns | done |
| A-Z index strip with the drag hint | done |
| Pinned row, folders, hidden apps behind biometrics | done |
| Long-press sheet: pin, hide, uninstall, app info, folders | done |
| Sort sheet for the app list and the pinned row | done |
| Notification badges and previews | done |
| Widgets: add, remove, reorder, resize, live hosting | done |
| Widget sizing: explicit host-view height + updateAppWidgetSize | done |
| Settings and About screens | done, Flutter-matched |
| Search bar at top or bottom | done |
| Swipe between Apps and Widgets, tab highlight tracks the drag | done |
| Search bar rides above the keyboard when pinned to the bottom | done |
| Slide-and-fade transitions into Settings and About | done |
| Flutter-matched drawer: metrics, badges, previews, chrome | done |
| Notification popup: open or swipe away a notification | done |

## Migrating user data

Users upgrading from the Flutter build keep their settings, because both stores
are read in place on first launch:

- **Preferences** live in the `FlutterSharedPreferences` XML file under a
  `flutter.` key prefix. String lists are a tagged base64 blob of a Java
  serialised `ArrayList<String>`; `FlutterPrefs` decodes that, restricted to
  string lists so a tampered pref cannot instantiate arbitrary classes.
  `Settings` copies everything across once and sets `migrated_from_flutter`.
  The Flutter keys are deliberately left in place, so downgrading is not
  destructive.
- **Folders** stay in `fuselauncher.db`, opened at the same version sqflite
  used, so no upgrade path fires. The old `apps` table was a name/icon cache
  that `LauncherApps` supplies directly; it is dropped rather than carried.
- **Widget ids** survive because `WidgetHost.HOST_ID` is still 442. Changing it
  orphans every widget a user has already placed.

Migration is only exercised by unit tests over the encoding. Before trusting it
on a real device, install over a populated Flutter build and check that pinned
apps, hidden apps, sort order and widget layout all come across.

## Matching the Flutter build

The drawer is meant to be visually indistinguishable from the Flutter version,
so the numbers are copied from it rather than picked fresh:

| Element | Value |
|---|---|
| App icon | 56dp, 12dp corners, cropped |
| Row padding | 16dp horizontal, 4dp vertical |
| App name | 17sp, medium |
| Notification age suffix | 13sp, muted, `· 33m` after the name |
| Preview title / text | 14sp medium / 13sp muted, two lines |
| Unread badge | red circle, 22dp minimum, overhanging the icon's top-right, 12sp |
| Section header | 20sp bold, 16dp / 10dp padding |
| Search bar | `#2D2D2D`, 16dp corners, sort and settings inside it |
| Index strip | 28dp wide, star for the pinned and folder run |
| Typeface | Poppins, the faces the Flutter build used (licence in `licenses/`) |
| Settings card | `#2D2D2D`, 20dp corners, tinted 14dp icon tile, 20dp inset |
| Settings hero | `#6750A4` gradient to 80% alpha, 20dp corners |
| About hero | same gradient, 24dp corners, 120dp logo at 28dp corners |
| About cards | `#2D2D2D`, 20dp corners, 24dp padding, tinted icon tile |

Settings and About draw no background of their own: like the Flutter build's
Scaffolds they are transparent, so the wallpaper and its scrim carry through.

Pinned apps are full-width rows under a "Pinned Apps" header, not a separate
icon strip, and an app that is pinned still appears in its letter section - the
pin marker only shows on the pinned run. Both match the Flutter build.

## Hosting widgets

Two things that are easy to get wrong, and were:

- `AppWidgetProviderInfo.minWidth` / `minHeight` are in **pixels**, not dp,
  despite reading like dp. They are also a floor, not a preference: the Apple
  Music widget declares 30dp tall. `WidgetHost.defaultHeightPx` therefore takes
  the larger of the declared minimum and a readable default.
- An `AppWidgetHostView` left at `WRAP_CONTENT` paints only its minimum and
  leaves the rest of the row empty, however tall the container is. The view
  needs an explicit pixel height, and `updateAppWidgetSize` has to be told what
  it got, or the widget keeps rendering the layout it picked for the old size.

## Known ceilings

- `Settings` does its SharedPreferences read, and the one-time migration, on the
  main thread in the ViewModel's constructor. Cold start is the whole point of
  this migration, so this wants moving off the main thread before release.
- Widget reordering is move-up/move-down buttons, not drag and drop. Compose has
  no reorderable list; a drag gesture is worth writing if the button dance gets
  tedious with more than a handful of widgets.
- `IconCache` holds 300 icons and never drops them on trim; fine for a drawer,
  revisit if memory shows up in profiling.
- Text over the wallpaper is white with a heavy shadow over a gradient scrim,
  always. It reads on any wallpaper but ignores the light theme entirely, which
  is the usual launcher trade and worth revisiting if a light drawer is wanted.
  The scrim strength is a single gradient in `Wallpaper.scrim`; tune it there.

## Deliberately not carried over

- The three method channels, and base64-ing icons and widget previews across
  them.
- The `AndroidView` platform-view wrapper around `AppWidgetHostView`, and its
  visibility-detector gate. Compose embeds the host view directly.
- The `onBackPressed` round trip that asked Dart which screen was open.
- The splash theme, the transparent page-transition override, and the
  wallpaper-flicker workarounds.
- The `apps` table: a cache of names and icons the system already holds.

## Layout

```
app/src/main/kotlin/com/kayfahaarukku/fuselauncher/
  apps/          LauncherApps access, search ranking, sections, usage decay
  data/          Settings, Flutter prefs reader, folder store, biometrics
  notifications/ NotificationListenerService and its StateFlow
  widgets/       AppWidgetHost wrapper
  ui/            Compose screens, theme, icon cache
app/src/main/res/font/      Poppins (OFL, see licenses/)
app/src/main/res/drawable/  app logo
```

Unit tests cover the pure logic - search, sections, and every encoding the
migration depends on:

```bash
./gradlew test
```
