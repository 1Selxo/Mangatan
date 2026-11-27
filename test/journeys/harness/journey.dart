/// A headless copy of the whole app for journey tests.
///
/// A journey boots the real router, screens, providers, theme and
/// translations on top of a real Isar database in a temporary directory, then
/// drives it the way a person would: taps, keys, window sizes, restarts. Only
/// what leaves the process is absent: no network, no Mihon bridge, no window
/// manager, no native plugins. That keeps each test at a few hundred
/// milliseconds while still catching the bugs that only show when the pieces
/// are wired together (a setting saved by one screen and read by another, a
/// page index written on exit and read on resume, focus after a popup).
library;

import 'dart:async';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:mangayomi/core/app_layers.dart';
import 'package:mangayomi/modules/mining/widgets/dictionary_lookup_popup.dart';
import 'package:mangayomi/modules/more/settings/appearance/providers/app_ui_scale_state_provider.dart';
import 'package:mangayomi/modules/more/settings/general/providers/memory_probe_provider.dart';
import 'package:mangayomi/modules/more/settings/security/app_lock_screen.dart';
import 'package:mangayomi/modules/onboarding/onboarding_screen.dart';
import 'package:mangayomi/modules/onboarding/providers/onboarding_state_provider.dart';
import 'package:mangayomi/modules/widgets/app_ui_scale.dart';
import 'package:mangayomi/modules/widgets/desktop_back_navigation_handler.dart';
import 'package:mangayomi/modules/widgets/error_text.dart';
import 'package:mangayomi/modules/widgets/memory_overlay.dart';
import 'package:mangayomi/providers/security_state_provider.dart';
import 'package:mangayomi/utils/legacy_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/l10n/generated/app_localizations.dart';
import 'package:mangayomi/l10n/l10n_delegates.dart';
import 'package:mangayomi/main.dart' as app;
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/modules/more/settings/appearance/providers/theme_mode_state_provider.dart';
import 'package:mangayomi/modules/more/settings/appearance/providers/theme_provider.dart';
import 'package:mangayomi/providers/storage_provider.dart';
import 'package:mangayomi/repositories/db_write_queue.dart';
import 'package:mangayomi/services/crash_report.dart';
import 'package:mangayomi/services/sync/chimahon_restore_sync_coordinator.dart';
import 'package:mangayomi/services/statistics/immersion_stats_storage.dart';
import 'package:mangayomi/services/sync_server.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';
import 'package:mangayomi/router/router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../../test_utils/isar_library.dart';
import 'plugins.dart';
import 'seed.dart';

export 'dart:ui' show Size;

export 'package:flutter/services.dart' show LogicalKeyboardKey;
export 'package:isar_community/isar.dart';
export 'package:mangayomi/models/category.dart';
export 'package:mangayomi/models/chapter.dart';
export 'package:mangayomi/models/history.dart';
export 'package:mangayomi/models/manga.dart';
export 'package:mangayomi/models/settings.dart';
export 'package:mangayomi/models/update.dart';

export 'plugins.dart';
export 'seed.dart';

bool _isarReady = false;

/// Loads the Isar native library once per test file.
Future<void> ensureIsar() async {
  if (_isarReady) return;
  await Isar.initializeIsarCore(
    libraries: {Abi.current(): await isarTestLibraryPath()},
  );
  _isarReady = true;
}

/// Process-wide state of the app that a real launch always starts fresh,
/// but tests share across launches in one process.
void resetAppGlobals() {
  dbWriteQueue.reset();
  // Errors an earlier test recorded would show on this one's Error reports.
  CrashReports.resetForTest();
  // A sync or restore of an earlier launch must not hold this one's.
  ChimahonRestoreSyncCoordinator.shared.resetForTest();
  SyncServer.resetForTest();
  ImmersionStatsStorage.resetLockForTest();
}

/// A desktop window, the size most of the fork's testing happens at.
const desktopWindow = Size(1280, 800);

/// A phone in portrait.
const phoneWindow = Size(412, 915);

class Journey {
  Journey._(this.tester, this.directory, this.seed, this.locale);

  final WidgetTester tester;
  final Directory directory;
  final Seed seed;

  /// The interface language the app runs in.
  final Locale locale;
  ProviderContainer? _container;
  var _launches = 0;

  /// The database the running app uses.
  Isar get db => app.isar;

