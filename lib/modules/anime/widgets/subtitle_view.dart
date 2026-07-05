/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright (c) 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
// ignore_for_file: dangling_library_doc_comments, doc_directive_missing_closing_tag, deprecated_member_use

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mangayomi/modules/anime/providers/state_provider.dart';
import 'package:mangayomi/modules/mining/widgets/dictionary_lookup_popup.dart';
import 'package:mangayomi/services/mining/mining_models.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class CustomSubtitleView extends ConsumerStatefulWidget {
  final VideoController controller;
  final SubtitleViewConfiguration configuration;
  final MiningContext Function(String text)? miningContextBuilder;
  final bool paintSubtitle;

  const CustomSubtitleView({
    super.key,
    required this.controller,
    required this.configuration,
    this.miningContextBuilder,
    this.paintSubtitle = true,
  });

  @override
  ConsumerState<CustomSubtitleView> createState() => _CustomSubtitleViewState();
}

class _CustomSubtitleViewState extends ConsumerState<CustomSubtitleView> {
  late List<String> subtitle = widget.controller.player.state.subtitle;
  late TextStyle style = widget.configuration.style;
  late TextAlign textAlign = widget.configuration.textAlign;
  late EdgeInsets padding = widget.configuration.padding;
  late Duration duration = const Duration(milliseconds: 100);
  final GlobalKey _subtitleTextKey = GlobalKey();
  int _highlightStart = -1;
  int _highlightEnd = -1;
  Timer? _hoverLookupTimer;
  Timer? _hoverExitTimer;
  DictionaryPopupHandle? _hoverPopup;
  _SubtitleLookupSelection? _hoverSelection;
  bool _subtitleHovered = false;
  bool _popupHovered = false;
  bool _resumeAfterHover = false;
  bool _popupPrewarmed = false;

  StreamSubscription<List<String>>? _subtitleSubscription;
  StreamSubscription<Track>? _trackSubscription;
  Timer? _nativeSubtitlePaintTimer;

  static const kTextScaleFactorReferenceWidth = 1920.0;
  static const kTextScaleFactorReferenceHeight = 1080.0;

  @override
  void initState() {
    super.initState();
    _hideNativeSubtitlePaintSoon();
    _subtitleSubscription = widget.controller.player.stream.subtitle.listen((
      value,
    ) {
      _hideNativeSubtitlePaintSoon();
      setState(() {
        subtitle = value;
        _clearHighlight();
      });
      _dismissHoverLookup(resume: true);
    });
    _trackSubscription = widget.controller.player.stream.track.listen((_) {
      _hideNativeSubtitlePaintSoon();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_desktopHoverEnabled && !_popupPrewarmed) {
      _popupPrewarmed = true;
      unawaited(DictionaryLookupPopup.prewarm(context));
    }
  }

  @override
  void dispose() {
    _subtitleSubscription?.cancel();
    _trackSubscription?.cancel();
    _nativeSubtitlePaintTimer?.cancel();
    _hoverLookupTimer?.cancel();
    _hoverExitTimer?.cancel();
    _hoverPopup?.dismiss();
    if (_resumeAfterHover) {
      unawaited(widget.controller.player.play());
    }
    super.dispose();
  }

  bool get _desktopHoverEnabled =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  void setPadding(
    EdgeInsets padding, {
    Duration duration = const Duration(milliseconds: 100),
  }) {
    if (this.duration != duration) {
      setState(() {
        this.duration = duration;
      });
    }
    setState(() {
      this.padding = padding;
    });
  }

  void _hideNativeSubtitlePaintSoon() {
    if (!widget.paintSubtitle) return;
    unawaited(_disableNativeSubtitlePaint());
    _nativeSubtitlePaintTimer?.cancel();
    _nativeSubtitlePaintTimer = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(_disableNativeSubtitlePaint()),
    );
  }

