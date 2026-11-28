import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/repositories/db_write_queue.dart';
import 'package:mangayomi/utils/ascii_json.dart';
import 'package:path/path.dart' as p;

/// Rewrites the filter and preference lists stored before they were kept as
/// ASCII JSON (see [asciiJson]), once per database. The values read back the
/// same; only how fast they load changes, so `updatedAt` is left alone and
/// nothing is synced for it.
Future<void> migrateSourceJsonToAscii(
  Isar isar,
  Directory databaseDirectory,
) async {
  final marker = File(p.join(databaseDirectory.path, '.source-json-ascii-v1'));
  if (await marker.exists()) return;
  final rows = await isar.sources
      .filter()
      .filterListIsNotNull()
      .or()
      .preferenceListIsNotNull()
      .findAll();
  final changed = <Source>[];
  for (final source in rows) {
    final filters = asciiJsonOrNull(source.filterList);
    final preferences = asciiJsonOrNull(source.preferenceList);
    if (identical(filters, source.filterList) &&
        identical(preferences, source.preferenceList)) {
      continue;
    }
    changed.add(
      source
        ..filterList = filters
        ..preferenceList = preferences,
    );
  }
  if (changed.isNotEmpty) {
    await dbWriteQueue.run(
      () => isar.writeTxn(() => isar.sources.putAll(changed)),
    );
  }
  await marker.writeAsString('done', flush: true);
}
