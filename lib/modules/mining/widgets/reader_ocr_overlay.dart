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
import 'package:mangayomi/utils/extensions/others.dart';

class ReaderOcrState {
  ReaderOcrState._();

  static final enabled = ValueNotifier<bool>(true);
  static bool _initialized = false;
  static final Set<ReaderOcrController> _controllers = {};

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    enabled.value = await MiningPreferences.getOcrOverlayEnabled();
  }

  static Future<void> setEnabled(bool value) async {
    enabled.value = value;
    await MiningPreferences.setOcrOverlayEnabled(value);
  }

  static Future<void> toggle() => setEnabled(!enabled.value);

  static Future<bool> handleTap(Offset globalPosition) async {
    if (!enabled.value) return false;
    for (final controller in _controllers.toList().reversed) {
      if (await controller.handleGlobalTap(globalPosition)) return true;
    }
    return false;
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
  int _matchLength = 1;
  bool _loading = false;
  bool _disposed = false;

  bool get enabled => ReaderOcrState.enabled.value;

  Future<void> load() async {
    if (!enabled || _loading || _page != null || data.isTransitionPage) return;
    _loading = true;
    String? cacheKey;
    try {
      final engine = await MiningPreferences.getOcrEngine();
      final language = await MiningPreferences.getOcrLanguage();
      final key =
          '${data.pageUrl?.url ?? data.directory?.path ?? ''}:'
          '${data.chapter?.id}:${data.index}:${data.pageIndex}:'
          '${engine.name}:$language';
      cacheKey = key;
      final page = await _cache.putIfAbsent(
        key,
        () => _recognize(data, engine: engine, language: language),
      );
      if (!_disposed) {
        _page = page;
        notifyListeners();
      }
    } catch (_) {
      if (cacheKey != null) _cache.remove(cacheKey);
      // A failed page stays unobtrusive in the reader and can retry when rebuilt.
    } finally {
      _loading = false;
    }
  }

  void paint(Canvas canvas, Rect imageRect, ui.Image image, Paint paint) {
    _imageRect = imageRect;
    final page = _page;
    if (!enabled || page == null) return;
    for (final block in page.blocks) {
      final rect = _blockRect(block, imageRect, page.boxScaleX, page.boxScaleY);
      if (rect.isEmpty) continue;
      final active = identical(block, _activeBlock);
      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.white.withValues(
            alpha: active ? math.max(0.86, page.opacity) : page.opacity,
          ),
      );
      if (active && _activeOffset >= 0) {
        _paintHighlight(canvas, rect, block);
      }
      if (page.outlineVisible) {
        canvas.drawRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = active ? 2 : 1
            ..color = active ? Colors.amber.shade700 : const Color(0xff168bd2),
        );
      }
      _paintText(canvas, rect, block);
    }
  }

  Future<bool> handleTap(BuildContext context, Offset localPosition) async {
    final page = _page;
    final imageRect = _imageRect;
    if (!enabled || page == null || imageRect == null) return false;
    for (final block in page.blocks.reversed) {
      final rect = _blockRect(block, imageRect, page.boxScaleX, page.boxScaleY);
      if (!rect.contains(localPosition)) continue;
      final rawOffset = _characterOffset(
        block,
        localPosition - rect.topLeft,
        rect.size,
      );
      final ordered = _orderedBlock(block);
      if (ordered.isEmpty) return true;
      final orderedOffset = _toOrderedOffset(
        block,
        rawOffset,
      ).clamp(0, ordered.length - 1);
      final lookup = _extractLookupString(ordered, orderedOffset);
      _activeBlock = block;
      _activeOffset = rawOffset;
      _matchLength = 1;
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
          _matchLength = math.max(1, length);
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

    if (engine != OcrEnginePreference.googleLens) {
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
    final client = ChromeLensOcrClient();
    try {
      final result = await client.recognize(bytes, language: language);
      return _ReaderOcrPage(
        blocks: result.blocks,
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

  void _paintText(Canvas canvas, Rect rect, OcrTextBlock block) {
    final text = block.vertical
        ? _orderedBlock(block).split('').join('\n')
        : _orderedBlock(block);
    if (text.isEmpty) return;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.black, fontSize: 20, height: 1),
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

  void _paintHighlight(Canvas canvas, Rect rect, OcrTextBlock block) {
    final length = math.min(
      _matchLength,
      math.max(1, _orderedBlock(block).length),
    );
    Rect highlight;
    if (block.vertical) {
      final chars = math.max(1, _orderedBlock(block).length);
      final cellHeight = rect.height / chars;
      highlight = Rect.fromLTWH(
        rect.left,
        rect.top + _activeOffset.clamp(0, chars - 1) * cellHeight,
        rect.width,
        math.min(rect.height, cellHeight * length),
      );
    } else {
      final chars = math.max(1, _orderedBlock(block).length);
      final cellWidth = rect.width / chars;
      highlight = Rect.fromLTWH(
        rect.left + _activeOffset.clamp(0, chars - 1) * cellWidth,
        rect.top,
        math.min(rect.width, cellWidth * length),
        rect.height,
      );
    }
    canvas.drawRect(
      highlight.intersect(rect),
      Paint()..color = Colors.amberAccent,
    );
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

String _extractLookupString(String text, int start) {
  final stop = RegExp(r'[\s。、！？「」『』（）\[\]・,.;:!?]');
  final buffer = StringBuffer();
  for (var index = start; index < text.length && buffer.length < 80; index++) {
    if (stop.hasMatch(text[index])) break;
    buffer.write(text[index]);
  }
  return buffer.toString();
}