  Future<void> _disableNativeSubtitlePaint() async {
    if (!widget.paintSubtitle) return;
    try {
      final platform = widget.controller.player.platform;
      if (platform is NativePlayer) {
        await platform.setProperty('sub-visibility', 'no');
      }
    } catch (_) {}
  }

  void _clearHighlight() {
    _highlightStart = -1;
    _highlightEnd = -1;
  }

  void _clearHighlightIfNeeded() {
    if (_highlightStart != -1 || _highlightEnd != -1) {
      setState(_clearHighlight);
    }
  }

  _SubtitleLookupSelection? _selectionAtPosition({
    required BuildContext context,
    required Offset globalPosition,
    required String subtitleText,
    required TextStyle subtitleStyle,
    required TextScaler textScaler,
  }) {
    if (subtitleText.trim().isEmpty) return null;
    final textBox =
        _subtitleTextKey.currentContext?.findRenderObject() as RenderBox?;
    if (textBox == null) return null;
    final selection = _lookupTextAtPosition(
      context: context,
      box: textBox,
      globalPosition: globalPosition,
      subtitleText: subtitleText,
      subtitleStyle: subtitleStyle,
      textScaler: textScaler,
    );
    if (selection.text.trim().isEmpty) {
      if (_highlightStart != -1 || _highlightEnd != -1) {
        setState(_clearHighlight);
      }
      return null;
    }
    return selection;
  }

