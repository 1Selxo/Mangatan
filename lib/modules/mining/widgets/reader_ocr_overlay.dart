import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mangayomi/modules/manga/reader/u_chap_data_preload.dart';
import 'package:mangayomi/modules/mining/reader_lookup_trigger.dart';
import 'package:mangayomi/modules/mining/widgets/dictionary_lookup_popup.dart';
import 'package:mangayomi/services/mining/chrome_lens_ocr.dart';
import 'package:mangayomi/services/mining/mining_models.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';
import 'package:mangayomi/services/mining/mokuro_parser.dart';
import 'package:mangayomi/services/mining/ocr_models.dart';
import 'package:mangayomi/services/mining/ocr_block_merger.dart';
import 'package:mangayomi/services/mining/screen_ai_ocr.dart';
import 'package:mangayomi/utils/extensions/others.dart';

class ReaderOcrState {
  ReaderOcrState._();

  static final enabled = ValueNotifier<bool>(true);
  static final outlineVisible = ValueNotifier<bool>(false);
  static final lookupOnHover = ValueNotifier<bool>(false);
  static bool _initialized = false;
  static Future<void>? _initializing;
  static final Set<ReaderOcrController> _controllers = {};
  static final progress = ValueNotifier<ReaderOcrProgress?>(null);
  static DictionaryPopupHandle? _hoverPopup;
  static Timer? _hoverDismissTimer;
  static String? _hoverLookupKey;
  static bool _hoveringPopup = false;
  static int _hoverGeneration = 0;
  static int _scanGeneration = 0;
  static int _paintGeneration = 0;
  static bool _popupWasVisibleOnPointerDown = false;
  static Offset? _lastPointerPosition;
  static bool _middleLookupActive = false;
  static List<UChapDataPreload> _lastScanPages = const [];
  static int _lastStartIndex = 0;
  static Future<void> Function(UChapDataPreload)? _lastPreparePage;

  static Future<void> initialize() async {
    if (_initialized) return;
    if (_initializing != null) return _initializing;
    _initializing = _loadPreferences();
    return _initializing;
  }

  static Future<void> _loadPreferences() async {
    try {
      final values = await Future.wait<dynamic>([
        MiningPreferences.getOcrOverlayEnabled(),
        MiningPreferences.getOcrOutlineVisible(),
        MiningPreferences.getOcrLookupOnHover(),
        ReaderLookupTriggerState.initialize(),
      ]);
      enabled.value = values[0] as bool;
      outlineVisible.value = values[1] as bool;
      lookupOnHover.value = values[2] as bool;
      _initialized = true;
    } finally {
      _initializing = null;
    }
  }

  static Future<void> setEnabled(bool value) async {
    enabled.value = value;
    await MiningPreferences.setOcrOverlayEnabled(value);
    if (!value) {
      _dismissHoverPopup();
      cancelScan(clearLast: false);
    } else if (_lastScanPages.isNotEmpty) {
      unawaited(
        scanChapter(
          _lastScanPages,
          startIndex: _lastStartIndex,
          preparePage: _lastPreparePage,
        ),
      );
    }
  }

  static Future<void> toggle() => setEnabled(!enabled.value);

  static Future<void> setOutlineVisible(bool value) async {
    await initialize();
    outlineVisible.value = value;
    await MiningPreferences.setOcrOutlineVisible(value);
  }

  static Future<void> setLookupOnHover(bool value) async {
    await initialize();
    lookupOnHover.value = value;
    await MiningPreferences.setOcrLookupOnHover(value);
    if (!value) _dismissHoverPopup();
  }

  static bool handlePointerUp(Offset globalPosition) {
    final popupWasVisible = _popupWasVisibleOnPointerDown;
    _popupWasVisibleOnPointerDown = false;
    if (!enabled.value) return false;
    if (lookupOnHover.value) {
      if (!popupWasVisible) return false;
      _dismissHoverPopup();
      clearActive();
      return true;
    }
    final hit = _bestGlobalHit(globalPosition);
    if (hit == null) {
      clearActive();
      final dismissedPopup = DictionaryLookupPopup.dismissActive();
      return readerOcrShouldConsumeMissedTap(
        popupWasVisibleOnPointerDown: popupWasVisible,
        dismissedPopup: dismissedPopup,
      );
    }
    _activateGlobalHit(hit);
    unawaited(hit.controller._activateHit(hit.context, hit.tapHit));
    return true;
  }

  static void handlePointerDown(Offset globalPosition) {
    _lastPointerPosition = globalPosition;
    _popupWasVisibleOnPointerDown = DictionaryLookupPopup.isActive;
  }

  static void handlePointerCancel() {
    _popupWasVisibleOnPointerDown = false;
    _middleLookupActive = false;
  }

  static bool handleMiddleLookupStart(Offset globalPosition, int buttons) {
    if (!enabled.value ||
        buttons != kMiddleMouseButton ||
        lookupOnHover.value ||
        ReaderLookupTriggerState.trigger.value !=
            DictionaryLookupTrigger.middleClick) {
      return false;
    }
    _middleLookupActive = true;
    _lastPointerPosition = globalPosition;
    unawaited(handleHover(globalPosition));
    return true;
  }

