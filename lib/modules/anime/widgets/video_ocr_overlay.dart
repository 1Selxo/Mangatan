import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mangayomi/modules/mining/widgets/dictionary_lookup_popup.dart';
import 'package:mangayomi/services/mining/chrome_lens_ocr.dart';
import 'package:mangayomi/services/mining/dictionary_profile_resolver.dart';
import 'package:mangayomi/services/mining/mining_models.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';
import 'package:mangayomi/services/mining/ocr_block_merger.dart';
import 'package:mangayomi/services/mining/ocr_models.dart';
import 'package:mangayomi/services/mining/profile_ocr_language.dart';
import 'package:mangayomi/services/mining/screen_ai_ocr.dart';

class VideoOcrResult {
  const VideoOcrResult({
    required this.imageWidth,
    required this.imageHeight,
    required this.blocks,
  });

  final int imageWidth;
  final int imageHeight;
  final List<OcrTextBlock> blocks;
}

Future<VideoOcrResult> recognizeVideoFrame(
  Uint8List bytes, {
  String? language,
}) async {
  final engine = await MiningPreferences.getOcrEngine();
  final effectiveLanguage =
      language ?? await MiningPreferences.getOcrLanguage();

  final tryScreenAi =
      engine == OcrEnginePreference.screenAi ||
      (engine == OcrEnginePreference.automatic &&
          await ScreenAiOcrClient.isAvailable());
  if (tryScreenAi) {
    final client = ScreenAiOcrClient();
    try {
      final result = await client.recognize(bytes);
      if (result.blocks.isNotEmpty || engine == OcrEnginePreference.screenAi) {
        return VideoOcrResult(
          imageWidth: result.imageWidth,
          imageHeight: result.imageHeight,
          blocks: mergeOcrBlocks(result.blocks, language: effectiveLanguage),
        );
      }
    } catch (_) {
      if (engine == OcrEnginePreference.screenAi) rethrow;
    } finally {
      client.close();
    }
  }

  if (engine == OcrEnginePreference.mokuroOnly) {
    throw StateError('Video OCR requires ScreenAI or Google Lens');
  }
  final client = ChromeLensOcrClient();
  try {
    final result = await client.recognize(bytes, language: effectiveLanguage);
    return VideoOcrResult(
      imageWidth: result.imageWidth,
      imageHeight: result.imageHeight,
      blocks: mergeOcrBlocks(result.blocks, language: effectiveLanguage),
    );
  } finally {
    client.close();
  }
}

class VideoOcrOverlay extends StatefulWidget {
  const VideoOcrOverlay({
    super.key,
    required this.imageBytes,
    required this.fit,
    required this.miningContextBuilder,
    required this.onDismiss,
  });

  final Uint8List imageBytes;
  final BoxFit fit;
  final Future<MiningContext> Function(String text) miningContextBuilder;
  final VoidCallback onDismiss;

  @override
  State<VideoOcrOverlay> createState() => _VideoOcrOverlayState();
}

class _VideoOcrOverlayState extends State<VideoOcrOverlay> {
  VideoOcrResult? _result;
  Object? _error;
  _VideoOcrSelection? _selection;
  DictionaryPopupHandle? _popup;

  @override
  void initState() {
    super.initState();
    unawaited(DictionaryLookupPopup.prewarm(context));
    unawaited(_recognize());
  }