  Future<DictionaryPopupHandle?> _showLookupAtPosition(
    BuildContext context,
    Offset globalPosition,
    String subtitleText,
    TextStyle subtitleStyle,
    TextScaler textScaler, {
    bool hoverTriggered = false,
  }) async {
    final builder = widget.miningContextBuilder;
    if (builder == null || subtitleText.trim().isEmpty) return null;
    final textBox =
        _subtitleTextKey.currentContext?.findRenderObject() as RenderBox?;
    final selection = textBox == null
        ? _SubtitleLookupSelection(
            text: subtitleText.trim(),
            start: 0,
            end: subtitleText.trim().length,
          )
        : _lookupTextAtPosition(
            context: context,
            box: textBox,
            globalPosition: globalPosition,
            subtitleText: subtitleText,
            subtitleStyle: subtitleStyle,
            textScaler: textScaler,
          );
    if (selection.text.trim().isEmpty || !context.mounted) return null;
    final anchor = textBox == null
        ? Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 1, 1)
        : _lookupAnchorRect(
            context: context,
            box: textBox,
            subtitleText: subtitleText,
            subtitleStyle: subtitleStyle,
            textScaler: textScaler,
            selection: selection,
          );
    return DictionaryLookupPopup.show(
      context: context,
      anchor: anchor,
      text: selection.text,
      miningContext: builder(subtitleText),
      onMatchChanged: (count) {
        if (!mounted || count <= 0) return;
        setState(() {
          _highlightStart = selection.start;
          _highlightEnd = (selection.start + count).clamp(
            selection.start + 1,
            subtitleText.length,
          );
        });
      },
      onHoverChanged: hoverTriggered ? _onPopupHoverChanged : null,
    );
  }

  void _handleSubtitleHover({
    required BuildContext context,
    required Offset globalPosition,
    required String subtitleText,
    required TextStyle subtitleStyle,
    required TextScaler textScaler,
  }) {
    _subtitleHovered = true;
    _hoverExitTimer?.cancel();
    final selection = _selectionAtPosition(
      context: context,
      globalPosition: globalPosition,
      subtitleText: subtitleText,
      subtitleStyle: subtitleStyle,
      textScaler: textScaler,
    );
    if (selection == null) {
      _scheduleHoverDismiss();
      return;
    }
    if (_sameSelection(_hoverSelection, selection) && _hoverPopup != null) {
      return;
    }
    _clearHighlightIfNeeded();
    _hoverSelection = selection;
    _hoverLookupTimer?.cancel();
    _hoverLookupTimer = Timer(const Duration(milliseconds: 140), () {
      unawaited(
        _openHoverLookup(
          context: context,
          selection: selection,
          subtitleText: subtitleText,
          subtitleStyle: subtitleStyle,
          textScaler: textScaler,
          globalPosition: globalPosition,
        ),
      );
    });
  }

  Future<void> _openHoverLookup({
    required BuildContext context,
    required _SubtitleLookupSelection selection,
    required String subtitleText,
    required TextStyle subtitleStyle,
    required TextScaler textScaler,
    required Offset globalPosition,
  }) async {
    if (!mounted ||
        !_subtitleHovered ||
        !_sameSelection(_hoverSelection, selection)) {
      return;
    }
    if (widget.controller.player.state.playing && !_resumeAfterHover) {
      _resumeAfterHover = true;
      await widget.controller.player.pause();
    }
    final previous = _hoverPopup;
    _hoverPopup = null;
    previous?.dismiss();
    if (!context.mounted) {
      _resumeHoverPlayback();
      return;
    }
    final handle = await _showLookupAtPosition(
      context,
      globalPosition,
      subtitleText,
      subtitleStyle,
      textScaler,
      hoverTriggered: true,
    );
    if (!mounted ||
        !_sameSelection(_hoverSelection, selection) ||
        (!_subtitleHovered && !_popupHovered)) {
      handle?.dismiss();
      if (_hoverPopup == null) _resumeHoverPlayback();
      return;
    }
    _hoverPopup = handle;
    if (handle != null) {
      unawaited(_watchHoverPopup(handle));
    } else {
      _resumeHoverPlayback();
    }
  }

  Future<void> _watchHoverPopup(DictionaryPopupHandle handle) async {
    await handle.dismissed;
    if (!mounted || !identical(_hoverPopup, handle)) return;
    _hoverPopup = null;
    _popupHovered = false;
    _hoverSelection = null;
    if (_highlightStart != -1 || _highlightEnd != -1) {
      setState(_clearHighlight);
    }
    _resumeHoverPlayback();
  }

  void _onPopupHoverChanged(bool hovered) {
    _popupHovered = hovered;
    if (hovered) {
      _hoverExitTimer?.cancel();
    } else {
      _scheduleHoverDismiss();
    }
  }

  void _scheduleHoverDismiss() {
    _hoverExitTimer?.cancel();
    _hoverExitTimer = Timer(const Duration(milliseconds: 220), () {
      if (!_subtitleHovered && !_popupHovered) {
        _dismissHoverLookup(resume: true);
      }
    });
  }

  void _dismissHoverLookup({required bool resume}) {
    _hoverLookupTimer?.cancel();
    _hoverExitTimer?.cancel();
    _hoverSelection = null;
    final popup = _hoverPopup;
    _hoverPopup = null;
    popup?.dismiss();
    if (resume) _resumeHoverPlayback();
  }

  void _resumeHoverPlayback() {
    if (!_resumeAfterHover) return;
    _resumeAfterHover = false;
    unawaited(widget.controller.player.play());
  }

  Rect _lookupAnchorRect({
    required BuildContext context,
    required RenderBox box,
    required String subtitleText,
    required TextStyle subtitleStyle,
    required TextScaler textScaler,
    required _SubtitleLookupSelection selection,
  }) {
    final painter = _subtitleTextPainter(
      context: context,
      subtitleText: subtitleText,
      subtitleStyle: subtitleStyle,
      textScaler: textScaler,
      textAlign: textAlign,
      maxWidth: box.size.width,
    );
    final rects = _textSelectionRects(
      painter,
      subtitleText,
      selection.start,
      selection.end,
    );
    if (rects.isEmpty) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    final local = rects.reduce(
      (value, element) => value.expandToInclude(element),
    );
    return box.localToGlobal(local.topLeft) & local.size;
  }

  _SubtitleLookupSelection _lookupTextAtPosition({
    required BuildContext context,
    required RenderBox box,
    required Offset globalPosition,
    required String subtitleText,
    required TextStyle subtitleStyle,
    required TextScaler textScaler,
  }) {
    final painter = _subtitleTextPainter(
      context: context,
      subtitleText: subtitleText,
      subtitleStyle: subtitleStyle,
      textScaler: textScaler,
      textAlign: textAlign,
      maxWidth: box.size.width,
    );
    final position = _nearestLookupOffset(
      painter,
      subtitleText,
      box.globalToLocal(globalPosition),
    );
    if (position == null) {
      return const _SubtitleLookupSelection(text: '', start: 0, end: 0);
    }
    return _extractSubtitleLookupSelection(subtitleText, position);
  }

  @override
  Widget build(BuildContext context) {
    subtitle = widget.controller.player.state.subtitle;
    style = widget.configuration.style;
    textAlign = widget.configuration.textAlign;
    padding = widget.configuration.padding;
    return LayoutBuilder(
      builder: (context, constraints) {
        final nr = constraints.maxWidth * constraints.maxHeight;
        const dr =
            kTextScaleFactorReferenceWidth * kTextScaleFactorReferenceHeight;
        final textScaleFactor = sqrt((nr / dr).clamp(0.0, 1.0));
        final textScaler =
            widget.configuration.textScaler ??
            TextScaler.linear(textScaleFactor);
        final subtitleText = [
          for (final line in subtitle)
            if (line.trim().isNotEmpty) line.trim(),
        ].join('\n');
        final rawSubtitleStyle = widget.paintSubtitle
            ? style
            : style.copyWith(
                color: Colors.transparent,
                backgroundColor: Colors.transparent,
                shadows: const [],
              );
        final subtitleStyle = _subtitleFillStyle(rawSubtitleStyle);
        final text = _CrispSubtitleText(
          key: _subtitleTextKey,
          text: subtitleText,
          style: subtitleStyle,
          textAlign: textAlign,
          textScaler: textScaler,
          outlineColor: _subtitleOutlineColor(rawSubtitleStyle),
          highlightStart: _highlightStart,
          highlightEnd: _highlightEnd,
        );
        return AnimatedPadding(
          padding: padding,
          duration: duration,
          child: Align(
            alignment: Alignment.bottomCenter,
            child:
                subtitleText.trim().isEmpty ||
                    widget.miningContextBuilder == null
                ? text
                : MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) {
                      if (_desktopHoverEnabled) _subtitleHovered = true;
                    },
                    onHover: (event) {
                      if (_desktopHoverEnabled) {
                        _handleSubtitleHover(
                          context: context,
                          globalPosition: event.position,
                          subtitleText: subtitleText,
                          subtitleStyle: subtitleStyle,
                          textScaler: textScaler,
                        );
                      } else {
                        _selectionAtPosition(
                          context: context,
                          globalPosition: event.position,
                          subtitleText: subtitleText,
                          subtitleStyle: subtitleStyle,
                          textScaler: textScaler,
                        );
                        _clearHighlightIfNeeded();
                      }
                    },
                    onExit: (_) {
                      if (_desktopHoverEnabled) {
                        _subtitleHovered = false;
                        _scheduleHoverDismiss();
                      } else if (_highlightStart != -1 || _highlightEnd != -1) {
                        setState(_clearHighlight);
                      }
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapDown: (_) => _clearHighlightIfNeeded(),
                      onTapUp: (details) {
                        _hoverLookupTimer?.cancel();
                        unawaited(
                          _showLookupAtPosition(
                            context,
                            details.globalPosition,
                            subtitleText,
                            subtitleStyle,
                            textScaler,
                          ),
                        );
                      },
                      child: text,
                    ),
                  ),
          ),
        );
      },
    );
  }
}