  static void handleMiddleLookupMove(Offset globalPosition) {
    if (!_middleLookupActive) return;
    unawaited(handleHover(globalPosition));
  }

  static void handleMiddleLookupEnd() {
    _middleLookupActive = false;
  }

  static Future<bool> handleHover(Offset globalPosition) async {
    _lastPointerPosition = globalPosition;
    if (!enabled.value) return false;
    final hoverLookupActive = _hoverLookupActive;
    final hit = _bestGlobalHit(globalPosition);
    if (hit == null) {
      if (hoverLookupActive) {
        _scheduleHoverDismiss();
      } else {
        clearActive();
      }
      return false;
    }
    _activateGlobalHit(hit);
    if (!hoverLookupActive) {
      hit.controller._revealHit(hit.tapHit);
      hit.controller._prefetchHit(hit.tapHit);
      return true;
    }
    _hoverDismissTimer?.cancel();
    return hit.controller._activateHit(
      hit.context,
      hit.tapHit,
      triggeredByHover: true,
    );
  }

  static void handleHoverExit() {
    _lastPointerPosition = null;
    if (_hoverLookupActive) {
      _scheduleHoverDismiss();
    } else {
      clearActive();
    }
  }

  static bool handleLookupTriggerKey(KeyEvent event) {
    if (!readerLookupTriggerMatchesKey(
      ReaderLookupTriggerState.trigger.value,
      event,
    )) {
      return false;
    }
    if (event is KeyUpEvent) {
      return true;
    }
    if (!enabled.value || lookupOnHover.value) return false;
    final position = _lastPointerPosition;
    if (position != null) unawaited(handleHover(position));
    return true;
  }

  static bool get _hoverLookupActive {
    return lookupOnHover.value ||
        _middleLookupActive ||
        (ReaderLookupTriggerState.trigger.value ==
                DictionaryLookupTrigger.shift &&
            HardwareKeyboard.instance.isShiftPressed);
  }

  static _GlobalOcrHit? _bestGlobalHit(Offset globalPosition) {
    final hits = <_GlobalOcrHit>[];
    for (final controller in _controllers.toList()) {
      final hit = controller._hitTestGlobal(globalPosition);
      if (hit != null) hits.add(hit);
    }
    if (hits.isEmpty) return null;
    hits.sort((a, b) {
      final areaCompare = a.globalBlockRectArea.compareTo(
        b.globalBlockRectArea,
      );
      if (areaCompare != 0) return areaCompare;
      return b.controller._paintOrder.compareTo(a.controller._paintOrder);
    });
    return hits.first;
  }

  static void _activateGlobalHit(_GlobalOcrHit hit) {
    for (final controller in _controllers.toList()) {
      if (!identical(controller, hit.controller)) {
        controller._clearActive();
      }
    }
  }

  static int? _beginHoverLookup(String key) {
    if (_hoverLookupKey == key) return null;
    _hoverLookupKey = key;
    _hoverDismissTimer?.cancel();
    return ++_hoverGeneration;
  }

  static bool _isCurrentHoverLookup(int generation, String key) {
    return _hoverGeneration == generation && _hoverLookupKey == key;
  }

  static void _setHoverPopup(
    DictionaryPopupHandle? handle,
    int generation,
    String key,
  ) {
    if (!_isCurrentHoverLookup(generation, key)) {
      handle?.dismiss();
      return;
    }
    _hoverPopup = handle;
  }

  static void _setHoveringPopup(bool value) {
    _hoveringPopup = value;
    if (value) {
      _hoverDismissTimer?.cancel();
    } else {
      _scheduleHoverDismiss();
    }
  }

  static void _scheduleHoverDismiss() {
    _hoverDismissTimer?.cancel();
    _hoverDismissTimer = Timer(const Duration(milliseconds: 250), () {
      if (_hoveringPopup) return;
      _dismissHoverPopup();
      clearActive();
    });
  }

  static void _dismissHoverPopup() {
    _hoverDismissTimer?.cancel();
    _hoverDismissTimer = null;
    _hoverLookupKey = null;
    _hoverGeneration++;
    _hoveringPopup = false;
    _hoverPopup?.dismiss();
    _hoverPopup = null;
  }

  static void clearActive() {
    for (final controller in _controllers.toList()) {
      controller._clearActive();
    }
  }

