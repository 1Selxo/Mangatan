import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;
import 'package:mangayomi/services/mining/ocr_models.dart';

class ChromeLensOcrResult {
  final int imageWidth;
  final int imageHeight;
  final List<OcrTextBlock> blocks;

  const ChromeLensOcrResult({
    required this.imageWidth,
    required this.imageHeight,
    required this.blocks,
  });
}

class ChromeLensOcrClient {
  static final Uri _endpoint = Uri.parse(
    'https://lensfrontend-pa.googleapis.com/v1/crupload',
  );
  static const _apiKey = 'AIzaSyDr2UxVnv_U85AbhhY8XSHSIavUW0DC-sY';
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/120.0.0.0 Safari/537.36';
  static const _maxDimension = 1500;

  final http.Client _client;

  ChromeLensOcrClient({http.Client? client})
    : _client = client ?? http.Client();

  Future<ChromeLensOcrResult> recognize(
    Uint8List imageBytes, {
    String language = 'ja',
  }) async {
    final image = await _prepareImage(imageBytes);
    final request = _buildRequest(image, language);
    final response = await _client
        .post(
          _endpoint,
          headers: const {
            'Content-Type': 'application/x-protobuf',
            'X-Goog-Api-Key': _apiKey,
            'User-Agent': _userAgent,
          },
          body: request,
        )
        .timeout(const Duration(seconds: 60));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Google Lens OCR failed (${response.statusCode}): '
        '${utf8.decode(response.bodyBytes, allowMalformed: true)}',
      );
    }
    return decodeResponse(
      response.bodyBytes,
      imageWidth: image.originalWidth,
      imageHeight: image.originalHeight,
      language: language,
    );
  }

  ChromeLensOcrResult decodeResponse(
    Uint8List bytes, {
    required int imageWidth,
    required int imageHeight,
    String language = 'ja',
  }) {
    final root = _ProtoMessage.decode(bytes);
    final objects = root.message(2);
    final text = objects?.message(3);
    final layout = text?.message(1);
    final blocks = <OcrTextBlock>[];

    for (final paragraph in layout?.messages(1) ?? const <_ProtoMessage>[]) {
      final lines = <String>[];
      final lineGeometries = <OcrLineGeometry>[];
      final lineRects = <_NormalizedRect>[];
      var verticalVotes = 0;

      for (final line in paragraph.messages(2)) {
        final words = line.messages(1).map((word) {
          final value = word.string(2);
          final separator = word.string(3);
          return '$value$separator';
        }).join();
        final normalizedText = _normalizeText(words, language);
        if (normalizedText.isEmpty) continue;
        final geometry = _readGeometry(line.message(2));
        if (geometry == null) continue;
        final rect = geometry.rect;
        lines.add(normalizedText);
        lineRects.add(rect);
        lineGeometries.add(
          OcrLineGeometry(
            xmin: rect.left,
            ymin: rect.top,
            xmax: rect.right,
            ymax: rect.bottom,
            rotation: geometry.rotation,
          ),
        );
        if (geometry.isVertical) verticalVotes++;
      }

      if (lines.isEmpty) continue;
      final paragraphGeometry = _readGeometry(paragraph.message(3));
      final rect = paragraphGeometry?.rect ?? _union(lineRects);
      if (rect == null || rect.width <= 0 || rect.height <= 0) continue;
      blocks.add(
        OcrTextBlock(
          xmin: rect.left,
          ymin: rect.top,
          xmax: rect.right,
          ymax: rect.bottom,
          lines: lines,
          vertical:
              paragraphGeometry?.isVertical == true ||
              verticalVotes > lines.length / 2,
          lineGeometries: lineGeometries,
          language: language,
        ),
      );
    }

    return ChromeLensOcrResult(
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      blocks: blocks,
    );
  }

  void close() => _client.close();

  Future<_PreparedImage> _prepareImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final originalWidth = frame.image.width;
    final originalHeight = frame.image.height;
    codec.dispose();

    final largest = math.max(originalWidth, originalHeight);
    if (largest <= _maxDimension) {
      final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      if (png == null) throw StateError('Could not encode image for OCR');
      return _PreparedImage(
        bytes: png.buffer.asUint8List(),
        width: originalWidth,
        height: originalHeight,
        originalWidth: originalWidth,
        originalHeight: originalHeight,
      );
    }
    frame.image.dispose();

    final scale = _maxDimension / largest;
    final width = math.max(1, (originalWidth * scale).round());
    final height = math.max(1, (originalHeight * scale).round());
    final resizedCodec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: width,
      targetHeight: height,
      allowUpscaling: false,
    );
    final resizedFrame = await resizedCodec.getNextFrame();
    final png = await resizedFrame.image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    resizedFrame.image.dispose();
    resizedCodec.dispose();
    if (png == null) throw StateError('Could not encode image for OCR');
    return _PreparedImage(
      bytes: png.buffer.asUint8List(),
      width: width,
      height: height,
      originalWidth: originalWidth,
      originalHeight: originalHeight,
    );
  }

  Uint8List _buildRequest(_PreparedImage image, String language) {
    final random = math.Random.secure();
    final uuid =
        ((random.nextInt(0x7fffffff) << 32) | random.nextInt(0xffffffff)) &
        0x7fffffffffffffff;
    final writer = _ProtoWriter();
    writer.message(1, (objects) {
      objects.message(1, (context) {
        context.message(3, (requestId) {
          requestId.uint(1, uuid);
          requestId.uint(2, 1);
          requestId.uint(3, 1);
        });
        context.message(4, (client) {
          client.uint(1, 3);
          client.uint(2, 4);
          client.message(4, (locale) {
            locale.string(1, language);
            locale.string(2, 'US');
            locale.string(3, 'America/New_York');
          });
        });
      });
      objects.message(3, (data) {
        data.message(1, (payload) => payload.bytes(1, image.bytes));
        data.message(3, (metadata) {
          metadata.uint(1, image.width);
          metadata.uint(2, image.height);
        });
      });
    });
    return writer.takeBytes();
  }

  static String _normalizeText(String text, String language) {
    final trimmed = text.trim();
    if (language == 'ja' || language == 'zh') {
      return trimmed.replaceAll(RegExp(r'\s+'), '');
    }
    return trimmed.replaceAll(RegExp(r'\s+'), ' ');
  }

  static _LensGeometry? _readGeometry(_ProtoMessage? geometry) {
    final box = geometry?.message(1);
    if (box == null) return null;
    final centerX = box.float32(1) ?? 0;
    final centerY = box.float32(2) ?? 0;
    final width = box.float32(3) ?? 0;
    final height = box.float32(4) ?? 0;
    final rotation = box.float32(5) ?? 0;
    if (width <= 0 || height <= 0) return null;
    final cos = math.cos(rotation).abs();
    final sin = math.sin(rotation).abs();
    final halfWidth = (width * cos + height * sin) / 2;
    final halfHeight = (width * sin + height * cos) / 2;
    final rect = _NormalizedRect(
      left: (centerX - halfWidth).clamp(0, 1).toDouble(),
      top: (centerY - halfHeight).clamp(0, 1).toDouble(),
      right: (centerX + halfWidth).clamp(0, 1).toDouble(),
      bottom: (centerY + halfHeight).clamp(0, 1).toDouble(),
    );
    final quarterTurn = (rotation.abs() - math.pi / 2).abs() < 0.5;
    return _LensGeometry(
      rect: rect,
      rotation: rotation,
      isVertical: quarterTurn || rect.height > rect.width * 1.25,
    );
  }

  static _NormalizedRect? _union(List<_NormalizedRect> rects) {
    if (rects.isEmpty) return null;
    return _NormalizedRect(
      left: rects.map((rect) => rect.left).reduce(math.min),
      top: rects.map((rect) => rect.top).reduce(math.min),
      right: rects.map((rect) => rect.right).reduce(math.max),
      bottom: rects.map((rect) => rect.bottom).reduce(math.max),
    );
  }
}

