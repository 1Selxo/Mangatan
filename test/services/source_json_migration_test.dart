import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/services/source_json_migration.dart';

import '../test_utils/isar_library.dart';

/// Filter and preference lists stored with non-ASCII text load through a
/// slow path into two-byte strings; on the profiled library they were larger
/// than the APKs and made each read of the installed sources four times
/// slower. Existing rows are rewritten once, reading back the same.
void main() {
  late Directory directory;
  late Isar db;

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): await isarTestLibraryPath()},
    );
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('source-json-');
    db = await Isar.open(
      [SourceSchema],
      directory: directory.path,
      name: 'json',
    );
  });

  tearDown(() async {
    await db.close(deleteFromDisk: true);
    await directory.delete(recursive: true);
  });

  test('stored lists become ASCII, read back the same, once', () async {
    final filters = jsonEncode([
      {
        'name': 'ジャンル',
        'values': ['恋愛', 'Ação', '📚'],
      },
    ]);
    const preferences = '[{"key":"lang","value":"ελληνικά"}]';
    await db.writeTxn(
      () => db.sources.putAll([
        Source(id: 1, filterList: filters, preferenceList: preferences)
          ..updatedAt = 42,
        Source(id: 2, filterList: '[]'),
      ]),
    );

    await migrateSourceJsonToAscii(db, directory);

    final stored = db.sources.getSync(1)!;
    expect(stored.filterList!.codeUnits.every((c) => c < 128), isTrue);
    expect(jsonDecode(stored.filterList!), jsonDecode(filters));
    expect(jsonDecode(stored.preferenceList!), jsonDecode(preferences));
    expect(stored.updatedAt, 42);

    // The marker keeps it from running again.
    await db.writeTxn(
      () => db.sources.put(stored..preferenceList = preferences),
    );
    await migrateSourceJsonToAscii(db, directory);
    expect(db.sources.getSync(1)!.preferenceList, preferences);
  });
}
