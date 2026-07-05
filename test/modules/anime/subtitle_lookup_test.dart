import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/anime/widgets/subtitle_view.dart';
import 'package:mangayomi/modules/mining/widgets/hoshi_dictionary_popup.dart';

void main() {
  test('subtitle lookup starts at the hovered Japanese character', () {
    final selection = subtitleLookupSelectionForTesting('夜払いがきます', 1);

    expect(selection.text, '払いがきます');
    expect(selection.start, 1);
    expect(selection.end, 7);
  });

  test('subtitle lookup expands to the complete hovered ASCII word', () {
    final selection = subtitleLookupSelectionForTesting('please pay now', 9);

    expect(selection.text, 'pay');
    expect(selection.start, 7);
    expect(selection.end, 10);
  });

  test('highlight geometry covers only the confirmed match', () {
    final match = subtitleHighlightRectsForTesting(
      text: '夜払いがきます',
      start: 1,
      end: 3,
    );
    final fullTail = subtitleHighlightRectsForTesting(
      text: '夜払いがきます',
      start: 1,
      end: 7,
    );

    expect(match, hasLength(1));
    expect(fullTail, hasLength(1));
    expect(match.single.width, lessThan(fullTail.single.width));
  });

  test(
    'persistent Hoshi renderer refreshes payload without reloading shell',
    () {
      final script = hoshiReplaceRenderScript(3);

      expect(script, contains('window.lookupEntries = undefined'));
      expect(script, contains('window.entryCount = 3'));
      expect(script, contains('entries-container'));
      expect(script, contains('window.renderPopup()'));
      expect(script, isNot(contains('location.reload')));
    },
  );
}