_SubtitleLookupSelection _extractSubtitleLookupSelection(
  String text,
  int offset,
) {
  if (text.isEmpty) {
    return const _SubtitleLookupSelection(text: '', start: 0, end: 0);
  }
  var start = offset.clamp(0, text.length - 1).toInt();
  while (start < text.length && _isLookupBoundary(text[start])) {
    start++;
  }
  if (start >= text.length) {
    return const _SubtitleLookupSelection(text: '', start: 0, end: 0);
  }
  if (_isAsciiWord(text[start])) {
    while (start > 0 && _isAsciiWord(text[start - 1])) {
      start--;
    }
  }
  var end = start;
  while (end < text.length &&
      !_isLookupBoundary(text[end]) &&
      end - start < 80) {
    end++;
  }
  return _SubtitleLookupSelection(
    text: text.substring(start, end).trim(),
    start: start,
    end: end,
  );
}

@visibleForTesting
({String text, int start, int end}) subtitleLookupSelectionForTesting(
  String text,
  int offset,
) {
  final selection = _extractSubtitleLookupSelection(text, offset);
  return (text: selection.text, start: selection.start, end: selection.end);
}

@visibleForTesting
List<Rect> subtitleHighlightRectsForTesting({
  required String text,
  required int start,
  required int end,
  double maxWidth = 600,
}) {
  final painter = TextPainter(
    text: const TextSpan(style: TextStyle(fontSize: 40)),
    textDirection: TextDirection.ltr,
  );
  painter.text = TextSpan(text: text, style: const TextStyle(fontSize: 40));
  painter.layout(maxWidth: maxWidth);
  return _textSelectionRects(painter, text, start, end);
}

