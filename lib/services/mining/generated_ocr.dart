import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image_lib;
import 'package:mangayomi/services/mining/anime_text_detection_service.dart';
import 'package:mangayomi/services/mining/apple_vision_ocr.dart';
import 'package:mangayomi/services/mining/chrome_lens_ocr.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';
import 'package:mangayomi/services/mining/ocr_block_merger.dart';
import 'package:mangayomi/services/mining/ocr_models.dart';
import 'package:mangayomi/services/mining/screen_ai_ocr.dart';
import 'package:mangayomi/services/mining/hayai_ocr.dart';

class GeneratedOcrResult {
  const GeneratedOcrResult({
    required this.imageWidth,
    required this.imageHeight,
    required this.blocks,
  });

  final int imageWidth;
  final int imageHeight;
  final List<OcrTextBlock> blocks;
}

List<OcrEnginePreference> generatedOcrEngineOrder({
  required OcrEnginePreference engine,
  required bool appleVisionAvailable,
  required bool screenAiAvailable,
}) {
  if (engine == OcrEnginePreference.mokuroOnly) return const [];
  if (engine != OcrEnginePreference.automatic) return [engine];
  return [
    OcrEnginePreference.googleLens,
    if (appleVisionAvailable) OcrEnginePreference.appleVision,
    if (screenAiAvailable) OcrEnginePreference.screenAi,
  ];
}

Future<GeneratedOcrResult> recognizeGeneratedOcr(
  Uint8List bytes, {
  required OcrEnginePreference engine,
  required String language,
}) async {
  if (engine == OcrEnginePreference.mokuroOnly) {
    throw StateError('This OCR operation requires a generated OCR engine');
  }

  final order = generatedOcrEngineOrder(
    engine: engine,
    appleVisionAvailable:
        engine == OcrEnginePreference.appleVision ||
        (engine == OcrEnginePreference.automatic &&
            AppleVisionOcrClient.isSupportedPlatform),
    screenAiAvailable:
        engine == OcrEnginePreference.screenAi ||
        (engine == OcrEnginePreference.automatic &&
            currentOcrHostPlatform == OcrHostPlatform.windows),
  );

  GeneratedOcrResult? emptyResult;
  Object? lastError;
  StackTrace? lastStackTrace;
  for (final provider in order) {
    try {
      final result = await _recognizeWithEngine(
        bytes,
        engine: provider,
        language: language,
      );
      if (engine != OcrEnginePreference.automatic || result.blocks.isNotEmpty) {
        return result;
      }
      emptyResult = result;
    } catch (error, stackTrace) {
      if (engine != OcrEnginePreference.automatic) rethrow;
      lastError = error;
      lastStackTrace = stackTrace;
    }
  }

  if (emptyResult != null) return emptyResult;
  if (lastError != null && lastStackTrace != null) {
    Error.throwWithStackTrace(lastError, lastStackTrace);
  }
  throw StateError('No OCR engine is available');
}

Future<GeneratedOcrResult> _recognizeWithEngine(
  Uint8List bytes, {
  required OcrEnginePreference engine,
  required String language,
}) async {
  final detectorEnabled =
      await MiningPreferences.getAnimeTextDetectionEnabled();
  final detectorRequired = engine == OcrEnginePreference.hayai;
  if (detectorEnabled || detectorRequired) {
    try {
      final ready = await AnimeTextDetectionService.instance.isModelReady();
      if (ready) {
        final regions = await AnimeTextDetectionService.instance.detect(bytes);
        if (regions.isNotEmpty) {
          return await _recognizeDetectedRegions(
            bytes,
            regions: regions,
            engine: engine,
            language: language,
          );
        }
      }
      if (detectorRequired) {
        throw StateError(
          ready
              ? 'AnimeText found no text regions on this page'
              : 'Hayai OCR requires an imported AnimeText LiteRT detector',
        );
      }
    } catch (_) {
      if (detectorRequired) rethrow;
      // AnimeText is an optional enhancement for the built-in engines. A
      // corrupt/incompatible model must not disable their full-page fallback.
    }
  }
  return _recognizeDirect(bytes, engine: engine, language: language);
}

