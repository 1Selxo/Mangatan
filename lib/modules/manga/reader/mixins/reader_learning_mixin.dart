import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/modules/manga/reader/mixins/reader_double_page_mixin.dart';
import 'package:mangayomi/modules/manga/reader/mixins/reader_memory_management.dart';
import 'package:mangayomi/modules/manga/reader/mixins/reader_zoom_control.dart';
import 'package:mangayomi/modules/manga/reader/reader_eink_state.dart';
import 'package:mangayomi/modules/manga/reader/services/page_navigation_service.dart';
import 'package:mangayomi/modules/manga/reader/u_chap_data_preload.dart';
import 'package:mangayomi/modules/manga/reader/widgets/reader_page_previews.dart';
import 'package:mangayomi/modules/mining/widgets/reader_ocr_overlay.dart';
import 'package:mangayomi/modules/more/statistics/widgets/manga_stats_sheet.dart';
import 'package:mangayomi/modules/reader_common/widgets/reader_app_bar.dart';
import 'package:mangayomi/providers/incognito_mode_state_provider.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';
import 'package:mangayomi/services/reader/panel_detection_service.dart';
import 'package:mangayomi/services/statistics/manga_statistics_tracker.dart';
import 'package:mangayomi/utils/extensions/others.dart';
import 'package:mangayomi/utils/log/logger.dart';
import 'package:photo_view/photo_view.dart';
import 'package:shiori/shiori.dart';

export 'package:mangayomi/modules/mining/widgets/reader_ocr_overlay.dart'
    show ReaderOcrState;

