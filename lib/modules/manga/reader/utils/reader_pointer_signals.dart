import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:photo_view/photo_view.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

const double _minWheelScale = 1.0;
const double _maxWheelScale = 8.0;
const double _wheelZoomSensitivity = 0.0015;

bool registerReaderModifierWheelZoom(
  PointerSignalEvent event, {
  required BuildContext zoomContext,
  required PhotoViewController photoViewController,
  required PhotoViewScaleStateController scaleStateController,
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
      scaleStateController: scaleStateController,
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
  required PhotoViewScaleStateController scaleStateController,
  required Alignment basePosition,
}) {
  final scrollEvent = event as PointerScrollEvent;
  final delta = scrollEvent.scrollDelta.dy != 0
      ? scrollEvent.scrollDelta.dy
      : scrollEvent.scrollDelta.dx;
  if (delta == 0) return;

  final currentScale = photoViewController.scale ?? _minWheelScale;
  final targetScale = (currentScale * math.exp(-delta * _wheelZoomSensitivity))
      .clamp(_minWheelScale, _maxWheelScale)
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
    position: targetScale <= _minWheelScale ? Offset.zero : targetPosition,
  );
  if (targetScale <= _minWheelScale) {
    scaleStateController.reset();
  }
  scrollEvent.respond(allowPlatformDefault: false);
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
