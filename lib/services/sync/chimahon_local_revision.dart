import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/model/source_preference.dart';
import 'package:mangayomi/models/category.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/download.dart';
import 'package:mangayomi/models/history.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/models/sync_preference.dart';
import 'package:mangayomi/models/track.dart';
import 'package:mangayomi/models/update.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';

/// Revision of every local collection that can change an authoritative
/// Download-only plan or one of its settings projections.
final class ChimahonLocalRevision {
  const ChimahonLocalRevision(this.value);

  final String value;

  static Future<ChimahonLocalRevision> capture(
    Isar database,
    BackupMihon projection,
  ) async {
    final mining = await MiningPreferences.writableSnapshot();
    final payload = <String, Object?>{
      'projection': base64Encode(projection.writeToBuffer()),
      'manga': _rows(
        database.mangas.where().findAllSync(),
        (row) => row.toJson(),
      ),
      'chapter': _rows(
        database.chapters.where().findAllSync(),
        (row) => row.toJson(),
      ),
      'category': _rows(
        database.categorys.where().findAllSync(),
        (row) => row.toJson(),
      ),
      'download': _rows(
        database.downloads.where().findAllSync(),
        (row) => row.toJson(),
      ),
      'history': _rows(
        database.historys.where().findAllSync(),
        (row) => row.toJson(),
      ),
      'update': _rows(
        database.updates.where().findAllSync(),
        (row) => row.toJson(),
      ),
      'track': _rows(
        database.tracks.where().findAllSync(),
        (row) => row.toJson(),
      ),
      'source': _rows(
        database.sources.where().findAllSync(),
        (row) => row.toJson(),
      ),
      'sourcePreference': _rows(
        database.sourcePreferences.where().findAllSync(),
        (row) => row.toJson(),
      ),
      'settings': _rows(
        database.settings.where().findAllSync(),
        (row) => row.toJson(),
      ),
      'syncPreference': _rows(
        database.syncPreferences.where().findAllSync(),
        (row) => row.toJson(),
      ),
      'mining': mining.revisionEntries,
    };
    return ChimahonLocalRevision(
      sha256.convert(utf8.encode(jsonEncode(payload))).toString(),
    );
  }

  static List<Map<String, dynamic>> _rows<T>(
    Iterable<T> rows,
    Map<String, dynamic> Function(T row) encode,
  ) {
    final encoded = rows.map(encode).toList(growable: false);
    encoded.sort(
      (left, right) => (left['id'] ?? left['syncId'] ?? 0).toString().compareTo(
        (right['id'] ?? right['syncId'] ?? 0).toString(),
      ),
    );
    return encoded;
  }
}
