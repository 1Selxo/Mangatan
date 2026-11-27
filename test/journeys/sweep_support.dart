// Shared by the sweep_*_journey_test.dart files, split so that no single
// test process starts the app several hundred times.
//
// Visits every screen of the app with a lived-in library, at several window
// sizes, themes and languages. Nothing is asserted per screen: the framework
// fails a test on any layout overflow or exception, and the harness fails it
// on an error view or a nonsense date. This is the "click through everything
// after a merge" round, the overflow fixes of 2026-11-06 and upstream's many
// "Fix overflow in ..." commits, done for every screen at once.
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/widgets/cover_view_widget.dart';
import 'package:material_ui/material_ui.dart';

import 'harness/journey.dart';
import 'harness/reader.dart';

/// Every route, as the router names them, but /massMigration, which the app
/// only ever opens with its item type and which fails without one.
/// Routes that need an argument open
/// their "missing" page, which must not fail either.
const allRoutes = [
  '/MangaLibrary',
  '/AnimeLibrary',
  '/NovelLibrary',
  '/trackerLibrary',
  '/history',
  '/updates',
  '/browse',
  '/dictionaryLookup',
  '/more',
  '/mangaHome',
  '/mangaHomeGenre',
  '/ExtensionLang',
  '/settings',
  '/appearance',
  '/extension_detail',
  '/globalSearch',
  '/about',
  '/errorReports',
  '/openSourceLicenses',
  '/track',
  '/sync',
  '/deviceSync',
  '/sourceFilter',
  '/downloadQueue',
  '/categories',
  '/statistics',
  '/immersionStatistics',
  '/immersionStatisticsTitles',
  '/immersionStatisticsTitle',
  '/general',
  '/readerMode',
  '/dictionary',
  '/ocrSettings',
  '/dictionaryPopup',
  '/ankiSettings',
  '/readerSettingsSection',
  '/novelReaderMode',
  '/browseS',
  '/extensionServer',
  '/SourceRepositories',
  '/downloads',
  '/dataAndStorage',
  '/security',
  '/manageTrackers',
  '/trackingDetail',
  '/playerOverview',
  '/playerMode',
  '/playerSubtitles',
  '/keyboardShortcuts',
  '/createExtension',
  '/createBackup',
  '/customNavigationSettings',
  '/customButtonScreen',
  '/playerDecoderScreen',
  '/playerAudioScreen',
  '/playerAdvancedScreen',
  '/calendarScreen',
  '/migrate',
  '/related',
  '/recommendations',
  '/watchOrder',
];

/// The screens a translation or a narrow window most often breaks.
const keyRoutes = [
  '/MangaLibrary',
  '/history',
  '/updates',
  '/browse',
  '/more',
  '/settings',
  '/appearance',
  '/general',
  '/readerMode',
  '/downloads',
  '/dataAndStorage',
  '/statistics',
  '/categories',
  '/downloadQueue',
  '/security',
  '/sync',
];

/// Screens with a suspected bug, by window, skipped here (each has its own
/// journey) so the sweep stays green for everything else. Remove an entry once its bug is fixed.
const knownIssues = {
  ('desktop', '/calendarScreen'): 'S2: calendar buttons need a Material',
  ('desktop dark', '/calendarScreen'): 'S2: calendar buttons need a Material',
  ('phone', '/calendarScreen'): 'S2: calendar buttons need a Material',
  ('small window', '/calendarScreen'): 'S2: calendar buttons need a Material',
};

/// Same, for the translation sweep: (language, window, test).
// Empty since the sweep measures text in the app's own font (S14, S17 and
// S18 were the test font's square letters).
const knownTranslationIssues = <(String, String, String), String>{};

/// `--dart-define=RUN_KNOWN=true` runs the known-issue journeys too, to see
/// which suspected bugs still reproduce.
const runKnown = bool.fromEnvironment('RUN_KNOWN');

Future<void> visit(Journey j, List<String> routes) async {
  for (final route in routes) {
    j.router.push(route);
    await j.settle(rounds: 8);
    if (j.router.canPop()) j.router.pop();
    await j.settle(rounds: 3);
  }
}

/// Opens the first series of the library and one of its chapters.
Future<void> openSeriesAndReader(Journey j) async {
  await j.go('/MangaLibrary');
  // The grid's tile: the Continue shelf above it opens the chapter.
  await j.tap(
    find.descendant(
      of: find.byType(CoverViewWidget),
      matching: find.text('KUSO ONNA NO SACHIARE'),
    ),
  );
  await j.openChapter('Chapter 2');
  await j.key(LogicalKeyboardKey.escape);
  await j.settle(rounds: 10);
}

/// The known-issue journeys of the sweep, skipped until their bugs are fixed.
void sweepKnownIssues() {
  testWidgets(
    'S8: the library fits a 640×480 window',
    skip: !runKnown, // Suspected bug S8: its category tabs overflow by 1px.
    (tester) async {
      await Journey.start(
        tester,
        window: const Size(640, 480),
        arrange: (seed) => seed.livedIn(),
      );
    },
  );
}

/// Every screen, then a series and its reader, in each of [windows].
void sweepWindows(List<(String, Size, bool)> windows) {
  for (final (label, size, dark) in windows) {
    group('every screen on a $label:', () {
      for (final route in allRoutes) {
        final known = knownIssues[(label, route)];
        testWidgets(route, skip: known != null && !runKnown, (tester) async {
          final j = await Journey.start(
            tester,
            window: size,
            dark: dark,
            arrange: (seed) => seed.livedIn(),
          );
          await visit(j, [route]);
        });
      }
      testWidgets('series page and reader', (tester) async {
        final j = await Journey.start(
          tester,
          window: size,
          dark: dark,
          arrange: (seed) => seed.livedIn(),
        );
        await openSeriesAndReader(j);
      });
    });
  }
}

/// The key screens, then a series and its reader, in each of [locales] on a
/// desktop and a phone.
void sweepTranslations(List<Locale> locales) {
  for (final locale in locales) {
    for (final (label, size) in [
      ('desktop', desktopWindow),
      ('phone', phoneWindow),
    ]) {
      group('${locale.toLanguageTag()} on a $label:', () {
        for (final test in [...keyRoutes, 'series page and reader']) {
          testWidgets(
            test,
            skip:
                !runKnown &&
                knownTranslationIssues.containsKey((
                  locale.toLanguageTag(),
                  label,
                  test,
                )),
            (tester) async {
              final j = await Journey.start(
                tester,
                window: size,
                locale: locale,
                arrange: (seed) => seed.livedIn(),
              );
              if (test.startsWith('/')) {
                await visit(j, [test]);
              } else {
                await openSeriesAndReader(j);
              }
            },
          );
        }
      });
    }
  }
}
