import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/modules/manga/reader/widgets/reader_mode_glyph.dart';
import 'package:mangayomi/modules/more/settings/reader/reader_screen.dart';
import 'package:mangayomi/providers/l10n_providers.dart';
import 'package:shiori/shiori.dart';

/// The glyph to draw for [mode] read in [direction]: the horizontal modes
/// turn the other way when reading right to left.
ReaderMode readerModeGlyphFor(ReaderMode mode, ReadingDirection direction) {
  if (!direction.isRtl) return mode.normalized;
  return switch (mode.normalized) {
    ReaderMode.horizontalPaged => ReaderMode.legacyHorizontalPagedRtl,
    ReaderMode.horizontalContinuous => ReaderMode.legacyHorizontalContinuousRtl,
    final other => other,
  };
}

/// Reading modes as tiles that show their direction, for one series, with
/// the reading direction under them, and the way to make the choice
/// everyone's default, or to go back to it.
///
/// Upstream merges mode and direction into one value; Mangatan keeps them
/// apart (the series remembers each), so the direction is its own control.
class ReaderModePicker extends StatelessWidget {
  const ReaderModePicker({
    super.key,
    required this.mode,
    required this.defaultMode,
    required this.direction,
    required this.defaultDirection,
    required this.seriesName,
    required this.onChanged,
    required this.onDirectionChanged,
    required this.onSetDefault,
  });

  /// The mode this series reads in.
  final ReaderMode mode;
  final ReaderMode defaultMode;
  final ReadingDirection direction;
  final ReadingDirection defaultDirection;
  final String seriesName;
  final ValueChanged<ReaderMode> onChanged;
  final ValueChanged<ReadingDirection> onDirectionChanged;

  /// Makes [mode] and [direction] the default for every series without
  /// its own.
  final VoidCallback onSetDefault;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.shiori;
    final c = tokens.color;
    final current = mode.normalized;
    final differs =
        current != defaultMode.normalized || direction != defaultDirection;
    final defaultLabel = defaultMode.isVertical
        ? getReaderModeName(defaultMode, context)
        : '${getReaderModeName(defaultMode, context)} · '
              '${getReadingDirectionName(defaultDirection, context)}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ShioriSpace.s16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: ShioriSpace.s8,
        children: [
          Text(
            l10n.reading_mode_for(seriesName),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.text.section.copyWith(color: c.fg),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = ShioriSpace.s8;
              final columns = math.max(
                3,
                ((constraints.maxWidth + gap) / (tokens.scaled(112) + gap))
                    .floor(),
              );
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final m in ReaderModeExtension.selectableValues)
                    _ModeTile(
                      mode: m,
                      glyph: readerModeGlyphFor(m, direction),
                      width: width,
                      selected: m == current,
                      onTap: () => onChanged(m),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: ShioriSpace.s4),
          Text(
            l10n.reading_direction,
            style: tokens.caption.copyWith(color: c.fgMuted),
          ),
          ShioriSegmentedControl<ReadingDirection>(
            segments: [
              for (final d in ReadingDirection.values)
                ShioriSegment(
                  value: d,
                  label: getReadingDirectionName(d, context),
                  icon: d.isRtl
                      ? Icons.format_textdirection_r_to_l
                      : Icons.format_textdirection_l_to_r,
                ),
            ],
            selected: direction,
            onSelected: onDirectionChanged,
          ),
          const SizedBox(height: ShioriSpace.s4),
          if (differs)
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.default_is(defaultLabel),
                    style: tokens.caption,
                  ),
                ),
                ShioriButton.quiet(
                  label: l10n.use_default,
                  icon: Symbols.restart_alt_rounded,
                  onPressed: () {
                    if (current != defaultMode.normalized) {
                      onChanged(defaultMode.normalized);
                    }
                    if (direction != defaultDirection) {
                      onDirectionChanged(defaultDirection);
                    }
                  },
                ),
              ],
            ),
          if (differs)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ShioriButton.secondary(
                label: l10n.set_as_default,
                icon: Symbols.star_rounded,
                onPressed: onSetDefault,
              ),
            )
          else
            Text(
              l10n.is_the_default,
              style: tokens.caption.copyWith(color: c.fgMuted),
            ),
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.mode,
    required this.glyph,
    required this.width,
    required this.selected,
    required this.onTap,
  });

  final ReaderMode mode;
  final ReaderMode glyph;
  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.shiori;
    final c = tokens.color;
    final fg = selected ? c.accentInk : c.fgMuted;
    final label = tokens.text.meta.copyWith(
      color: fg,
      fontWeight: selected ? FontWeight.w700 : null,
    );
    final labelHeight =
        2 *
        (label.fontSize ?? 12) *
        (label.height ?? 1.3) *
        MediaQuery.textScalerOf(context).scale(1);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected
            ? c.accent.withValues(alpha: Alphas.accentTint)
            : c.ink2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShioriShape.card),
          side: BorderSide(
            color: selected ? c.accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: width,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ShioriSpace.s4,
                vertical: ShioriSpace.s12,
              ),
              child: Column(
                spacing: ShioriSpace.s4,
                children: [
                  ReaderModeGlyph(
                    glyph,
                    size: tokens.scaled(28),
                    color: fg,
                    filled: selected,
                  ),
                  SizedBox(
                    height: labelHeight,
                    child: Center(
                      child: Text(
                        getReaderModeName(mode, context),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: label,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