/// Mangatan's language-learning parts of the manga reader, kept out of
/// upstream's reader view: reading the chapter's text ahead (OCR), immersion
/// statistics, E-Ink mode, the page preview grid and panel by panel
/// navigation.
mixin ReaderLearningMixin<T extends ConsumerStatefulWidget>
    on
        ConsumerState<T>,
        ReaderMemoryManagement,
        ReaderDoublePageMixin<T>,
        ReaderZoomControl<T>,
        PageNavigationMixin<T> {
  @override
  void initState() {
    super.initState();
    ReaderEInkState.enabled.addListener(_eInkChanged);
    unawaited(ReaderEInkState.initialize());
    unawaited(_refreshPanelNavigation());
    _statsIncognito = ref.read(incognitoModeStateProvider);
  }

  @override
  void dispose() {
    ReaderEInkState.enabled.removeListener(_eInkChanged);
    ReaderOcrState.cancelScan();
    // Attribute the page still on screen before the OCR cache goes away.
    unawaited(
      _statsTracker.flush(
        charactersForPage: _charactersForPageIndex,
        incognito: _statsIncognito,
      ),
    );
    _statsSheetRevision.dispose();
    _spreadZoom?.dispose();
    super.dispose();
  }

  /// The reader moved to the page at [actualIndex] in [pages]: reads the
  /// chapter's text from there and counts the page left in the statistics.
  void onLearningPageShown(int actualIndex) {
    scanChapterOcr(actualIndex);
    unawaited(_trackStatsForPage(actualIndex));
  }

  // ── OCR ────────────────────────────────────────────────────────────────

  /// Reads the text of the chapter's pages, starting with the page at
  /// [actualIndex] in [pages]. Asked again for the same chapter it carries
  /// on with the reading already going.
  void scanChapterOcr(int actualIndex) {
    if (!mounted || pages.isEmpty) return;
    final startPage = pages[actualIndex.clamp(0, pages.length - 1)];
    final chapter = startPage.chapter;
    if (chapter == null) return;
    final chapterPages = pages
        .where((page) => page.chapter?.id == chapter.id)
        .toList();
    if (chapterPages.isEmpty) return;
    var startIndex = chapterPages.indexWhere(
      (page) =>
          identical(page, startPage) ||
          (page.pageIndex != null && page.pageIndex == startPage.pageIndex),
    );
    if (startIndex < 0) startIndex = 0;
    unawaited(
      ReaderOcrState.scanChapter(
        chapterPages,
        startIndex: startIndex,
        preparePage: (page) async {
          if (!mounted) return;
          await precacheImage(page.getImageProvider(ref, true), context);
        },
      ),
    );
  }

  /// How far the chapter's text has been read, under the app bar while it
  /// shows.
  Widget ocrProgressHud({
    required bool uiVisible,
    required bool fullScreen,
  }) => ReaderOcrProgressHud(
    top: uiVisible
        ? ReaderAppBar.visibleHeight(context, fullScreenReader: fullScreen) + 12
        : 12.0,
  );

  // ── Immersion statistics ───────────────────────────────────────────────

  /// Chimahon-compatible immersion statistics for this reading session.
  late final MangaStatisticsTracker _statsTracker = MangaStatisticsTracker(
    mangaId: _mangaId,
  );

  /// Rebuilds the statistics sheet while it is open.
  final ValueNotifier<int> _statsSheetRevision = ValueNotifier(0);

  int get _mangaId {
    for (final page in pages) {
      final id = page.chapter?.manga.value?.id;
      if (id != null) return id;
    }
    return 0;
  }

  /// Whether incognito mode is on, read while the reader is mounted: the
  /// last page is counted while it is disposed, when ref cannot be read.
  bool _statsIncognito = false;

  /// Records the page just left into the statistics.
  Future<void> _trackStatsForPage(int actualIndex) async {
    _statsIncognito = ref.read(incognitoModeStateProvider);
    await _statsTracker.onPageChanged(
      pageIndex: actualIndex,
      charactersForPage: _charactersForPageIndex,
      incognito: _statsIncognito,
    );
    if (mounted) _statsSheetRevision.value++;
  }

  /// The OCR character count of a page, or zero if it has not been read.
  Future<int> _charactersForPageIndex(int actualIndex) async {
    if (actualIndex < 0 || actualIndex >= pages.length) return 0;
    return ReaderOcrState.cachedCharacterCount(pages[actualIndex]);
  }

  /// Opens the immersion statistics sheet for this manga.
  Future<void> showStatsSheet() async {
    final estimate = await _statsEstimate();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ValueListenableBuilder<int>(
        valueListenable: _statsSheetRevision,
        builder: (context, _, _) => MangaStatsSheet(
          mangaId: _mangaId,
          session: _statsTracker.session,
          estimate: estimate,
          onToggleTracking: () {
            _statsTracker.toggleTracking();
            _statsSheetRevision.value++;
          },
        ),
      ),
    );
  }

  /// Projects the time to finish from the session's reading speed.
  ///
  /// The characters left are estimated from the pages already read by OCR,
  /// as the pages ahead have not been read yet.
  Future<MangaStatsEstimate> _statsEstimate() async {
    final speed = _statsTracker.session.charactersPerHour;
    if (speed <= 0 || pages.isEmpty) return const MangaStatsEstimate();
    final actualIndex = getCurrentPagesActualIndex().clamp(0, pages.length - 1);
    final chapterId = pages[actualIndex].chapter?.id;
    final chapterPages = pages
        .where((page) => page.chapter?.id == chapterId)
        .toList();
    var recognizedPages = 0;
    var recognizedCharacters = 0;
    for (final page in chapterPages) {
      final characters = await ReaderOcrState.cachedCharacterCount(page);
      if (characters > 0) {
        recognizedPages++;
        recognizedCharacters += characters;
      }
    }
    // With nothing read there is no basis for a per-page estimate.
    if (recognizedPages == 0) return const MangaStatsEstimate();
    final averagePerPage = recognizedCharacters / recognizedPages;
    var pageInChapter = 0;
    for (var i = 0; i < actualIndex; i++) {
      if (pages[i].chapter?.id == chapterId) pageInChapter++;
    }
    final chapterRemainingPages = (chapterPages.length - pageInChapter - 1)
        .clamp(0, chapterPages.length);
    final bookRemainingPages = (pages.length - actualIndex - 1).clamp(
      0,
      pages.length,
    );
    final chapterCharacters = (averagePerPage * chapterRemainingPages).round();
    final bookCharacters = (averagePerPage * bookRemainingPages).round();
    return MangaStatsEstimate(
      remainingChapterCharacters: chapterCharacters,
      remainingBookCharacters: bookCharacters,
      remainingChapterSeconds: MangaStatsEstimate.secondsRemaining(
        chapterCharacters,
        speed,
      ),
      remainingBookSeconds: MangaStatsEstimate.secondsRemaining(
        bookCharacters,
        speed,
      ),
    );
  }

  // ── E-Ink mode ─────────────────────────────────────────────────────────

  void _eInkChanged() {
    if (mounted) setState(() {});
  }

  /// [configured], or white in E-Ink mode.
  BackgroundColor eInkBackground(BackgroundColor configured) =>
      ReaderEInkState.enabled.value ? BackgroundColor.white : configured;

  /// The reader's bars in [normal], or white in E-Ink mode.
  Color eInkBarColor(Color normal) =>
      // shiori: E-Ink mode's plain white surface, not a theme colour
      ReaderEInkState.enabled.value ? Colors.white : normal;

  // ── Page previews ──────────────────────────────────────────────────────

  /// The grid of the chapter's pages, to jump to one.
  Future<void> showPagePreviews() async {
    if (pages.isEmpty) return;
    final current = getCurrentPagesActualIndex().clamp(0, pages.length - 1);
    final chapterId = pages[current].chapter?.id;
    final chapterPages = pages
        .where(
          (page) => page.chapter?.id == chapterId && !page.isTransitionPage,
        )
        .toList(growable: false);
    if (chapterPages.isEmpty) return;
    await showReaderPagePreviews(
      context: context,
      pages: chapterPages,
      onSelected: (page) {
        final readerMode = activeReaderMode;
        final actualIndex = pages.indexOf(page);
        if (readerMode == null || actualIndex < 0) return;
        navigationService.jumpToPage(
          index: isDoublePageActive
              ? actualToPageViewIndex(actualIndex)
              : actualIndex,
          readerMode: readerMode,
        );
      },
    );
  }

  // ── Panel navigation ───────────────────────────────────────────────────

  bool _panelNavigationEnabled = false;

  /// The pages shown when their panels were found, the panels in reading
  /// order, and the one focused (-1 for none). A single page's panels are
  /// fractions of its whole image; a spread's, of the row of pages.
  List<UChapDataPreload>? _panelPages;
  Future<List<Rect>>? _panels;
  int _panelIndex = -1;

  /// Whether the page shown was reached going forward: its panels then
  /// start before the first, and going back turns back to the page left;
  /// reached going back, they start after the last.
  bool _enteredForward = true;

  /// The zoom moving a spread onto a panel.
  AnimationController? _spreadZoom;

  bool get panelNavigationActive =>
      _panelNavigationEnabled && !(activeReaderMode?.isContinuous ?? true);

  Future<void> _refreshPanelNavigation() async {
    _panelNavigationEnabled =
        await MiningPreferences.getPanelNavigationEnabled();
  }

  /// Focuses the next or previous panel of the page shown, with panel by
  /// panel navigation on. Returns false when the page should turn instead:
  /// past its last panel, or with the setting off.
  Future<bool> navigatePanel({required bool forward}) async {
    // Kept current for the next turn, so a page turn does not wait for it.
    unawaited(_refreshPanelNavigation());
    final viewIndex = currentDoublePageViewIndex;
    final readerMode = activeReaderMode;
    if (!_panelNavigationEnabled ||
        viewIndex == null ||
        readerMode == null ||
        readerMode.isContinuous) {
      return false;
    }
    final spread = isDoublePageActive;
    final shown = _pagesShown(viewIndex);
    if (shown.isEmpty || shown.any((page) => page.isTransitionPage)) {
      return false;
    }
    final previous = _panelPages;
    final samePages =
        previous != null &&
        previous.length == shown.length &&
        [
          for (var i = 0; i < shown.length; i++)
            identical(previous[i], shown[i]),
        ].every((same) => same);
    final List<Rect> panels;
    try {
      if (!samePages) {
        _panelPages = shown;
        _panels = _detectPanels(
          shown,
          rightToLeft: readerMode.isRTL,
        ).timeout(const Duration(seconds: 30));
        panels = await _panels!;
        _panelIndex = _enteredForward ? -1 : panels.length;
      } else {
        panels = await _panels!;
      }
    } catch (error) {
      _panels = null;
      _panelPages = null;
      _logPanels('detection failed on ${_describePages(shown)}: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Panel detection failed: $error')),
        );
      }
      return false;
    }
    if (!mounted) return false;
    final target = _panelIndex + (forward ? 1 : -1);
    if (panels.isEmpty || target < 0 || target >= panels.length) {
      _logPanels(
        '${panels.length} panels on ${_describePages(shown)}, '
        'turning the page ${forward ? 'forward' : 'back'}',
      );
      _resetPanelZoom(viewIndex, spread: spread);
      _enteredForward = forward;
      return false;
    }
    _panelIndex = target;
    final focused = spread
        ? _focusSpreadPanel(viewIndex, panels[target])
        : _focusPagePanel(viewIndex, panels[target]);
    _logPanels(
      'panel ${target + 1} of ${panels.length} on '
      '${_describePages(shown)} (${spread ? 'spread' : 'page'}) '
      '${focused ? 'focused' : 'could not be focused'}: '
      '${_describeRect(panels[target])}',
    );
    if (!focused) _enteredForward = forward;
    return focused;
  }

  String _describePages(List<UChapDataPreload> shown) =>
      'page ${shown.map((page) => page.index).join('+')}';

  /// Release builds print a [Rect] as its type only.
  String _describeRect(Rect rect) => [
    rect.left,
    rect.top,
    rect.right,
    rect.bottom,
  ].map((value) => value.toStringAsFixed(2)).join(', ');

  void _logPanels(String message) =>
      AppLogger.log('Panel navigation: $message', logLevel: LogLevel.debug);

  /// The pages of the page view's item at [viewIndex], left to right.
  List<UChapDataPreload> _pagesShown(int viewIndex) {
    if (!isDoublePageActive) {
      final actual = pageViewToActualIndex(viewIndex);
      return actual >= 0 && actual < pages.length ? [pages[actual]] : const [];
    }
    final first = pageViewToActualIndex(viewIndex);
    final shown = <UChapDataPreload>[];
    for (var i = first; i < pages.length && shown.length < 2; i++) {
      if (actualToPageViewIndex(i) != viewIndex) break;
      shown.add(pages[i]);
    }
    return activeReaderMode?.isRTL ?? false ? shown.reversed.toList() : shown;
  }

  /// The panels of [shown], the pages left to right, in reading order.
  /// Panels outside the part of a page shown (the other half of a split
  /// page) are left out.
  Future<List<Rect>> _detectPanels(
    List<UChapDataPreload> shown, {
    required bool rightToLeft,
  }) async {
    final readingOrder = rightToLeft ? shown.reversed.toList() : shown;
    final panels = <Rect>[];
    for (final page in readingOrder) {
      final slot = shown.indexOf(page);
      final bytes = await page.getImageBytes;
      if (bytes == null) continue;
      final detections = await PanelDetectionService.instance.detect(bytes);
      // Row by row from the top, each row in reading order; the detector
      // gives them in no particular order.
      detections.sort((a, b) {
        final rowDelta = a.rect.top - b.rect.top;
        if (rowDelta.abs() > .08) return rowDelta.sign.toInt();
        return rightToLeft
            ? b.rect.right.compareTo(a.rect.right)
            : a.rect.left.compareTo(b.rect.left);
      });
      final part = await _partShown(page, bytes);
      for (final detection in detections) {
        final rect = detection.rect;
        if (!part.contains(rect.center)) continue;
        if (shown.length == 1) {
          panels.add(rect);
          continue;
        }
        // Within the part shown, then within the row of pages.
        final inPart = Rect.fromLTRB(
          (rect.left - part.left) / part.width,
          (rect.top - part.top) / part.height,
          (rect.right - part.left) / part.width,
          (rect.bottom - part.top) / part.height,
        );
        panels.add(
          Rect.fromLTRB(
            (slot + inPart.left) / shown.length,
            inPart.top,
            (slot + inPart.right) / shown.length,
            inPart.bottom,
          ),
        );
      }
    }
    return panels;
  }

  /// The part of [page]'s whole image it shows, as fractions of it: all of
  /// it, or one half of a split page.
  Future<Rect> _partShown(UChapDataPreload page, Uint8List bytes) async {
    final region = page.srcRect;
    if (region == null) return const Rect.fromLTRB(0, 0, 1, 1);
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final size = Size(
      descriptor.width.toDouble(),
      descriptor.height.toDouble(),
    );
    descriptor.dispose();
    buffer.dispose();
    if (size.isEmpty) return const Rect.fromLTRB(0, 0, 1, 1);
    return Rect.fromLTRB(
      region.left / size.width,
      region.top / size.height,
      region.right / size.width,
      region.bottom / size.height,
    );
  }

  /// Zooms the single page at [viewIndex] onto [panel], a fraction of its
  /// whole image.
  bool _focusPagePanel(int viewIndex, Rect panel) {
    final controller = pageControllers[pageViewToActualIndex(viewIndex)];
    final whole = controller?.wholeImageRect;
    if (controller == null || !controller.isReady || whole == null) {
      return false;
    }
    // The whole image lies at [whole] in the view's source coordinates,
    // which start at the part shown.
    final source = Rect.fromLTRB(
      whole.left + panel.left * whole.width,
      whole.top + panel.top * whole.height,
      whole.left + panel.right * whole.width,
      whole.top + panel.bottom * whole.height,
    );
    final view = controller.viewSize;
    if (view.isEmpty || source.isEmpty) return false;
    final scale = math
        .min(view.width * .95 / source.width, view.height * .95 / source.height)
        .clamp(controller.minScale, controller.minScale * 8)
        .toDouble();
    controller.animateScaleAndCenter(scale, source.center);
    return true;
  }

  /// Zooms the spread at [viewIndex] onto [panel], a fraction of the row of
  /// pages.
  bool _focusSpreadPanel(int viewIndex, Rect panel) {
    final controller = doublePageControllers[viewIndex];
    final shown = _panelPages;
    if (controller == null || shown == null || shown.isEmpty) return false;
    final viewport = MediaQuery.sizeOf(context);
    // The pages side by side, as high as the screen unless that makes them
    // wider than it, centred: the row the panel is a fraction of.
    final rowAspect = shown.fold<double>(0, (sum, page) {
      final width = page.loadedWidth;
      final height = page.loadedHeight;
      return sum +
          (width != null && height != null && height > 0 ? width / height : .7);
    });
    var rowSize = Size(viewport.height * rowAspect, viewport.height);
    if (rowSize.width > viewport.width) {
      rowSize = Size(viewport.width, viewport.width / rowAspect);
    }
    final row = Alignment.center.inscribe(rowSize, Offset.zero & viewport);
    final target = Rect.fromLTRB(
      row.left + panel.left * row.width,
      row.top + panel.top * row.height,
      row.left + panel.right * row.width,
      row.top + panel.bottom * row.height,
    );
    if (target.isEmpty) return false;
    final scale = math
        .min(
          viewport.width * .95 / target.width,
          viewport.height * .95 / target.height,
        )
        .clamp(1.0, 8.0)
        .toDouble();
    // PhotoView's position is how far the centre of the spread sits from
    // the viewport's centre, scaled.
    final centre = viewport.center(Offset.zero);
    _animateSpread(controller, scale, (centre - target.center) * scale);
    return true;
  }

  /// Moves a spread's zoom to [scale] and [position], as a single page's
  /// zoom moves.
  void _animateSpread(
    PhotoViewController controller,
    double scale,
    Offset position,
  ) {
    _spreadZoom?.dispose();
    final from = controller.value;
    final fromScale = from.scale ?? 1.0;
    final zoom = AnimationController(
      vsync: this as TickerProvider,
      duration: ShioriMotion.of(context, ShioriMotion.enter),
    );
    _spreadZoom = zoom;
    final curve = CurvedAnimation(
      parent: zoom,
      curve: ShioriMotion.standardCurve,
    );
    zoom.addListener(() {
      controller.updateMultiple(
        scale: ui.lerpDouble(fromScale, scale, curve.value),
        position: Offset.lerp(from.position, position, curve.value),
      );
    });
    zoom.forward().whenComplete(() {
      if (!identical(_spreadZoom, zoom)) return;
      _spreadZoom = null;
      zoom.dispose();
    });
  }

  void _resetPanelZoom(int viewIndex, {required bool spread}) {
    if (spread) {
      final controller = doublePageControllers[viewIndex];
      if (controller == null) return;
      _animateSpread(controller, 1.0, Offset.zero);
    } else {
      pageControllers[pageViewToActualIndex(viewIndex)]?.resetScaleAndCenter();
    }
  }
}
