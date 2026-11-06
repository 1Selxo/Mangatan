import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../alphas.dart';
import '../tokens.dart';
import 'badge.dart';
import 'skeleton.dart';

/// A series' cover, at 2:3, with what a reader needs to see on it: unread
/// count, whether it is on the device, how far they are.
///
/// Focus draws an accent ring and lifts the cover, but only for keyboard or
/// remote input (or always on a TV), never for touch.
class ShioriCover extends StatefulWidget {
  const ShioriCover({
    super.key,
    required this.image,
    required this.title,
    this.unread = 0,
    this.downloaded = false,
    this.progress = 0,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.autofocus = false,
    this.onFocusChange,
  });

  /// Null while there is no image yet, or when the source has none.
  final ImageProvider? image;

  /// The series' title: read by screen readers, and drawn on the
  /// placeholder when there is no image.
  final String title;
  final int unread;
  final bool downloaded;

  /// Reading or watching progress, 0 to 1. Nothing is drawn at 0.
  final double progress;

  /// Part of a multi-selection.
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final bool autofocus;
  final ValueChanged<bool>? onFocusChange;

  @override
  State<ShioriCover> createState() => _ShioriCoverState();
}

class _ShioriCoverState extends State<ShioriCover> {
  bool _focused = false;

  void _onFocusChange(bool hasFocus, bool isTv) {
    widget.onFocusChange?.call(hasFocus);
    final show =
        hasFocus &&
        (isTv ||
            FocusManager.instance.highlightMode ==
                FocusHighlightMode.traditional);
    if (mounted && show != _focused) setState(() => _focused = show);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.shiori;
    final c = tokens.color;
    final isTv = tokens.density == ShioriDensity.tv;
    final radius = BorderRadius.circular(ShioriShape.cover);

    final image = widget.image == null
        ? _Placeholder(title: widget.title)
        : Image(
            image: widget.image!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, sync) =>
                sync || frame != null ? child : const ShioriSkeleton.cover(),
            errorBuilder: (context, _, _) => _Placeholder(title: widget.title),
          );

    final card = AspectRatio(
      aspectRatio: coverAspect,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: c.ink2, child: image),
            if (widget.selected)
              ColoredBox(
                color: c.accent.withValues(alpha: Alphas.secondary),
                child: Center(
                  child: Icon(
                    Symbols.check_circle_rounded,
                    fill: 1,
                    color: c.onAccent,
                    size: tokens.scaled(32),
                  ),
                ),
              ),
            if (widget.unread > 0)
              Positioned(
                top: ShioriSpace.s4,
                left: ShioriSpace.s4,
                child: ShioriBadge(widget.unread),
              ),
            if (widget.downloaded)
              Positioned(
                top: ShioriSpace.s4,
                right: ShioriSpace.s4,
                child: _DownloadedMark(color: c),
              ),
            if (widget.progress > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ProgressBar(value: widget.progress, color: c.accent),
              ),
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  autofocus: widget.autofocus,
                  onTap: widget.onTap,
                  onLongPress: widget.onLongPress,
                  onSecondaryTap: widget.onSecondaryTap,
                  onFocusChange: (f) => _onFocusChange(f, isTv),
                  focusColor: Colors.transparent,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      label: widget.title,
      button: widget.onTap != null,
      selected: widget.selected,
      child: AnimatedScale(
        scale: _focused ? 1.06 : 1,
        duration: ShioriMotion.of(context, ShioriMotion.fast),
        curve: ShioriMotion.standardCurve,
        child: AnimatedContainer(
          duration: ShioriMotion.of(context, ShioriMotion.fast),
          curve: ShioriMotion.standardCurve,
          // Outside the clip, so the ring is not cut off; the radius grows by
          // the ring's width so the corners stay concentric.
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ShioriShape.cover + 3),
            border: Border.all(
              color: _focused ? c.accent : Colors.transparent,
              width: 3,
              strokeAlign: BorderSide.strokeAlignOutside,
            ),
          ),
          child: card,
        ),
      ),
    );
  }
}

/// A cover with its title, and an optional line under it, as it sits in a
/// grid.
class ShioriCoverTile extends StatelessWidget {
  const ShioriCoverTile({super.key, required this.cover, this.subtitle});

  final ShioriCover cover;

  /// A muted line under the title: the source, the last chapter read.
  final String? subtitle;

  static const int _titleLines = 2;

  /// The style a caption line is drawn in, merged into the ambient one as
  /// [Text] does, so the strut uses the theme's font family.
  static TextStyle _resolve(BuildContext context, TextStyle style) =>
      DefaultTextStyle.of(context).style.merge(style);

  /// Pins every line to the primary font's metrics. Without it a line of
  /// CJK or emoji takes the taller metrics of a fallback font, and a tile
  /// sized from a Latin measure overflows by a pixel or two.
  static StrutStyle _strut(TextStyle resolved) =>
      StrutStyle.fromTextStyle(resolved, forceStrutHeight: true);

  static double _linesHeight(BuildContext context, TextStyle style, int n) {
    final resolved = _resolve(context, style);
    final painter = TextPainter(
      text: TextSpan(text: List.filled(n, 'Hg').join('\n'), style: resolved),
      strutStyle: _strut(resolved),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }

  /// The height a tile [width] wide takes at most, in the current theme and
  /// text size, for rows that must give their tiles a fixed extent.
  static double maxHeight(
    BuildContext context, {
    required double width,
    bool withSubtitle = true,
  }) {
    final text = context.shiori.text;
    return width / coverAspect +
        ShioriSpace.s4 +
        _linesHeight(context, text.card, _titleLines) +
        (withSubtitle ? _linesHeight(context, text.meta, 1) : 0);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.shiori;
    final titleStyle = _resolve(
      context,
      tokens.text.card.copyWith(color: tokens.color.fg),
    );
    final subtitleStyle = _resolve(
      context,
      tokens.text.meta.copyWith(color: tokens.color.fgMuted),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        cover,
        const SizedBox(height: ShioriSpace.s4),
        ExcludeSemantics(
          child: Text(
            cover.title,
            maxLines: _titleLines,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
            strutStyle: _strut(titleStyle),
          ),
        ),
        if (subtitle != null)
          ExcludeSemantics(
            child: Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: subtitleStyle,
              strutStyle: _strut(subtitleStyle),
            ),
          ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = context.shiori;
    return Padding(
      padding: const EdgeInsets.all(ShioriSpace.s8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Symbols.image_rounded,
            color: tokens.color.fgMuted,
            size: tokens.scaled(24),
          ),
          const SizedBox(height: ShioriSpace.s8),
          Text(
            title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: tokens.text.meta.copyWith(color: tokens.color.fgMuted),
          ),
        ],
      ),
    );
  }
}

class _DownloadedMark extends StatelessWidget {
  const _DownloadedMark({required this.color});

  final ShioriColors color;

  @override
  Widget build(BuildContext context) {
    final size = context.shiori.scaled(18);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.downloaded.background,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Symbols.download_done_rounded,
        size: size * 0.7,
        color: color.downloaded.foreground,
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: ShioriScrim.onImage),
          FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: value.clamp(0.0, 1.0),
            child: ColoredBox(color: color),
          ),
        ],
      ),
    );
  }
}
