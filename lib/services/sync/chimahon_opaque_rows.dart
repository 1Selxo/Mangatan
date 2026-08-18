import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:protobuf/protobuf.dart';

/// Exact-row operations for Chimahon fields that Mangatan cannot safely
/// interpret as cross-device identities.
///
/// In particular, global manga statistics contain a device-local database ID.
/// Keeping maximum exact-row multiplicity preserves both payloads without
/// inventing a merge key or synthesizing a record neither side wrote.
abstract final class ChimahonOpaqueRows {
  static List<T> mergeMaxMultiplicity<T extends GeneratedMessage>(
    Iterable<T> local,
    Iterable<T> remote,
  ) {
    final result = [for (final value in local) value.deepCopy()];
    final localCounts = _counts(local);
    final remoteSeen = <String, int>{};
    for (final value in remote) {
      final key = _exactKey(value);
      final seen = (remoteSeen[key] ?? 0) + 1;
      remoteSeen[key] = seen;
      if (seen > (localCounts[key] ?? 0)) result.add(value.deepCopy());
    }
    return result;
  }

  /// Returns one opaque digest for each baseline row not represented by an
  /// exact target row. Repeated equal rows retain multiset cardinality.
  static List<String> missingExactRows<T extends GeneratedMessage>(
    Iterable<T> baseline,
    Iterable<T> target,
  ) {
    final remaining = _counts(target);
    final missing = <String>[];
    for (final value in baseline) {
      final key = _exactKey(value);
      final count = remaining[key] ?? 0;
      if (count == 0) {
        missing.add(sha256.convert(value.writeToBuffer()).toString());
      } else {
        remaining[key] = count - 1;
      }
    }
    return missing;
  }

  static List<String> opaqueDigests<T extends GeneratedMessage>(
    Iterable<T> values,
  ) => [
    for (final value in values)
      sha256.convert(value.writeToBuffer()).toString(),
  ];

  static Map<String, int> _counts<T extends GeneratedMessage>(
    Iterable<T> values,
  ) {
    final result = <String, int>{};
    for (final value in values) {
      final key = _exactKey(value);
      result[key] = (result[key] ?? 0) + 1;
    }
    return result;
  }

  static String _exactKey(GeneratedMessage value) =>
      base64Encode(value.writeToBuffer());
}
