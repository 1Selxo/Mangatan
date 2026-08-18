import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:mangayomi/services/mining/ocr_image_tiling.dart';
import 'package:mangayomi/services/mining/ocr_models.dart';

class AppleVisionOcrResult {
  const AppleVisionOcrResult({
    required this.imageWidth,
    required this.imageHeight,
    required this.blocks,
  });

  final int imageWidth;
  final int imageHeight;
  final List<OcrTextBlock> blocks;
}

class AppleVisionOcrClient {
  AppleVisionOcrClient({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'com.mangatan.ocr/apple_vision';
  final MethodChannel _channel;

  static bool get isSupportedPlatform => Platform.isMacOS || Platform.isIOS;

  Future<List<String>> supportedLanguages() async {
    if (!isSupportedPlatform) return const [];
    final languages = await _channel.invokeListMethod<String>(
      'supportedLanguages',
    );
    return languages ?? const [];
  }

  Future<bool> supportsLanguage(String language) async {
    return resolveAppleVisionLanguage(language, await supportedLanguages()) !=
        null;
  }

  Future<AppleVisionOcrResult> recognize(
    Uint8List imageBytes, {
    required String language,
  }) async {
    if (!isSupportedPlatform) {
      throw UnsupportedError(
        'Apple Vision OCR is only available on macOS and iOS',
      );
    }
    final supported = await supportedLanguages();
    final resolved = resolveAppleVisionLanguage(language, supported);
    if (resolved == null) {
      throw UnsupportedError(
        'Apple Vision OCR does not support $language on this OS version',
      );
    }

    final decoded = await _decodeImage(imageBytes);
    final tiles = planVerticalOcrTiles(
      width: decoded.width,
      height: decoded.height,
    );
    final blocks = <OcrTextBlock>[];
    try {
      for (final tile in tiles) {
        // Re-encoding also normalizes EXIF orientation. The native side can
        // then sweep CJK recognition orientations and map every observation
        // against the same top-left pixel coordinate system.
        final bytes = await _encodeTile(decoded.image, tile);
        final response = await _channel.invokeMapMethod<String, dynamic>(
          'recognize',
          {'bytes': bytes, 'language': resolved},
        );
        if (response == null) {
          throw StateError('Apple Vision OCR returned no result');
        }
        final tileBlocks = parseAppleVisionBlocks(
          response['blocks'],
          language: language,
        );
        blocks.addAll(
          tiles.length == 1
              ? tileBlocks
              : remapOcrBlocksFromTile(tileBlocks, tile),
        );
      }
    } finally {
      decoded.image.dispose();
    }
    return AppleVisionOcrResult(
      imageWidth: decoded.width,
      imageHeight: decoded.height,
      blocks: blocks,
    );
  }
}

String? resolveAppleVisionLanguage(
  String requested,
  Iterable<String> supported,
) {
  final values = supported.toList(growable: false);
  if (values.isEmpty) return null;
  final normalized = requested.trim().replaceAll('_', '-').toLowerCase();
  if (normalized.isEmpty) return null;

  for (final value in values) {
    if (value.toLowerCase() == normalized) return value;
  }
  if (normalized == 'zh') {
    for (final preferred in ['zh-Hans', 'zh-CN', 'zh-Hant', 'zh-TW']) {
      for (final value in values) {
        if (value.toLowerCase() == preferred.toLowerCase()) return value;
      }
    }
  }
  final base = normalized.split('-').first;
  for (final value in values) {
    if (value.toLowerCase().split('-').first == base) return value;
  }
  return null;
}

List<OcrTextBlock> parseAppleVisionBlocks(
  Object? value, {
  required String language,
}) {
  if (value is! List) return const [];
  final result = <OcrTextBlock>[];
  for (final item in value) {
    if (item is! Map) continue;
    final text = item['text']?.toString().trim() ?? '';
    final xmin = _number(item['xmin']);
    final ymin = _number(item['ymin']);
    final xmax = _number(item['xmax']);
    final ymax = _number(item['ymax']);
    if (text.isEmpty ||
        xmin == null ||
        ymin == null ||
        xmax == null ||
        ymax == null) {
      continue;
    }
    final rotation = _number(item['rotation']) ?? 0;
    final geometry = OcrLineGeometry(
      xmin: xmin.clamp(0.0, 1.0).toDouble(),
      ymin: ymin.clamp(0.0, 1.0).toDouble(),
      xmax: xmax.clamp(0.0, 1.0).toDouble(),
      ymax: ymax.clamp(0.0, 1.0).toDouble(),
      rotation: rotation,
    );
    if (geometry.xmax <= geometry.xmin || geometry.ymax <= geometry.ymin) {
      continue;
    }
    result.add(
      OcrTextBlock(
        xmin: geometry.xmin,
        ymin: geometry.ymin,
        xmax: geometry.xmax,
        ymax: geometry.ymax,
        lines: [text],
        vertical: item['vertical'] == true,
        lineGeometries: [geometry],
        language: language,
      ),
    );
  }
  return result;
}

double? _number(Object? value) => value is num ? value.toDouble() : null;

Future<({ui.Image image, int width, int height})> _decodeImage(
  Uint8List bytes,
) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  codec.dispose();
  return (
    image: frame.image,
    width: frame.image.width,
    height: frame.image.height,
  );
}

Future<Uint8List> _encodeTile(ui.Image image, OcrVerticalTile tile) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final source = ui.Rect.fromLTWH(
    0,
    tile.top.toDouble(),
    image.width.toDouble(),
    tile.height.toDouble(),
  );
  final destination = ui.Rect.fromLTWH(
    0,
    0,
    image.width.toDouble(),
    tile.height.toDouble(),
  );
  canvas.drawImageRect(image, source, destination, ui.Paint());
  final picture = recorder.endRecording();
  late final ui.Image tileImage;
  try {
    tileImage = await picture.toImage(image.width, tile.height);
  } finally {
    picture.dispose();
  }
  try {
    final data = await tileImage.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('Could not encode Apple Vision OCR tile');
    }
    return data.buffer.asUint8List();
  } finally {
    tileImage.dispose();
  }
}
