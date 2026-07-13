import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mangayomi/modules/mining/reader_lookup_trigger.dart';
import 'package:mangayomi/modules/mining/widgets/reader_ocr_overlay.dart';
import 'package:mangayomi/utils/extensions/build_context_extensions.dart';
import 'package:mangayomi/utils/platform_utils.dart';

/// Navigation layout variants matching Mihon.
///
///  0 = Default  – current three-column + top/bottom zones
///  1 = L-shaped – top-left = prev, bottom-right = next, rest = UI
///  2 = Kindle   – top = UI, bottom split left = prev / right = next
///  3 = Edge     – thin side strips for prev/next, rest = UI
///  4 = Right & Left – simple two-zone left = prev / right = next
///  5 = Disabled – full screen = toggle UI
///
/// For horizontal reading (LTR), the default layout is:
/// ```
/// ┌─────────────────────────┐
/// │     TOP (prev page)     │
/// ├───────┬───────┬─────────┤
/// │ LEFT  │CENTER │  RIGHT  │
/// │(prev) │ (UI)  │ (next)  │
/// ├───────┴───────┴─────────┤
/// │   BOTTOM (next page)    │
/// └─────────────────────────┘
/// ```
///
/// For RTL mode, LEFT and RIGHT actions are reversed.
class ReaderGestureHandler extends StatelessWidget {
  /// Whether tap zones are enabled for navigation
  final bool usePageTapZones;

  /// Whether the reader is in RTL mode
  final bool isRTL;

  /// Whether there's an image loading error
  final bool hasImageError;

  /// Whether the reader is in continuous scroll mode
  final bool isContinuousMode;

  /// Navigation layout index (0-5), see class docs.
  final int navigationLayout;

  /// Tapping zone inversion mode (0 = None, 1 = Horizontal, 2 = Vertical, 3 = Both)
  final int tappingInversion;

  /// Callback when UI should be toggled
  final VoidCallback onToggleUI;

  /// Callback to go to previous page
  final VoidCallback onPreviousPage;

  /// Callback to go to next page
  final VoidCallback onNextPage;

  /// Callback for double-tap to zoom (with position)
  final void Function(Offset position)? onDoubleTapDown;

  /// Callback for double-tap gesture complete
  final VoidCallback? onDoubleTap;

  /// Callback for secondary tap (right-click on desktop)
  final void Function(Offset position)? onSecondaryTapDown;

  /// Callback for secondary tap complete
  final VoidCallback? onSecondaryTap;

