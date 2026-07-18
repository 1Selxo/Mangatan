import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:archive/archive.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/model/m_bridge.dart';
import 'package:mangayomi/models/custom_button.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/models/track.dart' as track;
import 'package:mangayomi/models/track_preference.dart';
import 'package:mangayomi/models/track_search.dart';
import 'package:mangayomi/modules/manga/detail/providers/track_state_providers.dart';
import 'package:mangayomi/modules/manga/reader/providers/crop_borders_provider.dart';
import 'package:mangayomi/modules/mining/widgets/dictionary_lookup_popup.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/storage_usage.dart';
import 'package:mangayomi/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:mangayomi/modules/more/settings/general/providers/general_state_provider.dart';
import 'package:mangayomi/modules/widgets/desktop_back_navigation_handler.dart';
import 'package:mangayomi/providers/l10n_providers.dart';
import 'package:mangayomi/providers/storage_provider.dart';
import 'package:mangayomi/router/router.dart';
import 'package:mangayomi/modules/more/settings/appearance/providers/animation_duration_scale_provider.dart';
import 'package:mangayomi/modules/more/settings/appearance/providers/theme_mode_state_provider.dart';
import 'package:mangayomi/l10n/generated/app_localizations.dart';
import 'package:mangayomi/services/http/m_client.dart';
import 'package:mangayomi/services/sync/chimahon_restore_sync_coordinator.dart';
import 'package:mangayomi/services/sync/google_drive_app_diagnostic.dart';
import 'package:mangayomi/services/sync/google_drive_chimahon_preview_runner.dart';
import 'package:mangayomi/services/sync/google_drive_platform_support.dart';
import 'package:mangayomi/services/isolate_service.dart';
import 'package:mangayomi/services/m_extension_server.dart';
import 'package:mangayomi/services/download_manager/m_downloader.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';
import 'package:mangayomi/src/rust/frb_generated.dart';
import 'package:mangayomi/utils/discord_rpc.dart';
import 'package:mangayomi/utils/log/logger.dart';
import 'package:mangayomi/utils/platform_utils.dart';
import 'package:mangayomi/utils/url_protocol/api.dart';
import 'package:mangayomi/modules/more/settings/appearance/providers/theme_provider.dart';
import 'package:mangayomi/modules/library/providers/file_scanner.dart';
import 'package:mangayomi/modules/more/settings/security/providers/security_state_provider.dart';
import 'package:mangayomi/modules/more/settings/security/app_lock_screen.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart' show rootBundle;
import 'package:mangayomi/utils/window_geometry.dart';

late Isar isar;
DiscordRPC? discordRpc;
WebViewEnvironment? webViewEnvironment;
String? customDns;

/// Captures a supported cold-start URI supplied directly to a desktop runner.
///
/// Linux depends on this because GTK's command-line signal can precede the
/// Dart app-links listener. Windows can also supply the initial URI in argv;
/// duplicate native delivery is harmless because [_MyAppState.lastUri]
/// de-duplicates it. The normal stream handles links sent to a running app.
@visibleForTesting
Uri? initialDesktopAppLinkFromArguments(
  List<String> arguments, {
  required TargetPlatform platform,
}) {
  if (!supportsGoogleDriveChimahonSync(platform)) return null;
  const supportedSchemes = {'mangayomi', 'app.chimahon.google.oauth'};
  for (final argument in arguments) {
    final uri = Uri.tryParse(argument);
    if (uri != null && supportedSchemes.contains(uri.scheme.toLowerCase())) {
      return uri;
    }
  }
  return null;
}

