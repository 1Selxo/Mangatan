import 'package:flutter/widgets.dart';
import 'package:mangayomi/modules/manga/reader/utils/reader_pointer_signals.dart';
import 'package:photo_view/photo_view.dart';

/// Gives a zoomed-out continuous reader enough layout space to paint the
/// pages immediately before and after the current viewport.
///
/// PhotoView scales its custom child after layout. Without this wrapper, the
/// scrollable's own viewport and clip are scaled too, leaving unused areas of
/// the reader black even though neighboring pages are cached. Only the main
/// axis grows here, so pages retain the exact same scale and spread layout.
class ContinuousReaderZoomViewport extends StatelessWidget {
  const ContinuousReaderZoomViewport({
    super.key,
    required this.controller,
    required this.scrollDirection,
    required this.alignment,
    required this.child,
  });

  final PhotoViewController controller;
  final Axis scrollDirection;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          StreamBuilder<PhotoViewControllerValue>(
            stream: controller.outputStateStream,
            initialData: controller.value,
            builder: (context, snapshot) {
              final scale = (snapshot.data?.scale ?? readerDefaultZoomScale)
                  .clamp(readerMinimumZoomScale, readerDefaultZoomScale);
              final width = scrollDirection == Axis.horizontal
                  ? constraints.maxWidth / scale
                  : constraints.maxWidth;
              final height = scrollDirection == Axis.vertical
                  ? constraints.maxHeight / scale
                  : constraints.maxHeight;

              return OverflowBox(
                alignment: alignment,
                minWidth: width,
                maxWidth: width,
                minHeight: height,
                maxHeight: height,
                child: SizedBox(width: width, height: height, child: child),
              );
            },
          ),
    );
  }
}

/// Keeps the same aligned content point in place while a zoomed-out
/// [ContinuousReaderZoomViewport] changes the scrollable's main-axis extent.
class ContinuousReaderZoomScrollPhysics extends ScrollPhysics {
  const ContinuousReaderZoomScrollPhysics({
    required this.controller,
    required this.alignment,
    required this.baseViewportDimension,
    super.parent,
  });

  final PhotoViewController controller;
  final Alignment alignment;
  final double baseViewportDimension;

  @override
  ContinuousReaderZoomScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ContinuousReaderZoomScrollPhysics(
      controller: controller,
      alignment: alignment,
      baseViewportDimension: baseViewportDimension,
      parent: buildParent(ancestor),
    );
  }

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    final adjustedPosition = super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
    final extentDelta =
        newPosition.viewportDimension - oldPosition.viewportDimension;
    if (extentDelta == 0 || !_isZoomDimensionChange(oldPosition, newPosition)) {
      return adjustedPosition;
    }

    final axisAlignment = newPosition.axis == Axis.vertical
        ? alignment.y
        : alignment.x;
    final leadingGrowth = extentDelta * (axisAlignment + 1) / 2;
    return adjustedPosition - leadingGrowth;
  }

  bool _isZoomDimensionChange(
    ScrollMetrics oldPosition,
    ScrollMetrics newPosition,
  ) {
    final scale = controller.scale ?? readerDefaultZoomScale;
    if (scale < readerDefaultZoomScale) return true;

    // Preserve the anchor for the final step back to 100%, but leave ordinary
    // window resizing at the default scale to the original scroll physics.
    final previousScale = controller.prevValue.scale ?? readerDefaultZoomScale;
    if (previousScale >= readerDefaultZoomScale) return false;
    final expectedExpandedExtent = baseViewportDimension / previousScale;
    return (oldPosition.viewportDimension - expectedExpandedExtent).abs() <
            0.01 &&
        (newPosition.viewportDimension - baseViewportDimension).abs() < 0.01;
  }
}
