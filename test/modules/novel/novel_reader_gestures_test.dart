import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/novel/novel_reader_view.dart';
import 'package:mangayomi/src/rust/api/epub.dart';

void main() {
  const viewport = Size(900, 900);

  test('reader tap zones preserve previous, menu, and next actions', () {
    expect(
      novelReaderTapActionForPosition(
        position: const Offset(450, 50),
        viewport: viewport,
        usePageTapZones: true,
      ),
      NovelReaderTapAction.previousPage,
    );
    expect(
      novelReaderTapActionForPosition(
        position: const Offset(450, 450),
        viewport: viewport,
        usePageTapZones: true,
      ),
      NovelReaderTapAction.toggleUi,
    );
    expect(
      novelReaderTapActionForPosition(
        position: const Offset(850, 450),
        viewport: viewport,
        usePageTapZones: true,
      ),
      NovelReaderTapAction.nextPage,
    );
  });

  test('reader tap zones disabled always toggles UI', () {
    expect(
      novelReaderTapActionForPosition(
        position: const Offset(10, 10),
        viewport: viewport,
        usePageTapZones: false,
      ),
      NovelReaderTapAction.toggleUi,
    );
  });

  test('vertical-rl tap zones advance from right to left', () {
    expect(
      novelReaderTapActionForPosition(
        position: const Offset(50, 450),
        viewport: viewport,
        usePageTapZones: true,
        reverseHorizontal: true,
      ),
      NovelReaderTapAction.nextPage,
    );
    expect(
      novelReaderTapActionForPosition(
        position: const Offset(850, 450),
        viewport: viewport,
        usePageTapZones: true,
        reverseHorizontal: true,
      ),
      NovelReaderTapAction.previousPage,
    );
  });

  test('EPUB navigation preserves exact spine order and duplicate names', () {
    const book = EpubNovel(
      name: 'fixture',
      chapters: [
        EpubChapter(
          name: 'Prologue',
          content: '<p>one</p>',
          path: 'item-a',
          href: 'Text/a.xhtml',
          spineIndex: 0,
          isNavigationEntry: true,
        ),
        EpubChapter(
          name: 'Interlude',
          content: '<p>two</p>',
          path: 'item-b',
          href: 'Text/b.xhtml',
          spineIndex: 1,
          isNavigationEntry: true,
        ),
        EpubChapter(
          name: 'Interlude',
          content: '<p>three</p>',
          path: 'item-c',
          href: 'Text/c.xhtml',
          spineIndex: 2,
          isNavigationEntry: true,
        ),
      ],
      images: [],
      stylesheets: [],
    );

    expect(
      adjacentEpubSpineTarget(
        book: book,
        currentReference: './Text/b.xhtml#part',
        next: true,
      ),
      (belongsToSpine: true, target: 'item-c', targetSpineIndex: 2),
    );
    expect(
      adjacentEpubSpineTarget(
        book: book,
        currentReference: 'item-b',
        next: false,
      ),
      (belongsToSpine: true, target: 'item-a', targetSpineIndex: 0),
    );
    expect(
      adjacentEpubSpineTarget(
        book: book,
        currentReference: 'item-c',
        next: true,
      ),
      (belongsToSpine: true, target: null, targetSpineIndex: null),
    );

    expect(
      adjacentEpubSpineTarget(
        book: book,
        currentReference: 'item-b',
        currentSpineIndex: 1,
        next: true,
      ),
      (belongsToSpine: true, target: 'item-c', targetSpineIndex: 2),
    );
  });

  test(
    'canonical href wins stale metadata and index disambiguates repeats',
    () {
      const book = EpubNovel(
        name: 'fixture',
        chapters: [
          EpubChapter(
            name: 'First x',
            content: '',
            path: 'Text/x.xhtml',
            href: 'Text/x.xhtml',
            spineIndex: 0,
            isNavigationEntry: false,
          ),
          EpubChapter(
            name: 'Second x',
            content: '',
            path: 'Text/x.xhtml',
            href: 'Text/x.xhtml',
            spineIndex: 1,
            isNavigationEntry: false,
          ),
          EpubChapter(
            name: 'Y',
            content: '',
            path: 'Text/y.xhtml',
            href: 'Text/y.xhtml',
            spineIndex: 2,
            isNavigationEntry: false,
          ),
        ],
        images: [],
        stylesheets: [],
      );

      expect(
        adjacentEpubSpineTarget(
          book: book,
          currentReference: 'Text/x.xhtml',
          currentSpineIndex: 1,
          next: true,
        ),
        (belongsToSpine: true, target: 'Text/y.xhtml', targetSpineIndex: 2),
      );
      expect(
        adjacentEpubSpineTarget(
          book: book,
          currentReference: 'Text/y.xhtml',
          currentSpineIndex: 0,
          next: false,
        ),
        (belongsToSpine: true, target: 'Text/x.xhtml', targetSpineIndex: 1),
      );
    },
  );
}
