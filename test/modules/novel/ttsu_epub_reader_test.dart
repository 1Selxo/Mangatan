import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/novel/widgets/ttsu_epub_reader.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';
import 'package:mangayomi/src/rust/api/epub.dart';

void main() {
  final book = EpubNovel(
    name: 'Reader fixture',
    chapters: const [],
    images: [
      EpubResource(
        name: 'OEBPS/images/cover.png',
        content: Uint8List.fromList([137, 80, 78, 71]),
      ),
    ],
    stylesheets: const [],
  );

  test('builds a selectable, self-contained DOM reader', () {
    final document = buildTtsuEpubDocument(
      html:
          '<p>探偵はもう、死んでいる。</p><img src="../images/cover.png"><script>bad()</script>',
      book: book,
      title: '探偵',
      backgroundColor: '#101010',
      textColor: '#f0f0f0',
      fontSize: 18,
      lineHeight: 1.8,
      padding: 24,
      textAlign: 'justify',
      initialProgress: 0.25,
      tapToScroll: true,
    );

    expect(document, contains('探偵はもう、死んでいる。'));
    expect(document, contains('data:image/png;base64,'));
    expect(document, isNot(contains('bad()')));
    expect(document, contains("call('readerDictionary'"));
    expect(document, contains('const initialProgress = 0.25'));
    expect(document, contains('user-select: text'));
    expect(document, contains("const lookupTrigger = \"leftClick\""));
    expect(
      document,
      contains("const repeatedLookup = lookupTrigger === 'leftClick'"),
    );
    expect(document, contains('activeLookup?.originNode === hit.node'));
    expect(document, contains('originOffset: hit.offset'));
    expect(document, contains('lookupToken, repeatedLookup'));
  });

  test('dismisses a repeated EPUB lookup only while its popup is visible', () {
    expect(
      ttsuRepeatedLookupShouldDismiss(repeatedLookup: true, popupVisible: true),
      isTrue,
    );
    expect(
      ttsuRepeatedLookupShouldDismiss(
        repeatedLookup: true,
        popupVisible: false,
      ),
      isFalse,
    );
    expect(
      ttsuRepeatedLookupShouldDismiss(
        repeatedLookup: false,
        popupVisible: true,
      ),
      isFalse,
    );
  });

  test('rewrites SVG xlink image references used by fixed-layout EPUBs', () {
    final document = buildTtsuEpubDocument(
      html:
          '<svg xmlns="http://www.w3.org/2000/svg"><image xlink:href="../images/cover.png"/></svg>',
      book: book,
      title: 'fixture',
      backgroundColor: '#101010',
      textColor: '#f0f0f0',
      fontSize: 18,
      lineHeight: 1.8,
      padding: 24,
      textAlign: 'left',
      initialProgress: 0,
      tapToScroll: true,
      chapterHref: 'OEBPS/text/chapter.xhtml',
    );

    expect(document, contains('xlink:href="data:image/png;base64,'));
  });

  test('generates middle-click dictionary lookup handling', () {
    final document = buildTtsuEpubDocument(
      html: '<p>辞書</p>',
      book: book,
      title: 'fixture',
      backgroundColor: '#101010',
      textColor: '#f0f0f0',
      fontSize: 18,
      lineHeight: 1.8,
      padding: 24,
      textAlign: 'left',
      initialProgress: 0,
      tapToScroll: true,
      lookupTrigger: DictionaryLookupTrigger.middleClick,
    );

    expect(document, contains("const lookupTrigger = \"middleClick\""));
    expect(document, contains("document.addEventListener('pointerup'"));
    expect(document, contains("document.addEventListener('auxclick'"));
    expect(document, contains("event.button !== 1"));
    expect(document, contains('middleLookupActive = true'));
    expect(document, contains("document.addEventListener('pointercancel'"));
    expect(document, contains("middleLookupActive"));
    expect(document, contains('triggerHeldLookupAt(x, y)'));
    expect(document, contains("call('readerDismissDictionary')"));
    expect(document, contains("event.preventDefault()"));
  });

  test('bridges trackpad wheels and two-finger touch panning', () {
    final document = buildTtsuEpubDocument(
      html: '<p>scroll fixture</p>',
      book: book,
      title: 'fixture',
      backgroundColor: '#101010',
      textColor: '#f0f0f0',
      fontSize: 18,
      lineHeight: 1.8,
      padding: 12,
      textAlign: 'left',
      initialProgress: 0,
      tapToScroll: true,
    );

    expect(document, contains('event.deltaMode === 1'));
    expect(document, contains('scrollByPixels(delta)'));
    expect(document, contains('clearTimeout(wheelUnlockTimer)'));
    expect(
      document,
      contains(
        'wheelUnlockTimer = setTimeout(() => { wheelLocked = false; }, 180)',
      ),
    );
    expect(document, contains('const touchCenter = (touches) =>'));
    expect(document, contains("document.addEventListener('touchstart'"));
    expect(document, contains("document.addEventListener('touchmove'"));
    expect(document, contains('if (!twoFingerPan) return'));
    expect(document, contains('event.preventDefault()'));
    final wheelAndTouchHandlers = document.substring(
      document.indexOf("document.addEventListener('wheel'"),
      document.indexOf("content.addEventListener('scroll'"),
    );
    expect(wheelAndTouchHandlers, isNot(contains("call('readerChapter'")));
  });

  test('generates left/right-agnostic Shift dictionary lookup handling', () {
    final document = buildTtsuEpubDocument(
      html: '<p>辞書</p>',
      book: book,
      title: 'fixture',
      backgroundColor: '#101010',
      textColor: '#f0f0f0',
      fontSize: 18,
      lineHeight: 1.8,
      padding: 24,
      textAlign: 'left',
      initialProgress: 0,
      tapToScroll: true,
      lookupTrigger: DictionaryLookupTrigger.shift,
    );

    expect(document, contains("const lookupTrigger = \"shift\""));
    expect(document, contains("event.key === 'Shift'"));
    expect(document, contains('!event.repeat'));
    expect(document, contains('const setShiftLookupActive = (active) =>'));
    expect(document, contains('setShiftLookupActive(true);'));
    expect(document, contains("document.addEventListener('keyup'"));
    expect(document, contains('setShiftLookupActive(false);'));
    expect(document, contains("event.shiftKey || shiftLookupActive"));
    expect(document, contains('triggerHeldLookupAt(x, y)'));
    expect(document, contains("call('readerDismissDictionary')"));
  });

  test('does not allow EPUB markup to inject executable elements', () {
    final document = buildTtsuEpubDocument(
      html: '<iframe src="https://example.test"></iframe><p>safe</p>',
      book: book,
      title: 'fixture',
      backgroundColor: 'not-a-color',
      textColor: 'also-invalid',
      fontSize: 14,
      lineHeight: 1.5,
      padding: 12,
      textAlign: 'invalid',
      initialProgress: 4,
      tapToScroll: false,
    );

    expect(document, isNot(contains('<iframe')));
    expect(document, contains('--reader-bg: #292832'));
    expect(document, contains('text-align: left'));
    expect(document, contains('const initialProgress = 1.0'));
  });

  test(
    'keeps EPUB-relative resources and stylesheet links in a file session',
    () {
      final document = buildTtsuEpubDocument(
        html: '''
        <html><head><link rel="stylesheet" href="../css/book.css"></head>
        <body><p style="display:none">日本語</p><img src="../images/cover.png"></body></html>
      ''',
        book: EpubNovel(
          name: 'Reader fixture',
          chapters: const [],
          images: book.images,
          stylesheets: [
            EpubResource(
              name: 'OEBPS/css/book.css',
              content: Uint8List.fromList([]),
            ),
          ],
        ),
        title: 'fixture',
        backgroundColor: '#101010',
        textColor: '#f0f0f0',
        fontSize: 18,
        lineHeight: 1.8,
        padding: 24,
        textAlign: 'justify',
        initialProgress: 0,
        tapToScroll: true,
        chapterHref: 'OEBPS/text/chapter.xhtml',
        resourceUrlFor: (resource) => resource.name.endsWith('.css')
            ? '../css/book.css'
            : '../images/cover.png',
      );

      expect(document, contains('href="../css/book.css"'));
      expect(document, contains('src="../images/cover.png"'));
      expect(document, isNot(contains('data:image/png;base64,')));
      expect(document, isNot(contains('display:none')));
      expect(document, contains("const lookupAt = (x, y, existingHit = null)"));
      expect(document, contains("call('readerLink', href)"));
      expect(document, contains('sentenceFor'));
    },
  );

  test('uses one selectable DOM for paged and vertical Japanese layouts', () {
    final document = buildTtsuEpubDocument(
      html: '<p>EPUB reader fixture</p>',
      book: book,
      title: 'fixture',
      backgroundColor: '#101010',
      textColor: '#f0f0f0',
      fontSize: 18,
      lineHeight: 1.8,
      padding: 24,
      textAlign: 'justify',
      initialProgress: 0.5,
      tapToScroll: true,
      layout: EpubReadingLayout.verticalPaged,
    );

    expect(document, contains('data-mangatan-reader-layout="vertical-pages"'));
    expect(document, contains('writing-mode: vertical-rl'));
    expect(document, contains('const pageMode = true'));
    expect(document, contains('const verticalWriting = true'));
    expect(document, contains('const scanLookup ='));
    expect(document, contains('fragment.querySelectorAll'));
    expect(document, contains("const axis = verticalWriting\n          ? 'y'"));
    expect(
      document,
      contains(
        'const yMax = Math.max(0, root.scrollHeight - root.clientHeight)',
      ),
    );
    expect(
      document,
      contains(
        "const pageSize = axis === 'x' ? root.clientWidth : root.clientHeight",
      ),
    );
    expect(document, contains('const calculateProgress = () =>'));
    expect(document, contains('const restoreProgress = async (value)'));
    expect(document, contains('range.getClientRects()'));
    expect(document, isNot(contains('const estimatedPages =')));
    expect(document, isNot(contains('--mangatan-page-shift')));
    expect(document, contains("document.addEventListener('wheel'"));
    expect(document, contains("event.key === 'ArrowLeft'"));
    expect(document, contains('const highlightMatch = (count, expectedToken)'));
    expect(
      document,
      contains(
        "CSS.highlights.set('hoshi-selection', new Highlight(...ranges))",
      ),
    );
    expect(document, isNot(contains('selection.addRange(range)')));
    expect(document, contains('lookupToken'));
    expect(document, contains('const clearLookup = (expectedToken)'));
    expect(document, contains("call('readerPrefetch', { text })"));
    expect(document, isNot(contains('highlightMatch(1)')));
    expect(document, contains("content.querySelectorAll('ruby')"));
    expect(document, contains('column-count: auto !important'));
    expect(document, contains('column-gap: 48.0vh !important'));
    expect(document, contains('alignToPage(context, progress * context.max)'));
    expect(document, contains('const measureLastContentPage = () =>'));
    expect(document, contains('measuredPageMax = measureLastContentPage()'));
    expect(document, contains("'img, svg, video, canvas, table, hr'"));
    expect(document, contains("content.addEventListener('scroll'"));
    expect(document, contains('if (pageMode && !verticalWriting)'));
    expect(document, isNot(contains('maxAligned')));
    expect(document, contains('background: rgba(138, 180, 248, .62)'));
    expect(
      document,
      contains('background: rgba(160, 160, 160, .4) !important'),
    );
  });

  test(
    'supports continuous vertical writing on the horizontal scroll axis',
    () {
      final document = buildTtsuEpubDocument(
        html: '<p>縦書きの連続表示</p>',
        book: book,
        title: 'fixture',
        backgroundColor: '#292832',
        textColor: '#cccccc',
        fontSize: 18,
        lineHeight: 1.8,
        padding: 12,
        textAlign: 'justify',
        initialProgress: 0.25,
        tapToScroll: true,
        layout: EpubReadingLayout.verticalContinuous,
      );

      expect(
        document,
        contains('data-mangatan-reader-layout="vertical-scroll"'),
      );
      expect(document, contains('--reader-padding: 12.0vh'));
      expect(document, contains('const pageMode = false'));
      expect(document, contains('const verticalWriting = true'));
      expect(
        document,
        contains('const continuousVertical = verticalWriting && !pageMode'),
      );
      expect(document, contains('const continuousVerticalContext = () =>'));
      expect(document, contains('content.scrollWidth - content.clientWidth'));
      expect(document, contains('overflow-x: auto !important'));
      expect(document, contains('overflow-y: hidden !important'));
    },
  );

  test('exposes every writing direction and flow combination', () {
    expect(
      EpubReadingLayout.fromAxes(vertical: false, paged: false),
      EpubReadingLayout.horizontalContinuous,
    );
    expect(
      EpubReadingLayout.fromAxes(vertical: false, paged: true),
      EpubReadingLayout.horizontalPaged,
    );
    expect(
      EpubReadingLayout.fromAxes(vertical: true, paged: true),
      EpubReadingLayout.verticalPaged,
    );
    expect(
      EpubReadingLayout.fromAxes(vertical: true, paged: false),
      EpubReadingLayout.verticalContinuous,
    );
  });

  test('writes generated reader shells as HTML beside the source XHTML', () {
    const document =
        '<html data-mangatan-reader-href="OEBPS/text/chapter.xhtml"></html>';

    expect(
      renderedEpubDocumentHref(document, 7),
      'OEBPS/text/.mangatan-reader-7.html',
    );
  });
}
