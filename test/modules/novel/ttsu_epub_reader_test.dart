import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/novel/widgets/ttsu_epub_reader.dart';
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
}
