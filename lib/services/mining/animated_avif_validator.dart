import 'dart:io';
import 'dart:typed_data';

const animatedAvifMaxBytes = 10 * 1024 * 1024;
const animatedAvifMaxDimension = 640;
const animatedAvifMaxFrames = 80;
const animatedAvifMaxDuration = Duration(seconds: 10);

class AnimatedAvifValidation {
  const AnimatedAvifValidation({
    required this.width,
    required this.height,
    required this.frameCount,
    required this.duration,
    required this.sampleBytes,
  });

  final int width;
  final int height;
  final int frameCount;
  final Duration duration;
  final int sampleBytes;
}

class AnimatedAvifValidationException implements Exception {
  const AnimatedAvifValidationException(this.message);

  final String message;

  @override
  String toString() => 'Invalid animated AVIF: $message';
}

class AnimatedAvifValidator {
  const AnimatedAvifValidator();

  Future<AnimatedAvifValidation> validateFile(File file) async {
    final length = await file.length();
    if (length <= 0 || length > animatedAvifMaxBytes) {
      throw const AnimatedAvifValidationException(
        'file size is outside the allowed range',
      );
    }
    return validateBytes(await file.readAsBytes());
  }

  AnimatedAvifValidation validateBytes(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > animatedAvifMaxBytes) {
      throw const AnimatedAvifValidationException(
        'file size is outside the allowed range',
      );
    }
    final boxes = _boxes(bytes, 0, bytes.length);
    final ftyp = boxes.where((box) => box.type == 'ftyp').firstOrNull;
    if (ftyp == null || ftyp.payloadLength < 8) {
      throw const AnimatedAvifValidationException('missing ftyp box');
    }
    final brands = <String>{
      _ascii(bytes, ftyp.dataStart, 4),
      for (
        var offset = ftyp.dataStart + 8;
        offset + 4 <= ftyp.dataEnd;
        offset += 4
      )
        _ascii(bytes, offset, 4),
    };
    if (!brands.contains('avif') || !brands.contains('avis')) {
      throw const AnimatedAvifValidationException(
        'missing animated AVIF brands',
      );
    }

    final moov = boxes.where((box) => box.type == 'moov').firstOrNull;
    if (moov == null) {
      throw const AnimatedAvifValidationException('missing moov box');
    }
    _TrackInfo? selected;
    for (final trak in _children(
      bytes,
      moov,
    ).where((box) => box.type == 'trak')) {
      final info = _parseTrack(bytes, trak);
      if (info != null &&
          (info.handler == 'vide' || info.handler == 'pict') &&
          info.codec == 'av01') {
        selected = info;
        break;
      }
    }
    if (selected == null) {
      throw const AnimatedAvifValidationException('missing AV1 video track');
    }
    if (selected.width <= 0 ||
        selected.height <= 0 ||
        selected.width > animatedAvifMaxDimension ||
        selected.height > animatedAvifMaxDimension ||
        selected.width.isOdd ||
        selected.height.isOdd) {
      throw const AnimatedAvifValidationException(
        'dimensions are invalid or exceed 640 pixels',
      );
    }
    if (selected.frameCount < 2 ||
        selected.frameCount > animatedAvifMaxFrames) {
      throw const AnimatedAvifValidationException(
        'frame count is outside 2..80',
      );
    }
    if (selected.timescale <= 0 ||
        selected.timingSamples != selected.frameCount ||
        selected.timingUnits <= 0) {
      throw const AnimatedAvifValidationException(
        'sample timing is inconsistent',
      );
    }
    final durationMicros =
        selected.timingUnits *
        Duration.microsecondsPerSecond ~/
        selected.timescale;
    final duration = Duration(microseconds: durationMicros);
    if (duration <= Duration.zero || duration > animatedAvifMaxDuration) {
      throw const AnimatedAvifValidationException(
        'duration is outside the allowed range',
      );
    }
    if (selected.sampleSizes.length != selected.frameCount ||
        selected.sampleSizes.any(
          (size) => size <= 0 || size > animatedAvifMaxBytes,
        )) {
      throw const AnimatedAvifValidationException('sample sizes are invalid');
    }
    final sampleBytes = selected.sampleSizes.fold<int>(
      0,
      (total, size) => total + size,
    );
    if (sampleBytes <= 0 ||
        sampleBytes > bytes.length ||
        sampleBytes > animatedAvifMaxBytes) {
      throw const AnimatedAvifValidationException(
        'sample data exceeds the file bounds',
      );
    }
    return AnimatedAvifValidation(
      width: selected.width,
      height: selected.height,
      frameCount: selected.frameCount,
      duration: duration,
      sampleBytes: sampleBytes,
    );
  }
}

