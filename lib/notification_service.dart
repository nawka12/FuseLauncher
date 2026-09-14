import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';

/// One notification an app is currently showing.
class AppNotification {
  final String packageName;
  final String key;
  final String title;
  final String text;
  final DateTime postTime;

  const AppNotification({
    required this.packageName,
    required this.key,
    required this.title,
    required this.text,
    required this.postTime,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
        packageName: map['packageName'] as String,
        key: map['key'] as String? ?? '',
        title: map['title'] as String? ?? '',
        text: map['text'] as String? ?? '',
        postTime: DateTime.fromMillisecondsSinceEpoch(
            (map['postTime'] as num?)?.toInt() ?? 0),
      );

  bool get hasPreview => title.isNotEmpty || text.isNotEmpty;
}

/// "now", "49m", "10h", "3d" - the age suffix Niagara puts after the app name.
String shortAgo(DateTime time, {DateTime? now}) {
  final seconds = (now ?? DateTime.now()).difference(time).inSeconds;
  if (seconds < 60) return 'now';
  if (seconds < 3600) return '${seconds ~/ 60}m';
  if (seconds < 86400) return '${seconds ~/ 3600}h';
  return '${seconds ~/ 86400}d';
}

/// Groups a snapshot of raw notifications by app, newest first, so a tile can
/// preview `.first` and the overlay can list the lot.
Map<String, List<AppNotification>> groupNotifications(List? raw) {
  final grouped = <String, List<AppNotification>>{};
  for (final item in raw ?? const []) {
    final notification =
        AppNotification.fromMap(Map<String, dynamic>.from(item as Map));
    grouped.putIfAbsent(notification.packageName, () => []).add(notification);
  }
  for (final list in grouped.values) {
    list.sort((a, b) => b.postTime.compareTo(a.postTime));
  }
  return grouped;
}

class NotificationService {
  static const platform =
      MethodChannel('com.kayfahaarukku.fuselauncher/notifications');
  static Map<String, List<AppNotification>> _notifications = {};
  static final _controller =
      StreamController<Map<String, List<AppNotification>>>.broadcast();

  static Stream<Map<String, List<AppNotification>>> get notificationStream =>
      _controller.stream;

  static Map<String, List<AppNotification>> get notifications => _notifications;

  static Future<void> initialize() async {
    try {
      final bool? hasAccess =
          await platform.invokeMethod('requestNotificationAccess');
      if (kDebugMode) {
        print('Notification access granted: $hasAccess');
      }

      platform.setMethodCallHandler((call) async {
        if (call.method == 'onNotificationsChanged') {
          _apply(call.arguments as List?);
        }
      });

      _apply(await platform.invokeMethod<List>('getCurrentNotifications'));
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing notification service: $e');
      }
    }
  }

  /// Native sends the full set every time, so the state is a straight replace -
  /// no per-event tally to drift out of sync with the shade.
  static void _apply(List? raw) {
    _notifications = groupNotifications(raw);
    if (!_controller.isClosed) _controller.add(_notifications);
  }

  /// Fires the notification's own tap action - the app opens where it wants to.
  static Future<bool> open(String key) async {
    try {
      return await platform
              .invokeMethod<bool>('openNotification', {'key': key}) ??
          false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> dismiss(String key) async {
    try {
      await platform.invokeMethod('dismissNotification', {'key': key});
    } catch (_) {}
  }

  static void dispose() {
    _controller.close();
  }
}
