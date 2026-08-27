import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mangayomi/l10n/generated/app_localizations.dart';
import 'package:mangayomi/models/sync_preference.dart';
import 'package:mangayomi/modules/main_view/main_screen.dart';
import 'package:mangayomi/modules/main_view/providers/migration.dart';
import 'package:mangayomi/modules/main_view/providers/tv_mode_provider.dart';
import 'package:mangayomi/modules/manga/detail/providers/state_providers.dart';
import 'package:mangayomi/modules/more/providers/downloaded_only_state_provider.dart';
import 'package:mangayomi/modules/more/providers/incognito_mode_state_provider.dart';
import 'package:mangayomi/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:mangayomi/modules/more/settings/sync/providers/sync_providers.dart';
import 'package:mangayomi/providers/l10n_providers.dart';
import 'package:mangayomi/router/router.dart';

void main() {
  test('mobile navigation keeps an accessible width for every destination', () {
    expect(mobileNavigationContentWidth(320, 8), 576);
    expect(mobileNavigationContentWidth(430, 4), 430);
  });

  testWidgets('keeps the More rail destination aligned with its route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/dictionaryLookup',
      routes: [
        ShellRoute(
          builder: (context, state, child) => MainScreen(child: child),
          routes: [
            GoRoute(
              path: '/dictionaryLookup',
              builder: (_, _) => const SizedBox.shrink(),
            ),
            GoRoute(path: '/more', builder: (_, _) => const SizedBox.shrink()),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          migrationProvider.overrideWith((ref) async {}),
          navigationOrderStateProvider.overrideWithValue(const [
            '/dictionaryLookup',
            '/more',
          ]),
          hideItemsStateProvider.overrideWithValue(const []),
          mergeLibraryNavMobileStateProvider.overrideWithValue(false),
          animeOnlyTvModeProvider.overrideWith(() => _StubAnimeOnlyTvMode()),
          l10nLocaleStateProvider.overrideWithValue(const Locale('en')),
          downloadedOnlyStateProvider.overrideWithValue(false),
          incognitoModeStateProvider.overrideWithValue(false),
          isLongPressedStateProvider.overrideWithValue(false),
          synchingProvider(syncId: 1)
              .overrideWithValue(SyncPreference(syncId: 1)),
          routerCurrentLocationStateProvider.overrideWithValue(
            '/dictionaryLookup',
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_outlined));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/more');

    // MainScreen schedules its normal startup work a few seconds after the
    // first frame. Let those callbacks run before the test is torn down.
    await tester.pump(const Duration(seconds: 5));
  });
}

class _StubAnimeOnlyTvMode extends AnimeOnlyTvMode {
  @override
  bool build() => false;
}
