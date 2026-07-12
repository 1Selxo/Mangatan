import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_qjs/quickjs/ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/epub_book_progress.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/modules/anime/widgets/desktop.dart';
import 'package:mangayomi/modules/manga/reader/mixins/reader_gestures.dart';
import 'package:mangayomi/modules/manga/reader/widgets/auto_scroll_button.dart';
import 'package:mangayomi/modules/manga/reader/widgets/reader_app_bar.dart';
import 'package:mangayomi/modules/mining/reader_lookup_trigger.dart';
import 'package:mangayomi/modules/mining/widgets/dictionary_lookup_popup.dart';
import 'package:mangayomi/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:mangayomi/modules/novel/novel_reader_controller_provider.dart';
import 'package:mangayomi/modules/novel/tts/novel_tts_service.dart';
import 'package:mangayomi/modules/novel/tts/tts_player_bar.dart';
import 'package:mangayomi/modules/novel/tts/tts_settings_tab.dart';
import 'package:mangayomi/modules/novel/widgets/novel_reader_settings_sheet.dart';
import 'package:mangayomi/modules/novel/widgets/novel_dictionary_selection.dart';
import 'package:mangayomi/modules/novel/widgets/ttsu_epub_reader.dart';
import 'package:mangayomi/modules/widgets/custom_draggable_tabbar.dart';
import 'package:mangayomi/providers/l10n_providers.dart';
import 'package:mangayomi/services/epub_chapter_metadata.dart';
import 'package:mangayomi/services/get_html_content.dart';
import 'package:mangayomi/src/rust/api/epub.dart';
import 'package:mangayomi/utils/extensions/dom_extensions.dart';
import 'package:mangayomi/utils/platform_utils.dart';
import 'package:mangayomi/utils/system_ui.dart';
import 'package:mangayomi/utils/utils.dart';
import 'package:mangayomi/modules/manga/reader/providers/push_router.dart';
import 'package:mangayomi/utils/extensions/build_context_extensions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:flutter/widgets.dart' as widgets;

typedef DoubleClickAnimationListener = void Function();

enum NovelReaderTapAction { previousPage, toggleUi, nextPage }

enum EpubReturnButtonEdge { top, bottom, left, right }

EpubReturnButtonEdge epubReturnButtonEdgeFor({
  required EpubReadingLayout layout,
  required bool targetAfterSavedPosition,
}) {
  return switch (layout) {
    EpubReadingLayout.horizontalContinuous =>
      targetAfterSavedPosition
          ? EpubReturnButtonEdge.top
          : EpubReturnButtonEdge.bottom,
    EpubReadingLayout.horizontalPaged =>
      targetAfterSavedPosition
          ? EpubReturnButtonEdge.left
          : EpubReturnButtonEdge.right,
    EpubReadingLayout.verticalPaged || EpubReadingLayout.verticalContinuous =>
      targetAfterSavedPosition
          ? EpubReturnButtonEdge.right
          : EpubReturnButtonEdge.left,
  };
}

class NovelReaderRouteArgs {
  const NovelReaderRouteArgs({
    required this.chapterId,
    this.initialProgress,
    this.initialEpubSpineIndex,
  });

  final int chapterId;
  final double? initialProgress;
  final int? initialEpubSpineIndex;
}

String normalizeEpubReaderReference(String? value) {
  if (value == null || value.isEmpty) return '';
  final withoutSuffix = value.split('#').first.split('?').first;
  String decoded;
  try {
    decoded = Uri.decodeComponent(withoutSuffix);
  } catch (_) {
    decoded = withoutSuffix;
  }
  final parts = <String>[];
  for (final part in decoded.replaceAll('\\', '/').split('/')) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (parts.isNotEmpty) parts.removeLast();
    } else {
      parts.add(part);
    }
  }
  return parts.join('/');
}

NovelReaderTapAction novelReaderTapActionForPosition({
  required Offset position,
  required Size viewport,
  required bool usePageTapZones,
  bool reverseHorizontal = false,
}) {
  if (!usePageTapZones || viewport.width <= 0 || viewport.height <= 0) {
    return NovelReaderTapAction.toggleUi;
  }

  final verticalRatio = position.dy / viewport.height;
  if (verticalRatio < 2 / 9) return NovelReaderTapAction.previousPage;
  if (verticalRatio > 7 / 9) return NovelReaderTapAction.nextPage;

  final horizontalRatio = position.dx / viewport.width;
  if (horizontalRatio < 1 / 3) {
    return reverseHorizontal
        ? NovelReaderTapAction.nextPage
        : NovelReaderTapAction.previousPage;
  }
  if (horizontalRatio > 2 / 3) {
    return reverseHorizontal
        ? NovelReaderTapAction.previousPage
        : NovelReaderTapAction.nextPage;
  }
  return NovelReaderTapAction.toggleUi;
}

class NovelReaderView extends ConsumerWidget {
  final int chapterId;
  final double? initialProgress;
  final int? initialEpubSpineIndex;
  NovelReaderView({
    super.key,
    required this.chapterId,
    this.initialProgress,
    this.initialEpubSpineIndex,
  });
  late final Chapter _requestedChapter = isar.chapters.getSync(chapterId)!;

  EpubBookProgress? _epubBookmark() {
    final mangaId = _requestedChapter.mangaId;
    final archivePath = _requestedChapter.archivePath;
    if (!isEpubNavigationChapter(_requestedChapter) ||
        mangaId == null ||
        archivePath == null ||
        archivePath.isEmpty) {
      return null;
    }
    return isar.epubBookProgress
        .filter()
        .mangaIdEqualTo(mangaId)
        .archivePathEqualTo(archivePath)
        .findFirstSync();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmark = _epubBookmark();
    final result = ref.watch(
      getHtmlContentProvider(chapter: _requestedChapter),
    );

    return NovelWebView(
      chapter: _requestedChapter,
      result: result,
      initialProgress: initialProgress,
      initialEpubChapterIndex: bookmark?.chapterIndex,
      initialEpubChapterProgress: bookmark?.progress,
      initialEpubCharacterCount: bookmark?.characterCount,
      initialEpubHasSavedPosition:
          bookmark != null &&
          (bookmark.lastModified != null ||
              bookmark.chapterIndex > 0 ||
              bookmark.progress > 0 ||
              bookmark.characterCount > 0),
      initialEpubSpineIndex: initialEpubSpineIndex,
    );
  }
}

class NovelWebView extends ConsumerStatefulWidget {
  const NovelWebView({
    super.key,
    required this.chapter,
    required this.result,
    this.initialProgress,
    this.initialEpubChapterIndex,
    this.initialEpubChapterProgress,
    this.initialEpubCharacterCount,
    this.initialEpubHasSavedPosition = false,
    this.initialEpubSpineIndex,
  });

  final Chapter chapter;
  final AsyncValue<(String, EpubNovel?)> result;
  final double? initialProgress;
  final int? initialEpubChapterIndex;
  final double? initialEpubChapterProgress;
  final int? initialEpubCharacterCount;
  final bool initialEpubHasSavedPosition;
  final int? initialEpubSpineIndex;

  @override
  ConsumerState createState() {
    return _NovelWebViewState();
  }
}

