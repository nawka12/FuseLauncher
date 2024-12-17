import 'package:shared_preferences/shared_preferences.dart';
import 'package:installed_apps/app_info.dart';
import 'dart:convert';
import 'sort_options.dart';

class AppUsageTracker {
  static const String _usageKey = 'app_usage_counts';
  static const String _pinnedSortTypeKey = 'pinned_sort_type';
  static const String _appListSortTypeKey = 'app_list_sort_type';
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
    
    await prefs.setString(_usageKey, json.encode(usageCounts));
  }
  
  static Future<void> sortPinnedApps(List<AppInfo> pinnedApps, PinnedAppsSortType sortType) async {
    switch (sortType) {
      case PinnedAppsSortType.usage:
        final usageCounts = await getUsageCounts();
        pinnedApps.sort((a, b) {
          final countA = usageCounts[a.packageName] ?? 0;
          final countB = usageCounts[b.packageName] ?? 0;
          return countB.compareTo(countA);
        });
      case PinnedAppsSortType.alphabeticalAsc:
        pinnedApps.sort((a, b) => 
          (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase())
        );
      case PinnedAppsSortType.alphabeticalDesc:
        pinnedApps.sort((a, b) => 
          (b.name ?? '').toLowerCase().compareTo((a.name ?? '').toLowerCase())
        );
    }
    
    // Save the sort type
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinnedSortTypeKey, sortType.toString());
  }
  
  static Future<void> sortAppList(List<AppInfo> apps, AppListSortType sortType) async {
    switch (sortType) {
      case AppListSortType.usage:
        final usageCounts = await getUsageCounts();
        apps.sort((a, b) {
          final countA = usageCounts[a.packageName] ?? 0;
          final countB = usageCounts[b.packageName] ?? 0;
          return countB.compareTo(countA);
        });
      case AppListSortType.alphabeticalAsc:
        apps.sort((a, b) => 
          (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase())
        );
      case AppListSortType.alphabeticalDesc:
        apps.sort((a, b) => 
          (b.name ?? '').toLowerCase().compareTo((a.name ?? '').toLowerCase())
        );
    }
    
    // Save the sort type
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
} 