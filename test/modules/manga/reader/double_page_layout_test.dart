import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/modules/manga/reader/utils/double_page_layout.dart';

void main() {
  test('regular double page groups pages from the first page', () {
    expect(doublePageViewCount(5, PageMode.doublePage), 3);
    expect(doublePageViewToActualIndex(0, 5, PageMode.doublePage), 0);
    expect(doublePageViewToActualIndex(1, 5, PageMode.doublePage), 2);
    expect(actualIndexToDoublePageView(3, PageMode.doublePage), 1);
    expect(doublePageSpreadItems([0, 1, 2, 3, 4], 1, PageMode.doublePage), [
      2,
      3,
    ]);
    expect(doublePageIndexLabel(1, 5, PageMode.doublePage), '3-4');
  });

  test('cover offset keeps the first page solo and pairs from page two', () {
    expect(doublePageViewCount(5, PageMode.doublePageCover), 3);
    expect(doublePageViewToActualIndex(0, 5, PageMode.doublePageCover), 0);
    expect(doublePageViewToActualIndex(1, 5, PageMode.doublePageCover), 1);
    expect(doublePageViewToActualIndex(2, 5, PageMode.doublePageCover), 3);
    expect(actualIndexToDoublePageView(0, PageMode.doublePageCover), 0);
    expect(actualIndexToDoublePageView(1, PageMode.doublePageCover), 1);
    expect(actualIndexToDoublePageView(2, PageMode.doublePageCover), 1);
    expect(
      doublePageSpreadItems([0, 1, 2, 3, 4], 0, PageMode.doublePageCover),
      [0, null],
    );
    expect(
      doublePageSpreadItems([0, 1, 2, 3, 4], 1, PageMode.doublePageCover),
      [1, 2],
    );
    expect(doublePageIndexLabel(0, 5, PageMode.doublePageCover), '1');
    expect(doublePageIndexLabel(1, 5, PageMode.doublePageCover), '2-3');
  });
}
