import 'package:flutter/services.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:typed_data';

/// Utility class for safely handling package operations
class AppPackageManager {
  static const MethodChannel _channel = MethodChannel('installed_apps');
  
  /// Get all installed package names safely by using the existing plugin methods
  static Future<List<String>> getInstalledPackageNames() async {
    try {
      // We'll use the existing plugin's methods but extract just the package names
      final List<dynamic> result = await _channel.invokeMethod(
        'getInstalledApps',
        <String, dynamic>{
          'exclude_system_apps': false,
          'with_icon': false, // Don't need icons for just package names
        },
      );
      
      // Extract just the package names from the result
      final List<String> packageNames = [];
      for (final app in result) {
        try {
          final packageName = app['package_name'] as String?;
          if (packageName != null && packageName.isNotEmpty) {
            packageNames.add(packageName);
          }
        } catch (e) {
          // Skip this app if there's an issue
        }
      }
      
      return packageNames;
    } on PlatformException catch (e) {
      debugPrint('Error getting installed package names: $e');
      return [];
    } catch (e) {
      debugPrint('Unexpected error getting package names: $e');
      return [];
    }
  }
  
  /// Get AppInfo safely for a single package
  static Future<AppInfo?> getAppInfoSafely(String packageName) async {
    try {
      // Check if package exists first
      final bool? exists = await _doesPackageExist(packageName);
      if (exists != true) {
        debugPrint('Package $packageName no longer exists on the device');
        return null;
      }
      
      // We'll directly use the channel to get app info for a specific package
      final result = await _channel.invokeMethod(
        'getAppInfo',
        <String, dynamic>{
          'package_name': packageName,
        },
      );
      
      if (result != null) {
        // Convert the result to an AppInfo object
        try {
          final name = result['name'] as String;
          final packageName = result['package_name'] as String;
          final versionName = result['version_name'] as String? ?? '';
          final versionCode = int.tryParse(result['version_code']?.toString() ?? '0') ?? 0;
          final installedTimestamp = (result['installed_timestamp'] as int?) ?? 0;
          
          // The icon is Base64 encoded if present
          Uint8List? iconData;
          if (result['icon'] != null) {
            try {
              iconData = result['icon'] as Uint8List;
            } catch (e) {
              debugPrint('Error decoding icon for $packageName: $e');
            }
          }
          
          return AppInfo(
            name: name,
            packageName: packageName,
            versionName: versionName,
            versionCode: versionCode,
            installedTimestamp: installedTimestamp,
            builtWith: BuiltWith.values.first,
            icon: iconData,
          );
        } catch (e) {
          debugPrint('Error parsing app info for $packageName: $e');
          return null;
        }
      }
    } on PlatformException catch (e) {
      if (e.message?.contains('NameNotFound') == true) {
        debugPrint('Package $packageName no longer exists (NameNotFoundException)');
      } else {
        debugPrint('Platform exception getting info for $packageName: $e');
      }
    } catch (e) {
      debugPrint('Error getting info for package $packageName: $e');
    }
    return null;
  }
  
  /// Helper method to check if a package exists
  static Future<bool> _doesPackageExist(String packageName) async {
    try {
      // Try to invoke a lightweight method to check if package exists
      final bool? result = await _channel.invokeMethod(
        'isAppInstalled',
        <String, dynamic>{
          'package_name': packageName,
        },
      );
      return result ?? false;
    } catch (e) {
      // If there's an error, the package likely doesn't exist
      return false;
    }
  }
  
  /// Get all installed apps safely, handling errors for individual apps
  static Future<List<AppInfo>> getInstalledAppsSafely({
    bool excludeSystemApps = false, 
    bool withIcon = true,
    bool includeAppSize = false
  }) async {
    List<AppInfo> apps = [];
    
    try {
      // First get all package names
      final packageNames = await getInstalledPackageNames();
      
      // Then try to get app info for each package individually
      for (final packageName in packageNames) {
        try {
          // Check if it's a system app if needed
          if (excludeSystemApps) {
            try {
              final bool? isSystemApp = await InstalledApps.isSystemApp(packageName);
              if (isSystemApp == true) {
                continue; // Skip system apps
              }
            } catch (e) {
              debugPrint('Error checking if $packageName is system app: $e');
              continue; // Skip if we can't determine
            }
          }
          
          // Get app info and add to list if successful
          final appInfo = await getAppInfoSafely(packageName);
          if (appInfo != null) {
            apps.add(appInfo);
          }
        } catch (e) {
          // Skip this app if there's any error
        }
      }
    } catch (e) {
      debugPrint('Error getting installed apps safely: $e');
    }
    
    return apps;
  }
} 