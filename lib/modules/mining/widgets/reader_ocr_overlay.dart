import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mangayomi/eval/model/m_bridge.dart';
import 'package:mangayomi/modules/manga/reader/u_chap_data_preload.dart';
import 'package:mangayomi/modules/mining/widgets/dictionary_glossary.dart';
import 'package:mangayomi/services/hoshidicts/hoshidicts_backend.dart';
import 'package:mangayomi/services/mining/anki_card_builder.dart';
import 'package:mangayomi/services/mining/anki_connect_service.dart';
import 'package:mangayomi/services/mining/chrome_lens_ocr.dart';
import 'package:mangayomi/services/mining/mining_models.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';
import 'package:mangayomi/services/mining/mokuro_parser.dart';
import 'package:mangayomi/services/mining/ocr_models.dart';
import 'package:mangayomi/src/rust/api/hoshidicts.dart';
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
      final rect = _blockRect(block, imageRect, page.boxScale);
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
      final rect = _blockRect(block, imageRect, page.boxScale);
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
      ReaderOcrLookupPopup.show(
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
      MiningPreferences.getOcrBoxScale(),
      MiningPreferences.getOcrOutlineVisible(),
    ]);
    final opacity = values[0] as double;
    final boxScale = values[1] as double;
    final outlineVisible = values[2] as bool;

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
            boxScale: boxScale,
            outlineVisible: outlineVisible,
          );
        }
      }
      if (engine == OcrEnginePreference.mokuroOnly) {
        return _ReaderOcrPage(
          blocks: const [],
          opacity: opacity,
          boxScale: boxScale,
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
        boxScale: boxScale,
        outlineVisible: outlineVisible,
      );
    } finally {
      client.close();
    }
  }

  Rect _blockRect(OcrTextBlock block, Rect imageRect, double scale) {
    final center = Offset(
      imageRect.left + (block.xmin + block.xmax) * imageRect.width / 2,
      imageRect.top + (block.ymin + block.ymax) * imageRect.height / 2,
    );
    final size = Size(
      (block.xmax - block.xmin) * imageRect.width * scale,
      (block.ymax - block.ymin) * imageRect.height * scale,
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

class ReaderOcrLookupPopup extends StatefulWidget {
  const ReaderOcrLookupPopup({
    super.key,
    required this.text,
    required this.miningContext,
    required this.onMatchChanged,
    required this.onClose,
  });

  final String text;
  final MiningContext miningContext;
  final ValueChanged<int> onMatchChanged;
  final VoidCallback onClose;

  static void show({
    required BuildContext context,
    required Rect anchor,
    required String text,
    required MiningContext miningContext,
    required ValueChanged<int> onMatchChanged,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final screen = MediaQuery.sizeOf(context);
    final width = math.min(430.0, screen.width - 24);
    final height = math.min(360.0, screen.height * 0.48);
    final left = (anchor.center.dx - width / 2).clamp(
      12.0,
      screen.width - width - 12,
    );
    final below = anchor.bottom + 8;
    final top = below + height <= screen.height - 12
        ? below
        : math.max(12.0, anchor.top - height - 8);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: entry.remove,
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: width,
            height: height,
            child: ReaderOcrLookupPopup(
              text: text,
              miningContext: miningContext,
              onMatchChanged: onMatchChanged,
              onClose: entry.remove,
            ),
          ),
        ],
      ),
    );
    overlay.insert(entry);
  }

  @override
  State<ReaderOcrLookupPopup> createState() => _ReaderOcrLookupPopupState();
}

class _ReaderOcrLookupPopupState extends State<ReaderOcrLookupPopup> {
  late final Future<_LookupPayload> _results = _lookup();
  bool _exporting = false;

  Future<_LookupPayload> _lookup() async {
    final results = await HoshidictsLookupBackend.instance.lookup(
      widget.text,
      maxResults: 20,
      scanLength: 80,
    );
    if (results.isNotEmpty) widget.onMatchChanged(results.first.matched.length);
    List<HoshiDictionaryStyle> styles;
    try {
      styles = await HoshidictsLookupBackend.instance.getStyles();
    } catch (_) {
      styles = const [];
    }
    return _LookupPayload(
      results: results,
      styles: {for (final style in styles) style.dictName: style.styles},
    );
  }

  Future<void> _export(HoshiLookupResult result) async {
    setState(() => _exporting = true);
    try {
      final profile = await MiningPreferences.getAnkiProfile();
      final draft = await const AnkiCardBuilder().build(
        result: result,
        context: widget.miningContext,
        profile: profile,
      );
      final noteId =
          await AnkiConnectService(
            endpoint: await MiningPreferences.getAnkiEndpoint(),
          ).exportDraft(
            draft,
            duplicateCheck: profile.duplicateCheck,
            syncOnCreate: profile.syncOnCreate,
          );
      botToast('Added to Anki (#$noteId)', second: 3);
    } catch (error) {
      botToast('Anki export failed: $error', second: 5);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(8),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.manage_search, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<_LookupPayload>(
              future: _results,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Lookup failed: ${snapshot.error}'),
                  );
                }
                final payload = snapshot.data;
                final results = payload?.results ?? const [];
                if (results.isEmpty) {
                  return const Center(
                    child: Text('No dictionary results found.'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final result = results[index];
                    final term = result.term;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: term.expression,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (term.reading.isNotEmpty)
                                        TextSpan(text: '  ${term.reading}'),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 3),
                                for (final glossary in term.glossaries.take(3))
                                  DictionaryGlossary(
                                    rawGlossary: glossary.glossary,
                                    dictionaryName: glossary.dictName,
                                    dictionaryCss:
                                        payload?.styles[glossary.dictName] ??
                                        '',
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Add to Anki',
                            onPressed: _exporting
                                ? null
                                : () => _export(result),
                            icon: const Icon(Icons.note_add_outlined, size: 20),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LookupPayload {
  const _LookupPayload({required this.results, required this.styles});

  final List<HoshiLookupResult> results;
  final Map<String, String> styles;
}

class _ReaderOcrPage {
  const _ReaderOcrPage({
    required this.blocks,
    required this.opacity,
    required this.boxScale,
    required this.outlineVisible,
  });

  final List<OcrTextBlock> blocks;
  final double opacity;
  final double boxScale;
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
