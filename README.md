# FuseLauncher (Previously FLauncher)

## If you installed FLauncher before the name change, please uninstall FLauncher, then install FuseLauncher.

A modern, customizable Android launcher built with Flutter that focuses on simplicity and functionality.

<p align="center">
  <img src="https://github.com/user-attachments/assets/9fe587e4-7294-4f79-b343-308af25f56d7" width="300" />
  <img src="https://github.com/user-attachments/assets/bb2c9627-7057-4f11-ba22-9411245f8e1a" width="300" />
</p>

## Features

### App Management
- 🔍 Fast app search with real-time filtering
- 📌 Pin up to 10 favorite apps for quick access
- 🔤 Multiple sorting options:
  - Alphabetical (A to Z)
  - Reverse alphabetical (Z to A)
  - Usage frequency
- 🗑️ Quick uninstall for user apps
- 👻 Hidden apps management
- 📊 Smart app usage tracking with decay

### Widget Support
- ➕ Add and manage Android widgets
- ↕️ Drag and drop widget reordering
- 🔍 Search available widgets by app or name
- 💾 Persistent widget layouts

### Notifications
- 🔔 Real-time notification badges
- 🔄 Auto-clearing notifications when launching apps
- 📊 Clean notification management
- 🎛️ Toggleable notification badges

### UI/UX
- 🌙 Dark theme optimized interface
- ↕️ Smooth scrolling with section indicators
- 📱 Edge-to-edge display support
- 💫 Haptic feedback for interactions
- 🔒 Prevents accidental launcher exits
- 🔐 Optional biometric authentication
- 🎯 Customizable search bar position (top/bottom)
- 📋 Multiple layout options (List and Grid views)
- 🎮 Customizable grid columns (2-6 columns)

## Building from Source

### Prerequisites
- Flutter SDK 3.47.2 stable (Dart 3.13.2), pinned in `.fvmrc`
- FVM for selecting the pinned SDK
- Java 17
- Android SDK 36 and NDK 28.2.13676358
- Android device or emulator running Android 7.0 (API 24) or newer
- Git

### Setup

1. Clone the repository:

```bash
git clone https://github.com/nawka12/FuseLauncher.git
cd FuseLauncher
```

2. Select the pinned Flutter SDK and install dependencies:
```bash
fvm install
fvm use
fvm flutter pub get
```

3. Update app icon (optional):
```bash
fvm dart run flutter_launcher_icons
```

### Required Permissions

The app needs several Android permissions to function properly. These are defined in the Android Manifest:

```xml
<uses-permission android:name="android.permission.QUERY_ALL_PACKAGES"/>
<uses-permission android:name="android.permission.BIND_APPWIDGET" />
<uses-permission android:name="android.permission.PACKAGE_USAGE_STATS" />
<uses-permission android:name="android.permission.APPWIDGET_HOST" />
<uses-permission android:name="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE"/>
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
```

### Building

For debug build:
```bash
fvm flutter build apk --debug
```

For release build, first set up signing (once):

```bash
keytool -genkey -v -keystore ~/fuselauncher-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias fuselauncher
```

Copy `android/key.properties.example` to `android/key.properties` and point it at
that keystore. Both the keystore and `key.properties` are gitignored - back the
keystore up, because losing it means no existing install can ever be upgraded
again. Without `key.properties` the release build still works but falls back to
the debug key and must not be published.

```bash
fvm flutter build apk --release
```

The built APK will be available at `build/app/outputs/flutter-apk/app-release.apk`

To validate and run the app on a connected Android device or emulator:
```bash
fvm flutter analyze
fvm flutter test
fvm flutter run
```

The Android build uses Gradle 8.14, Android Gradle Plugin 8.13.1, and Kotlin 2.2.20.
Poppins fonts are bundled so the app can start without downloading fonts.
The installed-apps plugin is pinned to a revision that supports Flutter's current Android embedding.

Static analysis currently reports informational deprecation and package-name notices.
Use `fvm flutter analyze --no-fatal-infos` to check for errors and warnings without failing on those notices.

## Contributing

Contributions are welcome! Here are some ways you can contribute:
- 🐛 Report bugs
- 💡 Suggest new features
- 🔧 Submit pull requests
- 📖 Improve documentation

## Technical Details

### State Management
The app uses Flutter's built-in state management with `StatefulWidget` and efficiently manages app data using `SharedPreferences` for persistence.

### Performance Optimizations
- Icon caching system with size limits
- Efficient widget rebuilding
- Optimized list rendering with `SliverList`
- Smart refresh mechanisms to prevent unnecessary reloads
- Usage history limits with decay algorithm
- Efficient app sorting and sectioning

### Key Components
- Custom widget management system
- Notification service integration
- App usage tracking
- Efficient app sorting and sectioning
- Multiple layout options (List and Grid)

### Security Features
- Biometric authentication support
- Hidden apps protection

## License

This project is licensed under the MIT License.

## Acknowledgments

- Flutter team for the amazing framework
- Contributors and users of the project

---

*Note: This launcher requires Android API level support for app widgets and notification access.*