_TrackInfo? _parseTrack(Uint8List bytes, _IsoBox trak) {
  final children = _children(bytes, trak);
  final tkhd = children.where((box) => box.type == 'tkhd').firstOrNull;
  final mdia = children.where((box) => box.type == 'mdia').firstOrNull;
  if (tkhd == null || mdia == null || tkhd.payloadLength < 8) return null;
  final width = _uint32(bytes, tkhd.dataEnd - 8) >> 16;
  final height = _uint32(bytes, tkhd.dataEnd - 4) >> 16;

  final mediaChildren = _children(bytes, mdia);
  final mdhd = mediaChildren.where((box) => box.type == 'mdhd').firstOrNull;
  final hdlr = mediaChildren.where((box) => box.type == 'hdlr').firstOrNull;
  final minf = mediaChildren.where((box) => box.type == 'minf').firstOrNull;
  if (mdhd == null || hdlr == null || minf == null) return null;
  final version = bytes[mdhd.dataStart];
  final timescaleOffset = mdhd.dataStart + (version == 1 ? 20 : 12);
  if (timescaleOffset + 4 > mdhd.dataEnd ||
      hdlr.dataStart + 12 > hdlr.dataEnd) {
    return null;
  }
  final timescale = _uint32(bytes, timescaleOffset);
  final handler = _ascii(bytes, hdlr.dataStart + 8, 4);

  final stbl = _children(
    bytes,
    minf,
  ).where((box) => box.type == 'stbl').firstOrNull;
  if (stbl == null) return null;
  final samples = _children(bytes, stbl);
  final stsd = samples.where((box) => box.type == 'stsd').firstOrNull;
  final stts = samples.where((box) => box.type == 'stts').firstOrNull;
  final stsz = samples.where((box) => box.type == 'stsz').firstOrNull;
  if (stsd == null || stts == null || stsz == null) return null;
  final codec = _sampleEntryCodec(bytes, stsd);
  final timing = _sampleTiming(bytes, stts);
  final sizes = _sampleSizes(bytes, stsz);
  if (codec == null || timing == null || sizes == null) return null;
  return _TrackInfo(
    handler: handler,
    codec: codec,
    width: width,
    height: height,
    timescale: timescale,
    frameCount: sizes.length,
    timingSamples: timing.$1,
    timingUnits: timing.$2,
    sampleSizes: sizes,
  );
}

String? _sampleEntryCodec(Uint8List bytes, _IsoBox stsd) {
  if (stsd.dataStart + 8 > stsd.dataEnd) return null;
  final entryCount = _uint32(bytes, stsd.dataStart + 4);
  if (entryCount <= 0) return null;
  final entryOffset = stsd.dataStart + 8;
  if (entryOffset + 8 > stsd.dataEnd) return null;
  final size = _uint32(bytes, entryOffset);
  if (size < 8 || entryOffset + size > stsd.dataEnd) return null;
  return _ascii(bytes, entryOffset + 4, 4);
}

