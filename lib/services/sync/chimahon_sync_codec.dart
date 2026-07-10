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
      final protobufBytes = format == ChimahonSyncWireFormat.gzipProtobuf
          ? const GZipDecoder().decodeBytes(bytes, verify: true)
          : Uint8List.fromList(bytes);
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
