import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'package:mangayomi/services/mining/ocr_models.dart';
import 'package:path/path.dart' as p;

class ScreenAiOcrResult {
  const ScreenAiOcrResult({
    required this.imageWidth,
    required this.imageHeight,
    required this.blocks,
    required this.componentPath,
  });

  final int imageWidth;
  final int imageHeight;
  final List<OcrTextBlock> blocks;
  final String componentPath;
}

/// A sequential lock to ensure only one Isolate accesses the native
/// ScreenAI DLL at any given time.
class _OcrLock {
  static Future<void> _last = Future.value();

  static Future<T> synchronized<T>(FutureOr<T> Function() action) {
    final completer = Completer<T>();
    _last.then((_) async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    _last = completer.future.catchError((_) {});
    return completer.future;
  }
}

class _ImageDecodeResult {
  final Uint8List rgbaBytes;
  final int width;
  final int height;

  const _ImageDecodeResult({
    required this.rgbaBytes,
    required this.width,
    required this.height,
  });
}

class ScreenAiOcrClient {
  ScreenAiOcrClient({this.componentDirectory});

  final Directory? componentDirectory;

  static Future<bool> isAvailable() async {
    return Platform.isWindows &&
        _ScreenAiBridge.isAvailable &&
        _findComponentDirectory() != null;
  }

  Future<ScreenAiOcrResult> recognize(Uint8List imageBytes) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('ScreenAI OCR is currently available on Windows');
    }
    final component = componentDirectory ?? _findComponentDirectory();
    if (component == null) {
      throw StateError(
        'ScreenAI is not installed. Open Chrome once or select Google Lens.',
      );
    }

    // 1. Decode image to RGBA async on the main thread (uses native engine threads)
    final decodeResult = await _decodeImageRgba(imageBytes);

    // 2. Offload FFI native execution to a background Isolate
    final result = await _OcrLock.synchronized(() {
      return Isolate.run(() {
        final image = _ScreenAiImage(
          pixels: decodeResult.rgbaBytes, // Pass raw RGBA bytes directly
          width: decodeResult.width,
          height: decodeResult.height,
          originalWidth: decodeResult.width,
          originalHeight: decodeResult.height,
        );

        final annotation = _ScreenAiBridge.instance.recognize(
          componentDirectory: component,
          image: image,
        );

        final blocks = _parseVisualAnnotation(
          annotation,
          imageWidth: decodeResult.width,
          imageHeight: decodeResult.height,
        );

        return (
          blocks: blocks,
          imageWidth: decodeResult.width,
          imageHeight: decodeResult.height,
        );
      });
    });