void main(List<String> args) async {
  // Zone-level catch-all for anything that slips through both layers
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      if (Platform.isLinux && runWebViewTitleBarWidget(args)) return;

      // Cap the decoded image cache so a large library grid can't fill the
      // default 100 MB ceiling with full-resolution covers and OOM constrained
      // mobile heaps. Mobile gets a tight 64 MB; desktop keeps 256 MB. The
      // encoded-bytes LRU in CustomExtendedNetworkImageProvider (50 MB) is a
      // separate cache and is not affected by this setting.
      PaintingBinding.instance.imageCache.maximumSizeBytes = isMobile
          ? 64 << 20
          : 256 << 20;

      // Widget-layer errors (build / layout / paint)
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details); // keep default red-screen in debug
        AppLogger.log(
          'FlutterError: ${details.exceptionAsString()}\n${details.stack}',
          logLevel: LogLevel.error,
        );
      };

      // Async errors that escape the Flutter framework (PlatformDispatcher)
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        AppLogger.log(
          'PlatformDispatcher error: $error\n$stack',
          logLevel: LogLevel.error,
        );
        return true; // handled — prevent app termination
      };

      MediaKit.ensureInitialized();
      await RustLib.init();
      await imgCropIsolate.start();
      await getIsolateService.start();
      if (!isMobile) {
        await windowManager.ensureInitialized();
        await WindowGeometry.restore();
      }
      if (Platform.isWindows || Platform.isLinux) {
        try {
          registerPersistentProtocolHandler("mangayomi");
        } catch (error, stackTrace) {
          // A protocol collision must not prevent Mangatan itself from opening.
          // The conflicting handler is deliberately left untouched.
          debugPrint('Could not register the mangayomi URL protocol: $error');
          AppLogger.log(
            'Could not register the desktop mangayomi URL protocol: '
            '$error\n$stackTrace',
            logLevel: LogLevel.warning,
          );
        }
      }
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        final availableVersion = await WebViewEnvironment.getAvailableVersion();
        if (availableVersion != null) {
          final document = await getApplicationDocumentsDirectory();
          webViewEnvironment = await WebViewEnvironment.create(
            settings: WebViewEnvironmentSettings(
              userDataFolder: p.join(document.path, 'flutter_inappwebview'),
            ),
          );
        }
      }
      final storage = StorageProvider();
      await storage.requestPermission();
      Object? startupError;
      try {
        isar = await storage.initDB(null, inspector: kDebugMode);
      } catch (e, st) {
        AppLogger.log('DB init failed: $e\n$st', logLevel: LogLevel.error);
        startupError = e;
      }
      runApp(
        startupError != null
            ? _StartupErrorApp(error: startupError.toString())
            : ProviderScope(
                child: MyApp(
                  initialAppLink: initialDesktopAppLinkFromArguments(
                    args,
                    platform: defaultTargetPlatform,
                  ),
                ),
                retry: (retryCount, error) => null,
              ),
      );
      if (startupError == null) unawaited(_postLaunchInit(storage));
    },
    (Object error, StackTrace stack) {
      AppLogger.log(
        'runZonedGuarded error: $error\n$stack',
        logLevel: LogLevel.error,
      );
    },
  );
}

