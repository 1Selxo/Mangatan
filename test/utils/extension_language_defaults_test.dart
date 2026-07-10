import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/utils/extension_language_defaults.dart';

void main() {
  const deviceLocales = [
    Locale('en', 'US'),
    Locale('pt', 'BR'),
    Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hans',
      countryCode: 'CN',
    ),
  ];

  test('enables All and OS locale languages by default', () {
    expect(
      shouldEnableExtensionLanguageByDefault('all', deviceLocales),
      isTrue,
    );
    expect(shouldEnableExtensionLanguageByDefault('en', deviceLocales), isTrue);
    expect(
      shouldEnableExtensionLanguageByDefault('pt-BR', deviceLocales),
      isTrue,
    );
    expect(
      shouldEnableExtensionLanguageByDefault('zh-Hans-CN', deviceLocales),
      isTrue,
    );
  });

  test('does not enable unrelated or mismatched regional languages', () {
    expect(
      shouldEnableExtensionLanguageByDefault('fr', deviceLocales),
      isFalse,
    );
    expect(
      shouldEnableExtensionLanguageByDefault('pt-PT', deviceLocales),
      isFalse,
    );
    expect(
      shouldEnableExtensionLanguageByDefault('zh-TW', deviceLocales),
      isFalse,
    );
  });

  test('normalizes extension language tags', () {
    expect(normalizeExtensionLanguageTag(' PT_br '), 'pt-br');
  });

  test('saved language states override OS defaults for new sources', () {
    expect(
      extensionLanguageEnabledForNewSource(
        'en',
        savedLanguageStates: const {'en': false},
        deviceLocales: deviceLocales,
      ),
      isFalse,
    );
    expect(
      extensionLanguageEnabledForNewSource(
        'fr',
        savedLanguageStates: const {'fr': true},
        deviceLocales: deviceLocales,
      ),
      isTrue,
    );
  });
}