class _SubtitleLookupSelection {
  const _SubtitleLookupSelection({
    required this.text,
    required this.start,
    required this.end,
  });

  final String text;
  final int start;
  final int end;
}

bool _sameSelection(
  _SubtitleLookupSelection? left,
  _SubtitleLookupSelection right,
) => left != null && left.start == right.start && left.end == right.end;

TextPainter _subtitleTextPainter({
  required BuildContext context,
  required String subtitleText,
  required TextStyle subtitleStyle,
  required TextScaler textScaler,
  required TextAlign textAlign,
  required double maxWidth,
}) => TextPainter(
  text: TextSpan(text: subtitleText, style: subtitleStyle),
  textDirection: Directionality.of(context),
  textAlign: textAlign,
  textScaler: textScaler,
)..layout(maxWidth: maxWidth);

int? _nearestLookupOffset(TextPainter painter, String text, Offset position) {
  int? nearest;
  double nearestScore = double.infinity;
  for (var offset = 0; offset < text.length; offset++) {
    if (_isLookupBoundary(text[offset])) continue;
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: offset, extentOffset: offset + 1),
      boxHeightStyle: ui.BoxHeightStyle.tight,
      boxWidthStyle: ui.BoxWidthStyle.tight,
    );
    for (final box in boxes) {
      final rect = box.toRect();
      if (rect.width <= 0 || rect.height <= 0) continue;
      final dx = position.dx < rect.left
          ? rect.left - position.dx
          : position.dx > rect.right
          ? position.dx - rect.right
          : 0.0;
      final dy = position.dy < rect.top
          ? rect.top - position.dy
          : position.dy > rect.bottom
          ? position.dy - rect.bottom
          : 0.0;
      final horizontalLimit = (rect.width * 0.9).clamp(8.0, 28.0);
      final verticalLimit = (rect.height * 0.8).clamp(10.0, 30.0);
      if (dx > horizontalLimit || dy > verticalLimit) continue;
      final centerDistance =
          (position.dx - rect.center.dx).abs() +
          (position.dy - rect.center.dy).abs() * 0.55;
      final score = dx * 2.2 + dy * 1.4 + centerDistance * 0.2;
      if (score < nearestScore) {
        nearest = offset;
        nearestScore = score;
      }
    }
  }
  return nearest;
}

