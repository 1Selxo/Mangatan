import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/modules/manga/reader/u_chap_data_preload.dart';
import 'package:mangayomi/modules/mining/widgets/mining_lookup_sheet.dart';
import 'package:mangayomi/services/mining/chrome_lens_ocr.dart';
import 'package:mangayomi/services/mining/mining_models.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';
import 'package:mangayomi/services/mining/mokuro_parser.dart';
import 'package:mangayomi/services/mining/ocr_models.dart';

class OcrOverlaySheet extends StatefulWidget {
  final Uint8List imageBytes;
  final UChapDataPreload data;
  final Manga manga;
  final String chapterName;

  const OcrOverlaySheet({
    super.key,
    required this.imageBytes,
    required this.data,
    required this.manga,
    required this.chapterName,
  });

  static Future<void> show({
    required BuildContext context,
    required Uint8List imageBytes,
    required UChapDataPreload data,
    required Manga manga,
    required String chapterName,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => OcrOverlaySheet(
          imageBytes: imageBytes,
          data: data,
          manga: manga,
          chapterName: chapterName,
        ),
      ),
    );
  }

  @override
  State<OcrOverlaySheet> createState() => _OcrOverlaySheetState();
}

class _OcrOverlaySheetState extends State<OcrOverlaySheet> {
  late Future<_OcrPageData> _future = _loadOcrData();
  bool _showText = true;

  void _reload() {
    setState(() => _future = _loadOcrData(forceLens: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.88),
        foregroundColor: Colors.white,
        title: const Text('OCR overlay'),
        actions: [
          IconButton(
            tooltip: _showText
                ? 'Hide recognized text'
                : 'Show recognized text',
            onPressed: () => setState(() => _showText = !_showText),
            icon: Icon(_showText ? Icons.visibility : Icons.visibility_off),
          ),
          IconButton(
            tooltip: 'Run Google Lens OCR',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_OcrPageData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(widget.imageBytes, fit: BoxFit.contain),
                const Center(child: CircularProgressIndicator()),
              ],
            );
          }
          if (snapshot.hasError) {
            return _OcrMessage(
              imageBytes: widget.imageBytes,
              message: 'OCR failed\n${snapshot.error}',
            );
          }
          final page = snapshot.data!;
          if (page.blocks.isEmpty) {
            return _OcrMessage(
              imageBytes: widget.imageBytes,
              message: 'No text was detected',
            );
          }
          return _OcrViewport(
            imageBytes: widget.imageBytes,
            page: page,
            showText: _showText,
            miningContext: _contextFor(''),
          );
        },
      ),
    );
  }

  MiningContext _contextFor(String sentence) {
    return MiningContext(
      mediaType: MiningMediaType.manga,
      sourceTitle: widget.manga.name ?? '',
      chapterTitle: widget.chapterName,
      sentence: sentence,
      pageIndex: widget.data.pageIndex,
      sourceUri: Uri.tryParse(widget.data.pageUrl?.url ?? ''),
      imageBytesLoader: () async => widget.imageBytes,
    );
  }

  Future<_OcrPageData> _loadOcrData({bool forceLens = false}) async {
    final values = await Future.wait<dynamic>([
      MiningPreferences.getOcrEngine(),
      MiningPreferences.getOcrLanguage(),
      MiningPreferences.getOcrOverlayOpacity(),
      MiningPreferences.getOcrBoxScale(),
      MiningPreferences.getOcrOutlineVisible(),
    ]);
    final engine = values[0] as OcrEnginePreference;
    final language = values[1] as String;
    final opacity = values[2] as double;
    final boxScale = values[3] as double;
    final outlineVisible = values[4] as bool;

    if (!forceLens && engine != OcrEnginePreference.googleLens) {
      const parser = MokuroParser();
      final volume = await parser.findForReaderPage(widget.data);
      final page = volume == null
          ? null
          : parser.resolvePage(volume, data: widget.data);
      if (page != null) {
        final blocks = parser.convertPage(page);
        if (blocks.isNotEmpty || engine == OcrEnginePreference.mokuroOnly) {
          return _OcrPageData(
            imageWidth: page.imageWidth,
            imageHeight: page.imageHeight,
            blocks: blocks,
            opacity: opacity,
            boxScale: boxScale,
            outlineVisible: outlineVisible,
          );
        }
      }
      if (engine == OcrEnginePreference.mokuroOnly) {
        final size = await _decodeImageSize(widget.imageBytes);
        return _OcrPageData(
          imageWidth: size.$1,
          imageHeight: size.$2,
          blocks: const [],
          opacity: opacity,
          boxScale: boxScale,
          outlineVisible: outlineVisible,
        );
      }
    }

    final client = ChromeLensOcrClient();
    try {
      final result = await client.recognize(
        widget.imageBytes,
        language: language,
      );
      return _OcrPageData(
        imageWidth: result.imageWidth,
        imageHeight: result.imageHeight,
        blocks: result.blocks,
        opacity: opacity,
        boxScale: boxScale,
        outlineVisible: outlineVisible,
      );
    } finally {
      client.close();
    }
  }

  Future<(int, int)> _decodeImageSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final size = (frame.image.width, frame.image.height);
    frame.image.dispose();
    codec.dispose();
    return size;
  }
}

