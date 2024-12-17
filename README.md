# FLauncher

A modern, customizable Android launcher built with Flutter that focuses on simplicity and functionality.

[SAMPLE IMAGE SOON]

## Features

### App Management
- 🔍 Fast app search with real-time filtering
- 📌 Pin up to 10 favorite apps for quick access
- 🔤 Multiple sorting options:
  - Alphabetical (A to Z)
  - Reverse alphabetical (Z to A)
  - Usage frequency
- 🗑️ Quick uninstall for user apps

### Widget Support
- ➕ Add and manage Android widgets
- ↕️ Drag and drop widget reordering
- 🔍 Search available widgets by app or name

### Notifications
- 🔔 Real-time notification badges
- 🔄 Auto-clearing notifications when launching apps
- 📊 Clean notification management

### UI/UX
- 🌙 Dark theme optimized interface
- ↕️ Smooth scrolling with section indicators
- 📱 Edge-to-edge display support
- 💫 Haptic feedback for interactions
- 🔒 Prevents accidental launcher exits

## Building from Source

### Prerequisites
- Flutter SDK (^3.6.0)
- Android SDK
- Git

### Setup

1. Clone the repository:

```bash
git clone https://github.com/yourusername/flauncher.git
cd flauncher
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

### Key Components
- Custom widget management system
- Notification service integration
- App usage tracking
- Efficient app sorting and sectioning

## License

This project is licensed under the MIT License.

## Acknowledgments

- Flutter team for the amazing framework
- Contributors and users of the project

---

*Note: This launcher requires Android API level support for app widgets and notification access.*
