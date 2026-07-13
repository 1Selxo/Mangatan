import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/modules/anime/widgets/subtitle_view.dart';
import 'package:mangayomi/modules/mining/widgets/hoshi_dictionary_popup.dart';

void main() {
  test('only the currently dismissed popup clears the subtitle highlight', () {
    expect(
      subtitleHighlightDismissalIsCurrent(
        popupGeneration: 4,
        currentGeneration: 4,
      ),
      isTrue,
    );
    expect(
      subtitleHighlightDismissalIsCurrent(
        popupGeneration: 3,
        currentGeneration: 4,
      ),
      isFalse,
    );
  });

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

  test('subtitle zero position clears the seek bar at every player size', () {
    final largeInset = subtitleBottomInsetForSeekBar(
      playerHeight: 1440,
      seekBarTop: 1300,
    );
    final compactInset = subtitleBottomInsetForSeekBar(
      playerHeight: 360,
      seekBarTop: 220,
    );

    expect(1440 - largeInset, lessThan(1300));
    expect(360 - compactInset, lessThan(220));
    expect(subtitleOffsetForPosition(0), Offset.zero);
    expect(subtitleOffsetForPosition(-40), const Offset(0, 40));
  });

  test('legacy subtitle settings default position to zero', () {
    final settings = PlayerSubtitleSettings.fromJson({'fontSize': 45});

    expect(settings.position, 0);
    expect(settings.toJson()['position'], 0);
  });

  test(
    'persistent Hoshi renderer refreshes payload without reloading shell',
    () {
      final script = hoshiReplaceRenderScriptForEntries([
        {'expression': '払う'},
      ]);

      expect(script, contains('__mangayomiHoshiRenderToken'));
      expect(script, contains('window.lookupEntries = [{"expression":"払う"}]'));
      expect(
        script,
        contains('window.entryCount = window.lookupEntries.length'),
      );
      expect(script, contains('entries-container'));
      expect(script, contains('window.renderPopup()'));
      expect(script, isNot(contains('location.reload')));
    },
  );
}