(int, int)? _sampleTiming(Uint8List bytes, _IsoBox stts) {
  if (stts.dataStart + 8 > stts.dataEnd) return null;
  final entryCount = _uint32(bytes, stts.dataStart + 4);
  if (entryCount <= 0 || entryCount > animatedAvifMaxFrames) return null;
  var offset = stts.dataStart + 8;
  var samples = 0;
  var units = 0;
  for (var index = 0; index < entryCount; index++) {
    if (offset + 8 > stts.dataEnd) return null;
    final count = _uint32(bytes, offset);
    final delta = _uint32(bytes, offset + 4);
    if (count <= 0 || delta <= 0) return null;
    samples += count;
    units += count * delta;
    if (samples > animatedAvifMaxFrames) return null;
    offset += 8;
  }
  return (samples, units);
}

List<int>? _sampleSizes(Uint8List bytes, _IsoBox stsz) {
  if (stsz.dataStart + 12 > stsz.dataEnd) return null;
  final uniformSize = _uint32(bytes, stsz.dataStart + 4);
  final sampleCount = _uint32(bytes, stsz.dataStart + 8);
  if (sampleCount <= 0 || sampleCount > animatedAvifMaxFrames) return null;
  if (uniformSize > 0) return List.filled(sampleCount, uniformSize);
  var offset = stsz.dataStart + 12;
  final result = <int>[];
  for (var index = 0; index < sampleCount; index++) {
    if (offset + 4 > stsz.dataEnd) return null;
    result.add(_uint32(bytes, offset));
    offset += 4;
  }
  return result;
}

List<_IsoBox> _children(Uint8List bytes, _IsoBox parent) =>
    _boxes(bytes, parent.dataStart, parent.dataEnd);

List<_IsoBox> _boxes(Uint8List bytes, int start, int end) {
  final result = <_IsoBox>[];
  var offset = start;
  while (offset < end) {
    if (offset + 8 > end) {
      throw const AnimatedAvifValidationException('truncated box header');
    }
    var size = _uint32(bytes, offset);
    final type = _ascii(bytes, offset + 4, 4);
    var headerSize = 8;
    if (size == 1) {
      if (offset + 16 > end) {
        throw const AnimatedAvifValidationException(
          'truncated extended box header',
        );
      }
      size = _uint64(bytes, offset + 8);
      headerSize = 16;
    } else if (size == 0) {
      size = end - offset;
    }
    if (size < headerSize || offset + size > end) {
      throw const AnimatedAvifValidationException('box exceeds file bounds');
    }
    result.add(
      _IsoBox(type: type, offset: offset, size: size, headerSize: headerSize),
    );
    offset += size;
  }
  return result;
}

int _uint32(Uint8List bytes, int offset) =>
    ByteData.sublistView(bytes).getUint32(offset);

int _uint64(Uint8List bytes, int offset) {
  final data = ByteData.sublistView(bytes);
  final high = data.getUint32(offset);
  final low = data.getUint32(offset + 4);
  final value = high * 0x100000000 + low;
  if (value > 0x7fffffffffffffff) {
    throw const AnimatedAvifValidationException('box size is too large');
  }
  return value;
}

String _ascii(Uint8List bytes, int offset, int length) =>
    String.fromCharCodes(bytes.sublist(offset, offset + length));

class _IsoBox {
  const _IsoBox({
    required this.type,
    required this.offset,
    required this.size,
    required this.headerSize,
  });

  final String type;
  final int offset;
  final int size;
  final int headerSize;

  int get dataStart => offset + headerSize;
  int get dataEnd => offset + size;
  int get payloadLength => size - headerSize;
}

class _TrackInfo {
  const _TrackInfo({
    required this.handler,
    required this.codec,
    required this.width,
    required this.height,
    required this.timescale,
    required this.frameCount,
    required this.timingSamples,
    required this.timingUnits,
    required this.sampleSizes,
  });

  final String handler;
  final String codec;
  final int width;
  final int height;
  final int timescale;
  final int frameCount;
  final int timingSamples;
  final int timingUnits;
  final List<int> sampleSizes;
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
