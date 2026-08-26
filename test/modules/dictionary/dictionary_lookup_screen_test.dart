import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mangayomi/l10n/generated/app_localizations.dart';
import 'package:mangayomi/modules/dictionary/dictionary_lookup_screen.dart';
import 'package:mangayomi/services/mining/anki_markers.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';

const _emptyDictionaryData = DictionaryLookupData(
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
);

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
          dataLoader: () async => _emptyDictionaryData,
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
          dataLoader: () async => _emptyDictionaryData,
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

  testWidgets('returns from dictionary settings without a setState error', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/dictionaryLookup',
      routes: [
        GoRoute(
          path: '/dictionaryLookup',
          builder: (_, _) => DictionaryLookupScreen(
            dataLoader: () async => _emptyDictionaryData,
          ),
        ),
        GoRoute(
          path: '/dictionary',
          builder: (_, _) =>
              Scaffold(appBar: AppBar(title: Text('Dictionary settings'))),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.text('Dictionary settings'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('No dictionaries installed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
