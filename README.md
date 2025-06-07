# FuseLauncher (Previously FLauncher)

## If you installed FLauncher before the name change, please do a full reinstall, then install FuseLauncher.

A modern, customizable Android launcher built with Flutter that focuses on simplicity and functionality.

<p align="center">
  <img src="https://github.com/user-attachments/assets/78c8ccba-441a-4c63-8c85-678b199f1e78" width="300" />
  <img src="https://github.com/user-attachments/assets/3a528ec3-658e-4624-8b1f-89d901ed7355" width="300" />
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
- Flutter SDK (^3.6.0)
- Android SDK
- Git

### Setup

1. Clone the repository:

```bash
git clone https://github.com/nawka12/FuseLauncher.git
cd FuseLauncher
```

2. Install dependencies:
```bash
flutter pub get
```

3. Update app icon (optional):
```bash
flutter pub run flutter_launcher_icons
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
flutter build apk --debug
```

For release build:
```bash
flutter build apk --release
```

The built APK will be available at `build/app/outputs/flutter-apk/app-release.apk`

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
