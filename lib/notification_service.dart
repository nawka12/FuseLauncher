import 'package:flutter/services.dart';
import 'dart:async';

class NotificationService {
  static const platform = MethodChannel('com.kayfahaarukku.flauncher/notifications');
  static final Map<String, int> _notificationCounts = {};
  static final _controller = StreamController<Map<String, int>>.broadcast();
  
  static Stream<Map<String, int>> get notificationStream => _controller.stream;
  
  static Future<void> initialize() async {
    try {
      print('Initializing notification service');
      final bool? hasAccess = await platform.invokeMethod('requestNotificationAccess');
      print('Notification access granted: $hasAccess');
      
      platform.setMethodCallHandler((call) async {
        print('Received method call: ${call.method}');
        switch (call.method) {
          case 'onNotificationPosted':
            final packageName = call.arguments['packageName'] as String;
            _notificationCounts[packageName] = 
              (_notificationCounts[packageName] ?? 0) + 1;
            _controller.add(Map.from(_notificationCounts));
            break;
            
          case 'onNotificationRemoved':
            final packageName = call.arguments['packageName'] as String;
            if (_notificationCounts.containsKey(packageName)) {
              _notificationCounts.remove(packageName);
              _controller.add(Map.from(_notificationCounts));
            }
            break;
        }
      });
    } catch (e) {
      print('Error initializing notification service: $e');
    }
  }
  
  static void resetNotificationCount(String packageName) {
    if (_notificationCounts.containsKey(packageName)) {
      _notificationCounts.remove(packageName);
      _controller.add(Map.from(_notificationCounts));
    }
  }
  
  static int getNotificationCount(String packageName) {
    return _notificationCounts[packageName] ?? 0;
  }
  
  static void dispose() {
    _controller.close();
  }
}
