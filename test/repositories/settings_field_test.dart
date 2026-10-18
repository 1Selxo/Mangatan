// SettingsRepository.field must return exactly what reading the same field
// from SettingsRepository.current returns, for every field the startup
// providers read through it, and fail the same way when the row is missing.
//
// With MANGATAN_PERF set it also prints how long each read takes on a
// settings row with a large library's per-entry lists.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/repositories/settings_repository.dart';

/// Each startup provider's field, read the old way and the new way.
final _fields = <String, (Object? Function(Settings), Object? Function())>{
  'showSourceBadge': (
    (s) => s.showSourceBadge,
    () => settingsRepository.field((s) => s.showSourceBadgeProperty()),
  ),
  'tvAnimeOnlyOverride': (
    (s) => s.tvAnimeOnlyOverride,
    () => settingsRepository.field((s) => s.tvAnimeOnlyOverrideProperty()),
  ),
  'navigationOrder': (
    (s) => s.navigationOrder?.toList(),
    () =>
        settingsRepository.field((s) => s.navigationOrderProperty())?.toList(),
  ),
  'hideItems': (
    (s) => s.hideItems,
    () => settingsRepository.field((s) => s.hideItemsProperty()),
  ),
  'mergeLibraryNavMobile': (
    (s) => s.mergeLibraryNavMobile,
    () => settingsRepository.field((s) => s.mergeLibraryNavMobileProperty()),
  ),
  'appLockEnabled': (
    (s) => s.appLockEnabled,
    () => settingsRepository.field((s) => s.appLockEnabledProperty()),
  ),
  'customDns': (
    (s) => s.customDns,
    () => settingsRepository.field((s) => s.customDnsProperty()),
  ),
  'userAgent': (
    (s) => s.userAgent,
    () => settingsRepository.field((s) => s.userAgentProperty()),
  ),
  'flexColorSchemeBlendLevel': (
    (s) => s.flexColorSchemeBlendLevel,
    () =>
        settingsRepository.field((s) => s.flexColorSchemeBlendLevelProperty()),
  ),
  'animationDurationScale': (
    (s) => s.animationDurationScale,
    () => settingsRepository.field((s) => s.animationDurationScaleProperty()),
  ),
  'pureBlackDarkMode': (
    (s) => s.pureBlackDarkMode,
    () => settingsRepository.field((s) => s.pureBlackDarkModeProperty()),
  ),
  'appUiScale': (
    (s) => s.appUiScale,
    () => settingsRepository.field((s) => s.appUiScaleProperty()),
  ),
  'flexSchemeColorIndex': (
    (s) => s.flexSchemeColorIndex,
    () => settingsRepository.field((s) => s.flexSchemeColorIndexProperty()),
  ),
  'appFontFamily': (
    (s) => s.appFontFamily,
    () => settingsRepository.field((s) => s.appFontFamilyProperty()),
  ),
  'themeIsDark': (
    (s) => s.themeIsDark,
    () => settingsRepository.field((s) => s.themeIsDarkProperty()),
  ),
  'followSystemTheme': (
    (s) => s.followSystemTheme,
    () => settingsRepository.field((s) => s.followSystemThemeProperty()),
  ),
  'checkForExtensionUpdates': (
    (s) => s.checkForExtensionUpdates,
    () => settingsRepository.field((s) => s.checkForExtensionUpdatesProperty()),
  ),
  'downloadedOnlyMode': (
    (s) => s.downloadedOnlyMode,
    () => settingsRepository.field((s) => s.downloadedOnlyModeProperty()),
  ),
  'incognitoMode': (
    (s) => s.incognitoMode,
    () => settingsRepository.field((s) => s.incognitoModeProperty()),
  ),
  'locale': (
    (s) => _locale(s.locale),
    () => _locale(settingsRepository.field((s) => s.localeProperty())),
  ),
  'clearChapterCacheOnAppLaunch': (
    (s) => s.clearChapterCacheOnAppLaunch,
    () => settingsRepository.field(
      (s) => s.clearChapterCacheOnAppLaunchProperty(),
    ),
  ),
  'mangaGridSize': (
    (s) => s.mangaGridSize,
    () => settingsRepository.field((s) => s.mangaGridSizeProperty()),
  ),
  'animeGridSize': (
    (s) => s.animeGridSize,
    () => settingsRepository.field((s) => s.animeGridSizeProperty()),
  ),
  'novelGridSize': (
    (s) => s.novelGridSize,
    () => settingsRepository.field((s) => s.novelGridSizeProperty()),
  ),
  'onboardingCompleted': (
    (s) => s.onboardingCompleted,
    () => settingsRepository.field((s) => s.onboardingCompletedProperty()),
  ),
  'mangaExtensionsRepo': (
    (s) => _json(s.mangaExtensionsRepo),
    () =>
        _json(settingsRepository.field((s) => s.mangaExtensionsRepoProperty())),
  ),
  'animeExtensionsRepo': (
    (s) => _json(s.animeExtensionsRepo),
    () =>
        _json(settingsRepository.field((s) => s.animeExtensionsRepoProperty())),
  ),
  'novelExtensionsRepo': (
    (s) => _json(s.novelExtensionsRepo),
    () =>
        _json(settingsRepository.field((s) => s.novelExtensionsRepoProperty())),
  ),
};

