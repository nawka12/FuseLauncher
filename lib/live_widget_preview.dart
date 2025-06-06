import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:visibility_detector/visibility_detector.dart';

class LiveWidgetPreview extends StatefulWidget {
  final int widgetId;
  final int minHeight;

  const LiveWidgetPreview({
    super.key,
    required this.widgetId,
    required this.minHeight,
  });

  @override
  State<LiveWidgetPreview> createState() => _LiveWidgetPreviewState();
}

class _LiveWidgetPreviewState extends State<LiveWidgetPreview> {
  bool _isVisible = false;

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('live_preview_${widget.widgetId}'),
      onVisibilityChanged: (VisibilityInfo info) {
        // For example, instantiate live preview if at least 10% is visible.
        bool visible = info.visibleFraction > 0.1;
        if (visible != _isVisible && mounted) {
          setState(() {
            _isVisible = visible;
          });
        }
      },
      child: _isVisible
          ? AndroidView(
              viewType: 'android_widget_view',
              creationParams: {
                'widgetId': widget.widgetId,
                // Adjust width based on your layout needs.
                'width': MediaQuery.of(context).size.width.toInt() - 32,
                'height': widget.minHeight,
              },
              creationParamsCodec: const StandardMessageCodec(),
            )
          : Container(
              height: widget.minHeight.toDouble(),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(13),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  Icons.widgets,
                  size: widget.minHeight / 2.5,
                  color: Colors.black.withAlpha(77),
                ),
              ),
            ),
    );
  }
}