List<Rect> _textSelectionRects(
  TextPainter painter,
  String text,
  int start,
  int end,
) {
  final safeStart = start.clamp(0, text.length);
  final safeEnd = end.clamp(safeStart, text.length);
  if (safeStart >= safeEnd) return const [];
  final rects = <Rect>[];
  for (var offset = safeStart; offset < safeEnd; offset++) {
    if (text[offset].trim().isEmpty) continue;
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: offset, extentOffset: offset + 1),
      boxHeightStyle: ui.BoxHeightStyle.tight,
      boxWidthStyle: ui.BoxWidthStyle.tight,
    );
    for (final box in boxes) {
      final rect = box.toRect();
      if (rect.width > 0 && rect.height > 0) rects.add(rect);
    }
  }
  final merged = <Rect>[];
  for (final rect in rects) {
    final line = merged.indexWhere(
      (candidate) =>
          (candidate.top - rect.top).abs() < 2 &&
          (candidate.bottom - rect.bottom).abs() < 2,
    );
    if (line < 0) {
      merged.add(rect);
    } else {
      merged[line] = merged[line].expandToInclude(rect);
    }
  }
  return merged;
}

bool _isAsciiWord(String value) {
  final code = value.codeUnitAt(0);
  return (code >= 0x30 && code <= 0x39) ||
      (code >= 0x41 && code <= 0x5a) ||
      (code >= 0x61 && code <= 0x7a) ||
      code == 0x27 ||
      code == 0x2d;
}

bool _isLookupBoundary(String value) {
  return RegExp(
    r'[\s\u3001\u3002\uff01\uff1f!?\u300c\u300d\u300e\u300f\uff08\uff09()\[\]{}.,;:\u30fb\u2026]',
  ).hasMatch(value);
}

class _CrispSubtitleText extends StatelessWidget {
  const _CrispSubtitleText({
    super.key,
    required this.text,
    required this.style,
    required this.textAlign,
    required this.textScaler,
    required this.outlineColor,
    required this.highlightStart,
    required this.highlightEnd,
  });

  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final TextScaler textScaler;
  final Color outlineColor;
  final int highlightStart;
  final int highlightEnd;

