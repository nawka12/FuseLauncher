import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WidgetInfo {
  final String label;
  final String provider;
  final int minWidth;
  final int minHeight;
  final String previewImage;
  final int? widgetId;
  final String appName;
  final String packageName;
  int currentWidth;
  int currentHeight;

  WidgetInfo({
    required this.label,
    required this.provider,
    required this.minWidth,
    required this.minHeight,
    this.previewImage = '',
    this.widgetId,
    required this.appName,
    required this.packageName,
    int? currentWidth,
    int? currentHeight,
  }) : 
    currentWidth = currentWidth ?? minWidth,
    currentHeight = currentHeight ?? minHeight;
}

class WidgetManager {
  static const platform = MethodChannel('com.kayfahaarukku.flauncher/widgets');

  static Future<List<WidgetInfo>> getAvailableWidgets() async {
    try {
      final List<dynamic> result = await platform.invokeMethod('getWidgetList');
      return result.map((widget) => WidgetInfo(
        label: widget['label'] ?? 'Unknown Widget',
        provider: widget['provider'] ?? '',
        minWidth: widget['minWidth'] ?? 0,
        minHeight: widget['minHeight'] ?? 0,
        previewImage: widget['previewImage'] ?? '',
        appName: widget['appName'] ?? '',
        packageName: widget['packageName'] ?? '',
      )).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting widgets: $e');
      }
      return [];
    }
  }

  static Future<List<WidgetInfo>> getAddedWidgets() async {
    try {
      final List<dynamic> result = await platform.invokeMethod('getAddedWidgets');
      return result.map((widget) => WidgetInfo(
        label: widget['label'] ?? 'Unknown Widget',
        provider: widget['provider'] ?? '',
        minWidth: widget['minWidth'] ?? 0,
        minHeight: widget['minHeight'] ?? 0,
        previewImage: widget['previewImage'] ?? '',
        widgetId: widget['widgetId'],
        appName: widget['appName'] ?? '',
        packageName: widget['packageName'] ?? '',
      )).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting added widgets: $e');
      }
      return [];
    }
  }

  static Future<bool> addWidget(WidgetInfo widget) async {
    try {
      final bool result = await platform.invokeMethod('addWidget', {
        'provider': widget.provider,
        'minWidth': widget.minWidth,
        'minHeight': widget.minHeight,
      });
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('Error adding widget: $e');
      }
      return false;
    }
  }

  static Future<bool> removeWidget(int widgetId) async {
    try {
      final bool result = await platform.invokeMethod('removeWidget', {
        'widgetId': widgetId,
      });
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('Error removing widget: $e');
      }
      return false;
    }
  }

  static Future<bool> updateWidgetSize(int widgetId, Size size) async {
    try {
      final bool result = await platform.invokeMethod('updateWidgetSize', {
        'widgetId': widgetId,
        'width': size.width.toInt(),
        'height': size.height.toInt(),
      });
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating widget size: $e');
      }
      return false;
    }
  }
}

class ResizableWidget extends StatelessWidget {
  final Widget child;
  final bool isReorderMode;
  final VoidCallback? onLongPress;

  const ResizableWidget({
    super.key,
    required this.child,
    required this.isReorderMode,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: isReorderMode ? null : onLongPress,
      child: Stack(
        children: [
          child,
          if (isReorderMode)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.drag_handle,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }
} 