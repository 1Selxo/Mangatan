import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/settings.dart';

void main() {
  test(
    'reader mode selector exposes exactly five direction-agnostic modes',
    () {
      expect(ReaderModeExtension.selectableValues, [
        ReaderMode.horizontalPaged,
        ReaderMode.verticalPaged,
        ReaderMode.horizontalContinuous,
        ReaderMode.verticalContinuous,
        ReaderMode.webtoon,
      ]);
    },
  );

  test('legacy RTL reader modes migrate into layout plus direction', () {
    final paged = PersonalReaderMode.fromJson({'mangaId': 1, 'readerMode': 2});
    final continuous = PersonalReaderMode.fromJson({
      'mangaId': 2,
      'readerMode': 6,
    });

    expect(paged.readerMode, ReaderMode.horizontalPaged);
    expect(paged.readingDirectionIndex, ReadingDirection.rightToLeft.index);
    expect(continuous.readerMode, ReaderMode.horizontalContinuous);
    expect(
      continuous.readingDirectionIndex,
      ReadingDirection.rightToLeft.index,
    );
  });

  test('legacy database values resolve direction before normalization', () {
    final settings = Settings()
      ..defaultReaderMode = ReaderMode.legacyHorizontalPagedRtl
      ..defaultReadingDirectionIndex = null;

    expect(settings.effectiveDefaultReaderMode, ReaderMode.horizontalPaged);
    expect(
      settings.effectiveDefaultReadingDirection,
      ReadingDirection.rightToLeft,
    );
  });

  test('page mode persistence falls back safely for old or invalid data', () {
    expect(PageModeExtension.fromPersistedIndex(null), PageMode.onePage);
    expect(PageModeExtension.fromPersistedIndex(-1), PageMode.onePage);
    expect(PageModeExtension.fromPersistedIndex(99), PageMode.onePage);
    expect(
      PageModeExtension.fromPersistedIndex(PageMode.doublePage.index),
      PageMode.doublePage,
    );
    expect(
      PageModeExtension.fromPersistedIndex(PageMode.doublePageCover.index),
      PageMode.doublePageCover,
    );
  });

  test('default page mode is included in settings backups', () {
    final settings = Settings(defaultPageMode: PageMode.doublePageCover);
    final backup = settings.toJson();
    final restored = Settings.fromJson(backup);

    expect(backup['defaultPageMode'], PageMode.doublePageCover.index);
    expect(restored.defaultPageMode, PageMode.doublePageCover);
  });
}
