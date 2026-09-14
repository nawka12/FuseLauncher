import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../notification_service.dart';

/// Every notification an app is currently showing. The arrow on an app tile -
/// or a swipe right across it - opens this instead of guessing which one you
/// meant; tapping a row fires that notification's own action and swiping it
/// away clears it, the way pulling down the shade would.
Future<void> showAppNotifications(
  BuildContext context, {
  required String appName,
  required List<AppNotification> notifications,
  Uint8List? icon,
}) {
  // A copy: the list handed in belongs to NotificationService, and swiping a
  // row here only clears it until the next snapshot arrives from the shade.
  final items = List.of(notifications);
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
  final textColor = isDarkMode ? Colors.white : Colors.black;
  final subtleColor = isDarkMode ? Colors.white70 : Colors.black54;

  return showDialog(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor:
            isDarkMode ? const Color(0xFF252525) : Colors.white.withAlpha(242),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        // Keeps a swipe's red panel inside the rounded corners.
        clipBehavior: Clip.antiAlias,
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Row(
                      children: [
                        if (icon != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(icon,
                                width: 40, height: 40, fit: BoxFit.cover),
                          )
                        else
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? const Color(0xFF424242)
                                  : const Color(0xFFE0E0E0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.apps, size: 22),
                          ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${items.length} notification'
                                '${items.length == 1 ? '' : 's'}',
                                style:
                                    TextStyle(color: subtleColor, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final notification = items[index];
                        return Dismissible(
                          key: ValueKey(notification.key),
                          background: Container(
                            color: Colors.red.withAlpha(180),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(Icons.clear, color: Colors.white),
                                Icon(Icons.clear, color: Colors.white),
                              ],
                            ),
                          ),
                          onDismissed: (_) {
                            NotificationService.dismiss(notification.key);
                            setDialogState(() => items.removeAt(index));
                            if (items.isEmpty) Navigator.pop(dialogContext);
                          },
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            title: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Expanded(
                                  child: Text(
                                    notification.title.isEmpty
                                        ? appName
                                        : notification.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  shortAgo(notification.postTime),
                                  style: TextStyle(
                                      color: subtleColor, fontSize: 12),
                                ),
                              ],
                            ),
                            subtitle: notification.text.isEmpty
                                ? null
                                : Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      notification.text,
                                      style: TextStyle(
                                          color: subtleColor, fontSize: 14),
                                    ),
                                  ),
                            onTap: () {
                              Navigator.pop(dialogContext);
                              NotificationService.open(notification.key);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}
