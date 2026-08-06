import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/eval/mihon/bridge_protocol.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/services/import_mihon_extension.dart';

void main() {
  group('local Mihon APK import planning', () {
    test('parses bridge-owned package identity and source metadata', () {
      final extension = MihonExtensionDescriptor.fromJson({
        'packageName': 'eu.kanade.tachiyomi.extension.all.example',
        'name': 'Example',
        'versionName': '1.4.2',
        'versionCode': 7,
        'lang': 'all',
        'isNsfw': true,
        'itemType': 'manga',
        'sources': [
          {
            'id': '1234567890123456789',
            'name': 'Example English',
            'lang': 'en',
            'baseUrl': 'https://example.test',
          },
        ],
      });

      expect(
        extension.packageName,
        'eu.kanade.tachiyomi.extension.all.example',
      );
      expect(extension.itemType, MihonExtensionItemType.manga);
      expect(extension.isNsfw, isTrue);
      expect(extension.sources.single.id, '1234567890123456789');
    });

    test('re-imports one package onto the same local source rows', () {
      final extension = _extension(
        version: '1.4.2',
        sourceIds: const ['1001', '1002'],
      );
      final first = planMihonApkImport(
        extension: extension,
        apkBase64: 'first APK',
        existingSources: const [],
      );
      final second = planMihonApkImport(
        extension: extension,
        apkBase64: 'second APK',
        existingSources: first.sources,
      );

      expect(first.itemType, ItemType.manga);
      expect(first.sourceCodeUrl, second.sourceCodeUrl);
      expect(
        first.sources.map((source) => source.id),
        second.sources.map((source) => source.id),
      );
      expect(second.sources.map((source) => source.id).toSet(), hasLength(2));
      expect(second.sources.every(isLocallyImportedMihonExtension), isTrue);
      expect(second.unavailableSourceIds, isEmpty);
    });

    test(
      'replaces removed children without losing the known newer version',
      () {
        final installed = planMihonApkImport(
          extension: _extension(
            version: '1.4.3',
            sourceIds: const ['1001', '1002'],
          ),
          apkBase64: 'installed APK',
          existingSources: const [],
        );
        final replacement = planMihonApkImport(
          extension: _extension(version: '1.4.2', sourceIds: const ['1001']),
          apkBase64: 'replacement APK',
          existingSources: installed.sources,
        );

        expect(replacement.sources.single.id, mihonLocalSourceId('1001'));
        expect(replacement.sources.single.version, '1.4.2');
        expect(replacement.sources.single.versionLast, '1.4.3');
        expect(replacement.unavailableSourceIds, {mihonLocalSourceId('1002')});
      },
    );

    test('reinstall makes a previously uninstalled local source visible', () {
      final installed =
          planMihonApkImport(
              extension: _extension(
                version: '1.4.2',
                sourceIds: const ['1001'],
              ),
              apkBase64: 'installed APK',
              existingSources: const [],
            ).sources.single
            ..isAdded = false
            ..isActive = false;

      final reinstalled = planMihonApkImport(
        extension: _extension(version: '1.4.2', sourceIds: const ['1001']),
        apkBase64: 'reinstalled APK',
        existingSources: [installed],
      ).sources.single;

      expect(reinstalled.isActive, isTrue);
    });
  });
}

MihonExtensionDescriptor _extension({
  required String version,
  required List<String> sourceIds,
}) => MihonExtensionDescriptor(
  packageName: 'eu.kanade.tachiyomi.extension.all.example',
  name: 'Example',
  versionName: version,
  versionCode: 7,
  lang: 'all',
  isNsfw: false,
  itemType: MihonExtensionItemType.manga,
  sources: sourceIds
      .map(
        (id) => MihonSourceDescriptor(
          id: id,
          name: 'Source $id',
          lang: 'en',
          baseUrl: 'https://example.test/$id',
        ),
      )
      .toList(),
);