  /// Starts the app on a fresh database. [arrange] fills the database before
  /// the first frame, the way an existing installation would be.
  static Future<Journey> start(
    WidgetTester tester, {
    Size window = desktopWindow,
    FutureOr<void> Function(Seed seed)? arrange,
    bool dark = false,
    bool pureBlack = false,
    Locale locale = const Locale('en'),
  }) async {
    late Journey journey;
    stubPlatformPlugins();
    resetAppGlobals();
    await realWork(tester, 'opening the test database', () async {
      final directory = await Directory.systemTemp.createTemp('mangatan-j-');
      // Mining, dictionary profiles and YouTube keep their preferences in
      // Hive, opened next to the database as the app does.
      Hive.init(directory.path);
      platformDirectory = directory.path;
      MiningPreferences.configureStorageDirectory(directory.path);
      final db = await _freshDatabase();
      app.isar = db;
      await db.writeTxn(
        () => db.settings.put(
          Settings()
            ..onboardingCompleted = true
            ..themeIsDark = dark || pureBlack
            ..pureBlackDarkMode = pureBlack
            ..followSystemTheme = false,
        ),
      );
      final seed = Seed(directory);
      journey = Journey._(tester, directory, seed, locale);
      if (arrange != null) await arrange(seed);
    });
    await journey.resize(window);
    addTearDown(journey._dispose);
    await journey._boot();
    return journey;
  }

  ProviderContainer get container => _container!;

  T read<T>(ProviderListenable<T> provider) => container.read(provider);

  GoRouter get router => read(routerProvider);

