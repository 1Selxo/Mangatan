import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:photo_view/photo_view.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

const double readerMinimumZoomScale = 0.5;
const double readerDefaultZoomScale = 1.0;
const double readerMaximumZoomScale = 8.0;
const double _wheelZoomSensitivity = 0.0015;

/// Dispatches pointer signals before descendants so the reader can win the
/// resolver over image widgets with unconditional mouse-wheel zoom handlers.
class ReaderPointerSignalInterceptor extends SingleChildRenderObjectWidget {
  const ReaderPointerSignalInterceptor({
    super.key,
    required this.onPointerSignal,
    required super.child,
  });

  final PointerSignalEventListener onPointerSignal;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderReaderPointerSignalInterceptor(onPointerSignal);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderReaderPointerSignalInterceptor renderObject,
  ) {
    renderObject.onPointerSignal = onPointerSignal;
  }
}

class RenderReaderPointerSignalInterceptor extends RenderProxyBox {
  RenderReaderPointerSignalInterceptor(this.onPointerSignal);

  PointerSignalEventListener onPointerSignal;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    result.add(BoxHitTestEntry(this, position));
    hitTestChildren(result, position: position);
    return true;
  }

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (event is PointerSignalEvent) onPointerSignal(event);
  }
}

bool registerPagedReaderWheelScroll(
  PointerSignalEvent event, {
  required VoidCallback onPreviousPage,
  required VoidCallback onNextPage,
}) {
  if (event is! PointerScrollEvent || _isModifierZoomPressed) return false;

  final delta = _primaryScrollDelta(event);
  if (delta == 0) return false;

  GestureBinding.instance.pointerSignalResolver.register(event, (event) {
    delta > 0 ? onNextPage() : onPreviousPage();
    (event as PointerScrollEvent).respond(allowPlatformDefault: false);
  });
  return true;
}

bool registerReaderModifierWheelZoom(
  PointerSignalEvent event, {
  required BuildContext zoomContext,
  required PhotoViewController photoViewController,
  required Alignment basePosition,
}) {
  if (event is! PointerScrollEvent || !_isModifierZoomPressed) {
    return false;
  }

  GestureBinding.instance.pointerSignalResolver.register(
    event,
    (event) => _handleModifierScrollZoom(
      event,
      zoomContext: zoomContext,
      photoViewController: photoViewController,
      basePosition: basePosition,
    ),
  );
  return true;
}

bool registerHorizontalContinuousWheelScroll(
  PointerSignalEvent event, {
  required bool isHorizontalContinuous,
  required BuildContext scrollContext,
  required ScrollOffsetController scrollOffsetController,
}) {
  if (event is! PointerScrollEvent ||
      !isHorizontalContinuous ||
      event.scrollDelta.dy == 0) {
    return false;
  }

  GestureBinding.instance.pointerSignalResolver.register(
    event,
    (event) => _handleHorizontalContinuousScroll(
      event,
      scrollContext: scrollContext,
      scrollOffsetController: scrollOffsetController,
    ),
  );
  return true;
}

bool get _isModifierZoomPressed {
  final keyboard = HardwareKeyboard.instance;
  return keyboard.isControlPressed || keyboard.isMetaPressed;
}

void _handleModifierScrollZoom(
  PointerSignalEvent event, {
  required BuildContext zoomContext,
  required PhotoViewController photoViewController,
  required Alignment basePosition,
}) {
  final scrollEvent = event as PointerScrollEvent;
  final delta = _primaryScrollDelta(scrollEvent);
  if (delta == 0) return;

  final currentScale = photoViewController.scale ?? readerDefaultZoomScale;
  final targetScale = (currentScale * math.exp(-delta * _wheelZoomSensitivity))
      .clamp(readerMinimumZoomScale, readerMaximumZoomScale)
      .toDouble();
  final scaleRatio = targetScale / currentScale;
  final focalPoint = _focalPointFromBasePosition(
    scrollEvent,
    zoomContext,
    basePosition,
  );
  final targetPosition = focalPoint == null
      ? photoViewController.position
      : photoViewController.position * scaleRatio +
            focalPoint * (1 - scaleRatio);

  photoViewController.updateMultiple(
    scale: targetScale,
    position: targetScale <= readerMinimumZoomScale
        ? Offset.zero
        : targetPosition,
  );
  scrollEvent.respond(allowPlatformDefault: false);
}

double _primaryScrollDelta(PointerScrollEvent event) {
  return event.scrollDelta.dy != 0
      ? event.scrollDelta.dy
      : event.scrollDelta.dx;
}

void _handleHorizontalContinuousScroll(
  PointerSignalEvent event, {
  required BuildContext scrollContext,
  required ScrollOffsetController scrollOffsetController,
}) {
  final scrollEvent = event as PointerScrollEvent;
  final delta = scrollEvent.scrollDelta.dy;
  if (delta == 0) return;

  final scrollable = Scrollable.maybeOf(scrollContext, axis: Axis.horizontal);
  final position = scrollable?.position;
  if (position != null) {
    position.pointerScroll(delta);
  } else {
    scrollOffsetController.animateScroll(
      offset: delta,
      duration: Duration.zero,
    );
  }
  scrollEvent.respond(allowPlatformDefault: false);
}

Offset? _focalPointFromBasePosition(
  PointerScrollEvent event,
  BuildContext zoomContext,
  Alignment basePosition,
) {
  final renderObject = zoomContext.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) {
    return null;
  }

  final localPosition = renderObject.globalToLocal(event.position);
  final alignmentOrigin = basePosition.alongSize(renderObject.size);
  return localPosition - alignmentOrigin;
}