class _StartupErrorApp extends StatelessWidget {
  final String error;
  const _StartupErrorApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Failed to start Mangatan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  error,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _postLaunchInit(StorageProvider storage) async {
  await AppLogger.init();
  unawaited(MDownloader.initializeIsolatePool(poolSize: 6));
  if (isApple || Platform.isAndroid) {
    await Hive.initFlutter(isApple ? "databases" : "");
    if (Platform.isMacOS) {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      MiningPreferences.configureStorageDirectory(
        p.join(documentsDirectory.path, 'databases'),
      );
    }
  } else {
    final databaseDirectory = await storage.getDatabaseDirectory();
    Hive.init(databaseDirectory!.path);
    MiningPreferences.configureStorageDirectory(databaseDirectory.path);
  }
  Hive.registerAdapter(TrackSearchAdapter());
  if (isDesktop && !kDebugMode) {
    discordRpc = DiscordRPC(applicationId: "1395040506677039157");
    await discordRpc?.initialize();
  }
  await storage.deleteBtDirectory();
  await webviewServer();
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key, this.initialAppLink});

  final Uri? initialAppLink;

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp>
    with
        WidgetsBindingObserver,
        WindowListener,
        SingleTickerProviderStateMixin {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  GoogleDriveDebugDiagnosticHandler? _googleDriveDiagnosticHandler;
  Uri? lastUri;
  late final AnimationController _disabledProgressController;

  @override
  void initState() {
    super.initState();
    _disabledProgressController = AnimationController(vsync: this, value: 0.5);
    WidgetsBinding.instance.addObserver(this);
    if (!isMobile) windowManager.addListener(this);
    initializeDateFormatting();
    customDns = ref.read(customDnsStateProvider);
    if (kDebugMode && supportsGoogleDriveChimahonSyncOnCurrentPlatform) {
      final previewRunner = GoogleDriveChimahonPreviewRunner.forDatabase(isar);
      _googleDriveDiagnosticHandler = GoogleDriveDebugDiagnosticHandler(
        syncPreview: (referenceBackupBytes) =>
            ChimahonRestoreSyncCoordinator.shared.duringReadOnlyPreview(
              () async => (await previewRunner.run(
                referenceBackupBytes: referenceBackupBytes,
              )).toSafeJson(),
            ),
      );
    }
    _checkTrackerRefresh();
    _initDeepLinks();
    _setupMpvConfig();
    unawaited(ref.read(scanLocalLibraryProvider.future));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      MExtensionServerPlatform(ref, persistent: true).startServer();
      if (ref.read(clearChapterCacheOnAppLaunchStateProvider)) {
        // Watch before calling clearcache to keep it alive, so that _getTotalDiskSpace completes safely
        ref.watch(totalChapterCacheSizeStateProvider);
        ref
            .read(totalChapterCacheSizeStateProvider.notifier)
            .clearCache(showToast: false);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (Platform.isLinux) {
        return;
      }
      // Lock the app when going to background (if lock is enabled)
      final lockEnabled = isar.settings.getSync(227)!.appLockEnabled ?? false;
      if (lockEnabled) {
        ref.read(appUnlockedStateProvider.notifier).lock();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final animationDurationScale = isMobile
        ? defaultAnimationDurationScale
        : ref.watch(animationDurationScaleProvider);
    if (!isMobile) {
      final dilation = animationTimeDilation(animationDurationScale);
      if (timeDilation != dilation) timeDilation = dilation;
    }

    final followSystem = ref.watch(followSystemThemeStateProvider);
    final forcedDark = ref.watch(themeModeStateProvider);
    final themeMode = followSystem
        ? ThemeMode.system
        : (forcedDark ? ThemeMode.dark : ThemeMode.light);
    final locale = ref.watch(l10nLocaleStateProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      theme: ref.watch(lightThemeProvider),
      darkTheme: ref.watch(darkThemeProvider),
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        final base = BotToastInit()(context, child);
        Widget content = !isMobile
            ? DesktopBackNavigationHandler(
                canGoBack: router.canPop,
                onBack: router.pop,
                dismissTransientUi: DictionaryLookupPopup.dismissActive,
                child: base,
              )
            : base;

        if (!Platform.isLinux) {
          final isUnlocked = ref.watch(appUnlockedStateProvider);
          final lockEnabled = ref.watch(appLockEnabledStateProvider);
          if (lockEnabled && !isUnlocked) {
            content = Stack(
              fit: StackFit.expand,
              children: [content, const AppLockScreen()],
            );
          }
        }

        if (!isMobile &&
            animationDurationScale == minimumAnimationDurationScale) {
          content = ProgressIndicatorTheme(
            data: Theme.of(context).progressIndicatorTheme.copyWith(
              controller: _disabledProgressController,
            ),
            child: content,
          );
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: content,
          );
        }

        return content;
      },
      routeInformationParser: router.routeInformationParser,
      routerDelegate: router.routerDelegate,
      routeInformationProvider: router.routeInformationProvider,
      title: 'Mangatan',
      scrollBehavior: AllowScrollBehavior(),
    );
  }

  @override
  void dispose() {
    if (!isMobile) timeDilation = defaultAnimationDurationScale;
    _disabledProgressController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    if (!isMobile) {
      windowManager.removeListener(this);
      WindowGeometry.save();
    }
    MExtensionServerPlatform(ref).stopServer();
    _linkSubscription?.cancel();
    _googleDriveDiagnosticHandler?.close();
    discordRpc?.destroy();
    stopwebviewServer();
    AppLogger.dispose();
    super.dispose();
  }

  @override
  void onWindowResized() => WindowGeometry.save();

  @override
  void onWindowMoved() => WindowGeometry.save();

  @override
  void onWindowClose() {
    WindowGeometry.save();
    // Workaround for libepoxy error when closing app; caused by media-kit
    if (Platform.isLinux) exit(0);
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();
    _linkSubscription = _appLinks.uriLinkStream.listen(_handleDeepLink);
    final initialAppLink = widget.initialAppLink;
    if (initialAppLink != null) {
      unawaited(_handleDeepLink(initialAppLink));
    }
  }

  Future<void> _handleDeepLink(Uri uri) async {
    if (uri == lastUri) return; // Debouncing Deep Links
    lastUri = uri;
    final googleDriveDiagnosticHandler = _googleDriveDiagnosticHandler;
    if (googleDriveDiagnosticHandler != null &&
        await googleDriveDiagnosticHandler.handle(uri)) {
      // AppLinks exposes a broadcast stream. Returning here only stops normal
      // app routing; it cannot consume the callback from an active OAuth
      // listener subscribed to the same URI event.
      return;
    }
    switch (uri.host) {
      case "add-repo":
        final repoName = uri.queryParameters["repo_name"];
        final repoUrl = uri.queryParameters["repo_url"];
        final mangaRepoUrls = uri.queryParametersAll["manga_url"];
        final animeRepoUrls = uri.queryParametersAll["anime_url"];
        final novelRepoUrls = uri.queryParametersAll["novel_url"];
        final context = navigatorKey.currentContext;
        if (context == null || !context.mounted) return;
        final l10n = context.l10n;
        showDialog(
          context: navigatorKey.currentContext!,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(l10n.add_repo),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${l10n.name}: ${repoName ?? 'Unknown'}"),
                  const SizedBox(height: 8),
                  Text("URL: ${repoUrl ?? 'Unknown'}"),
                ],
              ),
              actions: [
                TextButton(
                  child: Text(l10n.cancel),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                FilledButton(
                  child: Text(l10n.add),
                  onPressed: () async {
                    if (context.mounted) Navigator.of(context).pop();

                    final validUrls = await _checkValidUrls([
                      ...mangaRepoUrls ?? [],
                      ...animeRepoUrls ?? [],
                      ...novelRepoUrls ?? [],
                    ]);

                    if (!validUrls) {
                      botToast(l10n.unsupported_repo);
                      return;
                    }

                    void addRepos(ItemType type, List<String>? urls) {
                      if (urls == null) return;
                      final current = ref.read(
                        extensionsRepoStateProvider(type),
                      );
                      final updated = [
                        ...current,
                        ...urls.map(
                          (e) => Repo(
                            name: repoName,
                            jsonUrl: e,
                            website: repoUrl,
                          ),
                        ),
                      ];
                      ref
                          .read(extensionsRepoStateProvider(type).notifier)
                          .set(updated);
                    }

                    addRepos(ItemType.manga, mangaRepoUrls);
                    addRepos(ItemType.anime, animeRepoUrls);
                    addRepos(ItemType.novel, novelRepoUrls);
                    botToast(l10n.repo_added);
                  },
                ),
              ],
            );
          },
        );
        break;
      case "add-button":
        final buttonDataRaw = uri.queryParametersAll["button"];
        final context = navigatorKey.currentContext;
        if (context == null || !context.mounted || buttonDataRaw == null) {
          return;
        }
        final l10n = context.l10n;
        for (final buttonRaw in buttonDataRaw) {
          final buttonData = jsonDecode(utf8.decode(base64.decode(buttonRaw)));
          if (buttonData is Map<String, dynamic>) {
            final customButton = CustomButton.fromJson(buttonData);
            await showDialog(
              context: navigatorKey.currentContext!,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text(l10n.custom_buttons_add),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${l10n.name}: ${customButton.title ?? 'Unknown'}"),
                    ],
                  ),
                  actions: [
                    TextButton(
                      child: Text(l10n.cancel),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    FilledButton(
                      child: Text(l10n.add),
                      onPressed: () async {
                        if (context.mounted) Navigator.of(context).pop();
                        await isar.writeTxn(() async {
                          await isar.customButtons.put(
                            customButton
                              ..pos = await isar.customButtons.count()
                              ..isFavourite = false
                              ..id = null
                              ..updatedAt =
                                  DateTime.now().millisecondsSinceEpoch,
                          );
                        });
                        botToast(l10n.custom_buttons_added);
                      },
                    ),
                  ],
                );
              },
            );
          }
        }
        break;
      default:
    }
  }

  Future<bool> _checkValidUrls(List<String> urls) async {
    final http = MClient.init(reqcopyWith: {'useDartHttpClient': true});
    for (final url in urls) {
      final req = await http.get(Uri.parse(url));
      try {
        final sourceList = (jsonDecode(req.body) as List).map(
          (e) => Source.fromJson(e),
        );
        if (sourceList.firstOrNull?.name == null) {
          return false;
        }
      } catch (err) {
        return false;
      }
    }
    return true;
  }

  Future<void> _setupMpvConfig() async {
    final provider = StorageProvider();
    final dir = await provider.getMpvDirectory();
    final mpvFile = File('${dir!.path}/mpv.conf');
    final inputFile = File('${dir.path}/input.conf');
    final filesMissing =
        !(await mpvFile.exists()) && !(await inputFile.exists());
    if (filesMissing) {
      final bytes = await rootBundle.load("assets/mangayomi_mpv.zip");
      final archive = ZipDecoder().decodeBytes(bytes.buffer.asUint8List());
      String shadersDir = p.join(dir.path, 'shaders');
      await Directory(shadersDir).create(recursive: true);
      String scriptsDir = p.join(dir.path, 'scripts');
      await Directory(scriptsDir).create(recursive: true);
      for (final file in archive.files) {
        if (file.name == "mpv.conf") {
          await mpvFile.writeAsBytes(file.content);
        } else if (file.name == "input.conf") {
          await inputFile.writeAsBytes(file.content);
        } else if (file.name.startsWith("shaders/") &&
            file.name.endsWith(".glsl")) {
          final shaderFile = File('$shadersDir/${file.name.split("/").last}');
          await shaderFile.writeAsBytes(file.content);
        } else if (file.name.startsWith("scripts/") &&
            (file.name.endsWith(".js") || file.name.endsWith(".lua"))) {
          final scriptFile = File('$scriptsDir/${file.name.split("/").last}');
          await scriptFile.writeAsBytes(file.content);
        }
      }
    }
  }

  Future<void> _checkTrackerRefresh() async {
    final prefs = await isar.trackPreferences
        .filter()
        .syncIdIsNotNull()
        .findAll();
    for (final pref in prefs) {
      final temp = track.Track(
        syncId: pref.syncId,
        status: track.TrackStatus.completed,
      );
      ref
          .read(
            trackStateProvider(
              track: temp,
              itemType: null,
              widgetRef: ref,
            ).notifier,
          )
          .checkRefresh();
    }
  }
}

class AllowScrollBehavior extends MaterialScrollBehavior {
  // This allows the scrollable widgets to be scrolled with touch, mouse, stylus,
  // inverted stylus, trackpad, and unknown pointer devices.
  // This is useful for accessibility purposes, such as when using VoiceAccess,
  // which sends pointer events with unknown type when scrolling scrollables.
  // This is also useful for desktop platforms, where touch, stylus, and trackpad
  // interactions are common, and we want to ensure a consistent scrolling experience
  // across all devices.
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.unknown,
  };
}