/// Fields read with `currentOrNull?.<field>` before and with `fieldOrNull`
/// now: per HTTP request (DNS settings, cookies) and for the bridge address.
final _nullableFields =
    <String, (Object? Function(Settings?), Object? Function())>{
      'doHEnabled': (
        (s) => s?.doHEnabled,
        () => settingsRepository.fieldOrNull((s) => s.doHEnabledProperty()),
      ),
      'doHProviderId': (
        (s) => s?.doHProviderId,
        () => settingsRepository.fieldOrNull((s) => s.doHProviderIdProperty()),
      ),
      'cookiesList': (
        (s) => _json(s?.cookiesList),
        () => _json(
          settingsRepository.fieldOrNull((s) => s.cookiesListProperty()),
        ),
      ),
      'androidProxyServer': (
        (s) => s?.androidProxyServer,
        () => settingsRepository.fieldOrNull(
          (s) => s.androidProxyServerProperty(),
        ),
      ),
      'androidProxyServer (bridge base URL)': (
        (s) => s?.androidProxyServer,
        () => isar.settings
            .where()
            .idEqualTo(227)
            .androidProxyServerProperty()
            .findFirstSync(),
      ),
    };

/// Embedded objects have no field-by-field `==`, so compare their JSON.
String? _json(List<dynamic>? list) =>
    list == null ? null : jsonEncode([for (final e in list) e.toJson()]);

Object? _locale(L10nLocale? locale) =>
    locale == null ? null : (locale.languageCode, locale.countryCode);

bool _same(Object? a, Object? b) {
  if (a is List && b is List) return listEquals(a, b);
  return a == b && a.runtimeType == b.runtimeType;
}

void _expectAllFieldsMatch() {
  _expectNullableFieldsMatch();
  final current = settingsRepository.current;
  for (final MapEntry(key: name, value: (old, now)) in _fields.entries) {
    final expected = old(current);
    final actual = now();
    expect(
      _same(expected, actual),
      isTrue,
      reason: '$name: expected $expected, got $actual',
    );
  }
}

void _expectNullableFieldsMatch() {
  final current = settingsRepository.currentOrNull;
  for (final MapEntry(key: name, value: (old, now))
      in _nullableFields.entries) {
    final expected = old(current);
    final actual = now();
    expect(
      _same(expected, actual),
      isTrue,
      reason: '$name: expected $expected, got $actual',
    );
  }
}

