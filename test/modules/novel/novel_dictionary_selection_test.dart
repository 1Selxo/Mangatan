import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/modules/novel/widgets/novel_dictionary_selection.dart';
import 'package:mangayomi/services/get_html_content.dart';

void main() {
  testWidgets('novel content is exposed through Flutter text selection', (
    tester,
  ) async {
    final chapter = Chapter(mangaId: 1, name: '第一章');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GestureDetector(
            onTapUp: (_) {},
            child: NovelDictionarySelection(
              chapter: chapter,
              child: const Text('すべての本文を辞書で検索できます。'),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SelectionArea), findsOneWidget);
    expect(find.text('すべての本文を辞書で検索できます。'), findsOneWidget);

    await tester.longPress(find.text('すべての本文を辞書で検索できます。'));
    await tester.pumpAndSettle();

    expect(find.text('Dictionary'), findsOneWidget);
  });

  testWidgets('cleaned Japanese EPUB HTML renders as selectable text', (
    tester,
  ) async {
    final chapter = Chapter(mangaId: 1, name: '第一章');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NovelDictionarySelection(
            chapter: chapter,
            child: Html(
              data: buildReaderHtml(
                '<html><body><p>探偵はもう、死んでいる。</p></body></html>',
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      find.textContaining('探偵はもう、死んでいる。', findRichText: true),
      findsOneWidget,
    );
  });
}
