import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/settings.dart';

void main() {
  test('reader modes keep the stored positions of upstream and old forks', () {
    expect(ReaderMode.values, [
      ReaderMode.vertical,
      ReaderMode.ltr,
      ReaderMode.rtl,
      ReaderMode.verticalContinuous,
      ReaderMode.webtoon,
      ReaderMode.horizontalContinuous,
      ReaderMode.horizontalContinuousRTL,
    ]);
  });

  test('a direction stored apart from the mode folds into it', () {
    // Older Mangatan: horizontal mode plus right to left.
    final paged = PersonalReaderMode.fromJson({
      'mangaId': 1,
      'readerMode': ReaderMode.ltr.index,
      'readingDirection': 1,
    });
    final continuous = PersonalReaderMode.fromJson({
      'mangaId': 2,
      'readerMode': ReaderMode.horizontalContinuous.index,
      'readingDirection': 1,
    });
    // Its oldest backups: the combined right-to-left modes, no direction.
    final legacy = PersonalReaderMode.fromJson({'mangaId': 3, 'readerMode': 2});
    // A vertical mode has no direction to take.
    final vertical = PersonalReaderMode.fromJson({
      'mangaId': 4,
      'readerMode': ReaderMode.webtoon.index,
      'readingDirection': 1,
    });

    expect(paged.readerMode, ReaderMode.rtl);
    expect(continuous.readerMode, ReaderMode.horizontalContinuousRTL);
    expect(legacy.readerMode, ReaderMode.rtl);
    expect(vertical.readerMode, ReaderMode.webtoon);
    expect(paged.toJson(), {'mangaId': 1, 'readerMode': ReaderMode.rtl.index});
  });

  test('a stored direction folds into a mode read from the database', () {
    final personal = PersonalReaderMode(
      readerMode: ReaderMode.ltr,
      readingDirectionIndex: 1,
    );
    final leftToRight = PersonalReaderMode(
      readerMode: ReaderMode.rtl,
      readingDirectionIndex: 0,
    );
    final settings = Settings()
      ..defaultReaderMode = ReaderMode.horizontalContinuous
      ..defaultReadingDirectionIndex = 1;

    expect(personal.effectiveReaderMode, ReaderMode.rtl);
    expect(leftToRight.effectiveReaderMode, ReaderMode.ltr);
    expect(
      settings.effectiveDefaultReaderMode,
      ReaderMode.horizontalContinuousRTL,
    );
    expect(
      Settings(defaultReaderMode: ReaderMode.rtl).effectiveDefaultReaderMode,
      ReaderMode.rtl,
    );
  });

  test('backups store the folded default mode and no direction', () {
    final settings = Settings()
      ..defaultReaderMode = ReaderMode.ltr
      ..defaultReadingDirectionIndex = 1;
    final backup = settings.toJson();
    final restored = Settings.fromJson(backup);

    expect(backup['defaultReaderMode'], ReaderMode.rtl.index);
    expect(backup.containsKey('defaultReadingDirection'), isFalse);
    expect(restored.defaultReaderMode, ReaderMode.rtl);
    expect(restored.defaultReadingDirectionIndex, isNull);
  });

  test('page mode persistence falls back safely for old or invalid data', () {
    expect(PageModeExtension.fromPersistedIndex(null), PageMode.onePage);
    expect(PageModeExtension.fromPersistedIndex(-1), PageMode.onePage);
    expect(PageModeExtension.fromPersistedIndex(99), PageMode.onePage);
    expect(
      PageModeExtension.fromPersistedIndex(PageMode.doublePage.index),
      PageMode.doublePage,
    );
    // The old cover-offset mode reads as double page.
    expect(PageModeExtension.fromPersistedIndex(2), PageMode.doublePage);
    expect(PageMode.legacyDoublePageCover.normalized, PageMode.doublePage);
  });

  test('default page mode is included in settings backups', () {
    final settings = Settings(defaultPageMode: PageMode.doublePage);
    final backup = settings.toJson();
    final restored = Settings.fromJson(backup);

    expect(backup['defaultPageMode'], PageMode.doublePage.index);
    expect(restored.defaultPageMode, PageMode.doublePage);
  });
}
