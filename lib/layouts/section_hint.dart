import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Letter of the section under the top edge of the viewport, read from the real
/// sliver positions so it stays exact whatever the row heights turn out to be.
/// Keys must be in section order; ones not in the render tree are ignored.
String? sectionAtTop(Map<String, GlobalKey> sectionKeys, double scrollOffset) {
  String? current;
  for (final entry in sectionKeys.entries) {
    final renderObject = entry.value.currentContext?.findRenderObject();
    if (renderObject == null || !renderObject.attached) continue;
    final start = RenderAbstractViewport.of(renderObject)
        .getOffsetToReveal(renderObject, 0.0)
        .offset;
    if (start > scrollOffset + 1) break;
    current = entry.key;
  }
  return current;
}

/// Letter badge shown while the scrollbar thumb is being dragged. It tracks the
/// thumb off [position] (the scroll fraction) but rides above it, so the finger
/// doing the dragging never covers it.
class SectionHint extends StatelessWidget {
  final String? letter;
  final double position;

  const SectionHint({super.key, required this.letter, required this.position});

  @override
  Widget build(BuildContext context) {
    final visible = letter != null && letter!.isNotEmpty;
    // Alignment units, so the lift scales with the viewport and clamps to it.
    final y = ((position.clamp(0.0, 1.0) * 2) - 1 - 0.35).clamp(-1.0, 1.0);
    return IgnorePointer(
      child: Align(
        alignment: Alignment(0.88, y),
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(150),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              letter ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