  static Future<void> scanChapter(
    List<UChapDataPreload> pages, {
    int startIndex = 0,
    Future<void> Function(UChapDataPreload)? preparePage,
  }) async {
    _lastScanPages = pages;
    _lastStartIndex = startIndex;
    _lastPreparePage = preparePage;
    await initialize();
    if (!enabled.value) return;
    final scanPages = pages.where((page) => !page.isTransitionPage).toList();
    if (scanPages.isEmpty) return;
    final generation = ++_scanGeneration;
    final start = startIndex.clamp(0, scanPages.length - 1);
    final ordered = [
      ...scanPages.sublist(start),
      ...scanPages.sublist(0, start),
    ];
    var completed = 0;
    progress.value = ReaderOcrProgress(completed: 0, total: ordered.length);
    for (var index = 0; index < ordered.length; index += 2) {
      if (generation != _scanGeneration || !enabled.value) return;
      final end = math.min(index + 2, ordered.length);
      await Future.wait(
        ordered.sublist(index, end).map((page) async {
          try {
            await preparePage?.call(page);
            await ReaderOcrController._preload(page);
          } catch (error) {
            debugPrint('Reader OCR page ${page.pageIndex} failed: $error');
          }
        }),
      );
      completed = end;
      if (generation == _scanGeneration) {
        progress.value = ReaderOcrProgress(
          completed: completed,
          total: ordered.length,
        );
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (generation == _scanGeneration) progress.value = null;
  }

  static void cancelScan({bool clearLast = true}) {
    _scanGeneration++;
    progress.value = null;
    if (clearLast) {
      _lastScanPages = const [];
      _lastPreparePage = null;
    }
  }
}

class ReaderOcrProgress {
  const ReaderOcrProgress({required this.completed, required this.total});
  final int completed;
  final int total;
}

class ReaderOcrProgressHud extends StatelessWidget {
  const ReaderOcrProgressHud({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ReaderOcrProgress?>(
      valueListenable: ReaderOcrState.progress,
      builder: (context, progress, _) {
        if (progress == null) return const SizedBox.shrink();
        return Positioned(
          top: 12,
          right: 12,
          child: Material(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: .92),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text('OCR ${progress.completed}/${progress.total}'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ReaderOcrController extends ChangeNotifier {
  ReaderOcrController(this.data, {required this.imageKey}) {
    ReaderOcrState.enabled.addListener(_enabledChanged);
    ReaderOcrState.outlineVisible.addListener(_outlineVisibleChanged);
    ReaderOcrState._controllers.add(this);
    unawaited(ReaderOcrState.initialize());
  }

  static final Map<String, Future<_ReaderOcrPage>> _cache = {};

  final UChapDataPreload data;
  final GlobalKey imageKey;
  _ReaderOcrPage? _page;
  Rect? _imageRect;
  List<_PaintedOcrBlock> _paintedBlocks = const [];
  OcrTextBlock? _activeBlock;
  int _activeOffset = -1;
  int _matchLength = 0;
  int _paintOrder = 0;
  Color _highlightColor = const Color(0xff8ab4f8);
  Color _outlineColor = const Color(0xff8ab4f8);
  bool _loading = false;
  bool _disposed = false;
  String? _prefetchedLookupKey;

  bool get enabled => ReaderOcrState.enabled.value;

  void updateTheme(Color primary) {
    _highlightColor = primary;
    _outlineColor = primary;
  }

  Future<void> load() async {
    if (!enabled || _loading || _page != null || data.isTransitionPage) return;
    _loading = true;
    notifyListeners();
    try {
      final page = await _preload(data);
      if (!_disposed) {
        _page = page;
        notifyListeners();
      }
    } catch (error) {
      debugPrint('Reader OCR failed: $error');
    } finally {
      _loading = false;
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  static Future<_ReaderOcrPage> _preload(UChapDataPreload data) async {
    final engine = await MiningPreferences.getOcrEngine();
    final language = await MiningPreferences.getOcrLanguage();
    final key =
        '${data.pageUrl?.url ?? data.directory?.path ?? ''}:'
        '${data.chapter?.id}:${data.index}:${data.pageIndex}:'
        '${engine.name}:$language';
    try {
      return await _cache.putIfAbsent(
        key,
        () => _recognize(data, engine: engine, language: language),
      );
    } catch (_) {
      _cache.remove(key);
      rethrow;
    }
  }

  void paint(
    Canvas canvas,
    Rect imageRect,
    ui.Image image,
    Paint paint, {
    Rect? hitTestImageRect,
  }) {
    final hitImageRect = hitTestImageRect ?? imageRect;
    _imageRect = hitImageRect;
    _paintOrder = ++ReaderOcrState._paintGeneration;
    final page = _page;
    if (!enabled || page == null) {
      _paintedBlocks = const [];
      return;
    }
    final paintedBlocks = <_PaintedOcrBlock>[];
    final outlineVisible = ReaderOcrState.outlineVisible.value;
    for (final block in page.blocks) {
      final rect = _blockRect(block, imageRect, page.boxScaleX, page.boxScaleY);
      if (rect.isEmpty) continue;
      final hitRect = _blockRect(
        block,
        hitImageRect,
        page.boxScaleX,
        page.boxScaleY,
      );
      final active = identical(block, _activeBlock);
      final lineBoxes = _lineBoxes(
        block,
        imageRect,
        page.boxScaleX,
        page.boxScaleY,
      );
      final hitLineBoxes = _lineBoxes(
        block,
        hitImageRect,
        page.boxScaleX,
        page.boxScaleY,
      );
      paintedBlocks.add(
        _PaintedOcrBlock(block: block, rect: hitRect, lineBoxes: hitLineBoxes),
      );
      if (lineBoxes.isEmpty) {
        _paintOcrBox(
          canvas: canvas,
          rect: rect,
          text: _orderedBlock(block),
          vertical: block.vertical,
          active: active,
          opacity: page.opacity,
          highlight: active
              ? _lineHighlightFor(
                  lineStart: 0,
                  lineLength: _orderedBlock(block).length,
                  rect: rect,
                  vertical: block.vertical,
                )
              : null,
        );
        if (outlineVisible) {
          _paintOcrOutline(canvas, rect, active: active);
        }
        continue;
      }

      var lineStart = 0;
      for (final lineBox in lineBoxes) {
        final lineLength = lineBox.text.length;
        _paintOcrBox(
          canvas: canvas,
          rect: lineBox.rect,
          text: lineBox.text,
          vertical: lineBox.vertical,
          active: active,
          opacity: page.opacity,
          rotation: lineBox.rotation,
          highlight: active
              ? _lineHighlightFor(
                  lineStart: lineStart,
                  lineLength: lineLength,
                  rect: lineBox.rect,
                  vertical: lineBox.vertical,
                )
              : null,
        );
        lineStart += lineLength;
      }
      if (outlineVisible) {
        _paintOcrOutline(canvas, rect, active: active);
      }
    }
    _paintedBlocks = paintedBlocks;
  }

  Future<bool> handleTap(BuildContext context, Offset localPosition) async {
    final hit = _hitTestLocal(localPosition);
    if (hit == null) return false;
    return _activateHit(context, hit);
  }

  Future<bool> handleGlobalTap(Offset globalPosition) async {
    final hit = _hitTestGlobal(globalPosition);
    if (hit == null) return false;
    return _activateHit(hit.context, hit.tapHit);
  }

  _OcrTapHit? _hitTestLocal(Offset localPosition) {
    final imageRect = _imageRect;
    if (!enabled || imageRect == null || imageRect.isEmpty) return null;
    final hitSlop = _hitSlopFor(imageRect);
    if (!imageRect.inflate(hitSlop).contains(localPosition)) return null;
    for (final painted in _paintedBlocks.reversed) {
      final hit = _hitTestPaintedBlock(
        painted,
        localPosition,
        blockRect: painted.rect,
        hitSlop: 0,
      );
      if (hit != null) return hit;
    }
    return null;
  }

  _GlobalOcrHit? _hitTestGlobal(Offset globalPosition) {
    final context = imageKey.currentContext;
    final box = context?.findRenderObject() as RenderBox?;
    final imageRect = _imageRect;
    if (!enabled ||
        context == null ||
        box == null ||
        !box.attached ||
        !box.hasSize ||
        imageRect == null ||
        imageRect.isEmpty) {
      return null;
    }

    final imageGlobalRect = _localRectToGlobal(box, imageRect);
    final hitSlop = _hitSlopFor(imageGlobalRect);
    if (!imageGlobalRect.inflate(hitSlop).contains(globalPosition)) {
      return null;
    }

    // Route taps through the same painted rectangles users see. In double-page
    // and zoomed layouts, recomputing a separate local hit region can drift.
    for (final painted in _paintedBlocks.reversed) {
      final blockGlobalRect = _localRectToGlobal(box, painted.rect);
      final hit = _hitTestPaintedBlock(
        painted,
        globalPosition,
        blockRect: blockGlobalRect,
        blockRectIsGlobal: true,
        lineRectMapper: (rect) => _localRectToGlobal(box, rect),
        hitSlop: 0,
      );
      if (hit != null) {
        return _GlobalOcrHit(
          controller: this,
          context: context,
          tapHit: hit,
          globalBlockRect: blockGlobalRect,
        );
      }
    }
    return null;
  }

  _OcrTapHit? _hitTestPaintedBlock(
    _PaintedOcrBlock painted,
    Offset position, {
    required Rect blockRect,
    bool blockRectIsGlobal = false,
    Rect Function(Rect rect)? lineRectMapper,
    required double hitSlop,
  }) {
    var lineStart = 0;
    for (final lineBox in painted.lineBoxes) {
      final lineRect = lineRectMapper?.call(lineBox.rect) ?? lineBox.rect;
      if (lineRect.inflate(hitSlop).contains(position)) {
        final rawOffset = _characterOffsetForLine(
          lineBox,
          position - lineRect.topLeft,
          lineRect.size,
          lineStart,
        );
        return _OcrTapHit(
          block: painted.block,
          rawOffset: rawOffset,
          blockRect: blockRect,
          blockRectIsGlobal: blockRectIsGlobal,
          vertical: lineBox.vertical,
        );
      }
      lineStart += lineBox.text.length;
    }

    if (!blockRect.inflate(hitSlop).contains(position)) return null;
    return _OcrTapHit(
      block: painted.block,
      rawOffset: _characterOffset(
        painted.block,
        position - blockRect.topLeft,
        blockRect.size,
      ),
      blockRect: blockRect,
      blockRectIsGlobal: blockRectIsGlobal,
      vertical: painted.block.vertical,
    );
  }

  void _revealHit(_OcrTapHit hit) {
    if (identical(_activeBlock, hit.block)) return;
    _activeBlock = hit.block;
    _activeOffset = -1;
    _matchLength = 0;
    notifyListeners();
  }

  void _prefetchHit(_OcrTapHit hit) {
    final ordered = _orderedBlock(hit.block);
    if (ordered.isEmpty) return;
    final orderedOffset = _toOrderedOffset(
      hit.block,
      hit.rawOffset,
    ).clamp(0, ordered.length - 1);
    if (!_isLookupStartChar(ordered[orderedOffset])) return;
    final lookup = _extractOcrLookupString(ordered, orderedOffset);
    if (lookup.isEmpty) return;
    final key = '${identityHashCode(hit.block)}:$orderedOffset:$lookup';
    if (_prefetchedLookupKey == key) return;
    _prefetchedLookupKey = key;
    unawaited(
      DictionaryLookupPopup.lookup(lookup).then<void>(
        (_) {},
        onError: (_) {
          if (_prefetchedLookupKey == key) _prefetchedLookupKey = null;
        },
      ),
    );
  }

  int _characterOffsetForLine(
    _OcrLineBox lineBox,
    Offset local,
    Size size,
    int lineStart,
  ) {
    final line = lineBox.text;
    final char = lineBox.vertical
        ? (local.dy / math.max(1, size.height / math.max(1, line.length)))
              .floor()
              .clamp(0, math.max(0, line.length - 1))
        : (local.dx / math.max(1, size.width / math.max(1, line.length)))
              .floor()
              .clamp(0, math.max(0, line.length - 1));
    return lineStart + char.toInt();
  }

  Future<bool> _activateHit(
    BuildContext context,
    _OcrTapHit hit, {
    bool triggeredByHover = false,
  }) async {
    final block = hit.block;
    final rawOffset = hit.rawOffset;
    if (readerOcrShouldDismissRepeatedLookup(
      popupVisible: DictionaryLookupPopup.isActive,
      triggeredByHover: triggeredByHover,
      sameBlock: identical(_activeBlock, block),
      activeOffset: _activeOffset,
      hitOffset: rawOffset,
    )) {
      _clearActive();
      DictionaryLookupPopup.dismissActive();
      return true;
    }
    final ordered = _orderedBlock(block);
    if (ordered.isEmpty) return true;
    final orderedOffset = _toOrderedOffset(
      block,
      rawOffset,
    ).clamp(0, ordered.length - 1);
    if (!_isLookupStartChar(ordered[orderedOffset])) {
      if (triggeredByHover) ReaderOcrState._dismissHoverPopup();
      _activeBlock = block;
      _activeOffset = rawOffset;
      _matchLength = 0;
      notifyListeners();
      return true;
    }
    final lookup = _extractOcrLookupString(ordered, orderedOffset);
    final hoverKey = triggeredByHover
        ? '${identityHashCode(this)}:${identityHashCode(block)}:'
              '$orderedOffset:$lookup'
        : null;
    final hoverGeneration = hoverKey == null
        ? null
        : ReaderOcrState._beginHoverLookup(hoverKey);
    if (triggeredByHover && hoverGeneration == null) return true;
    _activeBlock = block;
    _activeOffset = rawOffset;
    _matchLength = 0;
    notifyListeners();
    if (lookup.isEmpty || !context.mounted) {
      if (triggeredByHover) ReaderOcrState._dismissHoverPopup();
      return true;
    }

    final anchor = hit.blockRectIsGlobal
        ? hit.blockRect
        : _localAnchorFor(context, hit.blockRect);
    if (triggeredByHover &&
        !ReaderOcrState._isCurrentHoverLookup(hoverGeneration!, hoverKey!)) {
      return true;
    }
    final handle = await DictionaryLookupPopup.show(
      context: context,
      anchor: anchor,
      text: lookup,
      miningContext: MiningContext(
        mediaType: MiningMediaType.manga,
        sourceTitle: data.chapter?.manga.value?.name ?? data.mangaName ?? '',
        chapterTitle: data.chapter?.name ?? '',
        sentence: ordered,
        pageIndex: data.pageIndex,
        sourceUri: Uri.tryParse(data.pageUrl?.url ?? ''),
        imageBytesLoader: () async =>
            data.cropImage ?? await data.getImageBytes,
      ),
      placement: hit.vertical
          ? DictionaryPopupPlacement.leftOrRight
          : DictionaryPopupPlacement.aboveOrBelow,
      onMatchChanged: (length) {
        _matchLength = math.max(0, length);
        if (!_disposed) notifyListeners();
      },
      dismissOnOutsideTap: !triggeredByHover,
      onHoverChanged: triggeredByHover
          ? ReaderOcrState._setHoveringPopup
          : null,
    );
    if (triggeredByHover) {
      ReaderOcrState._setHoverPopup(handle, hoverGeneration!, hoverKey!);
    }
    return true;
  }

  Rect _localRectToGlobal(RenderBox box, Rect rect) {
    final points = [
      box.localToGlobal(rect.topLeft),
      box.localToGlobal(rect.topRight),
      box.localToGlobal(rect.bottomLeft),
      box.localToGlobal(rect.bottomRight),
    ];
    return Rect.fromLTRB(
      points.map((point) => point.dx).reduce(math.min),
      points.map((point) => point.dy).reduce(math.min),
      points.map((point) => point.dx).reduce(math.max),
      points.map((point) => point.dy).reduce(math.max),
    );
  }

  double _hitSlopFor(Rect rect) =>
      math.max(8.0, math.max(rect.width, rect.height) * 0.002);

  Rect _localAnchorFor(BuildContext context, Rect rect) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return rect;
    return _localRectToGlobal(box, rect);
  }

  void _enabledChanged() {
    if (enabled) load();
    if (!_disposed) notifyListeners();
  }

  void _outlineVisibleChanged() {
    if (!_disposed) notifyListeners();
  }

  void _clearActive() {
    if (_activeBlock == null && _activeOffset < 0 && _matchLength == 0) {
      return;
    }
    _activeBlock = null;
    _activeOffset = -1;
    _matchLength = 0;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ReaderOcrState.enabled.removeListener(_enabledChanged);
    ReaderOcrState.outlineVisible.removeListener(_outlineVisibleChanged);
    ReaderOcrState._controllers.remove(this);
    super.dispose();
  }

  static Future<_ReaderOcrPage> _recognize(
    UChapDataPreload data, {
    required OcrEnginePreference engine,
    required String language,
  }) async {
    final values = await Future.wait<dynamic>([
      MiningPreferences.getOcrOverlayOpacity(),
      MiningPreferences.getOcrBoxScaleX(),
      MiningPreferences.getOcrBoxScaleY(),
    ]);
    final opacity = values[0] as double;
    final boxScaleX = values[1] as double;
    final boxScaleY = values[2] as double;

    if (engine != OcrEnginePreference.googleLens &&
        engine != OcrEnginePreference.screenAi) {
      const parser = MokuroParser();
      final volume = await parser.findForReaderPage(data);
      final mokuroPage = volume == null
          ? null
          : parser.resolvePage(volume, data: data);
      if (mokuroPage != null) {
        final blocks = parser.convertPage(mokuroPage);
        if (blocks.isNotEmpty || engine == OcrEnginePreference.mokuroOnly) {
          return _ReaderOcrPage(
            blocks: blocks,
            opacity: opacity,
            boxScaleX: boxScaleX,
            boxScaleY: boxScaleY,
          );
        }
      }
      if (engine == OcrEnginePreference.mokuroOnly) {
        return _ReaderOcrPage(
          blocks: const [],
          opacity: opacity,
          boxScaleX: boxScaleX,
          boxScaleY: boxScaleY,
        );
      }
    }

    Uint8List? bytes = data.cropImage ?? await data.getImageBytes;
    for (var retry = 0; bytes == null && retry < 3; retry++) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      bytes = data.cropImage ?? await data.getImageBytes;
    }
    if (bytes == null) throw StateError('Page image is not cached yet');
    final shouldTryScreenAi =
        engine == OcrEnginePreference.screenAi ||
        (engine == OcrEnginePreference.automatic &&
            await ScreenAiOcrClient.isAvailable());
    if (shouldTryScreenAi) {
      try {
        final client = ScreenAiOcrClient();
        try {
          final result = await client.recognize(bytes);
          if (result.blocks.isNotEmpty ||
              engine == OcrEnginePreference.screenAi) {
            return _ReaderOcrPage(
              blocks: mergeOcrBlocks(result.blocks, language: language),
              opacity: opacity,
              boxScaleX: boxScaleX,
              boxScaleY: boxScaleY,
            );
          }
        } finally {
          client.close();
        }
      } catch (_) {
        if (engine == OcrEnginePreference.screenAi) rethrow;
      }
    }

    final client = ChromeLensOcrClient();
    try {
      final result = await client.recognize(bytes, language: language);
      return _ReaderOcrPage(
        blocks: mergeOcrBlocks(result.blocks, language: language),
        opacity: opacity,
        boxScaleX: boxScaleX,
        boxScaleY: boxScaleY,
      );
    } finally {
      client.close();
    }
  }

  Rect _blockRect(
    OcrTextBlock block,
    Rect imageRect,
    double scaleX,
    double scaleY,
  ) {
    final center = Offset(
      imageRect.left + (block.xmin + block.xmax) * imageRect.width / 2,
      imageRect.top + (block.ymin + block.ymax) * imageRect.height / 2,
    );
    final size = Size(
      (block.xmax - block.xmin) * imageRect.width * scaleX,
      (block.ymax - block.ymin) * imageRect.height * scaleY,
    );
    return Rect.fromCenter(
      center: center,
      width: size.width,
      height: size.height,
    ).intersect(imageRect);
  }

  void _paintOcrBox({
    required Canvas canvas,
    required Rect rect,
    required String text,
    required bool vertical,
    required bool active,
    required double opacity,
    Rect? highlight,
    double rotation = 0,
  }) {
    if (text.isEmpty) return;
    final backgroundAlpha = active ? math.max(0.70, opacity) : opacity;
    final textAlpha = active ? 1.0 : opacity;
    canvas.save();
    if (rotation.abs() > 0.01) {
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.rotate(rotation * math.pi / 180);
      canvas.translate(-rect.center.dx, -rect.center.dy);
    }
    if (backgroundAlpha > 0.01) {
      canvas.drawRect(
        rect,
        Paint()..color = Colors.white.withValues(alpha: backgroundAlpha),
      );
    }
    if (highlight != null && !highlight.isEmpty) {
      canvas.drawRect(
        highlight.intersect(rect),
        Paint()..color = _highlightColor.withValues(alpha: 0.45),
      );
    }
    if (textAlpha > 0.01) {
      if (vertical) {
        _paintVerticalText(canvas, rect, text, textAlpha);
      } else {
        _paintHorizontalText(canvas, rect, text, textAlpha);
      }
    }
    canvas.restore();
  }

  void _paintOcrOutline(Canvas canvas, Rect rect, {required bool active}) {
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 2 : 1.5
        ..color = _outlineColor.withValues(alpha: active ? 1.0 : 0.70),
    );
  }

  void _paintHorizontalText(
    Canvas canvas,
    Rect rect,
    String text,
    double alpha,
  ) {
    final painter = TextPainter(
      maxLines: 1,
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black.withValues(alpha: alpha),
          fontSize: 20,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    final scale = math.min(
      rect.width / math.max(1, painter.width),
      rect.height / math.max(1, painter.height),
    );
    canvas.save();
    canvas.clipRect(rect);
    canvas.translate(
      rect.center.dx - painter.width * scale / 2,
      rect.center.dy - painter.height * scale / 2,
    );
    canvas.scale(scale);
    painter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  void _paintVerticalText(Canvas canvas, Rect rect, String text, double alpha) {
    final rowHeight = rect.height / math.max(1, text.length);
    final fontSize = math.max(
      8.0,
      math.min(rect.width * 0.82, rowHeight * 0.95),
    );
    for (var index = 0; index < text.length; index++) {
      final painter = TextPainter(
        maxLines: 1,
        text: TextSpan(
          text: text[index],
          style: TextStyle(
            color: Colors.black.withValues(alpha: alpha),
            fontSize: fontSize,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          rect.center.dx - painter.width / 2,
          rect.top + rowHeight * (index + 0.5) - painter.height / 2,
        ),
      );
    }
  }

  Rect? _lineHighlightFor({
    required int lineStart,
    required int lineLength,
    required Rect rect,
    required bool vertical,
  }) {
    if (_matchLength <= 0 || _activeOffset < 0 || lineLength <= 0) {
      return null;
    }
    final start = _activeOffset;
    final end = _activeOffset + _matchLength;
    final lineEnd = lineStart + lineLength;
    if (start >= lineEnd || end <= lineStart) return null;
    final overlapStart = math.max(start, lineStart) - lineStart;
    final overlapEnd = math.min(end, lineEnd) - lineStart;
    if (vertical) {
      final cellHeight = rect.height / lineLength;
      return Rect.fromLTWH(
        rect.left,
        rect.top + overlapStart * cellHeight,
        rect.width,
        math.max(1, (overlapEnd - overlapStart) * cellHeight),
      );
    }
    final cellWidth = rect.width / lineLength;
    return Rect.fromLTWH(
      rect.left + overlapStart * cellWidth,
      rect.top,
      math.max(1, (overlapEnd - overlapStart) * cellWidth),
      rect.height,
    );
  }

  List<_OcrLineBox> _lineBoxes(
    OcrTextBlock block,
    Rect imageRect,
    double scaleX,
    double scaleY,
  ) {
    if (block.lineGeometries.length != block.lines.length) return const [];
    final boxes = <_OcrLineBox>[];
    for (var index = 0; index < block.lines.length; index++) {
      final line = block.lines[index];
      if (line.trim().isEmpty) continue;
      final geo = block.lineGeometries[index];
      final rect = _normalizedRect(
        imageRect,
        geo.xmin,
        geo.ymin,
        geo.xmax,
        geo.ymax,
        scaleX,
        scaleY,
      );
      if (rect.isEmpty) continue;
      boxes.add(
        _OcrLineBox(
          text: line,
          rect: rect,
          vertical: block.vertical || _looksVertical(geo),
          rotation: geo.rotation,
        ),
      );
    }
    return boxes;
  }

  Rect _normalizedRect(
    Rect imageRect,
    double xmin,
    double ymin,
    double xmax,
    double ymax,
    double scaleX,
    double scaleY,
  ) {
    final center = Offset(
      imageRect.left + (xmin + xmax) * imageRect.width / 2,
      imageRect.top + (ymin + ymax) * imageRect.height / 2,
    );
    final size = Size(
      (xmax - xmin) * imageRect.width * scaleX,
      (ymax - ymin) * imageRect.height * scaleY,
    );
    return Rect.fromCenter(
      center: center,
      width: size.width,
      height: size.height,
    ).intersect(imageRect);
  }
}

class _ReaderOcrPage {
  const _ReaderOcrPage({
    required this.blocks,
    required this.opacity,
    required this.boxScaleX,
    required this.boxScaleY,
  });

  final List<OcrTextBlock> blocks;
  final double opacity;
  final double boxScaleX;
  final double boxScaleY;
}

List<int> _orderedLineIndices(OcrTextBlock block) {
  final indices = List.generate(block.lines.length, (index) => index);
  if (block.lines.length <= 1 ||
      block.lineGeometries.length != block.lines.length) {
    return indices;
  }
  if (block.vertical) {
    indices.sort((a, b) {
      final ax = block.lineGeometries[a].xmin + block.lineGeometries[a].xmax;
      final bx = block.lineGeometries[b].xmin + block.lineGeometries[b].xmax;
      return bx.compareTo(ax);
    });
  } else {
    indices.sort(
      (a, b) =>
          block.lineGeometries[a].ymin.compareTo(block.lineGeometries[b].ymin),
    );
  }
  return indices;
}

String _orderedBlock(OcrTextBlock block) =>
    _orderedLineIndices(block).map((index) => block.lines[index]).join();

int _toOrderedOffset(OcrTextBlock block, int rawOffset) {
  var start = 0;
  var rawLine = 0;
  var inLine = 0;
  for (var index = 0; index < block.lines.length; index++) {
    if (rawOffset < start + block.lines[index].length) {
      rawLine = index;
      inLine = rawOffset - start;
      break;
    }
    start += block.lines[index].length;
  }
  final order = _orderedLineIndices(block);
  return order
          .takeWhile((index) => index != rawLine)
          .fold<int>(0, (sum, index) => sum + block.lines[index].length) +
      inLine;
}

int _characterOffset(OcrTextBlock block, Offset local, Size size) {
  if (block.lines.isEmpty) return 0;
  if (block.vertical) {
    final column =
        ((size.width - local.dx) / math.max(1, size.width / block.lines.length))
            .floor()
            .clamp(0, block.lines.length - 1);
    final line = block.lines[column];
    final character =
        (local.dy / math.max(1, size.height / math.max(1, line.length)))
            .floor()
            .clamp(0, math.max(0, line.length - 1));
    return (block.lines
                .take(column)
                .fold<int>(0, (sum, value) => sum + value.length) +
            character)
        .toInt();
  }
  final row = (local.dy / math.max(1, size.height / block.lines.length))
      .floor()
      .clamp(0, block.lines.length - 1);
  final line = block.lines[row];
  final character =
      (local.dx / math.max(1, size.width / math.max(1, line.length)))
          .floor()
          .clamp(0, math.max(0, line.length - 1));
  return (block.lines
              .take(row)
              .fold<int>(0, (sum, value) => sum + value.length) +
          character)
      .toInt();
}

// ignore: unused_element
String _extractLookupString(String text, int start) {
  final stop = RegExp(r'[\s。、！？「」『』（）\[\]・,.;:!?]');
  final buffer = StringBuffer();
  for (var index = start; index < text.length && buffer.length < 80; index++) {
    if (stop.hasMatch(text[index])) break;
    buffer.write(text[index]);
  }
  return buffer.toString();
}

String _extractOcrLookupString(String text, int start) {
  final buffer = StringBuffer();
  for (var index = start; index < text.length && buffer.length < 80; index++) {
    if (!_isLookupStartChar(text[index])) break;
    buffer.write(text[index]);
  }
  return buffer.toString();
}

bool _isLookupStartChar(String char) {
  if (char.trim().isEmpty) return false;
  final code = char.runes.first;
  if ((code >= 0x21 && code <= 0x2f) ||
      (code >= 0x3a && code <= 0x40) ||
      (code >= 0x5b && code <= 0x60) ||
      (code >= 0x7b && code <= 0x7e)) {
    return false;
  }
  if ((code >= 0x3000 && code <= 0x303f) ||
      (code >= 0xff01 && code <= 0xff0f) ||
      (code >= 0xff1a && code <= 0xff20) ||
      (code >= 0xff3b && code <= 0xff40) ||
      (code >= 0xff5b && code <= 0xff65)) {
    return false;
  }
  return true;
}

bool _looksVertical(OcrLineGeometry geo) {
  final width = geo.xmax - geo.xmin;
  if (width <= 0) return false;
  return (geo.ymax - geo.ymin) / width > 1.2;
}

Rect readerOcrHitTestImageRect({
  required Rect paintedImageRect,
  required Size renderBoxSize,
  required bool normalizePaintCoordinates,
}) {
  if (!normalizePaintCoordinates) return paintedImageRect;
  return Alignment.center.inscribe(
    paintedImageRect.size,
    Offset.zero & renderBoxSize,
  );
}

@visibleForTesting
bool readerOcrShouldConsumeMissedTap({
  required bool popupWasVisibleOnPointerDown,
  required bool dismissedPopup,
}) => popupWasVisibleOnPointerDown || dismissedPopup;

@visibleForTesting
bool readerOcrShouldDismissRepeatedLookup({
  required bool popupVisible,
  required bool triggeredByHover,
  required bool sameBlock,
  required int activeOffset,
  required int hitOffset,
}) =>
    popupVisible && !triggeredByHover && sameBlock && activeOffset == hitOffset;

class _OcrLineBox {
  const _OcrLineBox({
    required this.text,
    required this.rect,
    required this.vertical,
    required this.rotation,
  });

  final String text;
  final Rect rect;
  final bool vertical;
  final double rotation;
}

class _PaintedOcrBlock {
  const _PaintedOcrBlock({
    required this.block,
    required this.rect,
    required this.lineBoxes,
  });

  final OcrTextBlock block;
  final Rect rect;
  final List<_OcrLineBox> lineBoxes;
}

class _OcrTapHit {
  const _OcrTapHit({
    required this.block,
    required this.rawOffset,
    required this.blockRect,
    required this.vertical,
    this.blockRectIsGlobal = false,
  });

  final OcrTextBlock block;
  final int rawOffset;
  final Rect blockRect;
  final bool vertical;
  final bool blockRectIsGlobal;
}

class _GlobalOcrHit {
  const _GlobalOcrHit({
    required this.controller,
    required this.context,
    required this.tapHit,
    required this.globalBlockRect,
  });

  final ReaderOcrController controller;
  final BuildContext context;
  final _OcrTapHit tapHit;
  final Rect globalBlockRect;

  double get globalBlockRectArea =>
      globalBlockRect.width.abs() * globalBlockRect.height.abs();
}
