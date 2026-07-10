import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/l10n/generated/app_localizations.dart';
import 'package:mangayomi/modules/dictionary/dictionary_lookup_screen.dart';
import 'package:mangayomi/services/mining/anki_markers.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';

void main() {
  test('uses the Flutter renderer on Linux', () {
    expect(dictionaryLookupUsesNativeRenderer(TargetPlatform.linux), isTrue);
    expect(dictionaryLookupUsesNativeRenderer(TargetPlatform.macOS), isFalse);
  });

  testWidgets('shows dictionary setup state and focuses search', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DictionaryLookupScreen(
          dataLoader: () async => const DictionaryLookupData(
            dictionaries: [],
            preferences: DictionaryPopupPreferences(
              width: 430,
              height: 360,
              fontSize: 14,
              theme: DictionaryThemePreference.system,
              eInkMode: false,
              paginatedScrolling: false,
              customCss: '',
              showFrequencyHarmonic: false,
              showFrequencyAverage: false,
              showPitchNumber: true,
              showPitchText: true,
            ),
            ankiProfile: AnkiMiningProfile(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dictionary'), findsOneWidget);
    expect(find.text('No dictionaries installed'), findsOneWidget);
    expect(find.text('Set up dictionaries'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
      isTrue,
    );
  });

  testWidgets('shows a clear action when the query has text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DictionaryLookupScreen(
          dataLoader: () async => const DictionaryLookupData(
            dictionaries: [],
            preferences: DictionaryPopupPreferences(
              width: 430,
              height: 360,
              fontSize: 14,
              theme: DictionaryThemePreference.system,
              eInkMode: false,
              paginatedScrolling: false,
              customCss: '',
              showFrequencyHarmonic: false,
              showFrequencyAverage: false,
              showPitchNumber: true,
              showPitchText: true,
            ),
            ankiProfile: AnkiMiningProfile(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '漫画');
    await tester.pump();
    expect(find.byTooltip('Clear search'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(find.byTooltip('Clear search'), findsNothing);
    expect(find.text('漫画'), findsNothing);
  });
}
