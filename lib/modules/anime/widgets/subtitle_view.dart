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

  StreamSubscription<List<String>>? subscription;

  static const kTextScaleFactorReferenceWidth = 1920.0;
  static const kTextScaleFactorReferenceHeight = 1080.0;

  @override
  void initState() {
    super.initState();
    subscription = widget.controller.player.stream.subtitle.listen((value) {
      setState(() {
        subtitle = value;
      });
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
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
    final lookupText = textBox == null
        ? subtitleText.trim()
        : _lookupTextAtPosition(
            context: context,
            box: textBox,
            globalPosition: details.globalPosition,
            subtitleText: subtitleText,
            subtitleStyle: subtitleStyle,
            textScaler: textScaler,
          );
    if (lookupText.trim().isEmpty || !context.mounted) return;
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
      text: lookupText,
      miningContext: builder(subtitleText),
    );
  }

  String _lookupTextAtPosition({
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
    return _extractSubtitleLookupString(subtitleText, position);
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
                : GestureDetector(
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
        );
      },
    );
  }
}

String _extractSubtitleLookupString(String text, int offset) {
  if (text.isEmpty) return '';
  var start = offset.clamp(0, text.length - 1).toInt();
  while (start < text.length && _isLookupBoundary(text[start])) {
    start++;
  }
  if (start >= text.length) return '';
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
  return text.substring(start, end).trim();
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
  });

  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final TextScaler textScaler;
  final Color outlineColor;

  @override
  Widget build(BuildContext context) {
    final fillColor = style.color ?? Colors.white;
    final outlineVisible = fillColor.a > 0 && outlineColor.a > 0;
    return Stack(
      alignment: Alignment.center,
      children: [
        if (outlineVisible)
          Text(
            text,
            style: _subtitleOutlineStyle(style, outlineColor),
            textAlign: textAlign,
            textScaler: textScaler,
          ),
        Text(text, style: style, textAlign: textAlign, textScaler: textScaler),
      ],
    );
  }
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
      ..strokeWidth = 4.2
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