  const ReaderGestureHandler({
    super.key,
    required this.usePageTapZones,
    required this.isRTL,
    required this.hasImageError,
    required this.isContinuousMode,
    required this.onToggleUI,
    required this.onPreviousPage,
    required this.onNextPage,
    this.navigationLayout = 0,
    this.tappingInversion = 0,
    this.onDoubleTapDown,
    this.onDoubleTap,
    this.onSecondaryTapDown,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final zones = switch (navigationLayout) {
      1 => _buildLShaped(context),
      2 => _buildKindle(context),
      3 => _buildEdge(context),
      4 => _buildRightAndLeft(context),
      5 => _buildDisabled(context),
      _ => _buildDefault(context),
    };
    return Listener(
      onPointerMove: (event) {
        ReaderOcrState.handleMiddleLookupMove(event.position);
      },
      child: MouseRegion(
        opaque: false,
        onHover: (event) {
          unawaited(ReaderOcrState.handleHover(event.position));
        },
        onExit: (_) => ReaderOcrState.handleHoverExit(),
        child: zones,
      ),
    );
  }

  // ── helpers ──

  bool get _shouldInvertHorizontal =>
      tappingInversion == 1 || tappingInversion == 3;
  bool get _shouldInvertVertical =>
      tappingInversion == 2 || tappingInversion == 3;

  VoidCallback _prev() => isRTL ? onNextPage : onPreviousPage;
  VoidCallback _next() => isRTL ? onPreviousPage : onNextPage;

  _ZoneGestureDetector _zone(VoidCallback onTap) => _ZoneGestureDetector(
    onTap: usePageTapZones ? onTap : onToggleUI,
    onDoubleTapDown: isContinuousMode ? onDoubleTapDown : null,
    onDoubleTap: isContinuousMode ? onDoubleTap : null,
    onSecondaryTapDown: isContinuousMode ? onSecondaryTapDown : null,
    onSecondaryTap: isContinuousMode ? onSecondaryTap : null,
  );

  _ZoneGestureDetector _uiZone() => _ZoneGestureDetector(
    onTap: onToggleUI,
    onDoubleTapDown: isContinuousMode ? onDoubleTapDown : null,
    onDoubleTap: isContinuousMode ? onDoubleTap : null,
    onSecondaryTapDown: isContinuousMode ? onSecondaryTapDown : null,
    onSecondaryTap: isContinuousMode ? onSecondaryTap : null,
  );

  // ── Layout 0: Default (original 3-col + top/bottom) ──

  Widget _buildDefault(BuildContext context) {
    return Stack(
      children: [
        _buildDefaultHorizontalZones(context),
        _buildDefaultVerticalZones(context),
      ],
    );
  }

  Widget _buildDefaultHorizontalZones(BuildContext context) {
    final leftAction = _shouldInvertHorizontal ? _next() : _prev();
    final rightAction = _shouldInvertHorizontal ? _prev() : _next();
    return Row(
      children: [
        Expanded(flex: 2, child: _zone(leftAction)),
        Expanded(
          flex: 2,
          child: hasImageError
              ? SizedBox(width: context.width(1), height: context.height(0.7))
              : _uiZone(),
        ),
        Expanded(flex: 2, child: _zone(rightAction)),
      ],
    );
  }

  Widget _buildDefaultVerticalZones(BuildContext context) {
    final topAction = _shouldInvertVertical ? onNextPage : onPreviousPage;
    final bottomAction = _shouldInvertVertical ? onPreviousPage : onNextPage;
    return Column(
      children: [
        Expanded(flex: 2, child: _zone(hasImageError ? onToggleUI : topAction)),
        const Expanded(flex: 5, child: SizedBox.shrink()),
        Expanded(
          flex: 2,
          child: _zone(hasImageError ? onToggleUI : bottomAction),
        ),
      ],
    );
  }

  // ── Layout 1: L-shaped ──
  // ┌───────┬───────────────┐
  // │ PREV  │               │
  // ├───────┘               │
  // │          UI           │
  // │               ┌───────┤
  // │               │ NEXT  │
  // └───────────────┴───────┘

  Widget _buildLShaped(BuildContext context) {
    final action1 = (_shouldInvertHorizontal ^ _shouldInvertVertical)
        ? _next()
        : _prev();
    final action2 = (_shouldInvertHorizontal ^ _shouldInvertVertical)
        ? _prev()
        : _next();
    return Column(
      children: [
        Expanded(
          flex: 1,
          child: Row(
            children: [
              Expanded(flex: 1, child: _zone(action1)),
              Expanded(flex: 2, child: _uiZone()),
            ],
          ),
        ),
        Expanded(flex: 2, child: _uiZone()),
        Expanded(
          flex: 1,
          child: Row(
            children: [
              Expanded(flex: 2, child: _uiZone()),
              Expanded(flex: 1, child: _zone(action2)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Layout 2: Kindle ──
  // ┌───────────────────────┐
  // │       UI (toggle)     │
  // ├───────────┬───────────┤
  // │   PREV    │   NEXT    │
  // └───────────┴───────────┘

  Widget _buildKindle(BuildContext context) {
    final leftAction = _shouldInvertHorizontal ? _next() : _prev();
    final rightAction = _shouldInvertHorizontal ? _prev() : _next();
    return Column(
      children: [
        Expanded(flex: 1, child: _uiZone()),
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Expanded(child: _zone(leftAction)),
              Expanded(child: _zone(rightAction)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Layout 3: Edge ──
  // ┌──┬──────────────┬──┐
  // │P │              │N │
  // │R │     UI       │E │
  // │E │   (toggle)   │X │
  // │V │              │T │
  // └──┴──────────────┴──┘

  Widget _buildEdge(BuildContext context) {
    final leftAction = _shouldInvertHorizontal ? _next() : _prev();
    final rightAction = _shouldInvertHorizontal ? _prev() : _next();
    return Row(
      children: [
        Expanded(flex: 1, child: _zone(leftAction)),
        Expanded(flex: 5, child: _uiZone()),
        Expanded(flex: 1, child: _zone(rightAction)),
      ],
    );
  }

  // ── Layout 4: Right and Left ──
  // ┌───────────┬───────────┐
  // │           │           │
  // │   PREV    │   NEXT    │
  // │           │           │
  // └───────────┴───────────┘

  Widget _buildRightAndLeft(BuildContext context) {
    final leftAction = _shouldInvertHorizontal ? _next() : _prev();
    final rightAction = _shouldInvertHorizontal ? _prev() : _next();
    return Row(
      children: [
        Expanded(child: _zone(leftAction)),
        Expanded(child: _zone(rightAction)),
      ],
    );
  }

  // ── Layout 5: Disabled ──

  Widget _buildDisabled(BuildContext context) {
    return SizedBox.expand(child: _uiZone());
  }
}

/// Individual gesture detector for a zone.
class _ZoneGestureDetector extends StatefulWidget {
  final VoidCallback onTap;
  final void Function(Offset position)? onDoubleTapDown;
  final VoidCallback? onDoubleTap;
  final void Function(Offset position)? onSecondaryTapDown;
  final VoidCallback? onSecondaryTap;

  const _ZoneGestureDetector({
    required this.onTap,
    this.onDoubleTapDown,
    this.onDoubleTap,
    this.onSecondaryTapDown,
    this.onSecondaryTap,
  });

  @override
  State<_ZoneGestureDetector> createState() => _ZoneGestureDetectorState();
}

class _ZoneGestureDetectorState extends State<_ZoneGestureDetector> {
  bool _pointerHandledByOcr = false;
  bool _lookupPointer = false;
  bool _lookupPointerUsesPrimaryButton = false;
  bool _middleHoverPointer = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (_) {
        final handled = _pointerHandledByOcr;
        _pointerHandledByOcr = false;
        if (!handled) widget.onTap();
      },
      onTapCancel: () => _pointerHandledByOcr = false,
      onDoubleTapDown: widget.onDoubleTapDown != null
          ? (details) => widget.onDoubleTapDown!(details.globalPosition)
          : null,
      onDoubleTap: widget.onDoubleTap,
      onSecondaryTapDown: widget.onSecondaryTapDown != null
          ? (details) => widget.onSecondaryTapDown!(details.globalPosition)
          : null,
      onSecondaryTap: widget.onSecondaryTap,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          _lookupPointerUsesPrimaryButton = event.buttons == kPrimaryButton;
          _middleHoverPointer = ReaderOcrState.handleMiddleLookupStart(
            event.position,
            event.buttons,
          );
          final additionalLeftClick =
              isDesktop &&
              event.kind == PointerDeviceKind.mouse &&
              ReaderLookupTriggerState.additionalLeftClick.value;
          _lookupPointer = ReaderOcrState.lookupOnHover.value
              ? _lookupPointerUsesPrimaryButton
              : _middleHoverPointer ||
                    readerLookupTriggerMatchesPointer(
                      ReaderLookupTriggerState.trigger.value,
                      event.buttons,
                      additionalLeftClick: additionalLeftClick,
                    );
          if (_lookupPointer && !_middleHoverPointer) {
            ReaderOcrState.handlePointerDown(event.position);
          }
        },
        onPointerUp: (event) {
          if (_middleHoverPointer) {
            ReaderOcrState.handleMiddleLookupEnd();
          } else if (_lookupPointer) {
            final handled = ReaderOcrState.handlePointerUp(event.position);
            _pointerHandledByOcr = _lookupPointerUsesPrimaryButton && handled;
          }
          _lookupPointer = false;
          _lookupPointerUsesPrimaryButton = false;
          _middleHoverPointer = false;
        },
        onPointerCancel: (_) {
          if (_lookupPointer) ReaderOcrState.handlePointerCancel();
          if (_middleHoverPointer) ReaderOcrState.handleMiddleLookupEnd();
          _lookupPointer = false;
          _lookupPointerUsesPrimaryButton = false;
          _middleHoverPointer = false;
        },
        child: const SizedBox.expand(),
      ),
    );
  }
}
