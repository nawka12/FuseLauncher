import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:installed_apps/app_info.dart';
import 'dart:convert';
import 'dart:typed_data';

class AppDatabase {
  static Database? _database;
  static const String tableName = 'apps';

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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableName(
            packageName TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            icon BLOB,
            version_name TEXT,
            version_code TEXT,
            lastUpdated INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  static Future<void> cacheApps(List<AppInfo> apps) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (var app in apps) {
      batch.insert(
        tableName,
        {
          'packageName': app.packageName,
          'name': app.name,
          'icon': app.icon,
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

    return List.generate(maps.length, (i) {
      return AppInfo(
        name: maps[i]['name'] as String,
        packageName: maps[i]['packageName'] as String,
        versionName: maps[i]['version_name'] as String? ?? '',
        versionCode: int.tryParse(maps[i]['version_code'] as String? ?? '0') ?? 0,
        installedTimestamp: maps[i]['lastUpdated'] as int,
        builtWith: BuiltWith.values.first,
        icon: maps[i]['icon'] as Uint8List?,
      );
    });
  }

  static Future<void> clearOldCache(Duration maxAge) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(maxAge).millisecondsSinceEpoch;
    
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
    
    return DateTime.fromMillisecondsSinceEpoch(result.first['lastUpdated'] as int);
  }
} 