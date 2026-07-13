import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/utils/language.dart';

void main() {
  test('labels the all pseudo-language as Multi', () {
    expect(completeLanguageName('all'), 'Multi');
    expect(completeLanguageNameEnglish('ALL'), 'Multi');
  });
}
