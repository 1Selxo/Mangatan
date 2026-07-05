import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/mining/widgets/dictionary_glossary.dart';

void main() {
  test('renders Yomitan structured content and inline styles as HTML', () {
    const raw = '''[
      {"type":"structured-content","content":{"tag":"ul","data":{"content":"glossary"},"style":{"listStyleType":"circle"},"content":[{"tag":"li","content":"what!"},{"tag":"li","content":"oh"}]}},
      ["何だ", "なんだ"]
    ]''';

    final html = yomitanGlossaryToHtml(
      raw,
      dictionaryCss: '.gloss-sc-li { color: red; }',
      customCss: '.dictionary-glossary { font-weight: bold; }',
    );

    expect(html, contains('class="gloss-sc-ul"'));
    expect(html, contains('data-sc-content="glossary"'));
    expect(html, contains('style="list-style-type:circle"'));
    expect(html, contains('<li class="gloss-sc-li">what!</li>'));
    expect(html, contains('.gloss-sc-li { color: red; }'));
    expect(html, contains('font-weight: bold'));
    expect(html, isNot(contains('&quot;type&quot;')));
  });

  test('finds structured-content and legacy image paths', () {
    const raw = '''[
      {"type":"image","path":"legacy.png"},
      {"type":"structured-content","content":{"tag":"img","path":"nested.webp"}}
    ]''';

    expect(yomitanGlossaryMediaPaths(raw), {'legacy.png', 'nested.webp'});
  });

  test('ports Hoshi structured content attributes and base styles', () {
    const raw = '''{
      "type":"structured-content",
      "content":{"tag":"div","data":{"content":"glossary","表記":"語"},"content":"first\\nsecond"}
    }''';

    final html = yomitanGlossaryToHtml(raw);

    expect(html, contains('data-sc-content="glossary"'));
    expect(html, contains('data-sc表記="語"'));
    expect(html, contains('first<br>second'));
    expect(html, contains('--text-color: currentColor'));
    expect(html, contains('.gloss-sc-thead'));
  });

  test('wraps dictionary images with Hoshi-compatible classes', () {
    const raw =
        '''{"type":"image","path":"entry.webp","appearance":"monochrome","background":true}''';

    final html = yomitanGlossaryToHtml(
      raw,
      mediaDataUris: const {'entry.webp': 'data:image/webp;base64,AAAA'},
    );

    expect(html, contains('class="gloss-image-link"'));
    expect(html, contains('data-appearance="monochrome"'));
    expect(html, contains('data-background="true"'));
    expect(html, contains('class="gloss-image-container"'));
  });
}
