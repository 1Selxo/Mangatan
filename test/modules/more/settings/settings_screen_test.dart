import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/l10n/generated/app_localizations.dart';
import 'package:mangayomi/modules/more/settings/dictionary/dictionary_settings_section.dart';
import 'package:mangayomi/modules/more/settings/settings_screen.dart';

void main() {
  test('dictionary settings match the Chimahon learning categories', () {
    expect(DictionarySettingsSection.values.map((section) => section.title), [
      'Dictionaries & audio',
      'Dictionary popup',
      'Anki',
    ]);
    expect(DictionarySettingsSection.values.map((section) => section.summary), [
      'Import, order, enable',
      'Layout, theme, OCR',
      'Deck, fields, export',
    ]);
  });

  testWidgets('settings list exposes the sectioned learning entries', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(),
      ),
    );

    for (final section in ['General', 'Media', 'Learning', 'Sync']) {
      expect(find.text(section), findsWidgets);
    }
    for (final section in DictionarySettingsSection.values) {
      expect(find.text(section.title), findsOneWidget);
      expect(find.text(section.summary), findsOneWidget);
    }
    expect(find.text('Dictionary & OCR'), findsNothing);
  });
}
