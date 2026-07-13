import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/mining/profile_ocr_language.dart';

void main() {
  test('resolved profile language selects OCR language', () {
    expect(profileOcrLanguage('KO'), 'ko');
    expect(profileOcrLanguage('aii'), 'ja');
    expect(profileOcrLanguage('', fallback: 'en'), 'en');
  });

  test('source and profile guard matches Chimahon base-language rules', () {
    expect(
      isProfileOcrAllowed(sourceLanguage: 'ja-JP', profileLanguage: 'ja'),
      isTrue,
    );
    expect(
      isProfileOcrAllowed(sourceLanguage: 'ja', profileLanguage: 'en'),
      isFalse,
    );
    expect(
      isProfileOcrAllowed(sourceLanguage: 'all', profileLanguage: 'en'),
      isTrue,
    );
    expect(
      isProfileOcrAllowed(sourceLanguage: 'en', profileLanguage: ''),
      isTrue,
    );
  });
}