  Future<void> _boot() async {
    resetAppGlobals();
    _container = ProviderContainer(retry: (_, _) => null);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: _container!,
        child: _App(locale: locale),
      ),
    );
    await settle();
  }

  /// Quits the app and opens it again on the same database, like closing
  /// the window and launching it again.
  Future<void> restart() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
    _container?.dispose();
    _container = null;
    await settle();
    await _boot();
  }

  /// Ends the app the way closing a desktop window does: the process is gone
  /// before any widget is disposed, so only what was already written to the
  /// database survives. Then launches it again on that database.
  Future<void> kill() async {
    _launches++;
    final relaunch = Directory(p.join(directory.path, 'launch-$_launches'));
    relaunch.createSync();
    final name = 'journey$_launches';
    final copied = await drive(
      db.copyToFile(p.join(relaunch.path, '$name.isar')),
    );
    expect(copied, isTrue, reason: 'snapshot of the database at the kill');
    final old = db;
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
    _container?.dispose();
    _container = null;
    await drive(old.close());
    if (identical(old, _shared)) _shared = null;
    await realWork(tester, 'reopening the database', () async {
      app.isar = await Isar.open(
        appIsarSchemas,
        directory: relaunch.path,
        name: name,
      );
    });
    await _boot();
  }

  /// Lets [duration] of app time pass (debounces, delayed saves, toasts)
  /// while real asynchronous work keeps finishing.
  Future<void> wait(Duration duration) async {
    const step = Duration(milliseconds: 250);
    for (var t = Duration.zero; t < duration; t += step) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      await tester.pump(step);
    }
    await settle(rounds: 3);
  }

  /// Lets real asynchronous work finish (database reads and writes, isolates,
  /// image decoding) while frames keep being drawn. Frame-clock waits alone
  /// never finish real IO.
  Future<void> settle({int rounds = 12}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    if (checkHealth) {
      final problems = healthProblems();
      expect(problems, isEmpty, reason: 'The screen shows a failure');
    }
  }

  /// Whether every settle checks the screen for failures the app shows
  /// rather than throws. Off only where a test expects such a screen.
  bool checkHealth = true;

  /// Failures on screen that throw nothing: the app's error view for a
  /// failed provider, Flutter's error box, nonsense relative dates.
  List<String> healthProblems() => [
    for (final e in find.byType(ErrorText).evaluate())
      'error view: ${(e.widget as ErrorText).errorText}',
    for (final _ in find.byType(ErrorWidget).evaluate()) 'Flutter error box',
    for (final text in visibleTexts())
      if (_absurdAge.hasMatch(text))
        'absurd date: "$text"'
      else if (_leakedValue.hasMatch(text))
        'raw value shown: "$text"',
  ];

  /// Text a person should never read: a null, a failed number, a Dart
  /// object's default description.
  static final _leakedValue = RegExp(
    r"^null$|\bnull\b(?= ?[·•|/]|$)|\bNaN\b|\bInfinity\b|Instance of '",
  );

  static final _absurdAge = RegExp(
    r'\b\d{5,} (days?|weeks?|months?|years?)\b|(^|\s)-\d+ (days?|hours?|minutes?)\b',
  );

  /// Waits until [finder] shows, for at most [rounds] settle rounds.
  /// Whether [finder] matches nothing; `.first` and `.last` finders throw
  /// instead of answering that.
  static bool _isEmpty(Finder finder) {
    try {
      return finder.evaluate().isEmpty;
    } on StateError {
      return true;
    }
  }

  Future<void> waitFor(Finder finder, {int rounds = 60}) async {
    for (var i = 0; i < rounds; i++) {
      if (!_isEmpty(finder)) return;
      await settle(rounds: 1);
    }
    String description;
    try {
      description = '$finder';
    } on StateError {
      description = finder.describeMatch(Plurality.many);
    }
    expect(_isEmpty(finder), isFalse, reason: 'waited for $description');
  }

  Future<void> resize(Size window) async {
    await tester.binding.setSurfaceSize(window);
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pump();
  }

  Future<void> go(String location, {Object? extra}) async {
    router.go(location, extra: extra);
    await settle();
  }

  Future<void> push(String name, {Object? extra}) async {
    unawaited(router.pushNamed(name, extra: extra));
    await settle();
  }

  Future<void> back() async {
    router.pop();
    await settle();
  }

  /// Taps [finder] like a person: when something covers it (a floating
  /// navigation bar, a sheet), the list holding it is scrolled until it is
  /// clear. Fails, naming the target, when it cannot be reached at all.
  Future<void> tap(Finder finder) async {
    await tester.tap(await reach(finder));
    await settle();
  }

  Future<void> tapText(String text) => tap(find.text(text));

  Future<void> tapTooltip(String tooltip) => tap(find.byTooltip(tooltip));

  Future<void> longPress(Finder finder) async {
    await tester.longPress(await reach(finder));
    await settle();
  }

  /// Waits for [finder], scrolls it into view and out from under anything
  /// covering it, and returns the first match.
  Future<Finder> reach(Finder finder) async {
    if (_isEmpty(finder)) await scrollTo(finder);
    await waitFor(finder);
    // What a person would tap: a match they can see and reach, if any.
    final reachable = finder.hitTestable();
    final target = reachable.evaluate().isNotEmpty
        ? reachable.first
        : finder.first;
    // Only scroll what cannot be tapped where it is: scrolling "into view"
    // something already on screen can swipe a tab view, which no click does.
    if (!isTappable(target)) {
      await tester.ensureVisible(target);
      await tester.pump();
    }
    for (var i = 0; i < 6 && !isTappable(target); i++) {
      final scrollable = find.ancestor(
        of: target,
        matching: find.byType(Scrollable),
      );
      if (scrollable.evaluate().isEmpty) break;
      await tester.drag(
        scrollable.first,
        const Offset(0, -120),
        warnIfMissed: false,
      );
      await settle(rounds: 2);
    }
    expect(
      isTappable(target),
      isTrue,
      reason: '$target is covered by another widget and cannot be tapped',
    );
    return target;
  }

  /// Whether a tap on the middle of [finder] reaches it.
  bool isTappable(Finder finder) {
    // A target can scroll out of the tree between finding and tapping it.
    final RenderObject box;
    try {
      if (finder.evaluate().isEmpty) return false;
      box = tester.renderObject(finder);
    } on StateError {
      return false;
    }
    final result = tester.hitTestOnBinding(tester.getCenter(finder));
    return result.path.any((entry) => identical(entry.target, box));
  }

  /// Presses [key] and waits as long as a person would before the next
  /// press, so scroll and page animations finish.
  Future<void> key(LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await wait(const Duration(milliseconds: 700));
  }

  /// Scrolls the first scrollable that holds [finder] until it is built and
  /// on screen, the way a person scrolls a long list to an item.
  Future<void> scrollTo(Finder finder) async {
    for (var i = 0; i < 30 && _isEmpty(finder); i++) {
      final scrollables = find.byType(Scrollable);
      if (scrollables.evaluate().isEmpty) break;
      await tester.drag(
        scrollables.last,
        const Offset(0, -300),
        warnIfMissed: false,
      );
      await settle(rounds: 2);
    }
    if (!_isEmpty(finder)) await tester.ensureVisible(finder.first);
    await settle(rounds: 2);
  }

  /// Every string currently on screen, for failure messages.
  List<String> visibleTexts() => find
      .byType(Text)
      .evaluate()
      .map(
        (e) =>
            (e.widget as Text).data ??
            (e.widget as Text).textSpan?.toPlainText(),
      )
      .whereType<String>()
      .toList();

  /// Waits for [work] that completes through callbacks queued in the test's
  /// fake-async zone (Isar and Hive do), by turning that zone while real time
  /// passes. Returns whether it finished within [limit].
  Future<bool> drive(
    Future<void> work, {
    Duration limit = const Duration(seconds: 5),
  }) async {
    var done = false;
    unawaited(work.whenComplete(() => done = true).catchError((_) {}));
    final clock = Stopwatch()..start();
    while (!done && clock.elapsed < limit) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      // App time passes too, so its own delays and timeouts fire.
      await tester.pump(const Duration(milliseconds: 20));
    }
    return done;
  }

  Future<void> _dispose() async {
    await tester.pumpWidget(const SizedBox());
    // Writes the screens started while closing (history, progress) finish
    // before the database goes, as they would before a process exits.
    await settle(rounds: 10);
    // Flush one-shot timers the screens started (delayed refreshes, toasts).
    await tester.pump(const Duration(seconds: 30));
    _container?.dispose();
    // The process-wide database stays open for the next journey; a database
    // reopened after a kill is this journey's own.
    if (identical(db, _shared)) {
      // Closing used to wait for this journey's last writes. The shared
      // database stays open, so wait for them here: an empty write queues
      // behind every write still running. One left running collided with
      // the next journey's first write (an intermittent IsarError).
      final drained = await drive(
        db.writeTxn(() async {}),
        limit: const Duration(seconds: 20),
      );
      expect(drained, isTrue, reason: "this journey's writes finished");
    } else {
      await drive(db.close());
    }
    // Hive closes its boxes on real time; boxes left open would carry this
    // test's preferences into the next one.
    await realWork(
      tester,
      'closing Hive',
      () => Future.any<void>([
        Hive.close(),
        Future<void>.delayed(const Duration(seconds: 5)),
      ]),
    );
    // Timers started while closing (perf windows, delayed refreshes).
    await tester.pump(const Duration(seconds: 30));
    try {
      directory.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows can hold image files a moment longer; temp is cleaned later.
    }
  }
}

