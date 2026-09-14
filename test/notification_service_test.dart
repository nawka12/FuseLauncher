import 'package:flutter_test/flutter_test.dart';

import 'package:FuseLauncher/notification_service.dart';

Map<String, dynamic> raw(String package, String key, int minutesAgo) => {
      'packageName': package,
      'key': key,
      'title': 'title-$key',
      'text': 'text-$key',
      'postTime': DateTime(2026, 1, 1, 12)
          .subtract(Duration(minutes: minutesAgo))
          .millisecondsSinceEpoch,
    };

void main() {
  test('groupNotifications groups by app, newest first', () {
    final grouped = groupNotifications([
      raw('com.discord', 'a', 600),
      raw('com.discord', 'b', 5),
      raw('com.discord', 'c', 90),
      raw('com.whatsapp', 'd', 30),
    ]);

    expect(grouped.keys.toSet(), {'com.discord', 'com.whatsapp'});
    expect(grouped['com.discord']!.map((n) => n.key), ['b', 'c', 'a']);
    expect(grouped['com.whatsapp']!.length, 1);
  });

  test('groupNotifications tolerates an empty or missing snapshot', () {
    expect(groupNotifications(null), isEmpty);
    expect(groupNotifications([]), isEmpty);
  });

  test('shortAgo reads like the age suffix after an app name', () {
    final now = DateTime(2026, 1, 1, 12);
    String ago(Duration d) => shortAgo(now.subtract(d), now: now);

    expect(ago(const Duration(seconds: 5)), 'now');
    expect(ago(const Duration(minutes: 49)), '49m');
    expect(ago(const Duration(hours: 10)), '10h');
    expect(ago(const Duration(days: 3)), '3d');
  });
}
