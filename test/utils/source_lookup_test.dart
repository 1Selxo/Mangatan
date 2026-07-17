import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/utils/source_lookup.dart';

void main() {
  test(
    'installed source remains available when hidden by a language filter',
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
          lang: 'ja',
          name: 'Example',
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
}
