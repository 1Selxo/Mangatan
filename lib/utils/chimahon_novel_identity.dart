import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Chimahon's identity rules for an imported EPUB book.
abstract final class ChimahonNovelIdentity {
  /// Returns the canonical wire identity, or `null` when empty metadata has no
  /// previously persisted book ID to fall back to.
  static String? stableIdOrNull({
    required String title,
    String? author,
    String? fallbackId,
  }) {
    final normalizedTitle = title.trim().toLowerCase();
    final normalizedAuthor = (author ?? '').trim().toLowerCase();
    if (normalizedTitle.isNotEmpty || normalizedAuthor.isNotEmpty) {
      return md5
          .convert(utf8.encode('$normalizedTitle|$normalizedAuthor'))
          .toString();
    }
    return fallbackId?.trim().isNotEmpty == true ? fallbackId : null;
  }

  /// Creates the exact ID Chimahon's EPUB importer assigns after parsing.
  /// Unlike restore's empty-metadata fallback, import always hashes the
  /// normalized pair, including the explicit-empty `|` pair.
  static String newBookId({required String title, String? author}) {
    final normalizedTitle = title.trim().toLowerCase();
    final normalizedAuthor = (author ?? '').trim().toLowerCase();
    return md5
        .convert(utf8.encode('$normalizedTitle|$normalizedAuthor'))
        .toString();
  }
}
