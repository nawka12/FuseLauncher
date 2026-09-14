import 'package:installed_apps/app_info.dart';

/// Matches [query] against app names and orders hits by how well they match:
/// exact name, then name prefix, then a word prefix ("X" finds "ibisPaint X"),
/// then anywhere in the name. Ties keep the incoming order, so the user's sort
/// setting still decides within a tier.
List<AppInfo> searchApps(List<AppInfo> apps, String query) {
  if (query.isEmpty) return apps;

  final ranked = <MapEntry<int, AppInfo>>[];
  for (var i = 0; i < apps.length; i++) {
    final rank = _rank(apps[i].name.toLowerCase(), query);
    if (rank != null) ranked.add(MapEntry(rank * apps.length + i, apps[i]));
  }
  ranked.sort((a, b) => a.key.compareTo(b.key));
  return ranked.map((e) => e.value).toList();
}

int? _rank(String name, String query) {
  if (name == query) return 0;
  if (name.startsWith(query)) return 1;
  final at = name.indexOf(query);
  if (at < 0) return null;
  // A word start counts as a prefix match: "x" should find "ibisPaint X".
  for (var i = at; i > 0; i = name.indexOf(query, i + 1)) {
    if (!_isWordChar(name.codeUnitAt(i - 1))) return 2;
  }
  return 3;
}

bool _isWordChar(int c) =>
    (c >= 0x30 && c <= 0x39) || (c >= 0x61 && c <= 0x7a) || c == 0x5f;