void main() {
  late Directory dir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final overrides = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      await Isar.initializeIsarCore(download: true);
    } finally {
      HttpOverrides.global = overrides;
    }
    dir = await Directory.systemTemp.createTemp('settings_field');
    isar = await Isar.open(
      [SettingsSchema, SourceSchema],
      directory: dir.path,
      name: 'settings_field_${dir.path.hashCode}',
    );
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    await dir.delete(recursive: true);
  });

  test('a fresh settings row reads the same', () {
    isar.writeTxnSync(() => isar.settings.putSync(Settings()));
    _expectAllFieldsMatch();
  });

  test('stored values and nulls read the same', () {
    isar.writeTxnSync(
      () => isar.settings.putSync(
        Settings()
          ..showSourceBadge = true
          ..tvAnimeOnlyOverride = null
          ..navigationOrder = ['/history', '/MangaLibrary', '/more']
          ..hideItems = []
          ..mergeLibraryNavMobile = true
          ..appLockEnabled = null
          ..customDns = 'https://dns.example/dns-query'
          ..userAgent = 'Agent/1.0 (é ü 漢字)'
          ..flexColorSchemeBlendLevel = 7.25
          ..animationDurationScale = 0.1 + 0.2
          ..pureBlackDarkMode = false
          ..appUiScale = null
          ..flexSchemeColorIndex = 12
          ..appFontFamily = ''
          ..themeIsDark = true
          ..followSystemTheme = null
          ..checkForExtensionUpdates = false
          ..downloadedOnlyMode = true
          ..incognitoMode = false
          ..locale = L10nLocale(languageCode: 'pt', countryCode: 'BR')
          ..clearChapterCacheOnAppLaunch = true
          ..mangaGridSize = 4
          ..animeGridSize = null
          ..novelGridSize = 0
          ..onboardingCompleted = false
          ..mangaExtensionsRepo = [
            Repo(name: 'Keiyoushi', jsonUrl: 'https://repo.example/i.json'),
            Repo(name: 'é 漢字', website: '', hidden: true),
          ]
          ..animeExtensionsRepo = []
          ..novelExtensionsRepo = null
          ..doHEnabled = true
          ..doHProviderId = null
          ..cookiesList = [
            MCookie(host: 'example.com', cookie: 'cf_clearance=ä; a=b'),
            MCookie(host: null, cookie: ''),
          ]
          ..androidProxyServer = 'http://192.168.1.5:8080'
          ..chapterPageIndexList = [
            for (var i = 0; i < 2000; i++)
              ChapterPageIndex(chapterId: i, index: i % 7),
          ],
      ),
    );
    _expectAllFieldsMatch();
  });

  test('a changed value is read fresh each time, as before', () {
    isar.writeTxnSync(() => isar.settings.putSync(Settings()));
    expect(
      settingsRepository.field((s) => s.themeIsDarkProperty()),
      settingsRepository.current.themeIsDark,
    );
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settingsRepository.current..themeIsDark = !(Settings().themeIsDark!),
      ),
    );
    _expectAllFieldsMatch();
    expect(
      settingsRepository.field((s) => s.themeIsDarkProperty()),
      !(Settings().themeIsDark!),
    );
  });

  test('stored DNS settings and repositories read the same', () {
    isar.writeTxnSync(
      () => isar.settings.putSync(
        Settings()
          ..doHEnabled = false
          ..doHProviderId = 3
          ..cookiesList = []
          ..androidProxyServer = ''
          ..onboardingCompleted = null
          ..mangaExtensionsRepo = null
          ..animeExtensionsRepo = [Repo(jsonUrl: 'https://a.example/x.json')],
      ),
    );
    _expectAllFieldsMatch();
  });

  test('a missing row reads null where currentOrNull did', () {
    expect(settingsRepository.currentOrNull, isNull);
    _expectNullableFieldsMatch();
    for (final (_, now) in _nullableFields.values) {
      expect(now(), isNull);
    }
  });

  test('a closed database reads null where currentOrNull did', () async {
    isar.writeTxnSync(() => isar.settings.putSync(Settings()));
    final open = isar;
    await open.close();
    expect(settingsRepository.currentOrNull, isNull);
    for (final (name, (_, now)) in [
      for (final e in _nullableFields.entries)
        if (!e.key.contains('bridge')) (e.key, e.value),
    ]) {
      expect(now(), isNull, reason: name);
    }
    isar = await Isar.open(
      [SettingsSchema, SourceSchema],
      directory: dir.path,
      name: 'settings_field_${dir.path.hashCode}',
    );
  });

  test('a missing row fails the same way', () {
    Object? oldError;
    Object? newError;
    try {
      settingsRepository.current;
    } catch (e) {
      oldError = e;
    }
    try {
      settingsRepository.field((s) => s.themeIsDarkProperty());
    } catch (e) {
      newError = e;
    }
    expect(oldError, isNotNull);
    expect(newError.runtimeType, oldError.runtimeType);
    expect(newError.toString(), oldError.toString());
  });

  test(
    'read cost with a large library',
    skip: Platform.environment['MANGATAN_PERF'] == null,
    () {
      isar.writeTxnSync(
        () => isar.settings.putSync(
          Settings()
            ..chapterPageIndexList = [
              for (var i = 0; i < 20000; i++)
                ChapterPageIndex(chapterId: i, index: i % 20),
            ]
            ..sortChapterList = [
              for (var i = 0; i < 500; i++) SortChapter(mangaId: i),
            ]
            ..chapterFilterUnreadList = [
              for (var i = 0; i < 500; i++) ChapterFilterUnread(mangaId: i),
            ]
            ..chapterFilterBookmarkedList = [
              for (var i = 0; i < 500; i++) ChapterFilterBookmarked(mangaId: i),
            ]
            ..chapterFilterDownloadedList = [
              for (var i = 0; i < 500; i++) ChapterFilterDownloaded(mangaId: i),
            ],
        ),
      );
      double median(void Function() read) {
        final times = <double>[];
        for (var i = 0; i < 43; i++) {
          final clock = Stopwatch()..start();
          read();
          if (i >= 3) times.add(clock.elapsedMicroseconds / 1000);
        }
        times.sort();
        return times[times.length ~/ 2];
      }

      final whole = median(() => settingsRepository.current.themeIsDark);
      final one = median(
        () => settingsRepository.field((s) => s.themeIsDarkProperty()),
      );
      // ignore: avoid_print
      print('BENCH settings read: current $whole ms, field $one ms');
      // What one HTTP request reads: MClient.init's DNS settings, then the
      // cookie lookup.
      final requestOld = median(() {
        final appSettings = settingsRepository.currentOrNull;
        appSettings?.doHEnabled;
        appSettings?.doHProviderId;
        settingsRepository.currentOrNull?.cookiesList;
      });
      final requestNew = median(() {
        settingsRepository.fieldOrNull((s) => s.doHEnabledProperty());
        settingsRepository.fieldOrNull((s) => s.doHProviderIdProperty());
        settingsRepository.fieldOrNull((s) => s.cookiesListProperty());
      });
      // ignore: avoid_print
      print(
        'BENCH per-request settings reads: whole row $requestOld ms, '
        'fields $requestNew ms',
      );
    },
  );
}
