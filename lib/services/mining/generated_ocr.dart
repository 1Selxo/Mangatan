import 'dart:typed_data';

import 'package:mangayomi/services/mining/apple_vision_ocr.dart';
import 'package:mangayomi/services/mining/chrome_lens_ocr.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';
import 'package:mangayomi/services/mining/ocr_block_merger.dart';
import 'package:mangayomi/services/mining/ocr_models.dart';
import 'package:mangayomi/services/mining/screen_ai_ocr.dart';

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
    case OcrEnginePreference.automatic:
    case OcrEnginePreference.mokuroOnly:
      throw StateError('$engine is not a generated OCR provider');
  }
}
