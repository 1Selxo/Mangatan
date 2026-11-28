import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/eval/mihon/bridge_protocol.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/services/extension_catalog_reconciler.dart';

void main() {
  test('refreshes mutable catalog metadata without changing user state', () {
    final existing = _twicomi()
      ..isActive = false
      ..isAdded = false
      ..isNsfw = true
      ..isPinned = true
      ..sourceCode = 'cached code'
      ..preferenceList = 'saved preferences'
      ..version = '1.4.0'
      ..versionLast = '1.4.0';
    final catalog = _twicomi()
      ..isNsfw = false
      ..iconUrl = 'https://repo.test/new-icon.png'
      ..version = '1.4.1';

    final changed = applyExtensionCatalogMetadata(
      existing,
      catalog,
      repo: catalog.repo,
    );

    expect(changed, isTrue);
    expect(existing.isNsfw, isFalse);
    expect(existing.iconUrl, catalog.iconUrl);
    expect(existing.version, '1.4.1');
    expect(existing.versionLast, '1.4.1');
    expect(existing.isActive, isFalse);
    expect(existing.isPinned, isTrue);
    expect(existing.sourceCode, 'cached code');
    expect(existing.preferenceList, 'saved preferences');
    expect(mihonSourceMetadata(existing)?.extensionName, 'Twicomi');
    expect(mihonSourceMetadata(existing)?.packageLang, 'all');
  });

  test('preserves factory availability and installed version', () {
    final existing = _twicomi()
      ..isAdded = true
      ..version = '1.4.0'
      ..versionLast = '1.4.1'
      ..additionalParams = encodeMihonSourceMetadata(
        sourceId: _sourceId,
        packageName: _packageName,
        factoryAvailable: false,
      );
    final catalog = _twicomi()..version = '1.4.2';

    applyExtensionCatalogMetadata(existing, catalog, repo: catalog.repo);

    expect(existing.version, '1.4.0');
    expect(existing.versionLast, '1.4.1');
    expect(mihonSourceMetadata(existing)?.factoryAvailable, isFalse);
  });

  test(
    'an installed Mihon source keeps the name and address its extension gives',
    () {
      // The launch refresh sets them from the extension itself. MangaBox's
      // listing gives another base URL, so the two wrote it back and forth on
      // every launch.
      final installed = _twicomi()
        ..isAdded = true
        ..baseUrl = 'https://twicomi.com';
      final catalog = _twicomi()
        ..baseUrl = 'https://twicomi.com/reader/'
        ..name = 'Twicomi (listing)';

      final changed = applyExtensionCatalogMetadata(
        installed,
        catalog,
        repo: catalog.repo,
      );

      expect(installed.baseUrl, 'https://twicomi.com');
      expect(installed.name, 'Twicomi');
      expect(changed, isFalse);
    },
  );

  test('an installed source keeps the address of the APK it holds', () {
    // The repository moved MangaDex to a new release URL without a version
    // bump. Taking that address into the installed rows made the launch
    // refresh, which finds an extension's rows by address, recreate 62 of
    // them on every launch, clearing their preferences.
    const moved = 'https://repo.test/b4f9106/tachiyomi-all.twicomi-v1.4.1.apk';
    final installed = _twicomi()..isAdded = true;
    final listing = _twicomi()..isAdded = false;
    final catalog = _twicomi()..sourceCodeUrl = moved;

    applyExtensionCatalogMetadata(installed, catalog, repo: catalog.repo);
    applyExtensionCatalogMetadata(listing, catalog, repo: catalog.repo);

    expect(
      installed.sourceCodeUrl,
      'https://repo.test/tachiyomi-all.twicomi-v1.4.1.apk',
    );
    expect(listing.sourceCodeUrl, moved);
  });
}

const _sourceId = '4589056979500242728';
const _packageName = 'eu.kanade.tachiyomi.extension.all.twicomi';

Source _twicomi() => Source()
  ..id = mihonLocalSourceId(_sourceId)
  ..name = 'Twicomi'
  ..baseUrl = 'https://twicomi.com'
  ..lang = 'all'
  ..isNsfw = false
  ..sourceCodeUrl = 'https://repo.test/tachiyomi-all.twicomi-v1.4.1.apk'
  ..iconUrl = 'https://repo.test/twicomi.png'
  ..version = '1.4.1'
  ..versionLast = '1.4.1'
  ..sourceCodeLanguage = SourceCodeLanguage.mihon
  ..additionalParams = encodeMihonSourceMetadata(
    sourceId: _sourceId,
    packageName: _packageName,
    extensionName: 'Twicomi',
    packageLang: 'all',
  )
  ..repo = Repo(
    name: 'Keiyoushi',
    website: 'https://keiyoushi.github.io',
    jsonUrl: 'https://repo.test/index.min.json',
  );