Future<GeneratedOcrResult> _recognizeDetectedRegions(
  Uint8List pageBytes, {
  required List<Rect> regions,
  required OcrEnginePreference engine,
  required String language,
}) async {
  final page = image_lib.decodeImage(pageBytes);
  if (page == null) throw const FormatException('Unsupported page image');
  final blocks = <OcrTextBlock>[];
  for (final rawRegion in regions.take(64)) {
    final region = rawRegion
        .inflate(.012)
        .intersect(const Rect.fromLTRB(0, 0, 1, 1));
    final left = (region.left * page.width).floor().clamp(0, page.width - 1);
    final top = (region.top * page.height).floor().clamp(0, page.height - 1);
    final right = (region.right * page.width).ceil().clamp(
      left + 1,
      page.width,
    );
    final bottom = (region.bottom * page.height).ceil().clamp(
      top + 1,
      page.height,
    );
    final crop = image_lib.copyCrop(
      page,
      x: left,
      y: top,
      width: right - left,
      height: bottom - top,
    );
    final result = await _recognizeDirect(
      Uint8List.fromList(image_lib.encodePng(crop)),
      engine: engine,
      language: language,
    );
    blocks.addAll(
      result.blocks.map((block) => remapOcrBlockToRegion(block, region)),
    );
  }
  return GeneratedOcrResult(
    imageWidth: page.width,
    imageHeight: page.height,
    blocks: mergeOcrBlocks(blocks, language: language),
  );
}

@visibleForTesting
OcrTextBlock remapOcrBlockToRegion(OcrTextBlock block, Rect region) {
  double x(double value) => region.left + value * region.width;
  double y(double value) => region.top + value * region.height;
  return OcrTextBlock(
    xmin: x(block.xmin),
    ymin: y(block.ymin),
    xmax: x(block.xmax),
    ymax: y(block.ymax),
    lines: block.lines,
    vertical: block.vertical,
    language: block.language,
    lineGeometries: [
      for (final line in block.lineGeometries)
        OcrLineGeometry(
          xmin: x(line.xmin),
          ymin: y(line.ymin),
          xmax: x(line.xmax),
          ymax: y(line.ymax),
          rotation: line.rotation,
        ),
    ],
  );
}

Future<GeneratedOcrResult> _recognizeDirect(
  Uint8List bytes, {
  required OcrEnginePreference engine,
  required String language,
}) async {
  switch (engine) {
    case OcrEnginePreference.appleVision:
      final appleClient = AppleVisionOcrClient();
      final result = await appleClient.recognize(bytes, language: language);
      return GeneratedOcrResult(
        imageWidth: result.imageWidth,
        imageHeight: result.imageHeight,
        blocks: mergeOcrBlocks(result.blocks, language: language),
      );
    case OcrEnginePreference.screenAi:
      final client = ScreenAiOcrClient();
      try {
        final result = await client.recognize(bytes);
        return GeneratedOcrResult(
          imageWidth: result.imageWidth,
          imageHeight: result.imageHeight,
          blocks: mergeOcrBlocks(result.blocks, language: language),
        );
      } finally {
        client.close();
      }
    case OcrEnginePreference.googleLens:
      final client = ChromeLensOcrClient();
      try {
        final result = await client.recognize(bytes, language: language);
        return GeneratedOcrResult(
          imageWidth: result.imageWidth,
          imageHeight: result.imageHeight,
          blocks: mergeOcrBlocks(result.blocks, language: language),
        );
      } finally {
        client.close();
      }
    case OcrEnginePreference.hayai:
      final endpoint = await MiningPreferences.getHayaiOcrEndpoint();
      final apiKey = await MiningPreferences.getHayaiOcrApiKey();
      final client = HayaiOcrClient(endpoint: endpoint, apiKey: apiKey);
      try {
        final text = await client.recognize(bytes);
        final decoded = image_lib.decodeImage(bytes);
        if (decoded == null) {
          throw const FormatException('Unsupported Hayai OCR crop');
        }
        return GeneratedOcrResult(
          imageWidth: decoded.width,
          imageHeight: decoded.height,
          blocks: text.isEmpty
              ? const []
              : [
                  OcrTextBlock(
                    xmin: 0,
                    ymin: 0,
                    xmax: 1,
                    ymax: 1,
                    lines: [text],
                    vertical: decoded.height > decoded.width * 1.35,
                    language: language,
                  ),
                ],
        );
      } finally {
        client.close();
      }
    case OcrEnginePreference.automatic:
    case OcrEnginePreference.mokuroOnly:
      throw StateError('$engine is not a generated OCR provider');
  }
}