  Future<void> _recognize() async {
    try {
      final miningContext = await widget.miningContextBuilder('');
      final profile = await DictionaryProfileResolver.resolveMiningContext(
        miningContext,
      );
      if (!isProfileOcrAllowed(
        sourceLanguage: miningContext.sourceLanguage,
        profileLanguage: profile.languageCode,
      )) {
        throw StateError(
          'OCR is disabled because the source and dictionary profile '
          'languages do not match.',
        );
      }
      final language = profileOcrLanguage(profile.languageCode);
      final result = await recognizeVideoFrame(
        widget.imageBytes,
        language: language,
      );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _popup?.dismiss();
    super.dispose();
  }

  Future<void> _lookup(
    BuildContext context,
    OcrTextBlock block,
    Rect rect,
    Offset position,
  ) async {
    final renderBox = context.findRenderObject();
    final localPosition = renderBox is RenderBox
        ? renderBox.globalToLocal(position)
        : position;
    final anchorOrigin = renderBox is RenderBox
        ? renderBox.localToGlobal(rect.topLeft)
        : rect.topLeft;
    final anchor = anchorOrigin & rect.size;
    final selection = _videoOcrSelectionAtPosition(block, rect, localPosition);
    if (selection.text.isEmpty) return;
    _popup?.dismiss();
    setState(() => _selection = selection);
    final miningContext = widget.miningContextBuilder(block.text);
    final prefetch = DictionaryLookupPopup.prefetch(
      selection.text,
      miningContext: miningContext,
    );
    final handle = await DictionaryLookupPopup.show(
      context: context,
      anchor: anchor,
      text: selection.text,
      miningContext: miningContext,
      prefetch: prefetch,
      onMatchChanged: (count) {
        if (!mounted || count <= 0) return;
        setState(() {
          _selection = selection.copyWith(matchLength: count);
        });
      },
    );
    if (!mounted) {
      handle?.dismiss();
      return;
    }
    _popup = handle;
    if (handle != null) {
      await handle.dismissed;
      if (mounted && identical(_popup, handle)) {
        setState(() {
          _popup = null;
          _selection = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final outputSize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            final result = _result;
            final mapping = result == null
                ? null
                : _VideoFrameMapping.create(
                    imageSize: Size(
                      result.imageWidth.toDouble(),
                      result.imageHeight.toDouble(),
                    ),
                    outputSize: outputSize,
                    fit: widget.fit,
                  );
            final mappedBlocks = result == null || mapping == null
                ? const <_MappedVideoOcrBlock>[]
                : [
                        for (final block in result.blocks)
                          _MappedVideoOcrBlock(
                            block: block,
                            rect: mapping.mapBlock(block),
                          ),
                      ]
                      .where(
                        (item) => item.rect.overlaps(Offset.zero & outputSize),
                      )
                      .toList();

            return Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(widget.imageBytes, fit: widget.fit),
                for (final item in mappedBlocks)
                  Positioned.fromRect(
                    rect: item.rect,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) => _lookup(
                          context,
                          item.block,
                          item.rect,
                          details.globalPosition,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          decoration: BoxDecoration(
                            color: identical(_selection?.block, item.block)
                                ? Colors.amber.withValues(alpha: 0.28)
                                : Colors.transparent,
                            border: Border.all(
                              color: identical(_selection?.block, item.block)
                                  ? Colors.amber
                                  : Colors.lightBlueAccent.withValues(
                                      alpha: 0.7,
                                    ),
                              width: identical(_selection?.block, item.block)
                                  ? 2
                                  : 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (result == null && _error == null)
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Finding text…',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                if (_error != null)
                  Center(
                    child: Card(
                      color: Colors.black87,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Video OCR failed\n$_error',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                if (result != null && result.blocks.isEmpty)
                  const Center(
                    child: Text(
                      'No text found',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: IconButton.filledTonal(
                      tooltip: 'Close video OCR',
                      onPressed: widget.onDismiss,
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
                if (result != null && result.blocks.isNotEmpty)
                  const SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.all(Radius.circular(18)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Text(
                              'Tap recognized text to look it up',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class LiveVideoOcrOverlay extends StatefulWidget {
  const LiveVideoOcrOverlay({
    super.key,
    required this.imageBytesLoader,
    required this.fit,
    required this.miningContextBuilder,
    required this.onDismiss,
  });

  final Future<Uint8List?> Function() imageBytesLoader;
  final BoxFit fit;
  final Future<MiningContext> Function(String text) miningContextBuilder;
  final VoidCallback onDismiss;

  @override
  State<LiveVideoOcrOverlay> createState() => _LiveVideoOcrOverlayState();
}

class _LiveVideoOcrOverlayState extends State<LiveVideoOcrOverlay> {
  static const _scanInterval = Duration(milliseconds: 2200);

  Timer? _timer;
  VideoOcrResult? _result;
  Object? _error;
  bool _scanning = false;
  String _lastSignature = '';
  _VideoOcrSelection? _selection;
  DictionaryPopupHandle? _popup;

  @override
  void initState() {
    super.initState();
    unawaited(DictionaryLookupPopup.prewarm(context));
    unawaited(_scanFrame());
    _timer = Timer.periodic(_scanInterval, (_) => unawaited(_scanFrame()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _popup?.dismiss();
    super.dispose();
  }

  Future<void> _scanFrame() async {
    if (_scanning) return;
    if (mounted) {
      setState(() => _scanning = true);
    } else {
      _scanning = true;
    }
    try {
      final miningContext = await widget.miningContextBuilder('');
      final profile = await DictionaryProfileResolver.resolveMiningContext(
        miningContext,
      );
      if (!isProfileOcrAllowed(
        sourceLanguage: miningContext.sourceLanguage,
        profileLanguage: profile.languageCode,
      )) {
        throw StateError(
          'Live OCR is disabled because the source and dictionary profile '
          'languages do not match.',
        );
      }
      final bytes = await widget.imageBytesLoader();
      if (bytes == null || bytes.isEmpty) return;
      final result = await recognizeVideoFrame(
        bytes,
        language: profileOcrLanguage(profile.languageCode),
      );
      if (!mounted) return;
      final signature = result.blocks.map((block) => block.text).join('\n');
      if (signature == _lastSignature && _error == null) return;
      setState(() {
        _lastSignature = signature;
        _result = result;
        _error = null;
        if (signature.isEmpty) {
          _popup?.dismiss();
          _selection = null;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() => _scanning = false);
      } else {
        _scanning = false;
      }
    }
  }

  Future<void> _lookup(
    BuildContext context,
    OcrTextBlock block,
    Rect rect,
    Offset position,
  ) async {
    final renderBox = context.findRenderObject();
    final localPosition = renderBox is RenderBox
        ? renderBox.globalToLocal(position)
        : position;
    final anchorOrigin = renderBox is RenderBox
        ? renderBox.localToGlobal(rect.topLeft)
        : rect.topLeft;
    final anchor = anchorOrigin & rect.size;
    final selection = _videoOcrSelectionAtPosition(block, rect, localPosition);
    if (selection.text.isEmpty) return;
    _popup?.dismiss();
    setState(() => _selection = selection);
    final miningContext = widget.miningContextBuilder(block.text);
    final prefetch = DictionaryLookupPopup.prefetch(
      selection.text,
      miningContext: miningContext,
    );
    final handle = await DictionaryLookupPopup.show(
      context: context,
      anchor: anchor,
      text: selection.text,
      miningContext: miningContext,
      prefetch: prefetch,
      onMatchChanged: (count) {
        if (!mounted || count <= 0) return;
        setState(() {
          _selection = selection.copyWith(matchLength: count);
        });
      },
    );
    if (!mounted) {
      handle?.dismiss();
      return;
    }
    _popup = handle;
    if (handle != null) {
      await handle.dismissed;
      if (mounted && identical(_popup, handle)) {
        setState(() {
          _popup = null;
          _selection = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Material(
          color: Colors.transparent,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final outputSize = Size(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              final result = _result;
              final mapping = result == null
                  ? null
                  : _VideoFrameMapping.create(
                      imageSize: Size(
                        result.imageWidth.toDouble(),
                        result.imageHeight.toDouble(),
                      ),
                      outputSize: outputSize,
                      fit: widget.fit,
                    );
              final mappedBlocks = result == null || mapping == null
                  ? const <_MappedVideoOcrBlock>[]
                  : [
                          for (final block in result.blocks)
                            _MappedVideoOcrBlock(
                              block: block,
                              rect: mapping.mapBlock(block),
                            ),
                        ]
                        .where(
                          (item) =>
                              item.rect.overlaps(Offset.zero & outputSize),
                        )
                        .toList();

              return Stack(
                fit: StackFit.expand,
                children: [
                  for (final item in mappedBlocks)
                    Positioned.fromRect(
                      rect: item.rect,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (details) => _lookup(
                            context,
                            item.block,
                            item.rect,
                            details.globalPosition,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            decoration: BoxDecoration(
                              color: identical(_selection?.block, item.block)
                                  ? Colors.amber.withValues(alpha: 0.28)
                                  : Colors.lightBlueAccent.withValues(
                                      alpha: 0.08,
                                    ),
                              border: Border.all(
                                color: identical(_selection?.block, item.block)
                                    ? Colors.amber
                                    : Colors.lightBlueAccent.withValues(
                                        alpha: 0.75,
                                      ),
                                width: identical(_selection?.block, item.block)
                                    ? 2
                                    : 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.all(Radius.circular(18)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_scanning)
                                  const SizedBox.square(
                                    dimension: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.visibility_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                const SizedBox(width: 8),
                                Text(
                                  _error == null
                                      ? 'Live OCR'
                                      : 'Live OCR paused: $_error',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: widget.onDismiss,
                                  child: const Padding(
                                    padding: EdgeInsets.all(2),
                                    child: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _VideoFrameMapping {
  const _VideoFrameMapping({
    required this.imageSize,
    required this.source,
    required this.destination,
  });

  final Size imageSize;
  final Rect source;
  final Rect destination;

  factory _VideoFrameMapping.create({
    required Size imageSize,
    required Size outputSize,
    required BoxFit fit,
  }) {
    final fitted = applyBoxFit(fit, imageSize, outputSize);
    return _VideoFrameMapping(
      imageSize: imageSize,
      source: Alignment.center.inscribe(fitted.source, Offset.zero & imageSize),
      destination: Alignment.center.inscribe(
        fitted.destination,
        Offset.zero & outputSize,
      ),
    );
  }

  Rect mapBlock(OcrTextBlock block) {
    final left = block.xmin * imageSize.width;
    final top = block.ymin * imageSize.height;
    final right = block.xmax * imageSize.width;
    final bottom = block.ymax * imageSize.height;
    return Rect.fromLTRB(
      destination.left +
          (left - source.left) * destination.width / source.width,
      destination.top + (top - source.top) * destination.height / source.height,
      destination.left +
          (right - source.left) * destination.width / source.width,
      destination.top +
          (bottom - source.top) * destination.height / source.height,
    );
  }
}

class _MappedVideoOcrBlock {
  const _MappedVideoOcrBlock({required this.block, required this.rect});

  final OcrTextBlock block;
  final Rect rect;
}

class _VideoOcrSelection {
  const _VideoOcrSelection({
    required this.block,
    required this.text,
    required this.offset,
    this.matchLength = 0,
  });

  final OcrTextBlock block;
  final String text;
  final int offset;
  final int matchLength;

  _VideoOcrSelection copyWith({int? matchLength}) => _VideoOcrSelection(
    block: block,
    text: text,
    offset: offset,
    matchLength: matchLength ?? this.matchLength,
  );
}

_VideoOcrSelection _videoOcrSelectionAtPosition(
  OcrTextBlock block,
  Rect rect,
  Offset globalPosition,
) {
  final text = block.text.replaceAll('\n', '');
  if (text.isEmpty || rect.isEmpty) {
    return _VideoOcrSelection(block: block, text: '', offset: 0);
  }
  final ratio = block.vertical
      ? ((globalPosition.dy - rect.top) / rect.height).clamp(0.0, 0.999)
      : ((globalPosition.dx - rect.left) / rect.width).clamp(0.0, 0.999);
  var offset = (ratio * text.length).floor().clamp(0, text.length - 1);
  while (offset < text.length && _isLookupBoundary(text[offset])) {
    offset++;
  }
  if (offset >= text.length) {
    return _VideoOcrSelection(block: block, text: '', offset: 0);
  }
  var start = offset;
  if (_isAsciiWord(text[start])) {
    while (start > 0 && _isAsciiWord(text[start - 1])) {
      start--;
    }
  }
  var end = start;
  while (end < text.length &&
      !_isLookupBoundary(text[end]) &&
      end - start < 80) {
    end++;
  }
  return _VideoOcrSelection(
    block: block,
    text: text.substring(start, end).trim(),
    offset: start,
  );
}

bool _isLookupBoundary(String character) =>
    character.trim().isEmpty ||
    RegExp(
      r'[\u3000-\u303f\uff01-\uff65、。！？「」『』（）［］【】…‥・,.!?;:()\[\]{}]',
    ).hasMatch(character);

bool _isAsciiWord(String character) =>
    RegExp(r'[A-Za-z0-9_\-]').hasMatch(character);
