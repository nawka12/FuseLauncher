import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:installed_apps/app_info.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class AppDatabase {
  static Database? _database;
  static const String tableName = 'apps';
  static const String iconCacheDirName = 'app_icons';
  static const int dbVersion = 2; // Increased version for schema changes

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'flauncher.db');

    return await openDatabase(
      path,
      version: dbVersion,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Handle migration from v1 to v2
          await _migrateV1ToV2(db);
        }
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    // Create app table without the icon blob
    await db.execute('''
      CREATE TABLE $tableName(
        packageName TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        version_name TEXT,
        version_code TEXT,
        lastUpdated INTEGER NOT NULL
      )
    ''');

    // Create indices for frequently queried columns
    await db.execute('CREATE INDEX idx_name ON $tableName (name)');
    await db
        .execute('CREATE INDEX idx_lastUpdated ON $tableName (lastUpdated)');
  }

  static Future<void> _migrateV1ToV2(Database db) async {
    // Check if icon column exists
    var tableInfo = await db.rawQuery("PRAGMA table_info($tableName)");
    bool hasIconColumn = tableInfo.any((column) => column['name'] == 'icon');

    if (hasIconColumn) {
      // Step 1: Extract icons and store them in the filesystem
      final List<Map<String, dynamic>> rows = await db.query(tableName);

      // Create icons directory if it doesn't exist
      final iconDir = await _getIconDir();
      if (!await iconDir.exists()) {
        await iconDir.create(recursive: true);
      }

      // Extract icons and save to filesystem
      for (var row in rows) {
        final packageName = row['packageName'] as String;
        final iconData = row['icon'] as Uint8List?;

        if (iconData != null) {
          await _saveIconToFile(packageName, iconData);
        }
      }

      // Step 2: Create a new table without the icon column
      await db.execute('''
        CREATE TABLE ${tableName}_new(
          packageName TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          version_name TEXT,
          version_code TEXT,
          lastUpdated INTEGER NOT NULL
        )
      ''');

      // Step 3: Copy data from old table to new table
      await db.execute('''
        INSERT INTO ${tableName}_new(packageName, name, version_name, version_code, lastUpdated)
        SELECT packageName, name, version_name, version_code, lastUpdated FROM $tableName
      ''');

      // Step 4: Drop the old table and rename the new one
      await db.execute('DROP TABLE $tableName');
      await db.execute('ALTER TABLE ${tableName}_new RENAME TO $tableName');

      // Step 5: Create indices
      await db.execute('CREATE INDEX idx_name ON $tableName (name)');
      await db
          .execute('CREATE INDEX idx_lastUpdated ON $tableName (lastUpdated)');
    }
  }

  static Future<void> cacheApps(List<AppInfo> apps) async {
    // Remove compute to avoid isolate issues
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    final iconDir = await _getIconDir();

    if (!await iconDir.exists()) {
      await iconDir.create(recursive: true);
    }

    // First get the list of currently cached app package names
    final List<Map<String, dynamic>> cachedApps = await db.query(
      tableName,
      columns: ['packageName'],
    );

    // Create a set of package names from the newly fetched apps
    final Set<String> currentPackageNames =
        apps.map((app) => app.packageName).toSet();

    // Find apps that are in the database but no longer installed
    final List<String> uninstalledApps = cachedApps
        .where((app) => !currentPackageNames.contains(app['packageName']))
        .map((app) => app['packageName'] as String)
        .toList();

    // Delete uninstalled apps from the database
    for (String packageName in uninstalledApps) {
      batch.delete(
        tableName,
        where: 'packageName = ?',
        whereArgs: [packageName],
      );

      // Also delete the icon file
      try {
        final iconFile = File(await _getIconPath(packageName));
        if (await iconFile.exists()) {
          await iconFile.delete();
        }
      } catch (e) {
        // Continue if we can't delete the file
        debugPrint('Error deleting icon for $packageName: $e');
      }
    }

    for (var app in apps) {
      // Save icon to file system if available
      if (app.icon != null) {
        await _saveIconToFile(app.packageName, app.icon!);
      }

      // Insert app data without icon
      batch.insert(
        tableName,
        {
          'packageName': app.packageName,
          'name': app.name,
          'version_name': app.versionName,
          'version_code': app.versionCode.toString(),
          'lastUpdated': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  static Future<List<AppInfo>> getCachedApps() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableName);
    final apps = <AppInfo>[];

    // Process apps without using compute
    for (var map in maps) {
      final packageName = map['packageName'] as String;

      // Load icon from file system
      Uint8List? iconData;
      try {
        final iconFile = File(await _getIconPath(packageName));
        if (await iconFile.exists()) {
          iconData = await iconFile.readAsBytes();
        }
      } catch (e) {
        // If we can't load the icon, continue without it
      }

      // Fix the type cast issue by ensuring version_code is properly handled
      String versionName = map['version_name']?.toString() ?? '';
      String versionCodeStr = map['version_code']?.toString() ?? '0';
      int versionCode = int.tryParse(versionCodeStr) ?? 0;
      int timestamp = map['lastUpdated'] as int;

      final app = AppInfo(
        name: map['name'] as String,
        packageName: packageName,
        versionName: versionName,
        versionCode: versionCode,
        installedTimestamp: timestamp,
        builtWith: BuiltWith.values.first,
        icon: iconData,
      );

      apps.add(app);
    }

    return apps;
  }

  static Future<void> clearOldCache(Duration maxAge) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(maxAge).millisecondsSinceEpoch;

    // Get package names of apps to be deleted
    final List<Map<String, dynamic>> oldApps = await db.query(
      tableName,
      columns: ['packageName'],
      where: 'lastUpdated < ?',
      whereArgs: [cutoff],
    );

    // Delete corresponding icon files
    for (var app in oldApps) {
      final packageName = app['packageName'] as String;
      try {
        final iconFile = File(await _getIconPath(packageName));
        if (await iconFile.exists()) {
          await iconFile.delete();
        }
      } catch (e) {
        // Continue if we can't delete the file
      }
    }

    // Delete from database
    await db.delete(
      tableName,
      where: 'lastUpdated < ?',
      whereArgs: [cutoff],
    );
  }

  static Future<DateTime?> getLastUpdateTime() async {
    final db = await database;
    final result = await db.query(
      tableName,
      columns: ['MAX(lastUpdated) as lastUpdated'],
    );

    if (result.isEmpty || result.first['lastUpdated'] == null) {
      return null;
    }

    return DateTime.fromMillisecondsSinceEpoch(
        result.first['lastUpdated'] as int);
  }

  static Future<Directory> _getIconDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/$iconCacheDirName');
  }

  static Future<String> _getIconPath(String packageName) async {
    final iconDir = await _getIconDir();
    return '${iconDir.path}/$packageName.png';
  }

  static Future<void> _saveIconToFile(
      String packageName, Uint8List iconData) async {
    final iconPath = await _getIconPath(packageName);
    final file = File(iconPath);
    await file.writeAsBytes(iconData);
  }

  static Future<Uint8List?> loadIconFromCache(String packageName) async {
    try {
      final iconFile = File(await _getIconPath(packageName));
      if (await iconFile.exists()) {
        return await iconFile.readAsBytes();
      }
    } catch (e) {
      debugPrint('Error loading icon for $packageName: $e');
    }
    return null;
  }

  static Future<void> removeApp(String packageName) async {
    final db = await database;

    // Delete from database
    await db.delete(
      tableName,
      where: 'packageName = ?',
      whereArgs: [packageName],
    );

    // Delete icon
    try {
      final iconFile = File(await _getIconPath(packageName));
      if (await iconFile.exists()) {
        await iconFile.delete();
      }
    } catch (e) {
      debugPrint('Error deleting icon for $packageName: $e');
    }
  }

  /// Clean up any potentially problematic app entries from the database
  /// This helps prevent crashes when trying to load app info for uninstalled apps
  static Future<void> cleanupInvalidApps(List<String> validPackageNames) async {
    try {
      final db = await database;

      // Get all package names in the database
      final List<Map<String, dynamic>> storedApps = await db.query(
        tableName,
        columns: ['packageName'],
      );

      // Find package names that are in the database but no longer valid
      final List<String> invalidPackages = storedApps
          .map((app) => app['packageName'] as String)
          .where((packageName) => !validPackageNames.contains(packageName))
          .toList();

      if (invalidPackages.isNotEmpty) {
        debugPrint('Cleaning up ${invalidPackages.length} invalid app entries');

        // Remove each invalid app
        for (final packageName in invalidPackages) {
          await removeApp(packageName);
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up invalid apps: $e');
    }
  }
}
