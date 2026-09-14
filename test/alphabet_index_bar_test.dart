import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:FuseLauncher/layouts/alphabet_index_bar.dart';

void main() {
  testWidgets('a touch on the strip picks the letter at that height',
      (tester) async {
    final letters = ['A', 'B', 'C', 'D'];
    final picked = <String>[];
    final dragging = <bool>[];

    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: SizedBox(
          height: 400,
          child: AlphabetIndexBar(
            letters: letters,
            onSelected: picked.add,
            onDragging: dragging.add,
          ),
        ),
      ),
    ));

    final bar = tester.getRect(find.byType(AlphabetIndexBar));

    await tester.tapAt(Offset(bar.center.dx, bar.top + 10));
    expect(picked.last, 'A');

    await tester.tapAt(Offset(bar.center.dx, bar.top + 250)); // third quarter
    expect(picked.last, 'C');

    await tester.tapAt(Offset(bar.center.dx, bar.bottom - 1));
    expect(picked.last, 'D');

    // The hint follows the finger: shown on touch down, hidden again on release.
    expect(dragging, everyElement(isA<bool>()));
    expect(dragging.first, isTrue);
    expect(dragging.last, isFalse);
  });
}
