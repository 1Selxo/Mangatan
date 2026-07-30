import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/eval/mihon/bridge_protocol.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/modules/browse/widgets/source_extension_icon.dart';
import 'package:mangayomi/services/extension_icon_resolver.dart';

void main() {
  test('derives an icon URL from any repository index filename', () {
    expect(
      extensionRepositoryIconUrl(
        'https://repo.example/catalog/index.json?cache=1',
        'eu.kanade.tachiyomi.extension.ja.example',
      ),
      'https://repo.example/catalog/icon/'
      'eu.kanade.tachiyomi.extension.ja.example.png',
    );
  });

  test('falls back from retired Keiyoushi manga icons to Yuzono', () {
    final source = Source()
      ..sourceCodeLanguage = SourceCodeLanguage.mihon
      ..iconUrl =
          'https://raw.githubusercontent.com/keiyoushi/extensions/repo/icon/'
          'eu.kanade.tachiyomi.extension.ja.manga1000.png'
      ..additionalParams = encodeMihonSourceMetadata(
        sourceId: '123',
        packageName: 'eu.kanade.tachiyomi.extension.ja.manga1000',
      )
      ..repo = Repo(
        jsonUrl:
            'https://raw.githubusercontent.com/keiyoushi/extensions/repo/'
            'index.min.json',
      );

    expect(extensionIconCandidates(source), [
      'https://raw.githubusercontent.com/keiyoushi/extensions/repo/icon/'
          'eu.kanade.tachiyomi.extension.ja.manga1000.png',
      'https://raw.githubusercontent.com/yuzono/manga-repo/repo/icon/'
          'eu.kanade.tachiyomi.extension.ja.manga1000.png',
    ]);
  });

  test('keeps custom repository icons ahead of derived fallbacks', () {
    final source = Source()
      ..sourceCodeLanguage = SourceCodeLanguage.mihon
      ..iconUrl = 'https://cdn.example/custom.png'
      ..additionalParams = encodeMihonSourceMetadata(
        sourceId: '456',
        packageName: 'eu.kanade.tachiyomi.extension.en.example',
      )
      ..repo = Repo(jsonUrl: 'https://repo.example/store/catalog.json');

    expect(extensionIconCandidates(source), [
      'https://cdn.example/custom.png',
      'https://repo.example/store/icon/'
          'eu.kanade.tachiyomi.extension.en.example.png',
    ]);
  });

  testWidgets('renders a generic icon after exhausting candidates', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: SourceExtensionIcon(source: Source(), size: 37)),
    );

    expect(find.byIcon(Icons.extension_rounded), findsOneWidget);
  });
}
