import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart';
import 'package:mangayomi/services/get_html_content.dart';
import 'package:mangayomi/src/rust/api/epub.dart';

void main() {
  const book = EpubNovel(
    name: 'Japanese novel',
    chapters: [
      EpubChapter(
        name: '第一章',
        content: '<html><body><p>探偵はもう、死んでいる。</p></body></html>',
        path: 'chapter-1',
        href: 'OEBPS/chapter-1.xhtml',
        spineIndex: 0,
        isNavigationEntry: true,
      ),
      EpubChapter(
        name: '第二章',
        content: '<html><body><p>辞書検索できます。</p></body></html>',
        path: 'chapter-2',
        href: 'OEBPS/chapter-2.xhtml',
        spineIndex: 1,
        isNavigationEntry: true,
      ),
    ],
    images: [],
    stylesheets: [],
  );

  test('selects a split EPUB chapter by its spine id', () {
    final content = selectEpubChapterContent(book, 'chapter-2');

    expect(content, contains('辞書検索できます。'));
    expect(content, isNot(contains('探偵はもう')));
  });

  test(
    'also selects a chapter when a legacy record stores its archive href',
    () {
      final content = selectEpubChapterContent(
        book,
        './OEBPS/chapter-2.xhtml#section-1',
      );

      expect(content, book.chapters[1].content);
    },
  );

  test('legacy EPUB chapters concatenate all readable spine entries', () {
    final content = selectEpubChapterContent(book, null);

    expect(content, contains('探偵はもう、死んでいる。'));
    expect(content, contains('辞書検索できます。'));
  });

  test('empty markup is not considered readable chapter content', () {
    expect(
      readerHtmlHasRenderableContent('<html><body></body></html>'),
      isFalse,
    );
    expect(readerHtmlHasRenderableContent('<p>本文</p>'), isTrue);
    expect(readerHtmlHasRenderableContent('<img src="cover.jpg">'), isTrue);
  });

  test('reader HTML preserves literal angle brackets as text', () {
    final result = buildReaderHtml('<p>&lt;探偵&gt; &amp; 辞書</p>');

    expect(parse(result).body?.text, contains('<探偵> & 辞書'));
  });
}
