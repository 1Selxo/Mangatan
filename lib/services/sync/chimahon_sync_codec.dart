import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:protobuf/protobuf.dart';

enum ChimahonSyncWireFormat { protobuf, gzipProtobuf }

class DecodedChimahonSync {
  const DecodedChimahonSync({
    required this.backup,
    required this.format,
    required this.protobufBytes,
  });

  final BackupMihon backup;
  final ChimahonSyncWireFormat format;
  final Uint8List protobufBytes;
}

class ChimahonSyncFormatException implements Exception {
  const ChimahonSyncFormatException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null ? message : '$message: $cause';
}

/// Encodes the backup envelope shared by Mihon, Komikku, and Chimahon.
///
/// SyncYomi and WebDAV send raw protobuf. Google Drive and normal `.tachibk`
/// files gzip the exact same protobuf payload, so both representations are
/// accepted here.
class ChimahonSyncCodec {
  const ChimahonSyncCodec();

  static const int defaultSizeLimit = 250 << 20;

  DecodedChimahonSync decode(
    List<int> bytes, {
    int sizeLimit = defaultSizeLimit,
  }) {
    if (bytes.isEmpty) {
      throw const ChimahonSyncFormatException('The sync payload is empty');
    }

    final format = _isGzip(bytes)
        ? ChimahonSyncWireFormat.gzipProtobuf
        : ChimahonSyncWireFormat.protobuf;

    try {
      late final Uint8List protobufBytes;
      if (format == ChimahonSyncWireFormat.gzipProtobuf) {
        final output = _SizeLimitedOutputStream(sizeLimit);
        const GZipDecoder().decodeStream(
          InputMemoryStream(bytes),
          output,
          verify: true,
        );
        protobufBytes = output.getBytes();
      } else {
        if (bytes.length > sizeLimit) {
          throw FormatException(
            'Payload exceeds the $sizeLimit-byte decoded size limit',
          );
        }
        protobufBytes = Uint8List.fromList(bytes);
      }
      final backup = BackupMihon.create()
        ..mergeFromCodedBufferReader(
          CodedBufferReader(protobufBytes, sizeLimit: sizeLimit),
        );
      return DecodedChimahonSync(
        backup: backup,
        format: format,
        protobufBytes: protobufBytes,
      );
    } catch (error) {
      throw ChimahonSyncFormatException(
        'Invalid Mihon/Komikku/Chimahon sync payload',
        error,
      );
    }
  }

  Uint8List encode(
    BackupMihon backup, {
    ChimahonSyncWireFormat format = ChimahonSyncWireFormat.protobuf,
    int compressionLevel = 6,
  }) {
    final protobufBytes = backup.writeToBuffer();
    if (format == ChimahonSyncWireFormat.protobuf) return protobufBytes;
    return const GZipEncoder().encodeBytes(
      protobufBytes,
      level: compressionLevel.clamp(0, 9),
    );
  }

  bool _isGzip(List<int> bytes) =>
      bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
}

/// Bounds gzip expansion before the protobuf reader receives the payload.
/// This avoids allocating an attacker-controlled decompressed buffer first.
class _SizeLimitedOutputStream extends OutputStream {
  _SizeLimitedOutputStream(this.limit)
    : super(byteOrder: ByteOrder.littleEndian);

  final int limit;
  final BytesBuilder _bytes = BytesBuilder(copy: false);

  @override
  int get length => _bytes.length;

  void _reserve(int count) {
    if (count < 0 || length + count > limit) {
      throw FormatException(
        'Payload exceeds the $limit-byte decoded size limit',
      );
    }
  }

  @override
  void clear() => _bytes.clear();

  @override
  void flush() {}

  @override
  void writeByte(int value) {
    _reserve(1);
    _bytes.addByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final count = length ?? bytes.length;
    if (count > bytes.length) {
      throw RangeError.range(count, 0, bytes.length, 'length');
    }
    _reserve(count);
    _bytes.add(count == bytes.length ? bytes : bytes.sublist(0, count));
  }

  @override
  void writeStream(InputStream stream) {
    final count = stream.length;
    _reserve(count);
    _bytes.add(stream.readBytes(count).toUint8List());
  }

  @override
  Uint8List getBytes() => _bytes.toBytes();

  @override
  Uint8List subset(int start, [int? end]) {
    final bytes = _bytes.toBytes();
    return Uint8List.sublistView(bytes, start, end);
  }
}
