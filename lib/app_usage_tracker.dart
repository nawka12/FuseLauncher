import 'package:shared_preferences/shared_preferences.dart';
import 'package:installed_apps/app_info.dart';
import 'dart:convert';
import 'sort_options.dart';

class AppUsageTracker {
  static const String _usageKey = 'app_usage_counts';
  static const String _pinnedSortTypeKey = 'pinned_sort_type';
  static const String _appListSortTypeKey = 'app_list_sort_type';
  static const String _tieOrderKey = 'tie_order';
  static const String _tieCounterKey = 'tie_order_counter';
  static const int _maxHistory = 100;
  
  static Future<Map<String, int>> getUsageCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? usageJson = prefs.getString(_usageKey);
    if (usageJson == null) return {};
    return Map<String, int>.from(json.decode(usageJson));
  }
  
  static Future<void> recordAppLaunch(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    final usageCounts = await getUsageCounts();
    
    usageCounts[packageName] = (usageCounts[packageName] ?? 0) + 1;
    if (usageCounts[packageName]! > _maxHistory) {
      usageCounts[packageName] = _maxHistory;
    }
    
    for (var key in usageCounts.keys.where((k) => k != packageName)) {
      usageCounts[key] = (usageCounts[key]! * 0.98).round();
      if (usageCounts[key]! < 5) usageCounts[key] = 5;
    }
    
    final tieOrders = await _getTieOrders();
    int tieCounter = prefs.getInt(_tieCounterKey) ?? 0;
    usageCounts.forEach((pkg, count) {
      if (count == 5 && !tieOrders.containsKey(pkg)) {
        tieOrders[pkg] = tieCounter;
        tieCounter++;
      }
    });
    await _saveTieOrders(tieOrders);
    await prefs.setInt(_tieCounterKey, tieCounter);
    
    await prefs.setString(_usageKey, json.encode(usageCounts));
  }
  
  static Future<void> sortPinnedApps(List<AppInfo> pinnedApps, PinnedAppsSortType sortType) async {
    switch (sortType) {
      case PinnedAppsSortType.usage:
        final usageCounts = await getUsageCounts();
        final tieOrders = await _getTieOrders();
        pinnedApps.sort((a, b) {
          final countA = usageCounts[a.packageName] ?? 0;
          final countB = usageCounts[b.packageName] ?? 0;
          int cmp = countB.compareTo(countA);
          if (cmp == 0) {
            if (countA == 5 && countB == 5) {
              final orderA = tieOrders[a.packageName] ?? 999999;
              final orderB = tieOrders[b.packageName] ?? 999999;
              cmp = orderA.compareTo(orderB);
            }
            if (cmp == 0) {
              cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
            }
          }
          return cmp;
        });
        break;
      case PinnedAppsSortType.alphabeticalAsc:
        pinnedApps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case PinnedAppsSortType.alphabeticalDesc:
        pinnedApps.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinnedSortTypeKey, sortType.toString());
  }
  
  static Future<void> sortAppList(List<AppInfo> apps, AppListSortType sortType) async {
    switch (sortType) {
      case AppListSortType.usage:
        final usageCounts = await getUsageCounts();
        final tieOrders = await _getTieOrders();
        apps.sort((a, b) {
          final countA = usageCounts[a.packageName] ?? 0;
          final countB = usageCounts[b.packageName] ?? 0;
          int cmp = countB.compareTo(countA);
          if (cmp == 0) {
            if (countA == 5 && countB == 5) {
              final orderA = tieOrders[a.packageName] ?? 999999;
              final orderB = tieOrders[b.packageName] ?? 999999;
              cmp = orderA.compareTo(orderB);
            }
            if (cmp == 0) {
              cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
            }
          }
          return cmp;
        });
        break;
      case AppListSortType.alphabeticalAsc:
        apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case AppListSortType.alphabeticalDesc:
        apps.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appListSortTypeKey, sortType.toString());
  }
  
  static Future<PinnedAppsSortType> getSavedPinnedSortType() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedType = prefs.getString(_pinnedSortTypeKey);
    return PinnedAppsSortType.values.firstWhere(
      (type) => type.toString() == savedType,
      orElse: () => PinnedAppsSortType.usage,
    );
  }
  
  static Future<AppListSortType> getSavedAppListSortType() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedType = prefs.getString(_appListSortTypeKey);
    return AppListSortType.values.firstWhere(
      (type) => type.toString() == savedType,
      orElse: () => AppListSortType.alphabeticalAsc,
    );
  }
  
  static Future<Map<String, int>> _getTieOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tieOrdersJson = prefs.getString(_tieOrderKey);
    if (tieOrdersJson == null) return {};
    return Map<String, int>.from(json.decode(tieOrdersJson));
  }
  
  static Future<void> _saveTieOrders(Map<String, int> tieOrders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tieOrderKey, json.encode(tieOrders));
  }
} 