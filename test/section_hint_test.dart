import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:FuseLauncher/layouts/section_hint.dart';

void main() {
  testWidgets('sectionAtTop reports the section under the viewport top',
      (tester) async {
    final keys = {'A': GlobalKey(), 'B': GlobalKey(), 'C': GlobalKey()};
    final controller = ScrollController();

    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: SizedBox(
          width: 400,
          height: 300,
          child: CustomScrollView(
            controller: controller,
            slivers: [
              for (final entry in keys.entries)
                SliverFixedExtentList(
                  key: entry.value,
                  itemExtent: 100,
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Text('${entry.key}$index'),
                    childCount: 5,
                  ),
                ),
            ],
          ),
        ),
      ),
    ));

    expect(sectionAtTop(keys, controller.offset), 'A');

    controller.jumpTo(600); // 100px into B, A fully scrolled past
    await tester.pump();
    expect(sectionAtTop(keys, controller.offset), 'B');

    controller.jumpTo(1000); // exactly at C's first row
    await tester.pump();
    expect(sectionAtTop(keys, controller.offset), 'C');
  });
}
