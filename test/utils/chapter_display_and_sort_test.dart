import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/utils/chapter_recognition.dart';
import 'package:mangayomi/utils/extensions/manga_extensions.dart';

Chapter chapter({
  required String name,
  required String uploadDate,
  String scanlator = '',
  double? number,
}) => Chapter(
  mangaId: 1,
  name: name,
  dateUpload: uploadDate,
  scanlator: scanlator,
  chapterNumber: number,
);

void main() {
  test('sorts chapters by every book-page sort mode', () {
    final chapters = [
      chapter(
        name: 'Chapter 20 - Zebra',
        uploadDate: '100',
        scanlator: 'Beta',
        number: 20,
      ),
      chapter(
        name: 'Chapter 3 - Alpha',
        uploadDate: '300',
        scanlator: 'Alpha',
        number: 3,
      ),
      chapter(
        name: 'Chapter 10 - Middle',
        uploadDate: '200',
        scanlator: 'Alpha',
        number: 10,
      ),
    ];

    List<String> namesFor(int sortIndex) => sortChaptersForDisplay(
      chapters: chapters,
      mangaTitle: 'Book',
      sortIndex: sortIndex,
      reverse: true,
    ).map((chapter) => chapter.name!).toList();

    expect(namesFor(0), [
      'Chapter 3 - Alpha',
      'Chapter 10 - Middle',
      'Chapter 20 - Zebra',
    ]);
    expect(namesFor(1), [
      'Chapter 3 - Alpha',
      'Chapter 10 - Middle',
      'Chapter 20 - Zebra',
    ]);
    expect(namesFor(2), [
      'Chapter 20 - Zebra',
      'Chapter 10 - Middle',
      'Chapter 3 - Alpha',
    ]);
    expect(namesFor(3), [
      'Chapter 10 - Middle',
      'Chapter 20 - Zebra',
      'Chapter 3 - Alpha',
    ]);
  });

  test('reverses the selected chapter ordering', () {
    final chapters = [
      chapter(name: 'Chapter 1', uploadDate: '1', number: 1),
      chapter(name: 'Chapter 2', uploadDate: '2', number: 2),
    ];

    final result = sortChaptersForDisplay(
      chapters: chapters,
      mangaTitle: 'Book',
      sortIndex: 1,
      reverse: false,
    );

    expect(result.map((chapter) => chapter.chapterNumber), [2, 1]);
  });

  test('persists the chapter display mode in settings JSON', () {
    final settings = SortChapter(
      mangaId: 7,
      index: 2,
      reverse: true,
      displayMode: SortChapter.chapterNumberDisplay,
    );

    final restored = SortChapter.fromJson(settings.toJson());

    expect(restored.displayMode, SortChapter.chapterNumberDisplay);
    expect(
      SortChapter.fromJson(const {}).displayMode,
      SortChapter.sourceTitleDisplay,
    );
  });

  test('formats whole and fractional chapter numbers without noise', () {
    expect(formatChapterNumberForDisplay(276), '276');
    expect(formatChapterNumberForDisplay(12.5), '12.5');
    expect(formatChapterNumberForDisplay(12.125), '12.125');
  });

  test('distinguishes an unknown chapter number from a real chapter zero', () {
    final recognition = ChapterRecognition();

    expect(
      recognition.resolveChapterNumberOrNull('Book', '雲の隙間から差し込む夕陽'),
      isNull,
    );
    expect(recognition.resolveChapterNumberOrNull('Book', 'Chapter 0'), 0);
    expect(
      recognition.resolveChapterNumberOrNull(
        'Book',
        'Prologue',
        sourceChapterNumber: 0,
      ),
      0,
    );
  });

  test(
    'falls back to the source title when no chapter number is available',
    () {
      expect(
        chapterNumberDisplayTitle(
          sourceTitle: '雲の隙間から差し込む夕陽',
          mangaTitle: 'kajigaku 6',
          numberLabel: 'Chapter',
        ),
        '雲の隙間から差し込む夕陽',
      );
      expect(
        chapterNumberDisplayTitle(
          sourceTitle: 'Chapter 0',
          mangaTitle: 'Book',
          numberLabel: 'Chapter',
        ),
        'Chapter 0',
      );
      expect(
        chapterNumberDisplayTitle(
          sourceTitle: 'Special',
          mangaTitle: 'Book',
          numberLabel: 'Chapter',
          sourceChapterNumber: -2,
        ),
        'Special',
      );
    },
  );

  test('recognizes Japanese kanji chapter numbers', () {
    final recognition = ChapterRecognition();
    const cases = {
      '第九話 この先': 9,
      '第十話 この先': 10,
      '第十一話 この先': 11,
      '第十二話 この先': 12,
      '第百二十三章': 123,
      '第二〇二四話': 2024,
    };

    for (final MapEntry(key: title, value: number) in cases.entries) {
      expect(
        recognition.resolveChapterNumberOrNull('Book', title),
        number,
        reason: title,
      );
      expect(
        chapterNumberDisplayTitle(
          sourceTitle: title,
          mangaTitle: 'Book',
          numberLabel: 'Chapter',
        ),
        'Chapter $number',
        reason: title,
      );
    }
  });
}
