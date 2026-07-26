import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:protobuf/protobuf.dart';

/// Privacy-safe, schema-level comparison of two Chimahon protobuf payloads.
///
/// The report contains protobuf field paths, occurrence counts, and aggregate
/// hashes only. Record identifiers and field values are used only in memory to
/// calculate those aggregates and are never retained by the public result.
class ChimahonBackupSemanticDiff {
  ChimahonBackupSemanticDiff._(
    Map<String, ChimahonSemanticFieldDifference> fieldDifferences,
  ) : fieldDifferences = Map.unmodifiable(fieldDifferences);

  factory ChimahonBackupSemanticDiff.compare({
    required BackupMihon remote,
    required BackupMihon proposed,
  }) {
    // A per-report secret salt prevents low-entropy values (for example a
    // boolean or short title) from being guessed from the published hashes.
    // Both sides share it in memory so equality and order evidence remain
    // useful, but it is deliberately absent from the result.
    final random = Random.secure();
    final reportSalt = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256), growable: false),
    );
    final remoteFields = _SemanticFieldCollector.collect(remote);
    final proposedFields = _SemanticFieldCollector.collect(proposed);
    final paths = {...remoteFields.keys, ...proposedFields.keys}.toList()
      ..sort();
    final differences = <String, ChimahonSemanticFieldDifference>{};
    for (final path in paths) {
      final remoteSummary = _SemanticSeriesSummary.from(
        path,
        remoteFields[path] ?? const [],
        reportSalt,
      );
      final proposedSummary = _SemanticSeriesSummary.from(
        path,
        proposedFields[path] ?? const [],
        reportSalt,
      );
      if (remoteSummary.orderedSha256 == proposedSummary.orderedSha256) {
        continue;
      }
      differences[path] = ChimahonSemanticFieldDifference._compare(
        remoteSummary,
        proposedSummary,
      );
    }
    return ChimahonBackupSemanticDiff._(differences);
  }

  /// Changed schema paths, ordered lexicographically for stable diagnostics.
  final Map<String, ChimahonSemanticFieldDifference> fieldDifferences;

  bool get equivalent => fieldDifferences.isEmpty;

  Map<String, Object> toSafeJson() => {
    'equivalent': equivalent,
    'changedFieldPathCount': fieldDifferences.length,
    'changedFieldPaths': {
      for (final entry in fieldDifferences.entries)
        entry.key: entry.value.toSafeJson(),
    },
  };
}

/// Aggregate-only evidence for one changed protobuf schema path.
class ChimahonSemanticFieldDifference {
  ChimahonSemanticFieldDifference._({
    required this.remoteOccurrences,
    required this.proposedOccurrences,
    required this.matchingOccurrences,
    required this.remoteOnlyOccurrences,
    required this.proposedOnlyOccurrences,
    required this.remoteOrderedSha256,
    required this.proposedOrderedSha256,
    required this.remoteUnorderedSha256,
    required this.proposedUnorderedSha256,
  });

  factory ChimahonSemanticFieldDifference._compare(
    _SemanticSeriesSummary remote,
    _SemanticSeriesSummary proposed,
  ) {
    var matching = 0;
    final digests = {
      ...remote.digestCounts.keys,
      ...proposed.digestCounts.keys,
    };
    for (final digest in digests) {
      final remoteCount = remote.digestCounts[digest] ?? 0;
      final proposedCount = proposed.digestCounts[digest] ?? 0;
      matching += remoteCount < proposedCount ? remoteCount : proposedCount;
    }
    return ChimahonSemanticFieldDifference._(
      remoteOccurrences: remote.occurrences,
      proposedOccurrences: proposed.occurrences,
      matchingOccurrences: matching,
      remoteOnlyOccurrences: remote.occurrences - matching,
      proposedOnlyOccurrences: proposed.occurrences - matching,
      remoteOrderedSha256: remote.orderedSha256,
      proposedOrderedSha256: proposed.orderedSha256,
      remoteUnorderedSha256: remote.unorderedSha256,
      proposedUnorderedSha256: proposed.unorderedSha256,
    );
  }

  final int remoteOccurrences;
  final int proposedOccurrences;
  final int matchingOccurrences;
  final int remoteOnlyOccurrences;
  final int proposedOnlyOccurrences;
  final String remoteOrderedSha256;
  final String proposedOrderedSha256;
  final String remoteUnorderedSha256;
  final String proposedUnorderedSha256;

  /// Whether the same multiset of values occurs in a different wire order.
  bool get orderOnly =>
      remoteOccurrences == proposedOccurrences &&
      remoteUnorderedSha256 == proposedUnorderedSha256;