class _OcrViewport extends StatefulWidget {
  final Uint8List imageBytes;
  final _OcrPageData page;
  final bool showText;
  final MiningContext miningContext;

  const _OcrViewport({
    required this.imageBytes,
    required this.page,
    required this.showText,
    required this.miningContext,
  });

  @override
  State<_OcrViewport> createState() => _OcrViewportState();
}

class _OcrViewportState extends State<_OcrViewport> {
  OcrTextBlock? _activeBlock;
  int _activeOffset = -1;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageSize = Size(
          widget.page.imageWidth.toDouble(),
          widget.page.imageHeight.toDouble(),
        );
        final fitted = applyBoxFit(
          BoxFit.contain,
          imageSize,
          constraints.biggest,
        ).destination;
        return InteractiveViewer(
          constrained: false,
          alignment: Alignment.center,
          minScale: 1,
          maxScale: 8,
          boundaryMargin: const EdgeInsets.all(80),
          child: SizedBox(
            width: fitted.width,
            height: fitted.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(widget.imageBytes, fit: BoxFit.fill),
                if (widget.showText)
                  for (final block in widget.page.blocks)
                    _buildBlock(context, block, fitted),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBlock(BuildContext context, OcrTextBlock block, Size canvas) {
    final centerX = (block.xmin + block.xmax) * canvas.width / 2;
    final centerY = (block.ymin + block.ymax) * canvas.height / 2;
    final width =
        (block.xmax - block.xmin) * canvas.width * widget.page.boxScale;
    final height =
        (block.ymax - block.ymin) * canvas.height * widget.page.boxScale;
    final left = (centerX - width / 2).clamp(0, canvas.width - 1).toDouble();
    final top = (centerY - height / 2).clamp(0, canvas.height - 1).toDouble();
    final safeWidth = math.min(width, canvas.width - left);
    final safeHeight = math.min(height, canvas.height - top);
    final active = identical(_activeBlock, block);

    return Positioned(
      left: left,
      top: top,
      width: safeWidth,
      height: safeHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) =>
            _lookupAt(block, details.localPosition, safeWidth, safeHeight),
        onLongPress: () => _showSelection(block),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: widget.page.outlineVisible
                ? Border.all(
                    color: active ? Colors.amber : const Color(0xff00aaff),
                    width: active ? 2 : 1,
                  )
                : null,
          ),
          child: _BlockText(
            block: block,
            activeOffset: active ? _activeOffset : -1,
            opacity: active
                ? math.max(0.86, widget.page.opacity)
                : widget.page.opacity,
          ),
        ),
      ),
    );
  }

  Future<void> _lookupAt(
    OcrTextBlock block,
    Offset local,
    double width,
    double height,
  ) async {
    final rawOffset = _uniformCharOffset(block, local, width, height);
    final ordered = _orderedBlock(block);
    final orderedOffset = _toOrderedOffset(block, rawOffset);
    if (ordered.isEmpty) return;
    final safeOffset = orderedOffset.clamp(0, ordered.length - 1);
    final lookup = _extractLookupString(ordered, safeOffset);
    setState(() {
      _activeBlock = block;
      _activeOffset = rawOffset;
    });
    if (lookup.isEmpty || !mounted) return;
    await MiningLookupSheet.show(
      context: context,
      text: lookup,
      miningContext: widget.miningContext.copyWith(sentence: ordered),
    );
  }

  Future<void> _showSelection(OcrTextBlock block) async {
    final text = _orderedBlock(block);
    if (text.isEmpty) return;
    setState(() {
      _activeBlock = block;
      _activeOffset = -1;
    });
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText(
                text,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  MiningLookupSheet.show(
                    context: this.context,
                    text: text,
                    miningContext: widget.miningContext.copyWith(
                      sentence: text,
                    ),
                  );
                },
                icon: const Icon(Icons.manage_search),
                label: const Text('Lookup'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockText extends StatelessWidget {
  final OcrTextBlock block;
  final int activeOffset;
  final double opacity;

  const _BlockText({
    required this.block,
    required this.activeOffset,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    if (block.lineGeometries.length == block.lines.length &&
        block.lines.length > 1) {
      return LayoutBuilder(
        builder: (context, constraints) => Stack(
          fit: StackFit.expand,
          children: [
            for (var index = 0; index < block.lines.length; index++)
              _positionedLine(index, constraints.biggest),
          ],
        ),
      );
    }
    return _FittedOcrText(
      text: block.text.replaceAll('\n', ''),
      vertical: block.vertical,
      activeIndex: activeOffset,
      opacity: opacity,
    );
  }

  Widget _positionedLine(int index, Size size) {
    final geometry = block.lineGeometries[index];
    final blockWidth = math.max(0.0001, block.xmax - block.xmin);
    final blockHeight = math.max(0.0001, block.ymax - block.ymin);
    final start = block.lines
        .take(index)
        .fold<int>(0, (sum, line) => sum + line.length);
    final activeIndex =
        activeOffset >= start &&
            activeOffset < start + block.lines[index].length
        ? activeOffset - start
        : -1;
    final vertical =
        block.vertical ||
        (geometry.ymax - geometry.ymin) > (geometry.xmax - geometry.xmin) * 1.2;
    return Positioned(
      left: ((geometry.xmin - block.xmin) / blockWidth * size.width)
          .clamp(0, size.width)
          .toDouble(),
      top: ((geometry.ymin - block.ymin) / blockHeight * size.height)
          .clamp(0, size.height)
          .toDouble(),
      right: ((block.xmax - geometry.xmax) / blockWidth * size.width)
          .clamp(0, size.width)
          .toDouble(),
      bottom: ((block.ymax - geometry.ymax) / blockHeight * size.height)
          .clamp(0, size.height)
          .toDouble(),
      child: _FittedOcrText(
        text: block.lines[index],
        vertical: vertical,
        activeIndex: activeIndex,
        opacity: opacity,
      ),
    );
  }
}

class _FittedOcrText extends StatelessWidget {
  final String text;
  final bool vertical;
  final int activeIndex;
  final double opacity;

  const _FittedOcrText({
    required this.text,
    required this.vertical,
    required this.activeIndex,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    final background = Colors.white.withValues(alpha: opacity);
    final child = vertical
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < text.length; index++)
                ColoredBox(
                  color: index == activeIndex
                      ? Colors.amberAccent
                      : Colors.transparent,
                  child: Text(
                    text[index],
                    style: const TextStyle(color: Colors.black, height: 1),
                  ),
                ),
            ],
          )
        : Text.rich(
            TextSpan(
              children: [
                for (var index = 0; index < text.length; index++)
                  TextSpan(
                    text: text[index],
                    style: TextStyle(
                      backgroundColor: index == activeIndex
                          ? Colors.amberAccent
                          : null,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            softWrap: false,
            style: const TextStyle(color: Colors.black, height: 1),
          );
    return ColoredBox(
      color: background,
      child: FittedBox(fit: BoxFit.contain, child: child),
    );
  }
}

class _OcrMessage extends StatelessWidget {
  final Uint8List imageBytes;
  final String message;

  const _OcrMessage({required this.imageBytes, required this.message});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(imageBytes, fit: BoxFit.contain),
        Center(
          child: Container(
            color: Colors.black.withValues(alpha: 0.82),
            padding: const EdgeInsets.all(16),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _OcrPageData {
  final int imageWidth;
  final int imageHeight;
  final List<OcrTextBlock> blocks;
  final double opacity;
  final double boxScale;
  final bool outlineVisible;

  const _OcrPageData({
    required this.imageWidth,
    required this.imageHeight,
    required this.blocks,
    required this.opacity,
    required this.boxScale,
    required this.outlineVisible,
  });
}

List<int> _orderedLineIndices(OcrTextBlock block) {
  if (block.lines.length <= 1 ||
      block.lineGeometries.length != block.lines.length) {
    return List.generate(block.lines.length, (index) => index);
  }
  final indices = List.generate(block.lines.length, (index) => index);
  if (block.vertical) {
    indices.sort((a, b) {
      final aCenter =
          (block.lineGeometries[a].xmin + block.lineGeometries[a].xmax) / 2;
      final bCenter =
          (block.lineGeometries[b].xmin + block.lineGeometries[b].xmax) / 2;
      final horizontal = bCenter.compareTo(aCenter);
      return horizontal != 0
          ? horizontal
          : block.lineGeometries[a].ymin.compareTo(
              block.lineGeometries[b].ymin,
            );
    });
  } else {
    indices.sort((a, b) {
      final aCenter =
          (block.lineGeometries[a].ymin + block.lineGeometries[a].ymax) / 2;
      final bCenter =
          (block.lineGeometries[b].ymin + block.lineGeometries[b].ymax) / 2;
      final vertical = aCenter.compareTo(bCenter);
      return vertical != 0
          ? vertical
          : block.lineGeometries[a].xmin.compareTo(
              block.lineGeometries[b].xmin,
            );
    });
  }
  return indices;
}

String _orderedBlock(OcrTextBlock block) {
  return _orderedLineIndices(block).map((index) => block.lines[index]).join();
}

int _toOrderedOffset(OcrTextBlock block, int rawOffset) {
  var rawStart = 0;
  var rawLine = 0;
  var offsetInLine = 0;
  for (var index = 0; index < block.lines.length; index++) {
    final end = rawStart + block.lines[index].length;
    if (rawOffset < end) {
      rawLine = index;
      offsetInLine = rawOffset - rawStart;
      break;
    }
    rawStart = end;
  }
  final order = _orderedLineIndices(block);
  final orderedStart = order
      .takeWhile((index) => index != rawLine)
      .fold<int>(0, (sum, index) => sum + block.lines[index].length);
  return orderedStart + offsetInLine;
}

int _uniformCharOffset(
  OcrTextBlock block,
  Offset local,
  double width,
  double height,
) {
  if (block.lines.isEmpty) return 0;
  if (block.vertical) {
    final columnWidth = width / block.lines.length;
    final fromRight = (width - local.dx).clamp(0, width - 0.001);
    final column = (fromRight / math.max(1, columnWidth)).floor().clamp(
      0,
      block.lines.length - 1,
    );
    final line = block.lines[column];
    final rowHeight = height / math.max(1, line.length);
    final character = (local.dy / math.max(1, rowHeight)).floor().clamp(
      0,
      math.max(0, line.length - 1),
    );
    return (block.lines
                .take(column)
                .fold<int>(0, (sum, value) => sum + value.length) +
            character)
        .toInt();
  }
  final rowHeight = height / block.lines.length;
  final row = (local.dy / math.max(1, rowHeight)).floor().clamp(
    0,
    block.lines.length - 1,
  );
  final line = block.lines[row];
  final characterWidth = width / math.max(1, line.length);
  final character = (local.dx / math.max(1, characterWidth)).floor().clamp(
    0,
    math.max(0, line.length - 1),
  );
  return (block.lines
              .take(row)
              .fold<int>(0, (sum, value) => sum + value.length) +
          character)
      .toInt();
}

String _extractLookupString(String text, int start) {
  final stop = RegExp(r'[\s。、！？「」『』（）()\[\]【】…・,.;:!?]');
  final buffer = StringBuffer();
  for (var index = start; index < text.length && buffer.length < 80; index++) {
    final character = text[index];
    if (stop.hasMatch(character)) break;
    buffer.write(character);
  }
  return buffer.toString();
}
