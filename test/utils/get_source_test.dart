import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/utils/source_lookup.dart';
import 'package:mangayomi/utils/utils.dart';

import '../test_utils/isar_library.dart';

/// getSource narrows its query before matching. It must answer exactly what
/// matching against every stored source answers.
void main() {
  late Directory directory;

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): await isarTestLibraryPath()},
    );
    directory = Directory.systemTemp.createTempSync('get_source');
    isar = await Isar.open(
      [SourceSchema],
      directory: directory.path,
      name: 'get_source',
    );
    var id = 1;
    Source source(
      String name,
      String lang, {
      bool added = true,
      String? code = 'code',
      String? params,
    }) => Source(
      id: id++,
      name: name,
      lang: lang,
      isAdded: added,
      sourceCode: code,
      itemType: ItemType.values[id % 3],
      additionalParams: params,
    )..sourceCodeLanguage = SourceCodeLanguage.mihon;
    isar.writeTxnSync(
      () => isar.sources.putAllSync([
        source('Alpha', 'en'),
        source('alpha', 'en'),
        source('ALPHA', 'fr'),
        source('Beta', 'en', added: false),
        source('Beta', 'en'),
        source('Gamma', 'ja', code: null),
        source('Gamma', 'ja'),
        source('Delta', 'all'),
        source('Ünï', 'de'),
        source(
          'Factory',
          'en',
          params: '{"mihon":{"factoryAvailable":false,"sourceId":"1"}}',
        ),
        source('Factory', 'en'),
        source('', ''),
      ]),
    );
  });

  tearDownAll(() async {
    await isar.close(deleteFromDisk: true);
    directory.deleteSync(recursive: true);
  });

  Source? reference(
    String lang,
    String name,
    int? sourceId, {
    bool installedOnly = false,
  }) {
    var query = isar.sources.filter().idIsNotNull();
    if (installedOnly) query = query.isAddedEqualTo(true);
    return findSourceFromList(
      query.findAllSync(),
      lang: lang,
      name: name,
      sourceId: sourceId,
      installedOnly: installedOnly,
    );
  }

  test('matches a lookup over every stored source', () {
    final names = [
      'Alpha',
      'alpha',
      'ALPHA',
      'Beta',
      'Gamma',
      'Delta',
      'Ünï',
      'ünï',
      'Factory',
      'Missing',
      '',
    ];
    final langs = ['en', 'fr', 'ja', 'all', 'de', 'EN', ''];
    final ids = <int?>[null, ...List.generate(14, (i) => i)];
    var checked = 0;
    for (final installedOnly in [false, true]) {
      for (final name in names) {
        for (final lang in langs) {
          for (final id in ids) {
            final expected = reference(
              lang,
              name,
              id,
              installedOnly: installedOnly,
            );
            final actual = getSource(
              lang,
              name,
              id,
              installedOnly: installedOnly,
            );
            expect(
              actual?.id,
              expected?.id,
              reason: 'lang=$lang name=$name id=$id installed=$installedOnly',
            );
            checked++;
          }
        }
      }
    }
    expect(checked, greaterThan(2000));
  });
}
