import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:installed_apps/app_info.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:FuseLauncher/database/app_database.dart';
import 'package:FuseLauncher/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Launcher starts, searches apps, and opens widgets in both themes',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      GoogleFonts.config.allowRuntimeFetching = false;
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfiNoIsolate;
      final directory = Directory.systemTemp.createTempSync(
        'fuselauncher_test_',
      );
      final messenger = tester.binding.defaultBinaryMessenger;
      const paths = MethodChannel('plugins.flutter.io/path_provider');
      const apps = MethodChannel('installed_apps');
      const widgets = MethodChannel('com.kayfahaarukku.fuselauncher/widgets');
      const notifications = MethodChannel(
        'com.kayfahaarukku.fuselauncher/notifications',
      );
      messenger.setMockMethodCallHandler(paths, (_) async => directory.path);
      messenger.setMockMethodCallHandler(apps, (call) async {
        if (call.method == 'getInstalledApps') {
          return [
            {'package_name': 'test.calendar'},
            {'package_name': 'test.camera'},
          ];
        }
        throw MissingPluginException(
          'Unexpected installed_apps call: ${call.method}',
        );
      });
      messenger.setMockMethodCallHandler(widgets, (_) async => []);
      messenger.setMockMethodCallHandler(notifications, (_) async => true);
      addTearDown(() async {
        for (final channel in [paths, apps, widgets, notifications]) {
          messenger.setMockMethodCallHandler(channel, null);
        }
        tester.binding.platformDispatcher.clearPlatformBrightnessTestValue();
        await (await AppDatabase.database).close();
        directory.deleteSync(recursive: true);
      });

      await tester.runAsync(() async {
        await databaseFactory.setDatabasesPath(directory.path);
        await AppDatabase.cacheApps([
          for (final name in ['Calendar', 'Camera'])
            AppInfo(
              name: name,
              icon: null,
              packageName: 'test.${name.toLowerCase()}',
              versionName: '1.0',
              versionCode: 1,
              installedTimestamp: 0,
              builtWith: BuiltWith.values.first,
            ),
        ]);
        // Empty so it does not hide any app from the list assertions below.
        await AppDatabase.createFolder('Media', const []);
        await tester.pumpWidget(const MyApp());
        // Allow native SQLite and bundled font reads to finish outside fake time.
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      for (final brightness in [Brightness.light, Brightness.dark]) {
        tester.binding.platformDispatcher.platformBrightnessTestValue =
            brightness;
        await tester.pumpAndSettle();
        expect(
          Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
          brightness,
        );
        // Exactly one dim layer over the wallpaper, tracking the theme.
        expect(
          tester
              .widgetList<ColoredBox>(find.byType(ColoredBox))
              .where((box) => box.color.a > 0 && box.color.a < 1),
          [isA<ColoredBox>()],
        );
        expect(find.text('Apps'), findsOneWidget);
        expect(find.text('Calendar'), findsOneWidget);
        expect(find.text('Camera'), findsOneWidget);

        await tester.enterText(find.byType(TextField).first, 'Calendar');
        await tester.pumpAndSettle();
        expect(find.text('Camera'), findsNothing);
        expect(find.text('Calendar'), findsWidgets);
        await tester.enterText(find.byType(TextField).first, '');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Widgets'));
        await tester.pumpAndSettle();
        expect(find.text('No widgets added'), findsOneWidget);
        expect(find.text('Add Widget'), findsOneWidget);
        await tester.tap(find.text('Apps'));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.settings));
        await tester.pumpAndSettle();
        expect(find.text('Settings'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      // Deleting a folder must refresh the list, not wait for a restart.
      expect(find.text('Media'), findsOneWidget);
      await tester.longPress(find.text('Media'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Folder'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Media'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
