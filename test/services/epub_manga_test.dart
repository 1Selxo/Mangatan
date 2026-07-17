import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/epub_manga.dart';
import 'package:mangayomi/src/rust/api/epub.dart';

void main() {
  group('analyzeEpubContent', () {
    test('confidently recognizes a run of image-only spine pages', () {
      final book = _book(
        chapters: List.generate(
          6,
          (index) => _chapter(
            index,
            '<html><body><img src="../images/$index.jpg"></body></html>',
          ),
        ),
      );

      final analysis = analyzeEpubContent(book);

      expect(analysis.kind, EpubContentKind.imageBased);
      expect(analysis.spineItemCount, 6);
      expect(analysis.imageOnlySpineItemCount, 6);
    });

    test('recognizes substantial prose with incidental illustrations', () {
      final prose = List.filled(160, 'A sentence of readable prose.').join(' ');
      final book = _book(
        chapters: List.generate(
          4,
          (index) => _chapter(
            index,
            '<html><body><p>$prose</p>'
            '${index == 0 ? '<img src="../images/cover.jpg">' : ''}'
            '</body></html>',
          ),
        ),
      );

      expect(analyzeEpubContent(book).kind, EpubContentKind.textBased);
    });

    test('leaves short, mixed, and non-linear content ambiguous', () {
      final book = _book(
        chapters: [
          _chapter(0, '<p>Short introduction</p>'),
          _chapter(1, '<img src="../images/one.jpg">'),
          _chapter(2, '<img src="../images/two.jpg">', isLinear: false),
        ],
      );

      final analysis = analyzeEpubContent(book);

      expect(analysis.kind, EpubContentKind.ambiguous);
      expect(analysis.spineItemCount, 2);
      expect(analysis.imageReferenceCount, 1);
    });

    test('does not mistake hidden and ruby annotation text for prose', () {
      final book = _book(
        chapters: List.generate(
          4,
          (index) => _chapter(
            index,
            '<html><body><img src="../images/$index.jpg">'
            '<div hidden>${List.filled(500, 'hidden').join()}</div>'
            '<ruby>字<rt>annotation</rt></ruby>'
            '</body></html>',
          ),
        ),
      );

      expect(analyzeEpubContent(book).kind, EpubContentKind.imageBased);
    });
  });

  group('epubMangaPageImages', () {
    test('uses spine and DOM order while omitting unused archive images', () {
      final book = _book(
        chapters: [
          _chapter(
            2,
            '<html><body><img src="./003.jpg"></body></html>',
            href: 'OEBPS/images/003.jpg',
          ),
          _chapter(
            0,
            '<html><body><img src="../images/001.jpg"></body></html>',
          ),
          _chapter(
            1,
            '<html><body><svg><image href="../images/002.webp" />'
            '</svg></body></html>',
          ),
          _chapter(3, '<img src="../images/non-linear.jpg">', isLinear: false),
        ],
        images: [
          _resource('OEBPS/images/unused.jpg', 99),
          _resource('OEBPS/images/003.jpg', 3),
          _resource('OEBPS/images/001.jpg', 1),
          _resource('OEBPS/images/002.webp', 2),
          _resource('OEBPS/images/non-linear.jpg', 4),
        ],
      );

      final pages = epubMangaPageImages(book);

      expect(pages.map((page) => page.name), [
        '001.jpg',
        '002.webp',
        '003.jpg',
      ]);
      expect(pages.map((page) => page.image!.single), [1, 2, 3]);
    });

    test('resolves percent escapes, queries, and legacy SVG xlink hrefs', () {
      final book = _book(
        chapters: [
          _chapter(
            0,
            '<html><body><img src="../images/page%201.PNG?size=large#page">'
            '<svg><image xlink:href="../images/page-2.jpg" /></svg>'
            '</body></html>',
          ),
        ],
        images: [
          _resource('OEBPS/images/page 1.PNG', 1),
          _resource('OEBPS/images/page-2.jpg', 2),
        ],
      );

      expect(epubMangaPageImages(book).map((page) => page.image!.single), [
        1,
        2,
      ]);
    });

    test('unwraps raster images referenced through an SVG resource', () {
      final svg = Uint8List.fromList(
        '<svg><image href="raster/page.jpg" /></svg>'.codeUnits,
      );
      final book = _book(
        chapters: [_chapter(0, '<img src="../images/page.svg">')],
        images: [
          EpubResource(name: 'OEBPS/images/page.svg', content: svg),
          _resource('OEBPS/images/raster/page.jpg', 7),
        ],
      );

      final pages = epubMangaPageImages(book);

      expect(pages.single.name, 'page.jpg');
      expect(pages.single.image!.single, 7);
    });
  });

  test(
    'normalizes archive resource paths without losing authored hierarchy',
    () {
      expect(
        resolveEpubResourceReference(
          'OEBPS/text/chapter.xhtml',
          '../images/./page%2001.jpg#fragment',
        ),
        'OEBPS/images/page 01.jpg',
      );
      expect(
        resolveEpubResourceReference(
          'OEBPS/text/chapter.xhtml',
          'data:image/png;base64,x',
        ),
        isNull,
      );
    },
  );
}

EpubNovel _book({
  required List<EpubChapter> chapters,
  List<EpubResource> images = const [],
}) {
  return EpubNovel(
    name: 'Fixture',
    chapters: chapters,
    images: images,
    stylesheets: const [],
  );
}

EpubChapter _chapter(
  int spineIndex,
  String content, {
  String? href,
  bool isLinear = true,
}) {
  return EpubChapter(
    name: 'Page ${spineIndex + 1}',
    content: content,
    path: 'page-$spineIndex',
    href: href ?? 'OEBPS/text/page-$spineIndex.xhtml',
    spineIndex: spineIndex,
    isLinear: isLinear,
    isNavigationEntry: true,
  );
}

EpubResource _resource(String name, int byte) {
  return EpubResource(name: name, content: Uint8List.fromList([byte]));
}