    return ScreenAiOcrResult(
      imageWidth: result.imageWidth,
      imageHeight: result.imageHeight,
      blocks: result.blocks,
      componentPath: component.path,
    );
  }

  void close() {}

  Future<_ImageDecodeResult> _decodeImageRgba(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final width = frame.image.width;
    final height = frame.image.height;
    final rgba = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    frame.image.dispose();
    codec.dispose();
    if (rgba == null) throw StateError('Could not decode image for ScreenAI');
    
    return _ImageDecodeResult(
      rgbaBytes: rgba.buffer.asUint8List(),
      width: width,
      height: height,
    );
  }

  static Directory? _findComponentDirectory() {
    final roots = <Directory>[
      _localAppDataDir(p.join('Google', 'Chrome', 'User Data', 'screen_ai')),
      _localAppDataDir(
        p.join('Google', 'Chrome SxS', 'User Data', 'screen_ai'),
      ),
      _localAppDataDir(p.join('Microsoft', 'Edge', 'User Data', 'screen_ai')),
    ];
    final versionDirs = <Directory>[];
    for (final root in roots) {
      if (!root.existsSync()) continue;
      for (final child in root.listSync().whereType<Directory>()) {
        final library = File(p.join(child.path, 'chrome_screen_ai.dll'));
        final manifest = File(p.join(child.path, 'manifest.json'));
        if (library.existsSync() && manifest.existsSync()) {
          versionDirs.add(child);
        }
      }
    }
    if (versionDirs.isEmpty) return null;
    versionDirs.sort((a, b) => _versionOf(b).compareTo(_versionOf(a)));
    return versionDirs.first;
  }

  static Directory _localAppDataDir(String relative) {
    final root = Platform.environment['LOCALAPPDATA'] ?? '';
    return Directory(p.join(root, relative));
  }

  static double _versionOf(Directory directory) {
    final parsed = double.tryParse(p.basename(directory.path));
    if (parsed != null) return parsed;
    final manifest = File(p.join(directory.path, 'manifest.json'));
    if (!manifest.existsSync()) return 0;
    try {
      final decoded = jsonDecode(manifest.readAsStringSync());
      return double.tryParse(decoded['version']?.toString() ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
  }
}

class _ScreenAiBridge {
  _ScreenAiBridge._(this.library)
    : _recognize = library
          .lookupFunction<
            Int32 Function(
              Pointer<Utf16>,
              Pointer<Uint8>,
              Int32,
              Int32,
              Pointer<Pointer<Uint8>>,
              Pointer<Uint32>,
              Pointer<Pointer<Utf8>>,
            ),
            int Function(
              Pointer<Utf16>,
              Pointer<Uint8>,
              int,
              int,
              Pointer<Pointer<Uint8>>,
              Pointer<Uint32>,
              Pointer<Pointer<Utf8>>,
            )
          >('ScreenAiRecognize'),
      _free = library
          .lookupFunction<
            Void Function(Pointer<Void>),
            void Function(Pointer<Void>)
          >('ScreenAiFree');

  final DynamicLibrary library;
  final int Function(
    Pointer<Utf16>,
    Pointer<Uint8>,
    int,
    int,
    Pointer<Pointer<Uint8>>,
    Pointer<Uint32>,
    Pointer<Pointer<Utf8>>,
  )
  _recognize;
  final void Function(Pointer<Void>) _free;

  static _ScreenAiBridge? _instance;

  static bool get isAvailable {
    if (!Platform.isWindows) return false;
    return File(_bridgePath()).existsSync();
  }

  static _ScreenAiBridge get instance {
    return _instance ??= _ScreenAiBridge._(DynamicLibrary.open(_bridgePath()));
  }

  Uint8List recognize({
    required Directory componentDirectory,
    required _ScreenAiImage image,
  }) {
    final componentPath = componentDirectory.path.toNativeUtf16();
    final pixels = calloc<Uint8>(image.pixels.length);
    final output = calloc<Pointer<Uint8>>();
    final outputLength = calloc<Uint32>();
    final error = calloc<Pointer<Utf8>>();
    try {
      pixels.asTypedList(image.pixels.length).setAll(0, image.pixels);
      final status = _recognize(
        componentPath,
        pixels,
        image.width,
        image.height,
        output,
        outputLength,
        error,
      );
      if (status == 0) {
        final message = error.value == nullptr
            ? 'ScreenAI OCR failed'
            : error.value.toDartString();
        throw StateError(message);
      }
      if (output.value == nullptr || outputLength.value == 0) {
        return Uint8List(0);
      }
      return Uint8List.fromList(output.value.asTypedList(outputLength.value));
    } finally {
      calloc.free(componentPath);
      calloc.free(pixels);
      if (output.value != nullptr) _free(output.value.cast<Void>());
      if (error.value != nullptr) _free(error.value.cast<Void>());
      calloc.free(output);
      calloc.free(outputLength);
      calloc.free(error);
    }
  }

  static String _bridgePath() {
    final executableDir = p.dirname(Platform.resolvedExecutable);
    final besideExe = File(p.join(executableDir, 'screen_ai_bridge.dll'));
    if (besideExe.existsSync()) return besideExe.path;
    return p.join(Directory.current.path, 'screen_ai_bridge.dll');
  }
}

List<OcrTextBlock> _parseVisualAnnotation(
  Uint8List bytes, {
  required int imageWidth,
  required int imageHeight,
}) {
  if (bytes.isEmpty) return const [];
  final root = _ProtoMessage.decode(bytes);
  final grouped = <String, List<_ScreenAiLine>>{};
  for (final line in root.messages(2)) {
    final text = line.string(3).trim();
    if (text.isEmpty) continue;
    final rect = _readRect(line.message(2), imageWidth, imageHeight);
    if (rect == null) continue;
    final block = line.int32(5) ?? 0;
    final paragraph = line.int32(11) ?? 0;
    final language = line.string(4);
    final direction = line.int32(7) ?? 0;
    grouped
        .putIfAbsent('$block:$paragraph:$language', () => [])
        .add(
          _ScreenAiLine(
            text: text,
            rect: rect,
            language: language,
            vertical: direction == 3 || rect.height > rect.width * 1.25,
          ),
        );
  }

  final blocks = <OcrTextBlock>[];
  for (final lines in grouped.values) {
    if (lines.isEmpty) continue;
    final union = lines
        .map((line) => line.rect)
        .reduce((value, element) => value.expandToInclude(element));
    blocks.add(
      OcrTextBlock(
        xmin: union.left,
        ymin: union.top,
        xmax: union.right,
        ymax: union.bottom,
        lines: [for (final line in lines) line.text],
        vertical:
            lines.where((line) => line.vertical).length > lines.length / 2,
        lineGeometries: [
          for (final line in lines)
            OcrLineGeometry(
              xmin: line.rect.left,
              ymin: line.rect.top,
              xmax: line.rect.right,
              ymax: line.rect.bottom,
            ),
        ],
        language: lines.first.language,
      ),
    );
  }
  return blocks;
}

_NormalizedRect? _readRect(
  _ProtoMessage? message,
  int imageWidth,
  int imageHeight,
) {
  if (message == null || imageWidth <= 0 || imageHeight <= 0) return null;
  final x = (message.int32(1) ?? 0).toDouble();
  final y = (message.int32(2) ?? 0).toDouble();
  final width = (message.int32(3) ?? 0).toDouble();
  final height = (message.int32(4) ?? 0).toDouble();
  if (width <= 0 || height <= 0) return null;
  return _NormalizedRect(
    left: (x / imageWidth).clamp(0, 1).toDouble(),
    top: (y / imageHeight).clamp(0, 1).toDouble(),
    right: ((x + width) / imageWidth).clamp(0, 1).toDouble(),
    bottom: ((y + height) / imageHeight).clamp(0, 1).toDouble(),
  );
}

class _ScreenAiImage {
  const _ScreenAiImage({
    required this.pixels,
    required this.width,
    required this.height,
    required this.originalWidth,
    required this.originalHeight,
  });

  final Uint8List pixels;
  final int width;
  final int height;
  final int originalWidth;
  final int originalHeight;
}

class _ScreenAiLine {
  const _ScreenAiLine({
    required this.text,
    required this.rect,
    required this.language,
    required this.vertical,
  });

  final String text;
  final _NormalizedRect rect;
  final String language;
  final bool vertical;
}

class _NormalizedRect {
  const _NormalizedRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;

  _NormalizedRect expandToInclude(_NormalizedRect other) => _NormalizedRect(
    left: math.min(left, other.left),
    top: math.min(top, other.top),
    right: math.max(right, other.right),
    bottom: math.max(bottom, other.bottom),
  );
}

class _ProtoMessage {
  const _ProtoMessage(this._fields);

  final Map<int, List<_ProtoField>> _fields;

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

  int? int32(int field) {
    final value = _fields[field]?.firstOrNull;
    if (value?.wireType != 0 || value?.value is! int) return null;
    return value!.value as int;
  }
}

class _ProtoField {
  const _ProtoField(this.wireType, this.value);

  final int wireType;
  final Object value;
}

class _ProtoCursor {
  _ProtoCursor(this.bytes);

  final Uint8List bytes;
  int offset = 0;

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