  @override
  Widget build(BuildContext context) {
    final fillColor = style.color ?? Colors.white;
    final outlineVisible = fillColor.a > 0 && outlineColor.a > 0;
    return Stack(
      alignment: Alignment.center,
      children: [
        if (highlightStart >= 0 && highlightEnd > highlightStart)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _SubtitleHighlightPainter(
                  text: text,
                  style: style,
                  textAlign: textAlign,
                  textScaler: textScaler,
                  textDirection: Directionality.of(context),
                  start: highlightStart,
                  end: highlightEnd,
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
        if (outlineVisible)
          Text.rich(
            _subtitleSpan(
              text: text,
              style: _subtitleOutlineStyle(style, outlineColor),
              highlightStart: -1,
              highlightEnd: -1,
            ),
            style: _subtitleOutlineStyle(style, outlineColor),
            textAlign: textAlign,
            textScaler: textScaler,
          ),
        Text.rich(
          _subtitleSpan(
            text: text,
            style: style,
            highlightStart: highlightStart,
            highlightEnd: highlightEnd,
          ),
          textAlign: textAlign,
          textScaler: textScaler,
        ),
      ],
    );
  }
}

TextSpan _subtitleSpan({
  required String text,
  required TextStyle style,
  required int highlightStart,
  required int highlightEnd,
}) {
  final start = highlightStart.clamp(0, text.length).toInt();
  final end = highlightEnd.clamp(start, text.length).toInt();
  if (start >= end) return TextSpan(text: text, style: style);
  return TextSpan(
    style: style,
    children: [
      if (start > 0) TextSpan(text: text.substring(0, start)),
      TextSpan(text: text.substring(start, end), style: style),
      if (end < text.length) TextSpan(text: text.substring(end)),
    ],
  );
}

class _SubtitleHighlightPainter extends CustomPainter {
  const _SubtitleHighlightPainter({
    required this.text,
    required this.style,
    required this.textAlign,
    required this.textScaler,
    required this.textDirection,
    required this.start,
    required this.end,
    required this.color,
  });

  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final TextScaler textScaler;
  final TextDirection textDirection;
  final int start;
  final int end;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textAlign: textAlign,
      textScaler: textScaler,
    )..layout(maxWidth: size.width);
    final paint = Paint()..color = color;
    for (final rect in _textSelectionRects(painter, text, start, end)) {
      final padded = Rect.fromLTRB(
        rect.left - 2,
        rect.top - 1,
        rect.right + 2,
        rect.bottom + 1,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(padded, const Radius.circular(6)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SubtitleHighlightPainter oldDelegate) =>
      oldDelegate.text != text ||
      oldDelegate.style != style ||
      oldDelegate.textAlign != textAlign ||
      oldDelegate.textScaler != textScaler ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.start != start ||
      oldDelegate.end != end ||
      oldDelegate.color != color;
}

TextStyle _subtitleFillStyle(TextStyle style) {
  return style.copyWith(shadows: const []);
}

Color _subtitleOutlineColor(TextStyle style) {
  final shadows = style.shadows;
  if (shadows != null && shadows.isNotEmpty) return shadows.first.color;
  return Colors.black;
}

TextStyle _subtitleOutlineStyle(TextStyle style, Color outlineColor) {
  return TextStyle(
    inherit: style.inherit,
    fontFamily: style.fontFamily,
    fontFamilyFallback: style.fontFamilyFallback,
    fontSize: style.fontSize,
    fontWeight: style.fontWeight,
    fontStyle: style.fontStyle,
    letterSpacing: style.letterSpacing,
    wordSpacing: style.wordSpacing,
    textBaseline: style.textBaseline,
    height: style.height,
    leadingDistribution: style.leadingDistribution,
    locale: style.locale,
    foreground: Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = _subtitleOutlineWidth(style)
      ..color = outlineColor,
    fontFeatures: style.fontFeatures,
    fontVariations: style.fontVariations,
    decoration: style.decoration,
    decorationColor: style.decorationColor,
    decorationStyle: style.decorationStyle,
    decorationThickness: style.decorationThickness,
    overflow: style.overflow,
  );
}

double _subtitleOutlineWidth(TextStyle style) {
  final size = style.fontSize ?? 40;
  return max(2.0, min(3.4, size * 0.075));
}

TextStyle subtileTextStyle(WidgetRef ref) {
  final subSets = ref.watch(subtitleSettingsStateProvider);
  final borderColor = Color.fromARGB(
    subSets.borderColorA!,
    subSets.borderColorR!,
    subSets.borderColorG!,
    subSets.borderColorB!,
  );
  return TextStyle(
    fontSize: subSets.fontSize!.toDouble(),
    fontWeight: subSets.useBold! ? FontWeight.bold : null,
    fontStyle: subSets.useItalic! ? FontStyle.italic : null,
    color: Color.fromARGB(
      subSets.textColorA!,
      subSets.textColorR!,
      subSets.textColorG!,
      subSets.textColorB!,
    ),
    shadows: [
      Shadow(offset: const Offset(-1.5, -1.5), color: borderColor),
      Shadow(offset: const Offset(1.5, -1.5), color: borderColor),
      Shadow(offset: const Offset(1.5, 1.5), color: borderColor),
      Shadow(offset: const Offset(-1.5, 1.5), color: borderColor),
    ],
    backgroundColor: Color.fromARGB(
      subSets.backgroundColorA!,
      subSets.backgroundColorR!,
      subSets.backgroundColorG!,
      subSets.backgroundColorB!,
    ),
  );
}