/// One database for all journeys of a test process, emptied before each.
/// Isar's native library on Windows stops opening databases after about 118
/// opens in one process (closing them does not help), and a sweep file
/// launches the app more often than that.
Isar? _shared;

Future<Isar> _freshDatabase() async {
  await ensureIsar();
  final existing = _shared;
  if (existing != null && existing.isOpen) {
    await existing.writeTxn(existing.clear);
    return existing;
  }
  final directory = await Directory.systemTemp.createTemp('mangatan-jdb-');
  return _shared = await Isar.open(
    appIsarSchemas,
    directory: directory.path,
    name: 'journeys',
  );
}

/// Runs [work] on real time, failing with [what] when it does not finish
/// within [limit]. A bare `runAsync` that never completes blocks every later
/// `runAsync` of the process, so one hang would fail all the tests after it.
Future<T> realWork<T>(
  WidgetTester tester,
  String what,
  Future<T> Function() work, {
  Duration limit = const Duration(seconds: 60),
}) async {
  var timedOut = false;
  final result = await tester.runAsync(
    () => work()
        .then<T?>((value) => value)
        .timeout(
          limit,
          onTimeout: () {
            timedOut = true;
            return null;
          },
        ),
  );
  if (timedOut) fail('$what did not finish within $limit');
  return result as T;
}

/// The app's [MaterialApp.router] without the side effects of `MyApp`
/// (window manager, Mihon bridge, deep links, background work).
class _App extends ConsumerWidget {
  const _App({required this.locale});

  final Locale locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = ref.watch(themeModeStateProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      theme: ref.watch(lightThemeProvider),
      darkTheme: ref.watch(darkThemeProvider),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      routerConfig: router,
      // The layers MyApp's builder puts around every page, in its order
      // (lib/main.dart): first run, theme ground, UI scale, toasts, desktop
      // back navigation, app lock and memory overlay.
      builder: (context, child) {
        Widget content = child ?? const SizedBox.shrink();
        content = ref.watch(onboardingCompletedStateProvider)
            ? content
            : const OnboardingScreen();
        content = ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: content,
        );
        content = AppUiScale(
          scale: ref.watch(appUiScaleStateProvider),
          child: content,
        );
        content = DesktopBackNavigationHandler(
          canGoBack: router.canPop,
          onBack: router.pop,
          dismissTransientUi: DictionaryLookupPopup.dismissActive,
          child: LegacyMaterialBridge(child: BotToastInit()(context, content)),
        );
        final locked =
            ref.watch(appLockEnabledStateProvider) &&
            !ref.watch(appUnlockedStateProvider);
        return AppLayers(
          app: content,
          covers: [
            if (locked) const AppLockScreen(key: ValueKey(AppLockScreen)),
            if (ref.watch(memoryOverlayVisibleProvider))
              MemoryOverlay(
                key: const ValueKey(MemoryOverlay),
                probe: ref.read(memoryProbeProvider),
                onClose: () =>
                    ref.read(memoryOverlayVisibleProvider.notifier).set(false),
              ),
          ],
        );
      },
    );
  }
}
