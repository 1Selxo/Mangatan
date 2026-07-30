import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/subtitles/subtitle_regex_filters.dart';

void main() {
  test('applies Chimahon-compatible subtitle cleanup options', () {
    const options = SubtitleRegexFilterOptions(
      removeSpeakerNames: true,
      removeBracketedText: true,
      removeCurlyBracedText: true,
      removeUppercaseLines: true,
      removeMusicSymbols: true,
    );

    expect(
      applySubtitleRegexFilters(
        '(John): Hello ♪\n[SIREN]\n{position}World\nALL CAPS',
        options,
      ),
      'Hello\nWorld',
    );
  });

  test('merges lines and safely ignores an invalid custom regex', () {
    const options = SubtitleRegexFilterOptions(
      mergeMultiline: true,
      customRegexEnabled: true,
      customRegexPattern: '[',
    );

    expect(applySubtitleRegexFilters('one\n two', options), 'one two');
  });

  test('custom regex removes matching text', () {
    const options = SubtitleRegexFilterOptions(
      customRegexEnabled: true,
      customRegexPattern: r'\bNOTE:\s*',
    );

    expect(applySubtitleRegexFilters('NOTE: Keep this', options), 'Keep this');
  });
}
