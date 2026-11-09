import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Gets the mouse wheel before the views inside it, and keeps it from them
/// when [onWheel] uses it.
///
/// A scrolling view inside claims every wheel event it can scroll with,
/// which would leave the reader none: a vertical page view would scroll a
/// little and snap back instead of turning the page, and a strip would
/// scroll instead of zooming with Ctrl held. Events this widget gets first
/// win the pointer-signal resolver.
class ReaderWheelInterceptor extends SingleChildRenderObjectWidget {
  const ReaderWheelInterceptor({
    super.key,
    required this.onWheel,
    required super.child,
  });

  /// Handles a wheel event and says whether it used it; null passes every
  /// event on.
  final bool Function(PointerScrollEvent event)? onWheel;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderReaderWheelInterceptor(onWheel);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderReaderWheelInterceptor renderObject,
  ) {
    renderObject.onWheel = onWheel;
  }
}

class RenderReaderWheelInterceptor extends RenderProxyBox {
  RenderReaderWheelInterceptor(this.onWheel);

  bool Function(PointerScrollEvent event)? onWheel;

  /// Added before the children, so pointer events reach this first.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    result.add(BoxHitTestEntry(this, position));
    hitTestChildren(result, position: position);
    return true;
  }

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    final onWheel = this.onWheel;
    if (onWheel == null || event is! PointerScrollEvent) return;
    if (!onWheel(event)) return;
    GestureBinding.instance.pointerSignalResolver.register(
      event,
      (event) =>
          (event as PointerScrollEvent).respond(allowPlatformDefault: false),
    );
  }
}