class _NovelWebViewState extends ConsumerState<NovelWebView>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final NovelReaderController _readerController = ref.read(
    novelReaderControllerProvider(chapter: chapter).notifier,
  );
  final _scrollController = ScrollController(
    initialScrollOffset: 0,
    keepScrollOffset: true,
  );
  final _epubReaderController = TtsuEpubReaderController();
  late final _epubLayout = ValueNotifier(
    EpubReadingLayout.values[ref.read(novelEpubReadingLayoutStateProvider)],
  );
  Timer? _progressPersistDebounce;
  bool _isDisposed = false;
  bool _chapterTransitionInProgress = false;
  bool _backNavigationInProgress = false;
  bool _dictionaryPopupPrewarmed = false;
  bool _usingTtsuReader = false;
  bool _appIsActive = true;
  bool scrolled = false;
  double offset = 0;
  double maxOffset = 0;
  int? _epubChapterIndex;
  double? _epubChapterProgress;
  int? _epubCharacterCount;
  int? _currentEpubSpineIndex;
  int? _lastProjectedEpubSpineIndex;
  int? _lastProjectedOverallPercent;
  bool _epubExploring = false;
  bool _epubRestoring = false;
  bool _returnButtonHovered = false;
  bool _savedEpubPositionExists = false;
  int _savedEpubChapterIndex = 0;
  double _savedEpubChapterProgress = 0;
  int _savedEpubCharacterCount = 0;
  int? _savedEpubSpineIndex;
  int? _effectiveInitialEpubSpineIndex;
  int? _explorationTargetSpineIndex;
  double? _pendingSeekFraction;
  int fontSize = 14;
  bool get _ttsSupported => !Platform.isLinux;

  final Stopwatch _readingStopwatch = Stopwatch();

  bool get _epubPositionLocked => _epubExploring || _epubRestoring;

  void _restartReadingStopwatch() {
    _readingStopwatch.reset();
    if (_appIsActive) _readingStopwatch.start();
  }

  void onScroll() {
    if (_scrollController.hasClients) {
      offset = _scrollController.offset;
      maxOffset = _scrollController.position.maxScrollExtent;
      _reportProgress(offset, maxOffset);
    }
  }

  void _reportProgress(
    double newOffset,
    double newMaxOffset, {
    int? epubChapterIndex,
    double? epubChapterProgress,
    int? epubCharacterCount,
    int? epubSpineIndex,
  }) {
    offset = newOffset;
    maxOffset = newMaxOffset;
    _epubChapterIndex = epubChapterIndex ?? _epubChapterIndex;
    _epubChapterProgress = epubChapterProgress ?? _epubChapterProgress;
    _epubCharacterCount = epubCharacterCount ?? _epubCharacterCount;
    _currentEpubSpineIndex = epubSpineIndex ?? _currentEpubSpineIndex;
    _pendingSeekFraction = null;
    if (!_isDisposed && !_rebuildDetail.isClosed) {
      _rebuildDetail.add(newOffset);
    }
    if (_epubPositionLocked) return;
    if (epubSpineIndex != null) {
      final overallProgress = newMaxOffset > 0
          ? (newOffset / newMaxOffset).clamp(0.0, 1.0).toDouble()
          : newOffset.clamp(0.0, 1.0).toDouble();
      final overallPercent = (overallProgress * 100).round();
      if (_lastProjectedEpubSpineIndex != epubSpineIndex ||
          _lastProjectedOverallPercent != overallPercent) {
        _lastProjectedEpubSpineIndex = epubSpineIndex;
        _lastProjectedOverallPercent = overallPercent;
        _readerController.updateEpubShortcutPosition(
          spineIndex: epubSpineIndex,
          overallProgress: overallProgress,
        );
      }
    }
    _progressPersistDebounce?.cancel();
    _progressPersistDebounce = Timer(const Duration(seconds: 2), () {
      if (!_isDisposed) {
        _persistProgress();
      }
    });
  }

  void _persistProgress() {
    if (_epubPositionLocked) return;
    _readerController.setChapterOffset(
      offset,
      maxOffset,
      epubChapterIndex: _epubChapterIndex,
      epubChapterProgress: _epubChapterProgress,
      epubCharacterCount: _epubCharacterCount,
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    HardwareKeyboard.instance.removeHandler(_handleHiddenEpubEscape);
    DictionaryLookupPopup.dismissActive();
    _readingStopwatch.stop();
    WidgetsBinding.instance.removeObserver(this);
    if (!_epubPositionLocked) {
      _persistProgress();
      _readerController.setHistoryUpdate(
        elapsedSeconds: _readingStopwatch.elapsed.inSeconds,
      );
    }
    _scrollController.removeListener(onScroll);
    _scrollController.dispose();
    _progressPersistDebounce?.cancel();
    _rebuildDetail.close();
    _autoScroll.value = false;
    _autoScroll.dispose();
    _autoScrollPage.dispose();
    _epubLayout.removeListener(_onEpubLayoutChanged);
    _epubLayout.dispose();
    _keyboardFocusNode.dispose();
    _ttsIndexSub?.cancel();
    _ttsStateSub?.cancel();
    _ttsWordSub?.cancel();
    _ttsProgress.dispose();
    NovelTtsService.instance.stop();
    clearGestureDetailsCache();
    if (isDesktop) {
      setFullScreen(value: false);
    } else {
      restoreSystemUI();
    }
    discordRpc?.showIdleText();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _appIsActive = false;
      _readingStopwatch.stop();
      if (!_epubPositionLocked) _persistProgress();
    } else if (state == AppLifecycleState.resumed) {
      _appIsActive = true;
      if (!_epubPositionLocked) _readingStopwatch.start();
    }
  }

  late Chapter chapter = widget.chapter;
  EpubNovel? epubBook;

  final StreamController<double> _rebuildDetail =
      StreamController<double>.broadcast();
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleHiddenEpubEscape);
    unawaited(ReaderLookupTriggerState.initialize());
    _epubLayout.addListener(_onEpubLayoutChanged);
    WidgetsBinding.instance.addObserver(this);
    _savedEpubPositionExists = widget.initialEpubHasSavedPosition;
    _savedEpubChapterIndex = widget.initialEpubChapterIndex ?? 0;
    _savedEpubChapterProgress = widget.initialEpubChapterProgress ?? 0;
    _savedEpubCharacterCount = widget.initialEpubCharacterCount ?? 0;
    _effectiveInitialEpubSpineIndex = widget.initialEpubSpineIndex;
    _explorationTargetSpineIndex = widget.initialEpubSpineIndex;
    _epubExploring =
        widget.initialEpubSpineIndex != null &&
        _savedEpubPositionExists &&
        ref.read(novelShowReturnToSavedPositionButtonStateProvider);
    if (!_epubPositionLocked) _readingStopwatch.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.addListener(onScroll);
      final initFontSize = ref.read(novelFontSizeStateProvider);
      setState(() {
        fontSize = initFontSize;
      });
    });
    if (!isDesktop) SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    discordRpc?.showChapterDetails(ref, chapter);

    _ttsIndexSub = NovelTtsService.instance.paragraphIndexStream.listen((i) {
      _ttsProgress.value = (paragraph: i, wordStart: -1, wordEnd: -1);
      _scrollToTtsParagraph(i);
    });
    _ttsStateSub = NovelTtsService.instance.stateStream.listen((s) {
      if (s == TtsState.stopped) {
        _ttsProgress.value = (paragraph: -1, wordStart: -1, wordEnd: -1);
      }
    });
    _ttsWordSub = NovelTtsService.instance.wordProgressStream.listen((wp) {
      _ttsProgress.value = (
        paragraph: wp.paragraphIndex,
        wordStart: wp.startOffset,
        wordEnd: wp.endOffset,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dictionaryPopupPrewarmed) return;
    _dictionaryPopupPrewarmed = true;
    unawaited(DictionaryLookupPopup.prewarm(context));
  }

  void _onEpubLayoutChanged() {
    if (mounted) setState(() {});
  }

  late bool _isBookmarked = _readerController.getChapterBookmarked();

  bool _isView = false;
  final _keyboardFocusNode = FocusNode();
  bool _showTts = false;
  String? _currentHtmlContent;
  final ValueNotifier<({int paragraph, int wordStart, int wordEnd})>
  _ttsProgress = ValueNotifier((paragraph: -1, wordStart: -1, wordEnd: -1));
  int _ttsTotalBlocks = 0;
  StreamSubscription<int>? _ttsIndexSub;
  StreamSubscription<TtsState>? _ttsStateSub;
  StreamSubscription<TtsWordProgress>? _ttsWordSub;

  double get pixelRatio => View.of(context).devicePixelRatio;

  Size get size => View.of(context).physicalSize / pixelRatio;

  Color _backgroundColor(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.9);

  void _setFullScreen({bool? value}) async {
    if (isDesktop) {
      value = await windowManager.isFullScreen();
      setFullScreen(value: !value);
    }
    ref.read(fullScreenReaderStateProvider.notifier).set(!value!);
  }

  late final _autoScroll = ValueNotifier(
    _readerController.autoScrollValues().$1,
  );
  late final _pageOffset = ValueNotifier(
    _readerController.autoScrollValues().$2,
  );
  late final _autoScrollPage = ValueNotifier(_autoScroll.value);
  void _autoPagescroll() async {
    for (int i = 0; i < 1; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!_autoScroll.value) {
        return;
      }
      if (_usingTtsuReader) {
        final moved = await _epubReaderController.scrollBy(_pageOffset.value);
        if (moved == false && mounted) {
          _autoScroll.value = false;
          return;
        }
      } else if (_scrollController.hasClients) {
        final currentOffset = _scrollController.offset;
        final maxScroll = _scrollController.position.maxScrollExtent;

        if (!(currentOffset >= maxScroll)) {
          final newOffset = currentOffset + _pageOffset.value;
          _scrollController.animateTo(
            min(newOffset, maxScroll),
            duration: Duration(milliseconds: 100),
            curve: Curves.linear,
          );
        }
      }
    }
    _autoPagescroll();
  }

  void _scrollToTtsParagraph(int index) {
    if (_ttsTotalBlocks <= 0) return;
    if (_usingTtsuReader) {
      unawaited(_epubReaderController.jumpToFraction(index / _ttsTotalBlocks));
      return;
    }
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final targetOffset = (index / _ttsTotalBlocks) * maxScroll;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, maxScroll),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  /// Goes to either next or previous chapter
  ///
  /// The [next] parameter determines the navigation direction:
  /// - `true` -> navigate to next chapter
  /// - `false` -> navigate to previous chapter
  ///
  /// If the reader is already at the first or last chapter (depending on
  /// the direction), the method returns without navigating.
  void _goToChapter(bool next) {
    if (_chapterTransitionInProgress || !mounted) return;
    if (epubBook != null) {
      unawaited(_epubReaderController.jumpToAdjacentChapter(next ? 1 : -1));
      return;
    }
    if (next && !_readerController.hasNextChapter) return;
    if (!next && !_readerController.hasPreviousChapter) return;
    _chapterTransitionInProgress = true;
    pushReplacementMangaReaderView(
      context: context,
      chapter: next
          ? _readerController.getNextChapter()
          : _readerController.getPrevChapter(),
    );
  }

  void _goToEpubChapter(String chapterId) {
    final wanted = normalizeEpubReaderReference(chapterId);
    if (wanted.isEmpty) return;
    final target = epubBook?.chapters
        .where(
          (entry) =>
              normalizeEpubReaderReference(entry.path) == wanted ||
              normalizeEpubReaderReference(entry.href) == wanted,
        )
        .firstOrNull;
    if (target != null) {
      unawaited(
        _epubReaderController.jumpToEpubSpine(
          target.spineIndex,
          isolateChapter: false,
        ),
      );
    }
  }

  void _initializeSavedEpubSpine(EpubNovel book) {
    if (_savedEpubSpineIndex == null) {
      final linearChapters = book.chapters
          .where((entry) => entry.isLinear)
          .toList();
      if (linearChapters.isEmpty) return;
      final index = _savedEpubChapterIndex.clamp(0, linearChapters.length - 1);
      _savedEpubSpineIndex = linearChapters[index].spineIndex;
    }
    if (_epubExploring &&
        _explorationTargetSpineIndex == _savedLogicalEpubSpineIndex()) {
      // A stale imported row can temporarily lack the projected percentage.
      // Treating the saved logical chapter as a preview would hide the return
      // control while keeping persistence locked, so resume the bookmark.
      _epubExploring = false;
      _effectiveInitialEpubSpineIndex = null;
      _explorationTargetSpineIndex = null;
      _restartReadingStopwatch();
    }
  }

  int? _savedLogicalEpubSpineIndex() {
    final book = epubBook;
    final saved = _savedEpubSpineIndex;
    if (book == null || saved == null) return saved;
    int? logical;
    for (final entry in book.chapters) {
      if (entry.spineIndex > saved) break;
      if (entry.isNavigationEntry) logical = entry.spineIndex;
    }
    return logical ?? saved;
  }

  bool _snapshotHasProgress(EpubReaderProgressSnapshot snapshot) {
    final overall = snapshot.maxOffset > 0
        ? snapshot.offset / snapshot.maxOffset
        : snapshot.offset;
    return overall > 0.000001 ||
        snapshot.chapterIndex > 0 ||
        snapshot.chapterProgress > 0.000001 ||
        snapshot.characterCount > 0;
  }

  void _writeEpubSnapshot(
    EpubReaderProgressSnapshot snapshot, {
    required bool updateSavedPosition,
  }) {
    final overall = snapshot.maxOffset > 0
        ? (snapshot.offset / snapshot.maxOffset).clamp(0.0, 1.0).toDouble()
        : snapshot.offset.clamp(0.0, 1.0).toDouble();
    _readerController.setChapterOffset(
      snapshot.offset,
      snapshot.maxOffset,
      epubChapterIndex: snapshot.chapterIndex,
      epubChapterProgress: snapshot.chapterProgress,
      epubCharacterCount: snapshot.characterCount,
    );
    _readerController.updateEpubShortcutPosition(
      spineIndex: snapshot.spineIndex,
      overallProgress: overall,
    );
    if (updateSavedPosition) {
      _savedEpubPositionExists = _snapshotHasProgress(snapshot);
      _savedEpubChapterIndex = snapshot.chapterIndex;
      _savedEpubChapterProgress = snapshot.chapterProgress;
      _savedEpubCharacterCount = snapshot.characterCount;
      _savedEpubSpineIndex = snapshot.spineIndex;
    }
  }

  Future<void> _selectEpubChapter(Chapter selected) async {
    if (!isEpubNavigationChapter(selected)) return;
    if (selected.lastPageRead?.isNotEmpty == true) {
      if (_epubExploring) await _returnToSavedEpubPosition();
      return;
    }
    final targetSpine = epubChapterSpineIndex(selected);
    if (targetSpine == null) return;
    if (_savedEpubPositionExists &&
        targetSpine == _savedLogicalEpubSpineIndex()) {
      if (_epubExploring) {
        await _returnToSavedEpubPosition();
      } else {
        await _epubReaderController.jumpToBookmark(
          _savedEpubChapterIndex,
          _savedEpubChapterProgress,
        );
      }
      return;
    }

    if (!_epubExploring &&
        ref.read(novelShowReturnToSavedPositionButtonStateProvider)) {
      final snapshot = await _epubReaderController.currentProgressSnapshot();
      if (!mounted || _isDisposed) return;
      if (snapshot != null && _snapshotHasProgress(snapshot)) {
        _progressPersistDebounce?.cancel();
        _writeEpubSnapshot(snapshot, updateSavedPosition: true);
        _readingStopwatch.stop();
        final elapsed = _readingStopwatch.elapsed.inSeconds;
        if (elapsed > 0) {
          _readerController.setHistoryUpdate(elapsedSeconds: elapsed);
        }
        _readingStopwatch.reset();
        _epubExploring = true;
      }
    }
    _explorationTargetSpineIndex = targetSpine;
    if (mounted) setState(() {});
    await _epubReaderController.jumpToEpubSpine(targetSpine);
  }

  Future<void> _returnToSavedEpubPosition() async {
    if (!_epubExploring || _epubRestoring || !_savedEpubPositionExists) return;
    _progressPersistDebounce?.cancel();
    _epubRestoring = true;
    _epubChapterIndex = _savedEpubChapterIndex;
    _epubChapterProgress = _savedEpubChapterProgress;
    _epubCharacterCount = _savedEpubCharacterCount;
    if (mounted) setState(() {});
    EpubReaderProgressSnapshot? snapshot;
    try {
      await _epubReaderController.jumpToBookmark(
        _savedEpubChapterIndex,
        _savedEpubChapterProgress,
      );
      await Future<void>.delayed(const Duration(milliseconds: 180));
      snapshot = await _epubReaderController.currentProgressSnapshot();
    } catch (_) {
      if (mounted) {
        setState(() => _epubRestoring = false);
      }
      return;
    }
    if (!mounted || _isDisposed) return;
    if (snapshot != null) {
      offset = snapshot.offset;
      maxOffset = snapshot.maxOffset;
      _epubChapterIndex = snapshot.chapterIndex;
      _epubChapterProgress = snapshot.chapterProgress;
      _epubCharacterCount = snapshot.characterCount;
      _currentEpubSpineIndex = snapshot.spineIndex;
    }
    _epubExploring = false;
    _epubRestoring = false;
    _returnButtonHovered = false;
    _restartReadingStopwatch();
    if (mounted) setState(() {});
  }

  Future<void> _continueReadingAtPreviewPosition() async {
    if (!_epubExploring || _epubRestoring) return;
    final snapshot = await _epubReaderController.currentProgressSnapshot();
    if (snapshot == null || !mounted || _isDisposed) return;
    _progressPersistDebounce?.cancel();
    _writeEpubSnapshot(snapshot, updateSavedPosition: true);
    try {
      await _epubReaderController.clearLogicalChapterIsolation();
    } catch (_) {
      // The position tuple is already committed. The isolation class only
      // affects the temporary viewport padding, so leaving it is safe.
    }
    if (!mounted || _isDisposed) return;
    _epubExploring = false;
    _returnButtonHovered = false;
    _restartReadingStopwatch();
    if (mounted) setState(() {});
  }

  bool _hasAdjacentChapter(bool next) {
    final book = epubBook;
    if (book != null) {
      final current =
          _currentEpubSpineIndex ??
          widget.initialEpubSpineIndex ??
          epubChapterSpineIndex(chapter) ??
          0;
      return book.chapters.any(
        (entry) =>
            entry.isNavigationEntry &&
            (next ? entry.spineIndex > current : entry.spineIndex < current),
      );
    }
    return next
        ? _readerController.hasNextChapter
        : _readerController.hasPreviousChapter;
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = ref.watch(backgroundColorStateProvider);
    final fullScreenReader = ref.watch(fullScreenReaderStateProvider);
    ref.listen<bool>(novelShowReturnToSavedPositionButtonStateProvider, (
      previous,
      next,
    ) {
      if (previous == true && !next && _epubExploring) {
        unawaited(_continueReadingAtPreviewPosition());
      }
    });
    final delegateHorizontalPageKeysToChild =
        widget.result.asData?.value.$2 != null && !Platform.isLinux;
    return ReaderKeyboardHandler(
      onEscape: () => _goBack(context),
      onFullScreen: () => _setFullScreen(),
      onPreviousPage: () => _onBtnTapped(-100),
      onNextPage: () => _onBtnTapped(100),
      onNextChapter: () => _goToChapter(true),
      onPreviousChapter: () => _goToChapter(false),
      onLookupTrigger: (event) {
        if (!_usingTtsuReader ||
            !readerLookupTriggerMatchesKey(
              ReaderLookupTriggerState.trigger.value,
              event,
            )) {
          return false;
        }
        unawaited(
          _epubReaderController.setShiftLookupActive(event is KeyDownEvent),
        );
        return true;
      },
      pageKeysNavigatePages: true,
      delegateHorizontalPageKeysToChild: delegateHorizontalPageKeysToChild,
    ).wrapWithKeyboardListener(
      isReverseHorizontal: _epubLayout.value.isVerticalWriting,
      child: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.direction == ScrollDirection.idle) {
            if (_isView) {
              _isViewFunction();
            }
          }
          return true;
        },
        child: Material(
          child: SafeArea(
            top: !fullScreenReader,
            bottom: false,
            child: widget.result.when(
              data: (data) {
                _usingTtsuReader = data.$2 != null && !Platform.isLinux;
                epubBook = data.$2;
                if (epubBook != null) {
                  _initializeSavedEpubSpine(epubBook!);
                }
                _currentHtmlContent = data.$1;
                return Stack(
                  children: [
                    Column(
                      children: [
                        Flexible(
                          child: Builder(
                            builder: (context) {
                              final padding = ref.watch(
                                novelReaderPaddingStateProvider,
                              );
                              final lineHeight = ref.watch(
                                novelReaderLineHeightStateProvider,
                              );
                              final textAlign = ref.watch(
                                novelTextAlignStateProvider,
                              );
                              final removeExtraSpacing = ref.watch(
                                novelRemoveExtraParagraphSpacingStateProvider,
                              );
                              final customBackgroundColor = ref.watch(
                                novelReaderThemeStateProvider,
                              );
                              final customTextColor = ref.watch(
                                novelReaderTextColorStateProvider,
                              );

                              Color parseColor(String hex, {Color? fallback}) {
                                try {
                                  String hexColor = hex.trim().replaceAll(
                                    '#',
                                    '',
                                  );
                                  // Ensure we have a valid 6-character hex color
                                  if (hexColor.length == 6) {
                                    return Color(
                                      int.parse('FF$hexColor', radix: 16),
                                    );
                                  } else if (hexColor.length == 8) {
                                    // Already has alpha channel
                                    return Color(
                                      int.parse(hexColor, radix: 16),
                                    );
                                  }
                                } catch (_) {
                                  // If parsing fails, use fallback
                                }
                                return fallback ?? Colors.grey;
                              }

                              TextAlign getTextAlign() {
                                switch (textAlign) {
                                  case NovelTextAlign.left:
                                    return TextAlign.left;
                                  case NovelTextAlign.center:
                                    return TextAlign.center;
                                  case NovelTextAlign.right:
                                    return TextAlign.right;
                                  case NovelTextAlign.block:
                                    return TextAlign.justify;
                                }
                              }

                              Future.delayed(
                                const Duration(milliseconds: 100),
                                () {
                                  if (!scrolled &&
                                      _scrollController.hasClients) {
                                    _scrollController
                                        .animateTo(
                                          _scrollController
                                                  .position
                                                  .maxScrollExtent *
                                              (widget.initialProgress ??
                                                  double.tryParse(
                                                    chapter.lastPageRead ?? '',
                                                  ) ??
                                                  0),
                                          duration: Duration(seconds: 1),
                                          curve: Curves.fastOutSlowIn,
                                        )
                                        .then((value) {
                                          _autoPagescroll();
                                          scrolled = true;
                                        });
                                  }
                                },
                              );
                              return Consumer(
                                builder: (context, ref, _) {
                                  final fontSize = ref.watch(
                                    novelFontSizeStateProvider,
                                  );
                                  final usePageTapZones = ref.watch(
                                    novelTapToScrollStateProvider,
                                  );
                                  if (_usingTtsuReader) {
                                    _ttsTotalBlocks = NovelTtsService.instance
                                        .extractParagraphs(data.$1)
                                        .length;
                                    return ValueListenableBuilder<
                                      EpubReadingLayout
                                    >(
                                      valueListenable: _epubLayout,
                                      builder: (context, layout, _) {
                                        return TtsuEpubReader(
                                          controller: _epubReaderController,
                                          chapter: chapter,
                                          html: data.$1,
                                          book: data.$2!,
                                          backgroundColor:
                                              customBackgroundColor,
                                          textColor: customTextColor,
                                          fontSize: fontSize.toDouble(),
                                          lineHeight: lineHeight,
                                          padding: padding.toDouble(),
                                          textAlign: switch (textAlign) {
                                            NovelTextAlign.left => 'left',
                                            NovelTextAlign.center => 'center',
                                            NovelTextAlign.right => 'right',
                                            NovelTextAlign.block => 'justify',
                                          },
                                          initialProgress:
                                              widget.initialProgress ??
                                              double.tryParse(
                                                chapter.lastPageRead ?? '0',
                                              ) ??
                                              0,
                                          initialChapterIndex:
                                              widget.initialEpubChapterIndex,
                                          initialChapterProgress:
                                              widget.initialEpubChapterProgress,
                                          initialSpineIndex:
                                              _effectiveInitialEpubSpineIndex,
                                          previewSpineIndex: _epubExploring
                                              ? _explorationTargetSpineIndex
                                              : null,
                                          tapToScroll: usePageTapZones,
                                          removeExtraParagraphSpacing:
                                              removeExtraSpacing,
                                          layout: layout,
                                          onProgress:
                                              (
                                                newOffset,
                                                newMaxOffset,
                                                chapterIndex,
                                                chapterProgress,
                                                characterCount,
                                                spineIndex,
                                              ) {
                                                _reportProgress(
                                                  newOffset,
                                                  newMaxOffset,
                                                  epubChapterIndex:
                                                      chapterIndex,
                                                  epubChapterProgress:
                                                      chapterProgress,
                                                  epubCharacterCount:
                                                      characterCount,
                                                  epubSpineIndex: spineIndex,
                                                );
                                              },
                                          onReaderTap: (position, viewport) =>
                                              _handleReaderTap(
                                                position,
                                                viewport,
                                                usePageTapZones,
                                                reverseHorizontal:
                                                    layout.isVerticalWriting,
                                              ),
                                          onBackRequested: () =>
                                              _goBack(context),
                                          onChapterRequested: (direction) =>
                                              _goToChapter(direction > 0),
                                          onChapterLinkRequested:
                                              _goToEpubChapter,
                                        );
                                      },
                                    );
                                  }
                                  return Scrollbar(
                                    controller: _scrollController,
                                    interactive: true,
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        return GestureDetector(
                                          behavior: HitTestBehavior.translucent,
                                          onTapUp: (details) =>
                                              _handleReaderTap(
                                                details.localPosition,
                                                constraints.biggest,
                                                usePageTapZones,
                                              ),
                                          child: CustomScrollView(
                                            controller: _scrollController,
                                            physics:
                                                const BouncingScrollPhysics(),
                                            slivers: [
                                              SliverToBoxAdapter(
                                                child:
                                                    ValueListenableBuilder<
                                                      ({
                                                        int paragraph,
                                                        int wordStart,
                                                        int wordEnd,
                                                      })
                                                    >(
                                                      valueListenable:
                                                          _ttsProgress,
                                                      builder: (context, tts, _) {
                                                        String htmlData =
                                                            data.$1;
                                                        if (_showTts &&
                                                            tts.paragraph >=
                                                                0) {
                                                          final result = NovelTtsService
                                                              .instance
                                                              .highlightHtml(
                                                                data.$1,
                                                                tts.paragraph,
                                                                wordStart: tts
                                                                    .wordStart,
                                                                wordEnd:
                                                                    tts.wordEnd,
                                                              );
                                                          htmlData = result.$1;
                                                          _ttsTotalBlocks =
                                                              result.$2;
                                                        }
                                                        return NovelDictionarySelection(
                                                          chapter: chapter,
                                                          child: Html(
                                                            data: htmlData,
                                                            style: {
                                                              "body": Style(
                                                                fontSize: FontSize(
                                                                  fontSize
                                                                      .toDouble(),
                                                                ),
                                                                color: parseColor(
                                                                  customTextColor,
                                                                  fallback:
                                                                      Colors
                                                                          .white,
                                                                ),
                                                                backgroundColor: parseColor(
                                                                  customBackgroundColor,
                                                                  fallback:
                                                                      const Color(
                                                                        0xFF292832,
                                                                      ),
                                                                ),
                                                                margin: Margins
                                                                    .zero,
                                                                padding:
                                                                    HtmlPaddings.all(
                                                                      padding
                                                                          .toDouble(),
                                                                    ),
                                                                lineHeight:
                                                                    LineHeight(
                                                                      lineHeight,
                                                                    ),
                                                                textAlign:
                                                                    getTextAlign(),
                                                              ),
                                                              "p": Style(
                                                                margin:
                                                                    removeExtraSpacing
                                                                    ? Margins.only(
                                                                        bottom:
                                                                            4,
                                                                      )
                                                                    : Margins.only(
                                                                        bottom:
                                                                            8,
                                                                      ),
                                                                fontSize: FontSize(
                                                                  fontSize
                                                                      .toDouble(),
                                                                ),
                                                                lineHeight:
                                                                    LineHeight(
                                                                      lineHeight,
                                                                    ),
                                                                textAlign:
                                                                    getTextAlign(),
                                                              ),
                                                              "div": Style(
                                                                fontSize: FontSize(
                                                                  fontSize
                                                                      .toDouble(),
                                                                ),
                                                                lineHeight:
                                                                    LineHeight(
                                                                      lineHeight,
                                                                    ),
                                                                textAlign:
                                                                    getTextAlign(),
                                                              ),
                                                              "span": Style(
                                                                fontSize: FontSize(
                                                                  fontSize
                                                                      .toDouble(),
                                                                ),
                                                                lineHeight:
                                                                    LineHeight(
                                                                      lineHeight,
                                                                    ),
                                                              ),
                                                              "h1, h2, h3, h4, h5, h6": Style(
                                                                color: parseColor(
                                                                  customTextColor,
                                                                  fallback:
                                                                      Colors
                                                                          .white,
                                                                ),
                                                                lineHeight:
                                                                    LineHeight(
                                                                      lineHeight,
                                                                    ),
                                                                textAlign:
                                                                    getTextAlign(),
                                                              ),
                                                              "a": Style(
                                                                color:
                                                                    Colors.blue,
                                                                textDecoration:
                                                                    TextDecoration
                                                                        .underline,
                                                              ),
                                                              "img": Style(
                                                                width: Width(
                                                                  100,
                                                                  Unit.percent,
                                                                ),
                                                                height:
                                                                    Height.auto(),
                                                              ),
                                                              "table": Style(
                                                                border: Border.all(
                                                                  color: Colors
                                                                      .grey,
                                                                  width: 1,
                                                                ),
                                                                margin:
                                                                    Margins.symmetric(
                                                                      vertical:
                                                                          10,
                                                                    ),
                                                              ),
                                                              "td, th": Style(
                                                                border: Border.all(
                                                                  color: Colors
                                                                      .grey,
                                                                  width: 0.5,
                                                                ),
                                                                padding:
                                                                    HtmlPaddings.all(
                                                                      8,
                                                                    ),
                                                              ),
                                                              "th": Style(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                backgroundColor:
                                                                    Colors.grey
                                                                        .withValues(
                                                                          alpha:
                                                                              0.2,
                                                                        ),
                                                              ),
                                                              "blockquote": Style(
                                                                border: Border(
                                                                  left: BorderSide(
                                                                    color: Colors
                                                                        .grey,
                                                                    width: 4,
                                                                  ),
                                                                ),
                                                                padding:
                                                                    HtmlPaddings.only(
                                                                      left: 15,
                                                                    ),
                                                                margin:
                                                                    Margins.symmetric(
                                                                      vertical:
                                                                          10,
                                                                    ),
                                                                fontStyle:
                                                                    FontStyle
                                                                        .italic,
                                                              ),
                                                              "pre, code": Style(
                                                                backgroundColor:
                                                                    Colors.grey
                                                                        .withValues(
                                                                          alpha:
                                                                              0.2,
                                                                        ),
                                                                padding:
                                                                    HtmlPaddings.all(
                                                                      8,
                                                                    ),
                                                                fontFamily:
                                                                    'monospace',
                                                              ),
                                                              "hr": Style(
                                                                margin:
                                                                    Margins.symmetric(
                                                                      vertical:
                                                                          20,
                                                                    ),
                                                              ),
                                                              if (_showTts &&
                                                                  tts.paragraph >=
                                                                      0)
                                                                "[data-tts-active]": Style(
                                                                  backgroundColor:
                                                                      Theme.of(
                                                                        context,
                                                                      ).colorScheme.primary.withValues(
                                                                        alpha:
                                                                            0.10,
                                                                      ),
                                                                  border: Border(
                                                                    left: BorderSide(
                                                                      color: Theme.of(
                                                                        context,
                                                                      ).colorScheme.primary,
                                                                      width: 3,
                                                                    ),
                                                                  ),
                                                                  padding:
                                                                      HtmlPaddings.only(
                                                                        left: 8,
                                                                      ),
                                                                ),
                                                              if (_showTts &&
                                                                  tts.paragraph >=
                                                                      0)
                                                                "[data-tts-word]": Style(
                                                                  backgroundColor:
                                                                      Theme.of(
                                                                        context,
                                                                      ).colorScheme.primary.withValues(
                                                                        alpha:
                                                                            0.35,
                                                                      ),
                                                                  textDecoration:
                                                                      TextDecoration
                                                                          .underline,
                                                                  textDecorationColor:
                                                                      Theme.of(
                                                                        context,
                                                                      ).colorScheme.primary,
                                                                ),
                                                            },
                                                            extensions: [
                                                              TagExtension(
                                                                tagsToExtend: {
                                                                  "img",
                                                                  "source",
                                                                },
                                                                builder:
                                                                    (
                                                                      extensionContext,
                                                                    ) {
                                                                      final element =
                                                                          extensionContext.node
                                                                              as dom.Element;
                                                                      final customWidget =
                                                                          _buildCustomWidgets(
                                                                            element,
                                                                          );
                                                                      if (customWidget !=
                                                                          null) {
                                                                        return customWidget;
                                                                      }

                                                                      return const SizedBox.shrink();
                                                                    },
                                                              ),
                                                            ],
                                                            onLinkTap:
                                                                (
                                                                  url,
                                                                  attributes,
                                                                  element,
                                                                ) {
                                                                  if (url !=
                                                                      null) {
                                                                    context.push(
                                                                      "/mangawebview",
                                                                      extra: {
                                                                        'url':
                                                                            url,
                                                                        'title':
                                                                            url,
                                                                      },
                                                                    );
                                                                  }
                                                                },
                                                          ),
                                                        );
                                                      },
                                                    ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        if (ref.watch(novelShowScrollPercentageStateProvider))
                          StreamBuilder(
                            stream: _rebuildDetail.stream,
                            builder: (context, asyncSnapshot) {
                              return Consumer(
                                builder: (context, ref, child) {
                                  final customBackgroundColor = ref.watch(
                                    novelReaderThemeStateProvider,
                                  );
                                  final customTextColor = ref.watch(
                                    novelReaderTextColorStateProvider,
                                  );
                                  final scrollPercentage = maxOffset > 0
                                      ? ((offset / maxOffset) * 100)
                                            .clamp(0, 100)
                                            .toInt()
                                      : 0;
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          color: Color(
                                            int.parse(
                                              'FF${customBackgroundColor.replaceAll('#', '')}',
                                              radix: 16,
                                            ),
                                          ),
                                          child: Center(
                                            child: Padding(
                                              padding: const EdgeInsets.all(
                                                4.0,
                                              ),
                                              child: Text(
                                                '$scrollPercentage %',
                                                style: TextStyle(
                                                  color: Color(
                                                    int.parse(
                                                      'FF${customTextColor.replaceAll('#', '')}',
                                                      radix: 16,
                                                    ),
                                                  ),
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                      ],
                    ),
                    _appBar(),
                    _bottomBar(backgroundColor),
                    ReaderAutoScrollButton(
                      isContinuousMode: true,
                      isUiVisible: _isView,
                      autoScrollPage: _autoScrollPage,
                      autoScroll: _autoScroll,
                      onToggle: () {
                        _autoPagescroll();
                        _autoScroll.value = !_autoScroll.value;
                      },
                    ),
                    // Recovery must remain available while the reader chrome
                    // is hidden; `_isView` only adjusts the safe padding.
                    if (_usingTtsuReader && _epubExploring)
                      _buildReturnToSavedPositionOverlay(),
                    if (_ttsSupported &&
                        _showTts &&
                        _currentHtmlContent != null)
                      Positioned(
                        bottom: _isView ? 145 : 0,
                        left: 0,
                        right: 0,
                        child: TtsPlayerBar(
                          htmlContent: _currentHtmlContent!,
                          onClose: () {
                            if (mounted) {
                              setState(() => _showTts = false);
                            }
                          },
                        ),
                      ),
                  ],
                );
              },
              loading: () => scaffoldWith(
                context,
                Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) =>
                  scaffoldWith(context, Center(child: Text(err.toString()))),
            ),
          ),
        ),
      ),
      focusNode: _keyboardFocusNode,
    );
  }

  Widget scaffoldWith(
    BuildContext context,
    Widget body, {
    bool restoreUi = false,
  }) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(''),
        leading: BackButton(
          onPressed: () {
            if (restoreUi) {
              restoreSystemUI();
            }
            Navigator.of(context).pop();
          },
        ),
      ),
      body: body,
    );
  }

  void _goBack(BuildContext context) {
    if (_backNavigationInProgress) return;
    _backNavigationInProgress = true;
    restoreSystemUI();
    Navigator.pop(context);
  }

  bool _handleHiddenEpubEscape(KeyEvent event) {
    if (!_usingTtsuReader || _isView || event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.escape) return false;
    _goBack(context);
    return true;
  }

  void _onBtnTapped(double value) {
    if (_usingTtsuReader) {
      unawaited(() async {
        final moved = await _epubReaderController.scrollPage(
          value.sign.toInt(),
        );
        // Page movement stops at the book boundary. Chapter controls are the
        // only UI that jumps between TOC shortcuts.
        if (moved == false) return;
      }());
      return;
    }
    if (!_scrollController.hasClients) return;
    final currentOffset = _scrollController.offset;
    final maxScroll = _scrollController.position.maxScrollExtent;

    final newOffset = currentOffset + value;
    _scrollController.animateTo(
      min(newOffset, maxScroll),
      duration: Duration(milliseconds: 100),
      curve: Curves.linear,
    );
  }

  void _handleReaderTap(
    Offset position,
    Size viewport,
    bool usePageTapZones, {
    bool reverseHorizontal = false,
  }) {
    switch (novelReaderTapActionForPosition(
      position: position,
      viewport: viewport,
      usePageTapZones: usePageTapZones,
      reverseHorizontal: reverseHorizontal,
    )) {
      case NovelReaderTapAction.previousPage:
        _onBtnTapped(-100);
      case NovelReaderTapAction.toggleUi:
        _isViewFunction();
      case NovelReaderTapAction.nextPage:
        _onBtnTapped(100);
    }
  }

  Widget _buildReturnToSavedPositionOverlay() {
    final target = _explorationTargetSpineIndex;
    final saved = _savedLogicalEpubSpineIndex();
    if (target == null || saved == null || target == saved) {
      return const SizedBox.shrink();
    }
    final layout = _epubLayout.value;
    final edge = epubReturnButtonEdgeFor(
      layout: layout,
      targetAfterSavedPosition: target > saved,
    );
    final alignment = switch (edge) {
      EpubReturnButtonEdge.top => Alignment.topCenter,
      EpubReturnButtonEdge.bottom => Alignment.bottomCenter,
      EpubReturnButtonEdge.left => Alignment.centerLeft,
      EpubReturnButtonEdge.right => Alignment.centerRight,
    };
    final arrow = switch (edge) {
      EpubReturnButtonEdge.top => Icons.arrow_upward_rounded,
      EpubReturnButtonEdge.bottom => Icons.arrow_downward_rounded,
      EpubReturnButtonEdge.left => Icons.arrow_back_rounded,
      EpubReturnButtonEdge.right => Icons.arrow_forward_rounded,
    };
    final chromePadding = EdgeInsets.only(
      top: edge == EpubReturnButtonEdge.top ? (_isView ? 88 : 16) : 16,
      bottom: edge == EpubReturnButtonEdge.bottom
          ? (_isView ? 156 : (_showTts ? 76 : 16))
          : 16,
      left: 16,
      right: 16,
    );
    final theme = Theme.of(context);
    final dismissButton = AnimatedOpacity(
      opacity: _returnButtonHovered ? 1 : 0,
      duration: const Duration(milliseconds: 140),
      child: IgnorePointer(
        ignoring: !_returnButtonHovered,
        child: Material(
          color: theme.colorScheme.surfaceContainerHighest,
          elevation: 4,
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: 'Continue reading here',
            onPressed: _continueReadingAtPreviewPosition,
            icon: const Icon(Icons.close_rounded, size: 16),
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
    final returnButton = FloatingActionButton(
      heroTag: null,
      tooltip: 'Jump to current reading position',
      onPressed: _epubRestoring ? null : _returnToSavedEpubPosition,
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      child: _epubRestoring
          ? SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: theme.colorScheme.onPrimary,
              ),
            )
          : Icon(arrow),
    );
    final controls = layout == EpubReadingLayout.horizontalContinuous
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [dismissButton, const SizedBox(width: 8), returnButton],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [returnButton, const SizedBox(height: 6), dismissButton],
          );

    return Positioned.fill(
      child: SafeArea(
        child: Padding(
          padding: chromePadding,
          child: Align(
            alignment: alignment,
            child: MouseRegion(
              onEnter: (_) {
                if (mounted) setState(() => _returnButtonHovered = true);
              },
              onExit: (_) {
                if (mounted) setState(() => _returnButtonHovered = false);
              },
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: controls,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _appBar() {
    return ReaderAppBar(
      chapter: chapter,
      mangaName: _readerController.getMangaName(),
      chapterTitle: _readerController.getChapterTitle(),
      isVisible: _isView,
      isBookmarked: _isBookmarked,
      backgroundColor: _backgroundColor,
      onBackPressed: () => _goBack(context),
      onBookmarkPressed: () {
        _readerController.setChapterBookmarked();
        setState(() => _isBookmarked = !_isBookmarked);
      },
      onChapterSelected: _usingTtsuReader ? _selectEpubChapter : null,
      onWebViewPressed: (chapter.manga.value!.isLocalArchive ?? false)
          ? null
          : () async {
              final manga = chapter.manga.value!;
              final source = getSource(
                manga.lang!,
                manga.source!,
                manga.sourceId,
              )!;
              final url = chapter.url!.startsWith('/')
                  ? '${source.baseUrl}/${chapter.url!}'
                  : chapter.url!;
              if (Platform.isLinux) {
                final uri = Uri.parse(url);
                await launchUrl(
                  uri,
                  mode: LaunchMode.inAppBrowserView,
                ).catchError(
                  (_) => launchUrl(uri, mode: LaunchMode.externalApplication),
                );
              } else {
                context.push(
                  '/mangawebview',
                  extra: {
                    'url': url,
                    'sourceId': source.id.toString(),
                    'title': chapter.name!,
                  },
                );
              }
            },
    );
  }

  Widget _bottomBar(BackgroundColor backgroundColor) {
    if (!_isView && Platform.isIOS) {
      return const SizedBox.shrink();
    }
    final hasPrevChapter = _hasAdjacentChapter(false);
    final hasNextChapter = _hasAdjacentChapter(true);
    final bodyLargeColor = Theme.of(context).textTheme.bodyLarge!.color;
    return Positioned(
      bottom: 0,
      child: AnimatedContainer(
        curve: Curves.ease,
        duration: const Duration(milliseconds: 300),
        width: context.width(1),
        height: (_isView ? 140 : 0),
        child: Column(
          children: [
            if (_isView)
              StreamBuilder(
                stream: _rebuildDetail.stream,
                builder: (context, asyncSnapshot) {
                  final double progressFraction =
                      _pendingSeekFraction ??
                      (maxOffset > 0
                          ? (offset / maxOffset).clamp(0.0, 1.0).toDouble()
                          : 0.0);
                  return NovelReaderProgressBar(
                    reverseHorizontal: _epubLayout.value.isVerticalWriting,
                    progressFraction: progressFraction,
                    backgroundColor: _backgroundColor(context),
                    foregroundColor: bodyLargeColor!,
                    onPreviousChapter: hasPrevChapter
                        ? () => _goToChapter(false)
                        : null,
                    onNextChapter: hasNextChapter
                        ? () => _goToChapter(true)
                        : null,
                    onChanged: (value) {
                      if (_usingTtsuReader) {
                        setState(() {
                          _pendingSeekFraction = value;
                        });
                      } else if (_scrollController.hasClients) {
                        _scrollController.jumpTo(
                          _scrollController.position.maxScrollExtent * value,
                        );
                      }
                    },
                    onChangeEnd: (value) {
                      if (!_usingTtsuReader) return;
                      unawaited(_epubReaderController.jumpToFraction(value));
                    },
                  );
                },
              ),
            if (_isView)
              Expanded(
                child: Container(
                  color: _backgroundColor(context),
                  child: Row(
                    children: [
                      Flexible(
                        child: SizedBox(
                          height: 50,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: bodyLargeColor!,
                                    width: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      context.l10n.text_size,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: bodyLargeColor,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        final newFontSize = max(
                                          4,
                                          fontSize - 1,
                                        );
                                        ref
                                            .read(
                                              novelFontSizeStateProvider
                                                  .notifier,
                                            )
                                            .set(newFontSize);
                                        setState(() {
                                          fontSize = newFontSize;
                                        });
                                      },
                                      icon: Icon(Icons.text_decrease),
                                      iconSize: 20,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 40,
                                        minHeight: 40,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primaryContainer
                                              .withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Consumer(
                                          builder: (context, ref, child) {
                                            final currentFontSize = ref.watch(
                                              novelFontSizeStateProvider,
                                            );
                                            return Text(
                                              "$currentFontSize px",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onPrimaryContainer,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        final newFontSize = min(
                                          40,
                                          fontSize + 1,
                                        );
                                        ref
                                            .read(
                                              novelFontSizeStateProvider
                                                  .notifier,
                                            )
                                            .set(newFontSize);
                                        setState(() {
                                          fontSize = newFontSize;
                                        });
                                      },
                                      icon: const Icon(Icons.text_increase),
                                      iconSize: 20,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 40,
                                        minHeight: 40,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (_ttsSupported)
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _showTts = !_showTts;
                                    });
                                  },
                                  icon: Icon(
                                    _showTts
                                        ? Icons.record_voice_over
                                        : Icons.record_voice_over_outlined,
                                    color: _showTts
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                  tooltip: context.l10n.tts,
                                ),

                              IconButton(
                                onPressed: () async {
                                  bool autoScrollAreadyFalse =
                                      _autoScroll.value == false;
                                  if (!autoScrollAreadyFalse) {
                                    _autoScroll.value = false;
                                  }
                                  await customDraggableTabBar(
                                    tabs: [
                                      Tab(text: context.l10n.reader),
                                      Tab(text: context.l10n.general),
                                      if (_ttsSupported)
                                        Tab(text: context.l10n.tts),
                                    ],
                                    children: [
                                      ReaderSettingsTab(
                                        epubLayout: _usingTtsuReader
                                            ? _epubLayout
                                            : null,
                                      ),
                                      GeneralSettingsTab(
                                        autoScrollPage: _autoScrollPage,
                                        autoScroll: _autoScroll,
                                        readerController: _readerController,
                                        pageOffset: _pageOffset,
                                        isEpubReader: _usingTtsuReader,
                                      ),
                                      if (_ttsSupported) const TtsSettingsTab(),
                                    ],
                                    context: context,
                                    vsync: this,
                                  );
                                  if (!autoScrollAreadyFalse ||
                                      _autoScroll.value) {
                                    if (_autoScrollPage.value) {
                                      _autoPagescroll();
                                      _autoScroll.value = true;
                                    }
                                  }
                                },
                                icon: const Icon(Icons.settings),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _isViewFunction() {
    final fullScreenReader = ref.watch(fullScreenReaderStateProvider);
    if (mounted) {
      setState(() {
        _isView = !_isView;
      });
    }
    if (fullScreenReader) {
      if (_isView) {
        restoreSystemUI();
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
      }
    }
  }

  Widget? _buildCustomWidgets(dom.Element element) {
    if (epubBook == null) return null;

    if (element.localName == "img" && element.getSrc != null) {
      final src = element.getSrc!;
      final fileName = src.split("/").last;
      final image = epubBook!.images
          .firstWhereOrNull(
            (img) =>
                img.name.endsWith(fileName) ||
                img.name.contains(fileName.replaceAll('%20', ' ')),
          )
          ?.content;

      if (image != null) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: widgets.Image(
            errorBuilder: (context, error, stackTrace) => Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red.withValues(alpha: 0.1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image, color: Colors.red),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Image not loaded: $fileName',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
            fit: BoxFit.contain,
            image: MemoryImage(image) as ImageProvider,
          ),
        );
      }
    }

    return null;
  }
}

class NovelReaderProgressBar extends StatelessWidget {
  const NovelReaderProgressBar({
    super.key,
    required this.reverseHorizontal,
    required this.progressFraction,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onChanged,
    required this.onChangeEnd,
    this.onPreviousChapter,
    this.onNextChapter,
  });

  final bool reverseHorizontal;
  final double progressFraction;
  final Color backgroundColor;
  final Color foregroundColor;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final VoidCallback? onPreviousChapter;
  final VoidCallback? onNextChapter;

  @override
  Widget build(BuildContext context) {
    final scaleX = reverseHorizontal ? -1.0 : 1.0;
    return Transform.scale(
      scaleX: scaleX,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: CircleAvatar(
              radius: 21,
              backgroundColor: backgroundColor,
              child: IconButton(
                onPressed: onPreviousChapter,
                icon: Icon(
                  Icons.skip_previous_rounded,
                  color: onPreviousChapter == null
                      ? foregroundColor.withValues(alpha: 0.4)
                      : foregroundColor,
                ),
              ),
            ),
          ),
          Flexible(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Transform.scale(
                    scaleX: scaleX,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        (progressFraction * 100).round().toString(),
                        style: TextStyle(
                          color: foregroundColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 14,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12,
                        ),
                      ),
                      child: Slider(
                        onChanged: onChanged,
                        onChangeEnd: onChangeEnd,
                        value: progressFraction,
                        min: 0,
                        max: 1,
                      ),
                    ),
                  ),
                  Transform.scale(
                    scaleX: scaleX,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        '100',
                        style: TextStyle(
                          color: foregroundColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: CircleAvatar(
              radius: 21,
              backgroundColor: backgroundColor,
              child: IconButton(
                onPressed: onNextChapter,
                icon: Icon(
                  Icons.skip_next_rounded,
                  color: onNextChapter == null
                      ? foregroundColor.withValues(alpha: 0.4)
                      : foregroundColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