class _PreparedImage {
  final Uint8List bytes;
  final int width;
  final int height;
  final int originalWidth;
  final int originalHeight;

  const _PreparedImage({
    required this.bytes,
    required this.width,
    required this.height,
    required this.originalWidth,
    required this.originalHeight,
  });
}

class _LensGeometry {
  final _NormalizedRect rect;
  final double rotation;
  final bool isVertical;

  const _LensGeometry({
    required this.rect,
    required this.rotation,
    required this.isVertical,
  });
}

class _NormalizedRect {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const _NormalizedRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get width => right - left;
  double get height => bottom - top;
}

class _ProtoWriter {
  final BytesBuilder _bytes = BytesBuilder(copy: false);

  void uint(int field, int value) {
    _varint((field << 3) | 0);
    _varint(value);
  }

  void string(int field, String value) => bytes(field, utf8.encode(value));

  void bytes(int field, List<int> value) {
    _varint((field << 3) | 2);
    _varint(value.length);
    _bytes.add(value);
  }

  void message(int field, void Function(_ProtoWriter writer) build) {
    final nested = _ProtoWriter();
    build(nested);
    bytes(field, nested.takeBytes());
  }

  Uint8List takeBytes() => _bytes.takeBytes();

  void _varint(int value) {
    var remaining = value;
    while (remaining > 0x7f) {
      _bytes.addByte((remaining & 0x7f) | 0x80);
      remaining >>= 7;
    }
    _bytes.addByte(remaining);
  }
}

