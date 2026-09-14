import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Index entry for the top of the list - pinned apps and folders, which have
/// no letter of their own.
const String kTopIndexLetter = '\u2605';

/// Niagara-style index strip down the right edge: tap or drag a letter to jump
/// straight to that section. It only ever lists sections the list really has,
/// so no entry can point at nothing.
class AlphabetIndexBar extends StatefulWidget {
  final List<String> letters;
  final ValueChanged<String> onSelected;

  /// True while a finger is on the strip, so the caller can show the big
  /// letter hint and hide it again on release.
  final ValueChanged<bool>? onDragging;

  const AlphabetIndexBar({
    super.key,
    required this.letters,
    required this.onSelected,
    this.onDragging,
  });

  /// Room the strip needs on the right of the list.
  static const double width = 28.0;

  @override
  State<AlphabetIndexBar> createState() => _AlphabetIndexBarState();
}

class _AlphabetIndexBarState extends State<AlphabetIndexBar> {
  String? _active;

  void _select(double dy, double height) {
    if (widget.letters.isEmpty || height <= 0) return;
    final index = (dy / height * widget.letters.length)
        .floor()
        .clamp(0, widget.letters.length - 1);
    final letter = widget.letters[index];
    if (letter == _active) return;
    setState(() => _active = letter);
    HapticFeedback.selectionClick();
    widget.onSelected(letter);
  }

  void _start(double dy, double height) {
    if (widget.letters.isEmpty) return;
    widget.onDragging?.call(true);
    _select(dy, height);
  }

  /// No-op unless a letter is actually held: the losing drag recognizer sends
  /// a cancel on every plain tap, before the tap itself is recognised.
  void _end() {
    if (_active == null) return;
    widget.onDragging?.call(false);
    setState(() => _active = null);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final base = isDarkMode ? Colors.white : Colors.black;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _start(details.localPosition.dy, height),
          onTapUp: (_) => _end(),
          onTapCancel: _end,
          onVerticalDragStart: (details) =>
              _start(details.localPosition.dy, height),
          onVerticalDragUpdate: (details) =>
              _select(details.localPosition.dy, height),
          onVerticalDragEnd: (_) => _end(),
          onVerticalDragCancel: _end,
          child: SizedBox(
            width: AlphabetIndexBar.width,
            child: Column(
              children: [
                for (final letter in widget.letters)
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: 18,
                        child: Text(
                          letter,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: base
                                .withAlpha(letter == _active ? 255 : 140),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