  Map<String, Object> toSafeJson() => {
    'counts': {
      'remoteOccurrences': remoteOccurrences,
      'proposedOccurrences': proposedOccurrences,
      'matchingOccurrences': matchingOccurrences,
      'remoteOnlyOccurrences': remoteOnlyOccurrences,
      'proposedOnlyOccurrences': proposedOnlyOccurrences,
    },
    'orderOnly': orderOnly,
    'hashes': {
      'remoteOrderedSha256': remoteOrderedSha256,
      'proposedOrderedSha256': proposedOrderedSha256,
      'remoteUnorderedSha256': remoteUnorderedSha256,
      'proposedUnorderedSha256': proposedUnorderedSha256,
    },
  };
}

class _SemanticFieldCollector {
  _SemanticFieldCollector._();

  final Map<String, List<Uint8List>> _fields = {};

  static Map<String, List<Uint8List>> collect(BackupMihon backup) {
    final collector = _SemanticFieldCollector._();
    collector._visitMessage(backup, 'BackupMihon');
    return collector._fields;
  }

  void _visitMessage(GeneratedMessage message, String messagePath) {
    final fields = message.info_.fieldInfo.values.toList()
      ..sort((left, right) => left.tagNumber.compareTo(right.tagNumber));
    for (final field in fields) {
      final value = message.getFieldOrNull(field.tagNumber);
      if (value == null) continue;
      if (field.isMapField) {
        final map = value as Map;
        if (map.isEmpty) continue;
        final path = '$messagePath.${field.protoName}{}';
        _add(path, _encodeMapField(message, field, map));
        continue;
      }
      if (field.isRepeated) {
        final values = value as List;
        final path = '$messagePath.${field.protoName}[]';
        for (final item in values) {
          _add(path, _encodeKnownFieldValue(message, field, item));
          if (item is GeneratedMessage) _visitMessage(item, path);
        }
        continue;
      }

      final path = '$messagePath.${field.protoName}';
      _add(path, _encodeKnownFieldValue(message, field, value));
      if (value is GeneratedMessage) _visitMessage(value, path);
    }

    final unknownFields = message.unknownFields.asMap().entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    for (final entry in unknownFields) {
      final path = '$messagePath.unknownFields[${entry.key}]';
      final writer = CodedBufferWriter();
      entry.value.writeTo(entry.key, writer);
      _add(path, writer.toBuffer());
    }
  }

  void _add(String path, Uint8List bytes) {
    (_fields[path] ??= []).add(bytes);
  }
}

Uint8List _encodeKnownFieldValue(
  GeneratedMessage owner,
  FieldInfo field,
  Object value,
) {
  final envelope = owner.createEmptyInstance();
  if (field.isRepeated) {
    (envelope.getField(field.tagNumber) as List).add(value);
  } else {
    envelope.setField(field.tagNumber, value);
  }
  return envelope.writeToBuffer();
}

Uint8List _encodeMapField(GeneratedMessage owner, FieldInfo field, Map value) {
  final envelope = owner.createEmptyInstance();
  (envelope.getField(field.tagNumber) as Map).addAll(value);
  return envelope.writeToBuffer();
}

class _SemanticSeriesSummary {
  _SemanticSeriesSummary._({
    required this.occurrences,
    required this.orderedSha256,
    required this.unorderedSha256,
    required this.digestCounts,
  });

  factory _SemanticSeriesSummary.from(
    String path,
    List<Uint8List> values,
    Uint8List reportSalt,
  ) {
    final digests = <String>[];
    final digestCounts = <String, int>{};
    for (final value in values) {
      final digest = sha256
          .convert(
            _frameBytes([
              utf8.encode('chimahon-semantic-field-value-v1'),
              reportSalt,
              utf8.encode(path),
              value,
            ]),
          )
          .toString();
      digests.add(digest);
      digestCounts[digest] = (digestCounts[digest] ?? 0) + 1;
    }
    final sortedDigests = [...digests]..sort();
    return _SemanticSeriesSummary._(
      occurrences: values.length,
      orderedSha256: _hashDigestSeries(path, 'ordered', digests, reportSalt),
      unorderedSha256: _hashDigestSeries(
        path,
        'unordered',
        sortedDigests,
        reportSalt,
      ),
      digestCounts: Map.unmodifiable(digestCounts),
    );
  }

  final int occurrences;
  final String orderedSha256;
  final String unorderedSha256;
  final Map<String, int> digestCounts;
}

String _hashDigestSeries(
  String path,
  String ordering,
  Iterable<String> digests,
  Uint8List reportSalt,
) => sha256
    .convert(
      _frameBytes([
        utf8.encode('chimahon-semantic-field-aggregate-v1'),
        reportSalt,
        utf8.encode(path),
        utf8.encode(ordering),
        ...digests.map(utf8.encode),
      ]),
    )
    .toString();

Uint8List _frameBytes(Iterable<List<int>> values) {
  final framed = BytesBuilder(copy: false);
  for (final value in values) {
    final length = ByteData(8)..setUint64(0, value.length, Endian.big);
    framed
      ..add(length.buffer.asUint8List())
      ..add(value);
  }
  return framed.takeBytes();
}
