import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:FuseLauncher/notification_service.dart';
import 'package:FuseLauncher/widgets/notification_popup.dart';

AppNotification note(String key) => AppNotification(
      packageName: 'com.discord',
      key: key,
      title: 'title-$key',
      text: 'text-$key',
      postTime: DateTime(2026, 1, 1, 12),
    );

void main() {
  testWidgets('swiping a row clears it without touching the caller\'s list',
      (tester) async {
    final dismissed = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(NotificationService.platform, (call) async {
      if (call.method == 'dismissNotification') {
        dismissed.add(call.arguments['key'] as String);
      }
      return true;
    });
    addTearDown(() =>
        messenger.setMockMethodCallHandler(NotificationService.platform, null));

    final source = [note('a'), note('b')];

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showAppNotifications(context,
              appName: 'Discord', notifications: source),
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('2 notifications'), findsOneWidget);

    await tester.drag(find.text('title-a'), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(dismissed, ['a']);
    expect(find.text('title-a'), findsNothing);
    expect(find.text('1 notification'), findsOneWidget);
    expect(source.map((n) => n.key), ['a', 'b']);
  });
}
