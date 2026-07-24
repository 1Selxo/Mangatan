import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/services/epub_chapter_metadata.dart';
import 'package:mangayomi/src/rust/api/epub.dart';

void main() {
  Chapter chapter({
    required int id,
    required int spineIndex,
    required bool navigation,
    int? logicalChapterSpineIndex,
    int? characterStart,
    String archivePath = 'book.epub',
  }) => Chapter(
    id: id,
    mangaId: 1,
    name: navigation ? 'Section $spineIndex' : 'internal',
    archivePath: archivePath,
    dateUpload: spineIndex.toString(),
    description: epubChapterMetadata(
      spineIndex: spineIndex,
      navigationEntry: navigation,
      logicalChapterSpineIndex: logicalChapterSpineIndex,
      characterStart: characterStart,
    ),
  );

  test('keeps only logical EPUB navigation rows in exact spine order', () {
    final rows = epubNavigationChaptersInSpineOrder([
      chapter(id: 3, spineIndex: 20, navigation: true),
      chapter(id: 2, spineIndex: 7, navigation: false),
      chapter(id: 4, spineIndex: 27, navigation: true),
      chapter(id: 1, spineIndex: 0, navigation: true),
      chapter(id: 5, spineIndex: 5, navigation: true),
    ]);

    expect(rows.map(epubChapterSpineIndex), [0, 5, 20, 27]);
    expect(rows.every((row) => !isInternalEpubSpineChapter(row)), isTrue);
  });

  test('metadata distinguishes internal reader fragments', () {
    final internal = chapter(id: 1, spineIndex: 6, navigation: false);
    final navigation = chapter(id: 2, spineIndex: 5, navigation: true);

    expect(isManagedEpubChapter(internal), isTrue);
    expect(isInternalEpubSpineChapter(internal), isTrue);
    expect(isEpubNavigationChapter(internal), isFalse);
    expect(isInternalEpubSpineChapter(navigation), isFalse);
    expect(isEpubNavigationChapter(navigation), isTrue);
  });

  test('stores Chimahon accumulated character positions on TOC rows', () {
    final counted = chapter(
      id: 1,
      spineIndex: 6,
      navigation: true,
      characterStart: 1200,
    );
    final legacy = Chapter(
      id: 2,
      mangaId: 1,
      name: 'Legacy',
      archivePath: 'book.epub',
      description: 'mangatan:epub:v6:navigation:6:6',
    );

    expect(epubChapterCharacterStart(counted), 1200);
    expect(epubChapterCharacterStart(legacy), isNull);
  });

  test('calculates accumulated character positions over the linear spine', () {
    const book = EpubNovel(
      name: 'fixture',
      chapters: [
        EpubChapter(
          name: 'First',
          content: '<body>abc日本</body>',
          path: 'first',
          href: 'first.xhtml',
          spineIndex: 2,
          isNavigationEntry: true,
        ),
        EpubChapter(
          name: 'Aside',
          content: '<body>ignored</body>',
          path: 'aside',
          href: 'aside.xhtml',
          spineIndex: 3,
          isLinear: false,
          isNavigationEntry: false,
        ),
        EpubChapter(
          name: 'Second',
          content: '<body>かな12</body>',
          path: 'second',
          href: 'second.xhtml',
          spineIndex: 4,
          isNavigationEntry: true,
        ),
      ],
      images: [],
      stylesheets: [],
    );

    expect(epubCharacterStartsBySpine(book), {2: 0, 4: 5});
  });

  test('managed metadata hides unmatched legacy spine fragments', () {
    final navigation = chapter(id: 2, spineIndex: 5, navigation: true);
    final legacy = Chapter(
      id: 3,
      mangaId: 1,
      name: 'Chapter 6',
      archivePath: 'book.epub',
      dateUpload: '6',
    );

    expect(epubNavigationChaptersInSpineOrder([legacy, navigation]), [
      navigation,
    ]);
  });

  test('keeps separate EPUB archives grouped by import order', () {
    final rows = epubNavigationChaptersInSpineOrder([
      chapter(
        id: 3,
        spineIndex: 0,
        navigation: true,
        archivePath: 'volume-b.epub',
      ),
      chapter(
        id: 2,
        spineIndex: 5,
        navigation: true,
        archivePath: 'volume-a.epub',
      ),
      chapter(
        id: 4,
        spineIndex: 5,
        navigation: true,
        archivePath: 'volume-b.epub',
      ),
      chapter(
        id: 1,
        spineIndex: 0,
        navigation: true,
        archivePath: 'volume-a.epub',
      ),
    ]);

    expect(rows.map((row) => row.id), [1, 2, 3, 4]);
  });

  test('preserves an explicitly unsplit EPUB row', () {
    final unsplit = Chapter(
      id: 1,
      mangaId: 1,
      name: 'Whole book',
      archivePath: 'book.epub',
      description: epubUnsplitChapterMetadata(),
    );

    expect(epubNavigationChaptersInSpineOrder([unsplit]), [unsplit]);
  });

  test('prefers reconciled navigation rows over an obsolete unsplit row', () {
    final unsplit = Chapter(
      id: 1,
      mangaId: 1,
      name: 'Whole book',
      archivePath: 'book.epub',
      description: epubUnsplitChapterMetadata(),
    );
    final staleNavigation = chapter(id: 2, spineIndex: 3, navigation: true);
    final staleInternal = chapter(id: 3, spineIndex: 4, navigation: false);

    expect(
      epubNavigationChaptersInSpineOrder([
        staleNavigation,
        unsplit,
        staleInternal,
      ]),
      [staleNavigation],
    );
  });

  test('recognizes legacy EPUB navigation metadata during migration', () {
    final legacy = Chapter(
      id: 1,
      mangaId: 1,
      name: 'Legacy shortcut',
      archivePath: 'book.epub',
      dateUpload: '12',
      description: 'mangatan:epub:v5:navigation:12:12',
    );

    expect(isEpubNavigationChapter(legacy), isTrue);
    expect(isManagedEpubChapter(legacy), isFalse);
    expect(epubChapterSpineIndex(legacy), 12);
  });

  test('projects read rows and whole-book progress from the live position', () {
    final first = chapter(id: 1, spineIndex: 0, navigation: true);
    final current = chapter(id: 2, spineIndex: 5, navigation: true);
    final later = chapter(id: 3, spineIndex: 20, navigation: true)
      ..isRead = true
      ..lastPageRead = '0.9';

    final changed = applyEpubShortcutPositionProjection(
      chapters: [later, current, first],
      spineIndex: 7,
      overallProgress: 0.42,
    );

    expect(changed, containsAll([first, current, later]));
    expect((first.isRead, first.lastPageRead), (true, ''));
    expect((current.isRead, current.lastPageRead), (false, '0.42'));
    expect((later.isRead, later.lastPageRead), (false, ''));

    applyEpubShortcutPositionProjection(
      chapters: [first, current, later],
      spineIndex: 0,
      overallProgress: 0.1,
    );
    expect((first.isRead, first.lastPageRead), (false, '0.1'));
    expect(current.isRead, isFalse);

    applyEpubShortcutPositionProjection(
      chapters: [first, current, later],
      spineIndex: 20,
      overallProgress: 1,
    );
    expect([first, current, later].every((row) => row.isRead == true), isTrue);
    expect(
      [first, current, later].every((row) => row.lastPageRead == ''),
      isTrue,
    );
  });
}
