import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/services/epub_chapter_metadata.dart';

void main() {
  Chapter chapter({
    required int id,
    required int spineIndex,
    required bool navigation,
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
}
