import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/gestures.dart';

enum AppLayoutType {
  list,
  grid,
}

class AppLayoutManager {
  static const String _layoutPreferenceKey = 'app_layout_type';
  static const String _gridColumnsKey = 'app_grid_columns';
  static const int _defaultGridColumns = 4;

  // Get the current layout preference
  static Future<AppLayoutType> getCurrentLayout() async {
    final prefs = await SharedPreferences.getInstance();
    final layoutIndex = prefs.getInt(_layoutPreferenceKey);
    return layoutIndex == null || layoutIndex >= AppLayoutType.values.length
        ? AppLayoutType.list
        : AppLayoutType.values[layoutIndex];
  }

  // Save layout preference
  static Future<void> saveLayoutPreference(AppLayoutType layoutType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_layoutPreferenceKey, layoutType.index);
  }

  // Get number of columns for grid layout
  static Future<int> getGridColumns() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_gridColumnsKey) ?? _defaultGridColumns;
  }

  // Save number of columns for grid layout
  static Future<void> saveGridColumns(int columns) async {
    if (columns < 2) columns = 2; // Minimum 2 columns
    if (columns > 6) columns = 6; // Maximum 6 columns

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_gridColumnsKey, columns);
  }

  // Convert layout type to display name
  static String layoutToDisplayName(AppLayoutType type) {
    switch (type) {
      case AppLayoutType.list:
        return 'List';
      case AppLayoutType.grid:
        return 'Grid';
    }
  }

  // Get layout type icon
  static IconData getLayoutIcon(AppLayoutType type) {
    switch (type) {
      case AppLayoutType.list:
        return Icons.view_list;
      case AppLayoutType.grid:
        return Icons.grid_view;
    }
  }
}

/// Custom scroll behavior that enables drag scrolling
class AppScrollBehavior extends ScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };
}
