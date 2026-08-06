import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/eval/mihon/bridge_protocol.dart';
import 'package:mangayomi/utils/source_lookup.dart';

void main() {
  test(
    'installed source id survives hidden filters and remote display aliases',
    () {
      final source = Source(
        id: 42,
        name: 'Example',
        lang: 'ja',
        sourceCode: 'installed code',
        isAdded: true,
        isActive: false,
      );

      expect(
        findSourceFromList(
          [source],
          lang: 'all',
          name: 'Remote Jellyfin alias',
          sourceId: 42,
          installedOnly: true,
        ),
        same(source),
      );
    },
  );

  test('catalog-only source is unavailable to installed-only lookups', () {
    final source = Source(
      id: 42,
      name: 'Example',
      lang: 'ja',
      sourceCode: 'catalog code',
      isAdded: false,
      isActive: true,
    );

    expect(
      findSourceFromList(
        [source],
        lang: 'ja',
        name: 'Example',
        sourceId: 42,
        installedOnly: true,
      ),
      isNull,
    );
  });

  test('missing factory child is unavailable to installed-only lookups', () {
    final source = Source(
      id: 9,
      name: 'Missing Jellyfin library',
      lang: 'all',
      sourceCode: 'installed extension',
      isAdded: true,
      additionalParams: encodeMihonSourceMetadata(
        sourceId: '99',
        packageName: 'jellyfin',
        factoryAvailable: false,
      ),
    )..sourceCodeLanguage = SourceCodeLanguage.mihon;

    expect(
      findSourceFromList(
        [source],
        lang: 'all',
        name: source.name!,
        sourceId: source.id,
        installedOnly: true,
      ),
      isNull,
    );
  });
}
