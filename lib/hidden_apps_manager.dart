import 'package:shared_preferences/shared_preferences.dart';

class HiddenAppsManager {
  static const String _hiddenAppsKey = 'hidden_apps';
  static const String _pinnedAppsBackupKey = 'pinned_apps_backup';
  
  static Future<List<String>> loadHiddenApps() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_hiddenAppsKey) ?? [];
  }
  
  static Future<void> saveHiddenApps(List<String> hiddenApps) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_hiddenAppsKey, hiddenApps);
  }
  
  static Future<Set<String>> loadPinnedAppsBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final backup = prefs.getStringList(_pinnedAppsBackupKey) ?? [];
    return Set<String>.from(backup);
  }
  
  static Future<void> savePinnedAppsBackup(Set<String> backup) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_pinnedAppsBackupKey, backup.toList());
  }
} 