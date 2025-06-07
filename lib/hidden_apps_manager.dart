import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class HiddenAppsManager {
  static const _hiddenAppsKey = 'hidden_apps';
  static const _pinnedBackupKey = 'pinned_apps_backup';
  static const _hiddenAppFolderMapKey = 'hidden_app_folder_map';

  static Future<void> saveHiddenApps(List<String> packageNames) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_hiddenAppsKey, packageNames);
  }

  static Future<List<String>> loadHiddenApps() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_hiddenAppsKey) ?? [];
  }

  static Future<void> savePinnedAppsBackup(Set<String> packageNames) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_pinnedBackupKey, packageNames.toList());
  }

  static Future<Set<String>> loadPinnedAppsBackup() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_pinnedBackupKey) ?? []).toSet();
  }

  static Future<void> saveHiddenAppFolderMap(Map<String, int> map) async {
    final prefs = await SharedPreferences.getInstance();
    final stringMap = map.map((key, value) => MapEntry(key, value.toString()));
    await prefs.setString(_hiddenAppFolderMapKey, jsonEncode(stringMap));
  }

  static Future<Map<String, int>> loadHiddenAppFolderMap() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_hiddenAppFolderMapKey);
    if (jsonString != null) {
      final stringMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return stringMap
          .map((key, value) => MapEntry(key, int.parse(value as String)));
    }
    return {};
  }
}
