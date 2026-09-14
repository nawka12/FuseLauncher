import 'package:flutter_test/flutter_test.dart';
import 'package:installed_apps/app_info.dart';
import 'package:FuseLauncher/app_search.dart';

AppInfo app(String name) => AppInfo(
      name: name,
      icon: null,
      packageName: name.toLowerCase().replaceAll(' ', '.'),
      versionName: '1.0.0',
      versionCode: 1,
      builtWith: BuiltWith.flutter,
      installedTimestamp: 0,
    );

void main() {
  test('ranks exact, prefix and word-start matches above substrings', () {
    final apps = ['ibisPaint X', 'KernelSU Next', 'myXL', 'Sandbox', 'Termux', 'X']
        .map(app)
        .toList();

    expect(searchApps(apps, 'x').map((a) => a.name).toList(), [
      'X',
      'ibisPaint X',
      'KernelSU Next',
      'myXL',
      'Sandbox',
      'Termux',
    ]);
  });

  test('name prefix beats word start, and non-matches drop out', () {
    final apps = ['ibisPaint X', 'Xodo', 'Termux', 'Clock'].map(app).toList();

    expect(searchApps(apps, 'x').map((a) => a.name).toList(),
        ['Xodo', 'ibisPaint X', 'Termux']);
  });

  test('empty query returns the list untouched', () {
    final apps = ['B', 'A'].map(app).toList();
    expect(searchApps(apps, ''), same(apps));
  });
}
