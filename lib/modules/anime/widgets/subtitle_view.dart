/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright (c) 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
// ignore_for_file: dangling_library_doc_comments, doc_directive_missing_closing_tag, deprecated_member_use

import 'dart:async';
import 'dart:math';

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
    });
    _trackSubscription = widget.controller.player.stream.track.listen((_) {
      _hideNativeSubtitlePaintSoon();
    });
  }

  @override
  void dispose() {
    _subtitleSubscription?.cancel();
    _trackSubscription?.cancel();
    _nativeSubtitlePaintTimer?.cancel();
    super.dispose();
  }

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

  void _setHighlight(_SubtitleLookupSelection selection) {
    if (_highlightStart == selection.start && _highlightEnd == selection.end) {
      return;
    }
    setState(() {
      _highlightStart = selection.start;
      _highlightEnd = selection.end;
    });
  }

  void _setHighlightAtPosition({
    required BuildContext context,
    required Offset globalPosition,
    required String subtitleText,
    required TextStyle subtitleStyle,
    required TextScaler textScaler,
  }) {
    if (subtitleText.trim().isEmpty) return;
    final textBox =
        _subtitleTextKey.currentContext?.findRenderObject() as RenderBox?;
    if (textBox == null) return;
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
      return;
    }
    _setHighlight(selection);
  }

  Future<void> _showLookup(
    BuildContext context,
    TapUpDetails details,
    String subtitleText,
    TextStyle subtitleStyle,
    TextScaler textScaler,
  ) async {
    final builder = widget.miningContextBuilder;
    if (builder == null || subtitleText.trim().isEmpty) return;
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
            globalPosition: details.globalPosition,
            subtitleText: subtitleText,
            subtitleStyle: subtitleStyle,
            textScaler: textScaler,
          );
    if (selection.text.trim().isEmpty || !context.mounted) return;
    _setHighlight(selection);
    final anchor = textBox == null
        ? Rect.fromLTWH(
            details.globalPosition.dx,
            details.globalPosition.dy,
            1,
            1,
          )
        : textBox.localToGlobal(Offset.zero) & textBox.size;
    await DictionaryLookupPopup.show(
      context: context,
      anchor: anchor,
      text: selection.text,
      miningContext: builder(subtitleText),
    );
  }

  _SubtitleLookupSelection _lookupTextAtPosition({
    required BuildContext context,
    required RenderBox box,
    required Offset globalPosition,
    required String subtitleText,
    required TextStyle subtitleStyle,
    required TextScaler textScaler,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: subtitleText, style: subtitleStyle),
      textDirection: Directionality.of(context),
      textAlign: textAlign,
      textScaler: textScaler,
    )..layout(maxWidth: box.size.width);
    final position = painter
        .getPositionForOffset(box.globalToLocal(globalPosition))
        .offset
        .clamp(0, subtitleText.length)
        .toInt();
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
                    onHover: (event) => _setHighlightAtPosition(
                      context: context,
                      globalPosition: event.position,
                      subtitleText: subtitleText,
                      subtitleStyle: subtitleStyle,
                      textScaler: textScaler,
                    ),
                    onExit: (_) {
                      if (_highlightStart != -1 || _highlightEnd != -1) {
                        setState(_clearHighlight);
                      }
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapDown: (details) => _setHighlightAtPosition(
                        context: context,
                        globalPosition: details.globalPosition,
                        subtitleText: subtitleText,
                        subtitleStyle: subtitleStyle,
                        textScaler: textScaler,
                      ),
                      onTapUp: (details) => _showLookup(
                        context,
                        details,
                        subtitleText,
                        subtitleStyle,
                        textScaler,
                      ),
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
      TextSpan(
        text: text.substring(start, end),
        style: style.copyWith(
          backgroundColor: const Color(0x99ffd54f),
          color: Colors.white,
        ),
      ),
      if (end < text.length) TextSpan(text: text.substring(end)),
    ],
  );
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
