import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mangayomi/modules/manga/reader/u_chap_data_preload.dart';
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
  static bool _initialized = false;
  static final Set<ReaderOcrController> _controllers = {};
  static final progress = ValueNotifier<ReaderOcrProgress?>(null);
  static int _scanGeneration = 0;
  static List<UChapDataPreload> _lastScanPages = const [];
  static int _lastStartIndex = 0;
  static Future<void> Function(UChapDataPreload)? _lastPreparePage;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    enabled.value = await MiningPreferences.getOcrOverlayEnabled();
  }

  static Future<void> setEnabled(bool value) async {
    enabled.value = value;
    await MiningPreferences.setOcrOverlayEnabled(value);
    if (!value) {
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

  static Future<bool> handleTap(Offset globalPosition) async {
    if (!enabled.value) return false;
    for (final controller in _controllers.toList().reversed) {
      if (await controller.handleGlobalTap(globalPosition)) return true;
    }
    clearActive();
    return false;
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
    ReaderOcrState._controllers.add(this);
    ReaderOcrState.initialize();
  }

  static final Map<String, Future<_ReaderOcrPage>> _cache = {};

  final UChapDataPreload data;
  final GlobalKey imageKey;
  _ReaderOcrPage? _page;
  Rect? _imageRect;
  OcrTextBlock? _activeBlock;
  int _activeOffset = -1;
  int _matchLength = 0;
  Color _highlightColor = const Color(0xff8ab4f8);
  Color _outlineColor = const Color(0xff8ab4f8);
  bool _loading = false;
  bool _disposed = false;

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

  void paint(Canvas canvas, Rect imageRect, ui.Image image, Paint paint) {
    _imageRect = imageRect;
    final page = _page;
    if (!enabled) return;
    if (page == null) return;
    for (final block in page.blocks) {
      final rect = _blockRect(block, imageRect, page.boxScaleX, page.boxScaleY);
      if (rect.isEmpty) continue;
      final active = identical(block, _activeBlock);
      final lineBoxes = _lineBoxes(
        block,
        imageRect,
        page.boxScaleX,
        page.boxScaleY,
      );
      if (lineBoxes.isEmpty) {
        _paintOcrBox(
          canvas: canvas,
          rect: rect,
          text: _orderedBlock(block),
          vertical: block.vertical,
          active: active,
          opacity: page.opacity,
          outlineVisible: page.outlineVisible,
          highlight: active
              ? _lineHighlightFor(
                  lineStart: 0,
                  lineLength: _orderedBlock(block).length,
                  rect: rect,
                  vertical: block.vertical,
                )
              : null,
        );
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
          outlineVisible: page.outlineVisible,
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
    }
  }

  Future<bool> handleTap(BuildContext context, Offset localPosition) async {
    final page = _page;
    final imageRect = _imageRect;
    if (!enabled || page == null || imageRect == null) return false;
    for (final block in page.blocks.reversed) {
      final rect = _blockRect(block, imageRect, page.boxScaleX, page.boxScaleY);
      final hit = _hitTestBlock(
        block,
        localPosition,
        imageRect,
        page.boxScaleX,
        page.boxScaleY,
      );
      if (hit == null && !rect.contains(localPosition)) continue;
      final rawOffset =
          hit?.rawOffset ??
          _characterOffset(block, localPosition - rect.topLeft, rect.size);
      final ordered = _orderedBlock(block);
      if (ordered.isEmpty) return true;
      final orderedOffset = _toOrderedOffset(
        block,
        rawOffset,
      ).clamp(0, ordered.length - 1);
      if (!_isLookupStartChar(ordered[orderedOffset])) {
        _activeBlock = block;
        _activeOffset = rawOffset;
        _matchLength = 0;
        notifyListeners();
        return true;
      }
      final lookup = _extractOcrLookupString(ordered, orderedOffset);
      _activeBlock = block;
      _activeOffset = rawOffset;
      _matchLength = 0;
      notifyListeners();
      if (lookup.isEmpty || !context.mounted) return true;

      final box = context.findRenderObject() as RenderBox?;
      final topLeft = box?.localToGlobal(rect.topLeft) ?? rect.topLeft;
      final bottomRight =
          box?.localToGlobal(rect.bottomRight) ?? rect.bottomRight;
      final bytes = data.cropImage ?? await data.getImageBytes;
      if (!context.mounted) return true;
      await DictionaryLookupPopup.show(
        context: context,
        anchor: Rect.fromPoints(topLeft, bottomRight),
        text: lookup,
        miningContext: MiningContext(
          mediaType: MiningMediaType.manga,
          sourceTitle: data.chapter?.manga.value?.name ?? data.mangaName ?? '',
          chapterTitle: data.chapter?.name ?? '',
          sentence: ordered,
          pageIndex: data.pageIndex,
          sourceUri: Uri.tryParse(data.pageUrl?.url ?? ''),
          imageBytesLoader: () async => bytes,
        ),
        onMatchChanged: (length) {
          _matchLength = math.max(0, length);
          if (!_disposed) notifyListeners();
        },
      );
      return true;
    }
    return false;
  }

  Future<bool> handleGlobalTap(Offset globalPosition) async {
    final imageContext = imageKey.currentContext;
    final box = imageContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return false;
    final localPosition = box.globalToLocal(globalPosition);
    if (!(Offset.zero & box.size).contains(localPosition)) return false;
    return handleTap(imageContext!, localPosition);
  }

  void _enabledChanged() {
    if (enabled) load();
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
      MiningPreferences.getOcrOutlineVisible(),
    ]);
    final opacity = values[0] as double;
    final boxScaleX = values[1] as double;
    final boxScaleY = values[2] as double;
    final outlineVisible = values[3] as bool;

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
            outlineVisible: outlineVisible,
          );
        }
      }
      if (engine == OcrEnginePreference.mokuroOnly) {
        return _ReaderOcrPage(
          blocks: const [],
          opacity: opacity,
          boxScaleX: boxScaleX,
          boxScaleY: boxScaleY,
          outlineVisible: outlineVisible,
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
              outlineVisible: outlineVisible,
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
        outlineVisible: outlineVisible,
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
    required bool outlineVisible,
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
    if (outlineVisible && active) {
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = active ? 2 : 1
          ..color = active ? _outlineColor : Colors.transparent,
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

  _OcrHit? _hitTestBlock(
    OcrTextBlock block,
    Offset localPosition,
    Rect imageRect,
    double scaleX,
    double scaleY,
  ) {
    final boxes = _lineBoxes(block, imageRect, scaleX, scaleY);
    var lineStart = 0;
    for (final box in boxes) {
      final line = box.text;
      if (box.rect.contains(localPosition)) {
        final local = localPosition - box.rect.topLeft;
        final char = box.vertical
            ? (local.dy /
                      math.max(1, box.rect.height / math.max(1, line.length)))
                  .floor()
                  .clamp(0, math.max(0, line.length - 1))
            : (local.dx /
                      math.max(1, box.rect.width / math.max(1, line.length)))
                  .floor()
                  .clamp(0, math.max(0, line.length - 1));
        return _OcrHit(lineStart + char.toInt());
      }
      lineStart += line.length;
    }
    return null;
  }
}

class _ReaderOcrPage {
  const _ReaderOcrPage({
    required this.blocks,
    required this.opacity,
    required this.boxScaleX,
    required this.boxScaleY,
    required this.outlineVisible,
  });

  final List<OcrTextBlock> blocks;
  final double opacity;
  final double boxScaleX;
  final double boxScaleY;
  final bool outlineVisible;
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

class _OcrHit {
  const _OcrHit(this.rawOffset);

  final int rawOffset;
}
