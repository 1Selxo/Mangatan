import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/eval/mihon/bridge_protocol.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/modules/browse/extension/extension_package.dart';

void main() {
  group('extension package catalog entries', () {
    test('expands an available package into enabled source languages', () {
      final sources = [
        _mihonSource('1', name: 'Comick', lang: 'en', active: true),
        _mihonSource('2', name: 'Comick', lang: 'fr', active: true),
        _mihonSource('3', name: 'Comick', lang: 'sv', active: false),
        _mihonSource('4', name: 'Comick', lang: 'id'),
      ];

      final packages = groupExtensionPackages(sources);
      final available = packages.single.catalogEntries.toList();

      expect(packages, hasLength(1));
      expect(packages.single.sources, hasLength(4));
      expect(available.map((entry) => entry.lang), ['en', 'fr']);
      expect(available.map((entry) => entry.name), ['Comick', 'Comick']);
      expect(available.map((entry) => entry.lang), isNot(contains('all')));
      expect(
        available.every((entry) => identical(entry.package, packages.single)),
        isTrue,
      );
      expect(
        belongsToSameMihonExtension(
          available.first.source,
          available.last.source,
        ),
        isTrue,
      );
      expect(available.map((entry) => entry.section).toSet(), {
        ExtensionCatalogSection.available,
      });
    });

    test(
      'removes an available language row when that language is disabled',
      () {
        final english = _mihonSource(
          '1',
          name: 'MangaDex',
          lang: 'en',
          active: true,
        );
        final japanese = _mihonSource(
          '2',
          name: 'MangaDex',
          lang: 'ja',
          active: true,
        );

        japanese.isActive = false;
        final available = groupExtensionPackages([
          english,
          japanese,
        ]).single.catalogEntries.toList();

        expect(available.map((entry) => entry.lang), ['en']);
      },
    );

    test('keeps a generic all source in the Multi category', () {
      final package = groupExtensionPackages([
        _mihonSource('1', name: 'Twicomi', lang: 'all', active: true),
      ]).single;

      expect(package.catalogEntries.single.lang, 'all');
      expect(package.catalogEntries.single.name, 'Twicomi');
    });

    test('collapses an installed multi-language package to one Multi row', () {
      final package = groupExtensionPackages([
        _mihonSource('1', name: 'MangaDex', lang: 'en')
          ..isAdded = true
          ..sourceCode = 'installed APK',
        _mihonSource('2', name: 'MangaDex', lang: 'ja'),
      ]).single;

      expect(package.isInstalled, isTrue);
      expect(package.catalogEntries, hasLength(1));
      expect(package.catalogEntries.single.lang, 'all');
      expect(package.catalogEntries.single.name, 'MangaDex');
      expect(
        package.catalogEntries.single.section,
        ExtensionCatalogSection.installed,
      );
    });

    test('aggregates updates and searches contained source metadata', () {
      final package = groupExtensionPackages([
        _mihonSource(
            '4589056979500242728',
            name: 'Twicomi',
            lang: 'all',
            active: true,
            baseUrl: 'https://twicomi.com',
          )
          ..isAdded = true
          ..sourceCode = 'installed APK'
          ..version = '1.4.0'
          ..versionLast = '1.4.1',
      ]).single;

      expect(package.updateAvailable, isTrue);
      expect(
        package.catalogEntries.single.section,
        ExtensionCatalogSection.update,
      );
      expect(package.matchesQuery('twicomi.com'), isTrue);
      expect(package.matchesQuery('4589056979500242728'), isTrue);
    });

    test('detects updates for legacy installed-code rows', () {
      final package = groupExtensionPackages([
        _mihonSource('1', name: 'Legacy', lang: 'all', active: false)
          ..isAdded = false
          ..sourceCode = 'installed APK'
          ..version = '1.4.0'
          ..versionLast = '1.4.1',
      ]).single;

      expect(package.updateAvailable, isTrue);
      expect(package.source.id, mihonLocalSourceId('1'));
    });

    test('does not combine unrelated non-Mihon extensions', () {
      final first = Source(id: 1, name: 'First')..isActive = true;
      final second = Source(id: 2, name: 'Second')..isActive = true;

      expect(groupExtensionPackages([first, second]), hasLength(2));
    });

    test(
      'keeps factory child settings separate inside an installed package',
      () {
        final webtoon = _mihonSource('1', name: 'Wolf - Webtoon', lang: 'ko');
        final comics = _mihonSource('2', name: 'Wolf - Comics', lang: 'ko');
        final photo = _mihonSource('3', name: 'Wolf - Photo', lang: 'ko');
        final unrelated = _mihonSource('4', name: 'Other', lang: 'ko')
          ..sourceCodeUrl = 'https://example.test/apk/other.apk'
          ..additionalParams = encodeMihonSourceMetadata(
            sourceId: '4',
            packageName: 'eu.kanade.tachiyomi.extension.ko.other',
          );

        final settingsSources = extensionSettingsSources(webtoon, [
          webtoon,
          comics,
          photo,
          unrelated,
        ]);

        expect(settingsSources.map((source) => source.name), [
          'Wolf - Comics',
          'Wolf - Photo',
          'Wolf - Webtoon',
        ]);
      },
    );
  });
}

Source _mihonSource(
  String sourceId, {
  required String name,
  required String lang,
  bool active = false,
  String baseUrl = 'https://example.test',
}) => Source()
  ..id = mihonLocalSourceId(sourceId)
  ..name = name
  ..lang = lang
  ..baseUrl = baseUrl
  ..isActive = active
  ..version = '1.4.1'
  ..versionLast = '1.4.1'
  ..sourceCodeLanguage = SourceCodeLanguage.mihon
  ..sourceCodeUrl = 'https://example.test/apk/comick.apk'
  ..repo = Repo(jsonUrl: 'https://example.test/index.min.json')
  ..additionalParams = encodeMihonSourceMetadata(
    sourceId: sourceId,
    packageName: 'eu.kanade.tachiyomi.extension.all.comick',
    extensionName: name,
    packageLang: 'all',
  );
