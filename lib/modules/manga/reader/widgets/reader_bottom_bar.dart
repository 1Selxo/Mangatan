import 'package:flutter/foundation.dart';

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/modules/manga/reader/widgets/crop_off_glyph.dart';
import 'package:mangayomi/modules/manga/reader/widgets/custom_value_indicator_shape.dart';
import 'package:mangayomi/modules/manga/reader/widgets/reader_mode_glyph.dart';
import 'package:mangayomi/modules/manga/reader/widgets/reader_mode_picker.dart';
import 'package:mangayomi/modules/more/settings/reader/reader_screen.dart';
import 'package:mangayomi/modules/reader_common/widgets/btn_chapter_list_dialog.dart';
import 'package:mangayomi/modules/reader_common/widgets/reader_app_bar.dart';
import 'package:mangayomi/providers/l10n_providers.dart';
import 'package:mangayomi/providers/reader_state_provider.dart';
import 'package:shiori/shiori.dart';

/// The manga reader's bottom panel: one floating card, within reach of a
/// thumb, with the page slider between the previous and next chapters, and
/// under it what is changed while reading (the chapter list, the reading
/// mode and direction, cropping, double pages, page previews, auto-scroll,
/// every setting).
///
/// Upstream's Shiori design, kept with Mangatan's separate reading
/// direction, the cover-offset double page and the page preview grid.
class ReaderBottomBar extends ConsumerWidget {
  /// The chapter being read
  final Chapter chapter;

  /// Whether the bar is visible
  final bool isVisible;

  /// Whether there is a previous chapter
  final bool hasPreviousChapter;

  /// Whether there is a next chapter
  final bool hasNextChapter;

  /// Callback when previous chapter button is pressed
  final VoidCallback? onPreviousChapter;

  /// Callback when next chapter button is pressed
  final VoidCallback? onNextChapter;

  /// Callback when slider value changes (for updating provider)
  final void Function(int value, WidgetRef ref) onSliderChanged;

  /// Callback when slider drag ends (for navigation)
  final void Function(int value) onSliderChangeEnd;

  /// Callback when reader mode is changed
  final void Function(ReaderMode mode, WidgetRef ref) onReaderModeChanged;

  /// Callback when reading direction is changed.
  final void Function(ReadingDirection direction, WidgetRef ref)
  onReadingDirectionChanged;

  /// Callback when page mode toggle button is pressed
  final VoidCallback? onPageModeToggle;

  /// Callback when settings button is pressed
  final VoidCallback onSettingsPressed;
  final VoidCallback? onPagePreviewsPressed;

  /// Provider for watching current reader mode
  final ProviderListenable<ReaderMode?> currentReaderModeProvider;

  /// Provider for watching the current reading direction.
  final ProviderListenable<ReadingDirection?> currentReadingDirectionProvider;

  /// Session-local current page index for the visible reader state.
  final ValueListenable<int> currentPageListenable;

  /// Current page mode (nullable for safety)
  final PageMode? currentPageMode;

  /// Whether RTL reading direction is active
  final bool isReverseHorizontal;

  /// Total number of pages in current chapter
  final int totalPages;

  /// Function to get current page index label
  final String Function(int currentIndex) currentIndexLabel;

  /// Background color getter
  final Color Function(BuildContext) backgroundColor;

  /// Whether auto-scroll is on, for the button's state; with
  /// [onAutoScrollPressed], the button shows in the vertical continuous
  /// modes, the ones auto-scroll runs in.
  final ValueListenable<bool>? autoScrollEnabled;

  /// Opens auto-scroll's switch and speed.
  final VoidCallback? onAutoScrollPressed;

  const ReaderBottomBar({
    super.key,
    required this.chapter,
    required this.isVisible,
    required this.hasPreviousChapter,
    required this.hasNextChapter,
    this.onPreviousChapter,
    this.onNextChapter,
    required this.onSliderChanged,
    required this.onSliderChangeEnd,
    required this.onReaderModeChanged,
    required this.onReadingDirectionChanged,
    this.onPageModeToggle,
    required this.onSettingsPressed,
    this.onPagePreviewsPressed,
    required this.currentReaderModeProvider,
    required this.currentReadingDirectionProvider,
    required this.currentPageListenable,
    required this.currentPageMode,
    required this.isReverseHorizontal,
    required this.totalPages,
    required this.currentIndexLabel,
    required this.backgroundColor,
    this.autoScrollEnabled,
    this.onAutoScrollPressed,
  });

  bool get _isDoublePageMode => currentPageMode?.isDoublePage ?? false;

