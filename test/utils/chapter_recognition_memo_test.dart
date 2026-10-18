import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/utils/chapter_recognition.dart';

/// rawSeasonAndNumber remembers its answers. Remembered answers, and answers
/// recomputed after the memory is cleared, must equal the first ones.
void main() {
  const titles = ['One Piece', 'Season Show', '進撃の巨人', ''];
  const names = [
    'Chapter 12',
    'Chapter 12.5',
    'Vol.3 Ch.45 - Title',
    'Ch. 7 extra',
    'Season 2 Episode 4',
    'S2 - Ep. 11',
    'One Piece 1050',
    '第十二話',
    '第3巻',
    'Special',
    'Prologue',
    'Episode 3.5',
    'Chapter 8b',
    '',
  ];

  test('repeat calls and recomputed answers equal the first', () {
    final recognition = ChapterRecognition();
    final first = {
      for (final title in titles)
        for (final name in names)
          '$title|$name': recognition.rawSeasonAndNumber(title, name),
    };

    for (final title in titles) {
      for (final name in names) {
        expect(
          ChapterRecognition().rawSeasonAndNumber(title, name),
          first['$title|$name'],
        );
      }
    }

    // Fill the memory past its limit so it is cleared.
    for (var i = 0; i < 60000; i++) {
      recognition.rawSeasonAndNumber('Filler', 'Chapter $i');
    }
    for (final title in titles) {
      for (final name in names) {
        expect(
          recognition.rawSeasonAndNumber(title, name),
          first['$title|$name'],
        );
      }
    }
    expect(recognition.rawSeasonAndNumber('Filler', 'Chapter 59999'), (
      0,
      59999.0,
    ));
  });
}