class _ProtoMessage {
  final Map<int, List<_ProtoField>> _fields;

  const _ProtoMessage(this._fields);

  factory _ProtoMessage.decode(Uint8List bytes) {
    final fields = <int, List<_ProtoField>>{};
    final cursor = _ProtoCursor(bytes);
    while (!cursor.isDone) {
      final tag = cursor.varint();
      final field = tag >> 3;
      final wireType = tag & 7;
      if (field == 0) throw const FormatException('Invalid protobuf field');
      final value = switch (wireType) {
        0 => _ProtoField(wireType, cursor.varint()),
        1 => _ProtoField(wireType, cursor.read(8)),
        2 => _ProtoField(wireType, cursor.read(cursor.varint())),
        5 => _ProtoField(wireType, cursor.read(4)),
        _ => throw FormatException('Unsupported protobuf wire type $wireType'),
      };
      fields.putIfAbsent(field, () => []).add(value);
    }
    return _ProtoMessage(fields);
  }

  Iterable<_ProtoMessage> messages(int field) sync* {
    for (final value in _fields[field] ?? const <_ProtoField>[]) {
      if (value.wireType == 2 && value.value is Uint8List) {
        yield _ProtoMessage.decode(value.value as Uint8List);
      }
    }
  }

  _ProtoMessage? message(int field) => messages(field).firstOrNull;

  String string(int field) {
    final value = _fields[field]?.firstOrNull;
    if (value?.wireType != 2 || value?.value is! Uint8List) return '';
    return utf8.decode(value!.value as Uint8List, allowMalformed: true);
  }

  double? float32(int field) {
    final value = _fields[field]?.firstOrNull;
    if (value?.wireType != 5 || value?.value is! Uint8List) return null;
    final data = ByteData.sublistView(value!.value as Uint8List);
    return data.getFloat32(0, Endian.little).toDouble();
  }
}

class _ProtoField {
  final int wireType;
  final Object value;

  const _ProtoField(this.wireType, this.value);
}

class _ProtoCursor {
  final Uint8List bytes;
  int offset = 0;

  _ProtoCursor(this.bytes);

  bool get isDone => offset >= bytes.length;

  int varint() {
    var result = 0;
    var shift = 0;
    while (offset < bytes.length && shift < 70) {
      final byte = bytes[offset++];
      result |= (byte & 0x7f) << shift;
      if ((byte & 0x80) == 0) return result;
      shift += 7;
    }
    throw const FormatException('Truncated protobuf varint');
  }

  Uint8List read(int length) {
    if (length < 0 || offset + length > bytes.length) {
      throw const FormatException('Truncated protobuf field');
    }
    final value = Uint8List.sublistView(bytes, offset, offset + length);
    offset += length;
    return value;
  }
}
