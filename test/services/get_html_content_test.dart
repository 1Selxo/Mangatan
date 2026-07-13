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
    expect(content, contains('id="mangatan-spine-0"'));
    expect(content, contains('data-mangatan-chapter-index="0"'));
    expect(content, contains('data-mangatan-chapter-index="1"'));
    final document = parse(content);
    expect(
      document.querySelectorAll('.mangatan-logical-section'),
      hasLength(2),
    );
  });

  test('groups physical spine files under logical TOC chapter boundaries', () {
    const grouped = EpubNovel(
      name: 'fixture',
      chapters: [
        EpubChapter(
          name: 'One',
          content: '<body><p>one</p></body>',
          path: 'one',
          href: 'one.xhtml',
          spineIndex: 0,
          isNavigationEntry: true,
        ),
        EpubChapter(
          name: 'One continued',
          content: '<body><p>continued</p></body>',
          path: 'one-b',
          href: 'one-b.xhtml',
          spineIndex: 1,
          isNavigationEntry: false,
        ),
        EpubChapter(
          name: 'Two',
          content: '<body><p>two</p></body>',
          path: 'two',
          href: 'two.xhtml',
          spineIndex: 2,
          isNavigationEntry: true,
        ),
      ],
      images: [],
      stylesheets: [],
    );

    final document = parse(buildContinuousEpubContent(grouped));
    final logical = document.querySelectorAll('.mangatan-logical-section');
    expect(logical, hasLength(2));
    expect(logical.first.attributes['data-mangatan-navigation-spine'], '0');
    expect(
      logical.first.querySelectorAll('section[data-mangatan-spine-index]'),
      hasLength(2),
    );
    expect(logical.last.attributes['data-mangatan-navigation-spine'], '2');
    expect(
      logical.last.querySelectorAll('section[data-mangatan-spine-index]'),
      hasLength(1),
    );
  });

  test('uses Chimahon character counting semantics', () {
    const content = '''<html><body>
      <ruby>漢<rt>かん</rt></ruby> ABC １２３ 한글 😀
      <script>ignored漢字</script><style>.ignored{}</style>
    </body></html>''';

    expect(chimahonChapterCharacterCount(content), 9);
  });

  test('non-linear spine items do not consume Chimahon chapter indices', () {
    const withNonLinear = EpubNovel(
      name: 'fixture',
      chapters: [
        EpubChapter(
          name: 'Cover',
          content: '<body><p>Cover</p></body>',
          path: 'cover',
          href: 'cover.xhtml',
          spineIndex: 0,
          isLinear: false,
          isNavigationEntry: false,
        ),
        EpubChapter(
          name: 'Chapter',
          content: '<body><p>本文</p></body>',
          path: 'chapter',
          href: 'chapter.xhtml',
          spineIndex: 1,
          isNavigationEntry: true,
        ),
      ],
      images: [],
      stylesheets: [],
    );

    final content = buildContinuousEpubContent(withNonLinear);
    expect(content, contains('id="mangatan-spine-0"'));
    expect(content, contains('id="mangatan-spine-1"'));
    expect(
      RegExp(r'data-mangatan-chapter-index=').allMatches(content).length,
      1,
    );
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

  test('EPUB document cache shares one parse across TOC shortcuts', () async {
    var loads = 0;
    final cache = EpubDocumentCache(
      loader: (_) async {
        loads++;
        return book;
      },
      fingerprintLoader: (_) async => 'same-file',
    );

    final results = await Future.wait([
      cache.load('fixture.epub'),
      cache.load('fixture.epub'),
    ]);

    expect(loads, 1);
    expect(identical(results.first.book, results.last.book), isTrue);
    expect(results.first.html, results.last.html);
  });

  test('EPUB document cache invalidates when the file changes', () async {
    var loads = 0;
    var fingerprint = 'first';
    final cache = EpubDocumentCache(
      loader: (_) async {
        loads++;
        return book;
      },
      fingerprintLoader: (_) async => fingerprint,
    );

    await cache.load('fixture.epub');
    fingerprint = 'second';
    await cache.load('fixture.epub');

    expect(loads, 2);
  });

  test('EPUB document cache retries a failed parse', () async {
    var loads = 0;
    final cache = EpubDocumentCache(
      loader: (_) async {
        loads++;
        if (loads == 1) throw const FormatException('broken once');
        return book;
      },
      fingerprintLoader: (_) async => 'same-file',
    );

    await expectLater(cache.load('fixture.epub'), throwsFormatException);
    await cache.load('fixture.epub');

    expect(loads, 2);
  });
}
