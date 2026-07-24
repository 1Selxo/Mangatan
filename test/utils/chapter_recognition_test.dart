import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/utils/chapter_recognition.dart';

void main() {
  final recognition = ChapterRecognition();

  test('prefers a chapter number supplied by a Mihon extension', () {
    expect(
      recognition.resolveChapterNumber(
        '14 Sai no Koi',
        '[水谷フーカ] 14歳の恋 第12巻',
        sourceChapterNumber: 12,
      ),
      12,
    );
  });

  test('recognizes Japanese Mokuro volume names as a fallback', () {
    expect(
      recognition.parseChapterNumber('14 Sai no Koi', '[水谷フーカ] 14歳の恋 第12巻'),
      12,
    );
  });

  test('recognizes western Mokuro volume markers as a fallback', () {
    expect(
      recognition.parseChapterNumber('Ao no Hako (Upscaled)', 'アオのハコ v22'),
      22,
    );
  });

  test('chapter markers still take precedence over volume markers', () {
    expect(
      recognition.parseChapterNumber(
        'Mokushiroku Alice',
        'Mokushiroku Alice Vol.1 Ch.4: Misrepresentation',
      ),
      4,
    );
  });

  test('episode fallback keeps its season-independent tracker behavior', () {
    expect(recognition.resolveEpisodeNumber('Show', 'S2 Episode 3'), 3);
  });
}
