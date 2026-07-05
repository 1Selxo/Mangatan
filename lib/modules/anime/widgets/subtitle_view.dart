/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
// ignore_for_file: dangling_library_doc_comments, doc_directive_missing_closing_tag, deprecated_member_use

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mangayomi/modules/anime/providers/state_provider.dart';
import 'package:mangayomi/modules/mining/widgets/mining_lookup_sheet.dart';
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

  @override
  Widget build(BuildContext context) {
    subtitle = widget.controller.player.state.subtitle;
    style = widget.configuration.style;
    textAlign = widget.configuration.textAlign;
    padding = widget.configuration.padding;
    return LayoutBuilder(
      builder: (context, constraints) {
        final nr = (constraints.maxWidth * constraints.maxHeight);
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
        final subtitleStyle = widget.paintSubtitle
            ? style
            : style.copyWith(
                color: Colors.transparent,
                backgroundColor: Colors.transparent,
                shadows: const [],
              );
        final text = Text(
          subtitleText,
          style: subtitleStyle,
          textAlign: textAlign,
          textScaler: textScaler,
        );
        return Material(
          color: Colors.transparent,
          child: AnimatedContainer(
            padding: padding,
            duration: duration,
            alignment: Alignment.bottomCenter,
            child:
                subtitleText.trim().isEmpty ||
                    widget.miningContextBuilder == null
                ? text
                : GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onLongPress: () {
                      MiningLookupSheet.show(
                        context: context,
                        text: subtitleText,
                        miningContext: widget.miningContextBuilder!(
                          subtitleText,
                        ),
                      );
                    },
                    child: text,
                  ),
          ),
        );
      },
    );
  }
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
      Shadow(
        offset: const Offset(-1.5, -1.5),
        color: borderColor,
        blurRadius: 1.4,
      ),
      Shadow(
        offset: const Offset(1.5, -1.5),
        color: borderColor,
        blurRadius: 1.4,
      ),
      Shadow(
        offset: const Offset(1.5, 1.5),
        color: borderColor,
        blurRadius: 1.4,
      ),
      Shadow(
        offset: const Offset(-1.5, 1.5),
        color: borderColor,
        blurRadius: 1.4,
      ),
    ],
    backgroundColor: Color.fromARGB(
      subSets.backgroundColorA!,
      subSets.backgroundColorR!,
      subSets.backgroundColorG!,
      subSets.backgroundColorB!,
    ),
  );
}
