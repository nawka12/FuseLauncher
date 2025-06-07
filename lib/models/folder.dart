import 'dart:convert';

import 'package:installed_apps/app_info.dart';

class Folder {
  int? id;
  String name;
  List<String> appPackageNames;
  List<AppInfo> apps = [];

  Folder({
    this.id,
    required this.name,
    this.appPackageNames = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'app_packages': jsonEncode(appPackageNames),
    };
  }

  static Folder fromMap(Map<String, dynamic> map) {
    dynamic idValue = map['id'];
    int? folderId;
    if (idValue is int) {
      folderId = idValue;
    } else if (idValue is String) {
      folderId = int.tryParse(idValue);
    }

    return Folder(
      id: folderId,
      name: map['name'],
      appPackageNames:
          (jsonDecode(map['app_packages'] as String) as List<dynamic>)
              .map((e) => e as String)
              .toList(),
    );
  }
}