  /// How far above the bottom edge the panel's top sits, plus a margin:
  /// where something shown over the panel (the page preview) starts.
  static double heightAbove(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = max(
      mediaQuery.viewPadding.bottom,
      mediaQuery.systemGestureInsets.bottom,
    );
    final row = context.shiori.density.rowHeight;
    return bottomInset + ShioriSpace.s8 + row * 2 + 1 + ShioriSpace.s8;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readerMode = ref.watch(currentReaderModeProvider);
    final readingDirection = ref.watch(currentReadingDirectionProvider);
    if (readerMode == null || readingDirection == null) {
      return const SizedBox.shrink();
    }
    final isHorizontalContinuous = readerMode.isHorizontalContinuous;
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = max(
      mediaQuery.viewPadding.bottom,
      mediaQuery.systemGestureInsets.bottom,
    );
    final duration = ShioriMotion.of(context, ShioriMotion.enter);
    final curve = isVisible ? ShioriMotion.enterCurve : ShioriMotion.exitCurve;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ReaderChromeGate(
        shown: isVisible,
        child: AnimatedSlide(
          offset: isVisible ? Offset.zero : const Offset(0, 1),
          duration: duration,
          curve: curve,
          child: AnimatedOpacity(
            opacity: isVisible ? 1 : 0,
            duration: duration,
            curve: curve,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                ShioriSpace.s8,
                0,
                ShioriSpace.s8,
                bottomInset + ShioriSpace.s8,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Material(
                    color: backgroundColor(context),
                    borderRadius: BorderRadius.circular(ShioriShape.sheet),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPageSlider(context, ref),
                        const Divider(height: 1),
                        _buildQuickActions(
                          context,
                          ref,
                          readerMode,
                          readingDirection,
                          isHorizontalContinuous,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The previous chapter, the page slider between the current page and the
  /// count, and the next chapter. Mirrored when reading right to left, the
  /// figures put back the right way round.
  Widget _buildPageSlider(BuildContext context, WidgetRef ref) {
    Widget unmirrored(Widget child) =>
        Transform.scale(scaleX: !isReverseHorizontal ? 1 : -1, child: child);
    return Transform.scale(
      scaleX: !isReverseHorizontal ? 1 : -1,
      child: SizedBox(
        height: context.shiori.density.rowHeight,
        child: Row(
          children: [
            IconButton(
              tooltip: context.l10n.previous_chapter,
              onPressed: hasPreviousChapter ? onPreviousChapter : null,
              icon: const Icon(Symbols.skip_previous_rounded, fill: 1),
            ),
            unmirrored(
              SizedBox(
                width: 44,
                child: Center(
                  child: ValueListenableBuilder<int>(
                    valueListenable: currentPageListenable,
                    builder: (context, currentIndex, child) => Text(
                      currentIndexLabel(currentIndex),
                      style: _pageLabelStyle(context),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: isVisible && totalPages > 0
                  ? _buildSlider(context, ref)
                  : const SizedBox.shrink(),
            ),
            unmirrored(
              SizedBox(
                width: 44,
                child: Center(
                  child: Text(
                    "$totalPages",
                    style: _pageLabelStyle(context)
                        .copyWith(color: context.shiori.color.fgMuted),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: context.l10n.next_chapter,
              onPressed: hasNextChapter ? onNextChapter : null,
              icon: const Icon(Symbols.skip_next_rounded, fill: 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<int>(
      valueListenable: currentPageListenable,
      builder: (context, currentIndex, child) {
        final maxValue = (totalPages - 1).toDouble();
        final divisions = totalPages <= 1 ? null : totalPages - 1;
        final currentValue = min(currentIndex.toDouble(), maxValue);

        return SliderTheme(
          data: SliderTheme.of(context).copyWith(
            valueIndicatorShape: CustomValueIndicatorShape(
              tranform: isReverseHorizontal,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 5.0),
          ),
          child: Slider(
            onChanged: (value) => onSliderChanged(value.toInt(), ref),
            onChangeEnd: (newValue) => onSliderChangeEnd(newValue.toInt()),
            divisions: divisions,
            value: currentValue,
            label: currentIndexLabel(currentIndex),
            min: 0,
            max: maxValue,
          ),
        );
      },
    );
  }

  /// Tabular, so the slider does not shift as the count changes width.
  TextStyle _pageLabelStyle(BuildContext context) => context.shiori.text.meta
      .copyWith(color: context.shiori.color.fg, fontWeight: FontWeight.w700);

  /// The reading mode and direction picker in a sheet. A mode tile picks
  /// and closes it; the direction can be flipped while it stays open.
  Future<void> _pickReaderMode(BuildContext context) {
    return showShioriSheet<void>(
      context,
      builder: (sheetContext) => Consumer(
        builder: (sheetContext, ref, _) {
          final mode = ref.watch(currentReaderModeProvider);
          final direction = ref.watch(currentReadingDirectionProvider);
          if (mode == null || direction == null) {
            return const SizedBox.shrink();
          }
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(
                top: ShioriSpace.s8,
                bottom: ShioriSpace.s16,
              ),
              child: ReaderModePicker(
                mode: mode,
                defaultMode: ref.watch(defaultReadingModeStateProvider),
                direction: direction,
                defaultDirection: ref.watch(
                  defaultReadingDirectionStateProvider,
                ),
                seriesName: chapter.manga.value?.name ?? '',
                onChanged: (value) {
                  onReaderModeChanged(value, ref);
                  Navigator.pop(sheetContext);
                },
                onDirectionChanged: (value) =>
                    onReadingDirectionChanged(value, ref),
                onSetDefault: () {
                  ref.read(defaultReadingModeStateProvider.notifier).set(mode);
                  ref
                      .read(defaultReadingDirectionStateProvider.notifier)
                      .set(direction);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  String _pageModeTooltip(BuildContext context) => switch (currentPageMode) {
    PageMode.doublePage => context.l10n.double_page,
    PageMode.doublePageCover => 'Double page with cover offset',
    _ => context.l10n.double_page,
  };

  Widget _buildQuickActions(
    BuildContext context,
    WidgetRef ref,
    ReaderMode readerMode,
    ReadingDirection readingDirection,
    bool isHorizontalContinuous,
  ) {
    final l10n = context.l10n;
    final accent = context.shiori.color.accentInk;
    final modeLabel = readerMode.isVertical
        ? getReaderModeName(readerMode, context)
        : '${getReaderModeName(readerMode, context)} · '
              '${getReadingDirectionName(readingDirection, context)}';
    return SizedBox(
      height: context.shiori.density.rowHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // The chapter list, down here within reach rather than in the
          // top bar.
          IconButton(
            tooltip: l10n.chapters,
            onPressed: () => showChapterListPanel(
              context,
              title: l10n.chapters,
              chapter: chapter,
            ),
            icon: const Icon(Symbols.format_list_numbered_rounded),
          ),

          // The reading mode, drawn turning the way it reads, opening the
          // mode and direction picker.
          IconButton(
            tooltip: '${l10n.reading_mode} · $modeLabel',
            onPressed: () => _pickReaderMode(context),
            icon: ReaderModeGlyph(
              readerModeGlyphFor(readerMode, readingDirection),
            ),
          ),

          // Crop borders: the crop struck through while it is off, and in
          // the accent while it is on.
          Consumer(
            builder: (context, ref, child) {
              final cropBorders = ref.watch(cropBordersStateProvider);
              return IconButton(
                tooltip: l10n.crop_borders,
                isSelected: cropBorders,
                onPressed: () {
                  ref.read(cropBordersStateProvider.notifier).set(!cropBorders);
                },
                icon: const CropOffGlyph(),
                selectedIcon: Icon(Symbols.crop_rounded, color: accent),
              );
            },
          ),

          // Single, double, then double with the cover alone.
          IconButton(
            tooltip: _pageModeTooltip(context),
            isSelected: _isDoublePageMode,
            onPressed: !isHorizontalContinuous ? onPageModeToggle : null,
            icon: const Icon(Symbols.book_rounded),
            selectedIcon: currentPageMode == PageMode.doublePageCover
                ? Badge(
                    label: const Text('1'),
                    backgroundColor: accent,
                    child: Icon(
                      Symbols.menu_book_rounded,
                      fill: 1,
                      color: accent,
                    ),
                  )
                : Icon(Symbols.menu_book_rounded, fill: 1, color: accent),
          ),

          if (onPagePreviewsPressed != null)
            IconButton(
              tooltip: 'Page previews',
              onPressed: onPagePreviewsPressed,
              icon: const Icon(Symbols.grid_view_rounded),
            ),

          // Auto-scroll, where it runs: lit while it is on.
          if (readerMode.isVerticalContinuous && onAutoScrollPressed != null)
            ValueListenableBuilder<bool>(
              valueListenable: autoScrollEnabled ?? ValueNotifier(false),
              builder: (context, enabled, _) => IconButton(
                tooltip: l10n.auto_scroll,
                isSelected: enabled,
                onPressed: onAutoScrollPressed,
                icon: const Icon(Symbols.timer_rounded),
                selectedIcon: Icon(
                  Symbols.timer_rounded,
                  fill: 1,
                  color: accent,
                ),
              ),
            ),

          IconButton(
            tooltip: l10n.settings,
            onPressed: onSettingsPressed,
            icon: const Icon(Symbols.settings_rounded),
          ),
        ],
      ),
    );
  }
}
