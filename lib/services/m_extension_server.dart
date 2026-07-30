import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:m_extension_server/m_extension_server.dart';
import 'package:mangayomi/eval/mihon/image_proxy.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:mangayomi/utils/log/logger.dart';
import 'package:mangayomi/utils/platform_utils.dart';
import 'package:path/path.dart' as path;

@visibleForTesting
String? embeddedMihonBaseUrlFromResponse(Map<Object?, Object?>? response) {
  final port = (response?['port'] as num?)?.toInt();
  final returnedBaseUrl = response?['baseUrl'] as String?;
  final baseUrl =
      returnedBaseUrl ?? (port == null ? null : 'http://127.0.0.1:$port');
  final uri = baseUrl == null ? null : Uri.tryParse(baseUrl);
  if (port == null ||
      port <= 0 ||
      port > 65535 ||
      uri == null ||
      uri.scheme != 'http' ||
      uri.port != port ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.host != InternetAddress.loopbackIPv4.address &&
          uri.host != InternetAddress.loopbackIPv6.address &&
          uri.host != 'localhost')) {
    return null;
  }
  return 'http://127.0.0.1:$port';
}

class MExtensionServerPlatform {
  static const _unavailableBaseUrl = 'http://127.0.0.1:0';
  static const _embeddedIosChannel = MethodChannel(
    'com.selxo.mangatan.embedded_mihon',
  );
  static const _launchAttempts = 3;
  static const _embeddedIosLaunchAttempts = 2;
  static Future<void>? _pendingStart;
  static Future<void> _iosLifecycleTransition = Future<void>.value();
  static Process? _windowsProcess;
  static StreamSubscription<String>? _windowsStdout;
  static StreamSubscription<String>? _windowsStderr;
  static int _lifecycleGeneration = 0;
  static bool _iosAppIsForeground = true;
  static bool _iosBridgeWasRequested = false;
  static bool _iosBridgeIsReady = false;
  static bool _iosRestartOnResume = false;
  static int? _iosResumePort;
  static int? _preferredRestartPort;
  static Timer? _restartTimer;
  static final List<DateTime> _automaticRestartHistory = [];
  static String Function()? _stableReadBaseUrl;
  static void Function(String)? _stableWriteBaseUrl;
  static MExtensionServerPlatform? _stableInstance;

  late final String Function() _readBaseUrl;
  late final void Function(String) _writeBaseUrl;
  late final void Function(String) _writeRuntimeBaseUrl;
  late final void Function() _restoreSavedBaseUrl;

  MExtensionServerPlatform(WidgetRef ref, {bool persistent = false}) {
    final proxyServerState = ref.read(androidProxyServerStateProvider.notifier);
    _readBaseUrl = () => proxyServerState.currentValue;
    _writeBaseUrl = proxyServerState.set;
    _writeRuntimeBaseUrl = proxyServerState.setRuntime;
    _restoreSavedBaseUrl = proxyServerState.restoreSaved;
    if (persistent) {
      _stableReadBaseUrl = _readBaseUrl;
      _stableWriteBaseUrl = _writeBaseUrl;
      _stableInstance = this;
    }
  }

  MExtensionServerPlatform.fromRef(Ref ref) {
    final proxyServerState = ref.read(androidProxyServerStateProvider.notifier);
    _readBaseUrl = () => proxyServerState.currentValue;
    _writeBaseUrl = proxyServerState.set;
    _writeRuntimeBaseUrl = proxyServerState.setRuntime;
    _restoreSavedBaseUrl = proxyServerState.restoreSaved;
  }

  Future<bool> check() async {
    return _checkHealth(_baseUrl);
  }

  String get baseUrl => _baseUrl;

  Future<bool> _checkHealth(String baseUrl) async {
    if (baseUrl == _unavailableBaseUrl) return false;
    try {
      final res = await http
          .get(Uri.parse("$baseUrl/"))
          .timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> startServer({
    int? preferredPort,
    bool foregroundRequest = false,
  }) {
    if (Platform.isIOS) {
      _iosBridgeWasRequested = true;
      final lifecycleState = WidgetsBinding.instance.lifecycleState;
      if (foregroundRequest ||
          lifecycleState == AppLifecycleState.resumed ||
          lifecycleState == null) {
        // Lifecycle notifications and image retries can race during route
        // restoration. Trust Flutter's current state instead of a stale
        // notification cached before the route became visible.
        _iosAppIsForeground = true;
      } else {
        _iosAppIsForeground = false;
      }
      if (!_iosAppIsForeground) {
        _iosRestartOnResume = true;
        return Future<void>.value();
      }
    }

    final pending = _pendingStart;
    if (pending != null) return pending;

    final generation = _lifecycleGeneration;
    final requestedPort = preferredPort ?? _preferredRestartPort;
    _preferredRestartPort = null;
    late final Future<void> operation;
    final startOperation = Platform.isIOS
        ? _startEmbeddedIosBridge(generation, requestedPort)
        : _startServer(generation, requestedPort);
    operation = startOperation.whenComplete(() {
      if (identical(_pendingStart, operation)) {
        _pendingStart = null;
      }
    });
    _pendingStart = operation;
    return operation;
  }

  Future<void> _startEmbeddedIosBridge(
    int generation,
    int? preferredPort,
  ) async {
    var restartPort = preferredPort;
    try {
      final runningBaseUrl = _baseUrl;
      if (_isLoopbackServer(runningBaseUrl) &&
          await _supportsMangatanMihonBridge(runningBaseUrl)) {
        _iosBridgeIsReady = true;
        return;
      }
      _iosBridgeIsReady = false;

      final runningUri = Uri.tryParse(runningBaseUrl);
      if (_isLoopbackServer(runningBaseUrl) &&
          runningUri != null &&
          runningUri.port > 0) {
        restartPort ??= runningUri.port;
      }

      // iOS can leave the Java listener thread alive but its socket unusable
      // after device sleep. Native status alone therefore is insufficient:
      // when HTTP health failed, stop the stale listener before restarting it.
      if (await _isEmbeddedIosBridgeRunning()) {
        await _pauseEmbeddedIosBridge();
      }

      for (var attempt = 1; attempt <= _embeddedIosLaunchAttempts; attempt++) {
        try {
          final response = await _embeddedIosChannel
              .invokeMapMethod<String, Object?>('start', <String, Object?>{
                'port': attempt == 1 ? restartPort ?? 0 : 0,
              });
          if (_isCancelled(generation)) {
            await _pauseEmbeddedIosBridge();
            return;
          }

          final baseUrl = embeddedMihonBaseUrlFromResponse(response);
          if (baseUrl != null &&
              await _waitForMangatanMihonBridge(
                baseUrl,
                generation,
                deadline: const Duration(seconds: 8),
              )) {
            _writeRuntimeBaseUrl(baseUrl);
            _iosBridgeIsReady = true;
            _log('Embedded iPhone Mihon bridge is ready at $baseUrl.');
            return;
          }
          throw StateError('The embedded iOS bridge did not become ready.');
        } catch (error, stackTrace) {
          _log(
            'Embedded iPhone Mihon bridge launch failed on attempt $attempt '
            'of $_embeddedIosLaunchAttempts: $error\n$stackTrace',
            level: LogLevel.warning,
          );
          await _pauseEmbeddedIosBridge();
          if (_isCancelled(generation)) return;
        }
      }

      throw StateError(
        'The embedded iOS bridge did not become ready after '
        '$_embeddedIosLaunchAttempts attempts.',
      );
    } catch (error, stackTrace) {
      _iosBridgeIsReady = false;
      _restoreSavedBaseUrl();
      if (_isLoopbackServer(_baseUrl)) {
        // A saved desktop loopback URL points back at the iPhone on iOS and
        // can never reach the user's computer. Do not hide an embedded-runtime
        // failure behind a misleading connection-refused error for that URL.
        _writeRuntimeBaseUrl(_unavailableBaseUrl);
      }
      _log(
        'Embedded iPhone Mihon bridge startup failed; a usable saved external '
        'bridge will be used when available: $error\n$stackTrace',
        level: LogLevel.error,
      );
    }
  }

  Future<bool> _isEmbeddedIosBridgeRunning() async {
    try {
      return await _embeddedIosChannel
              .invokeMethod<bool>('status')
              .timeout(const Duration(seconds: 2)) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> suspendEmbeddedIosBridge() {
    if (!Platform.isIOS) return Future<void>.value();
    _iosAppIsForeground = false;
    _iosBridgeIsReady = false;
    if (!_iosBridgeWasRequested) return Future<void>.value();
    _iosRestartOnResume = true;

    return _queueIosLifecycleTransition(() async {
      final currentUri = Uri.tryParse(_baseUrl);
      if (_isLoopbackServer(_baseUrl) &&
          currentUri != null &&
          currentUri.port > 0) {
        _iosResumePort = currentUri.port;
      }
      _lifecycleGeneration++;
      _preferredRestartPort = null;
      _restartTimer?.cancel();
      _restartTimer = null;
      final pending = _pendingStart;
      if (pending != null) {
        try {
          await pending;
        } catch (_) {}
      }
      await _pauseEmbeddedIosBridge();
      _restoreSavedBaseUrl();
      _log('Embedded iPhone Mihon bridge paused for app suspension.');
    });
  }

  Future<void> resumeEmbeddedIosBridge() {
    if (!Platform.isIOS) return Future<void>.value();
    _iosAppIsForeground = true;
    if (!_iosRestartOnResume) return Future<void>.value();

    return _queueIosLifecycleTransition(() async {
      if (!_iosAppIsForeground || !_iosRestartOnResume) return;
      final resumePort = _iosResumePort;
      _iosResumePort = null;
      await startServer(preferredPort: resumePort);
      final restarted =
          _isLoopbackServer(_baseUrl) &&
          await _supportsMangatanMihonBridge(_baseUrl);
      _iosBridgeIsReady = restarted;
      if (_iosAppIsForeground && restarted) {
        _iosRestartOnResume = false;
      } else {
        _iosRestartOnResume = true;
      }
    });
  }

  Future<void> _queueIosLifecycleTransition(
    Future<void> Function() transition,
  ) {
    final queued = _iosLifecycleTransition.then((_) => transition()).catchError(
      (Object error, StackTrace stackTrace) {
        _log(
          'Embedded iPhone Mihon bridge lifecycle transition failed: '
          '$error\n$stackTrace',
          level: LogLevel.error,
        );
      },
    );
    _iosLifecycleTransition = queued;
    return queued;
  }

  Future<void> _startServer(int generation, int? preferredPort) async {
    try {
      final currentBaseUrl = _baseUrl;
      var isRunning = await _checkHealth(currentBaseUrl);
      if (_isCancelled(generation)) return;
      if (isDesktop &&
          isRunning &&
          _isLoopbackServer(currentBaseUrl) &&
          !await _supportsMangatanMihonBridge(currentBaseUrl)) {
        await _stopDesktopServer(currentBaseUrl);
        isRunning = false;
      }
      if (_isCancelled(generation)) return;
      if (isRunning) return;

      _setBaseUrl(_unavailableBaseUrl);
      final settings = isar.settings.getSync(227);
      final jrePath = settings?.jrePath ?? '';
      final serverJarPath = settings?.extensionServerPath ?? '';
      if (isDesktop &&
          (!await _isFile(jrePath) || !await _isFile(serverJarPath))) {
        _log(
          'Mihon bridge was not started because the configured JRE or JAR '
          'does not exist. JRE: "$jrePath", JAR: "$serverJarPath".',
          level: LogLevel.error,
        );
        return;
      }

      for (var attempt = 1; attempt <= _launchAttempts; attempt++) {
        if (_isCancelled(generation)) return;
        final port = attempt == 1 && preferredPort != null
            ? preferredPort
            : await _allocatePort();
        final baseUrl = 'http://127.0.0.1:$port';
        try {
          await _launchServer(port, jrePath, serverJarPath);
          final isReady =
              !isDesktop ||
              await _waitForMangatanMihonBridge(baseUrl, generation);
          if (_isCancelled(generation)) {
            await _stopDesktopServer(baseUrl);
            return;
          }
          if (isReady) {
            _setBaseUrl(baseUrl);
            _log('Mihon bridge is ready at $baseUrl.');
            return;
          }
          _log(
            'Mihon bridge did not become ready at $baseUrl '
            '(attempt $attempt of $_launchAttempts).',
            level: LogLevel.warning,
          );
        } catch (error, stackTrace) {
          _log(
            'Mihon bridge launch failed on attempt $attempt of '
            '$_launchAttempts: $error\n$stackTrace',
            level: LogLevel.error,
          );
        }
        await _stopDesktopServer(baseUrl);
        if (_isCancelled(generation)) return;
      }

      _setBaseUrl(_unavailableBaseUrl);
    } catch (error, stackTrace) {
      _setBaseUrl(_unavailableBaseUrl);
      _log(
        'Mihon bridge startup failed: $error\n$stackTrace',
        level: LogLevel.error,
      );
    }
  }

  Future<void> stopServer() async {
    _lifecycleGeneration++;
    _preferredRestartPort = null;
    _restartTimer?.cancel();
    _restartTimer = null;
    final pending = _pendingStart;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {}
    }
    if (Platform.isIOS) {
      await _stopEmbeddedIosBridge();
      _restoreSavedBaseUrl();
      return;
    }
    final baseUrl = _baseUrl;
    if (isDesktop &&
        baseUrl != _unavailableBaseUrl &&
        _isLoopbackServer(baseUrl)) {
      try {
        await http
            .get(Uri.parse('$baseUrl/stop'))
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
    try {
      if (Platform.isWindows) {
        await _stopWindowsProcess();
      }
      await MExtensionServer().stopServer();
    } catch (_) {}
    _setBaseUrl(_unavailableBaseUrl);
  }

  Future<void> _stopEmbeddedIosBridge() async {
    try {
      await _embeddedIosChannel.invokeMethod<void>('stop');
    } catch (error, stackTrace) {
      _log(
        'Embedded iPhone Mihon bridge stop failed: $error\n$stackTrace',
        level: LogLevel.warning,
      );
    }
  }

  Future<void> _pauseEmbeddedIosBridge() async {
    try {
      await _embeddedIosChannel.invokeMethod<void>('pause');
    } catch (error, stackTrace) {
      _log(
        'Embedded iPhone Mihon bridge pause failed: $error\n$stackTrace',
        level: LogLevel.warning,
      );
    }
  }

  bool _isCancelled(int generation) => generation != _lifecycleGeneration;

  String get _baseUrl {
    for (final read in [_stableReadBaseUrl, _readBaseUrl]) {
      try {
        final value = read?.call();
        if (value != null) return value;
      } catch (_) {}
    }
    return isar.settings.getSync(227)?.androidProxyServer ??
        _unavailableBaseUrl;
  }

  void _setBaseUrl(String value) {
    if (_baseUrl == value) return;
    for (final write in [_stableWriteBaseUrl, _writeBaseUrl]) {
      try {
        write?.call(value);
        return;
      } catch (_) {}
    }
    final settings = isar.settings.getSync(227);
    if (settings == null) return;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings
          ..androidProxyServer = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<bool> _isFile(String filePath) async {
    return filePath.isNotEmpty && await File(filePath).exists();
  }

  Future<int> _allocatePort() async {
    final socket = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close(force: true);
    return port;
  }

  Future<void> _launchServer(
    int port,
    String jrePath,
    String serverJarPath,
  ) async {
    if (Platform.isWindows) {
      await _startWindowsProcess(port, jrePath, serverJarPath);
    } else if (isDesktop) {
      await MExtensionServer().startServer(
        port,
        jvmPath: jrePath,
        serverJarPath: serverJarPath,
      );
    } else {
      await MExtensionServer().startServer(port);
    }
  }

  Future<void> _startWindowsProcess(
    int port,
    String jrePath,
    String serverJarPath,
  ) async {
    await _stopWindowsProcess();

    // The upstream plugin currently launches through CreateProcessA. That
    // corrupts non-ASCII paths (for example, a localized OneDrive Documents
    // folder). Dart's Process API uses Windows' Unicode process APIs.
    final process = await Process.start(
      jrePath,
      ['-jar', serverJarPath, '$port'],
      workingDirectory: path.dirname(serverJarPath),
      runInShell: false,
    );
    _windowsProcess = process;
    _windowsStdout = process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((line) => _log('[Mihon bridge stdout] $line'));
    _windowsStderr = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen(
          (line) =>
              _log('[Mihon bridge stderr] $line', level: LogLevel.warning),
        );
    unawaited(
      process.exitCode.then((exitCode) {
        if (identical(_windowsProcess, process)) {
          _windowsProcess = null;
          _log(
            'Mihon bridge process exited with code $exitCode.',
            level: exitCode == 0 ? LogLevel.info : LogLevel.error,
          );
          try {
            if (_baseUrl == 'http://127.0.0.1:$port') {
              _setBaseUrl(_unavailableBaseUrl);
            }
          } catch (_) {
            return;
          }
          final now = DateTime.now();
          _automaticRestartHistory.removeWhere(
            (restart) => now.difference(restart) > const Duration(minutes: 1),
          );
          if (_pendingStart == null && _automaticRestartHistory.length < 2) {
            _automaticRestartHistory.add(now);
            _preferredRestartPort = port;
            _restartTimer?.cancel();
            _restartTimer = Timer(const Duration(milliseconds: 500), () {
              _restartTimer = null;
              unawaited(startServer());
            });
          }
        }
      }),
    );
  }

  Future<void> _stopWindowsProcess() async {
    final process = _windowsProcess;
    _windowsProcess = null;
    if (process != null) {
      process.kill();
      try {
        await process.exitCode.timeout(const Duration(seconds: 3));
      } on TimeoutException {
        process.kill(ProcessSignal.sigkill);
      }
    }
    await _windowsStdout?.cancel();
    await _windowsStderr?.cancel();
    _windowsStdout = null;
    _windowsStderr = null;
  }

  bool _isLoopbackServer(String baseUrl) {
    final host = Uri.tryParse(baseUrl)?.host;
    return host == InternetAddress.loopbackIPv4.address ||
        host == InternetAddress.loopbackIPv6.address ||
        host == 'localhost';
  }

  Future<bool> _supportsMangatanMihonBridge(
    String baseUrl, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/capabilities'))
          .timeout(timeout);
      if (response.statusCode != 200) return false;
      final capabilities = jsonDecode(response.body) as Map<String, dynamic>;
      return (capabilities['mangatanMihonBridge'] as num?)?.toInt() == 1 &&
          capabilities['sourceFactory'] == true &&
          capabilities['preferenceCallbacks'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _supportsYouTubeResolver(
    String baseUrl, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/capabilities'))
          .timeout(timeout);
      if (response.statusCode != 200) return false;
      final capabilities = jsonDecode(response.body) as Map<String, dynamic>;
      return capabilities['youtubeResolver'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _waitForMangatanMihonBridge(
    String baseUrl,
    int generation, {
    Duration deadline = const Duration(seconds: 20),
  }) async {
    // A portable JRE can be cold and antivirus/OneDrive scanning can delay the
    // first class load substantially on Windows.
    final elapsed = Stopwatch()..start();
    while (elapsed.elapsed < deadline) {
      if (_isCancelled(generation)) return false;
      if (await _supportsMangatanMihonBridge(
        baseUrl,
        timeout: const Duration(milliseconds: 500),
      )) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return false;
  }

  Future<void> _stopDesktopServer(String baseUrl) async {
    try {
      await http
          .get(Uri.parse('$baseUrl/stop'))
          .timeout(const Duration(seconds: 2));
    } catch (_) {}
    try {
      await MExtensionServer().stopServer();
    } catch (_) {}
    if (Platform.isWindows) {
      await _stopWindowsProcess();
    }
    for (var attempt = 0; attempt < 20; attempt++) {
      if (!await _checkHealth(baseUrl)) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  void _log(String message, {LogLevel level = LogLevel.info}) {
    AppLogger.log(message, logLevel: level);
    if (kDebugMode) debugPrint(message);
  }
}

Future<String?> prepareYouTubeResolverBridge() async {
  if (!isDesktop && !Platform.isIOS) return null;
  final server = MExtensionServerPlatform._stableInstance;
  if (server == null) return null;

  await server.startServer(foregroundRequest: Platform.isIOS);
  final baseUrl = server.baseUrl;
  if (baseUrl == MExtensionServerPlatform._unavailableBaseUrl ||
      !server._isLoopbackServer(baseUrl) ||
      !await server._supportsYouTubeResolver(baseUrl)) {
    return null;
  }
  return baseUrl;
}

/// Restarts the embedded listener before a reader retries a transient Mihon
/// image URL. Image tokens live in the retained JVM, so only the loopback
/// origin needs to be updated if iOS could not reclaim the previous port.
Future<String> prepareActiveIosMihonProxyUrl(String url) async {
  if (!Platform.isIOS || !isTransientMihonImageUrl(url)) return url;

  // Wake the bridge before the first restored reader request. Concurrent
  // pages await the same pending launch; later healthy requests take this
  // synchronous fast path and avoid per-image capability probes.
  if (MExtensionServerPlatform._iosBridgeIsReady &&
      !MExtensionServerPlatform._iosRestartOnResume &&
      MExtensionServerPlatform._pendingStart == null) {
    return url;
  }
  return resolveActiveIosMihonProxyUrl(url);
}

Future<String> resolveActiveIosMihonProxyUrl(String url) async {
  if (!Platform.isIOS || !isTransientMihonImageUrl(url)) return url;

  final server = MExtensionServerPlatform._stableInstance;
  final proxyUri = Uri.tryParse(url);
  if (server == null || proxyUri == null) return url;

  await server.startServer(
    preferredPort: proxyUri.hasPort && proxyUri.port > 0 ? proxyUri.port : null,
    foregroundRequest: true,
  );
  final baseUrl = server.baseUrl;
  if (baseUrl == MExtensionServerPlatform._unavailableBaseUrl ||
      !server._isLoopbackServer(baseUrl) ||
      !await server._supportsMangatanMihonBridge(baseUrl)) {
    return url;
  }
  return resolveMihonImageUrl(baseUrl, url);
}

Future<String> prepareMihonBridge(Ref ref, Source? source) async {
  final server = MExtensionServerPlatform.fromRef(ref);
  if ((isDesktop || Platform.isIOS) &&
      source?.sourceCodeLanguage == SourceCodeLanguage.mihon) {
    await server.startServer();
  }
  final baseUrl = server.baseUrl;
  final requiresMihonBridge =
      (isDesktop || Platform.isIOS) &&
      source?.sourceCodeLanguage == SourceCodeLanguage.mihon;
  final unusableIosLoopback =
      Platform.isIOS &&
      server._isLoopbackServer(baseUrl) &&
      !await server._supportsMangatanMihonBridge(baseUrl);
  if (requiresMihonBridge &&
      (baseUrl == MExtensionServerPlatform._unavailableBaseUrl ||
          unusableIosLoopback)) {
    throw const MihonBridgeUnavailableException();
  }
  return baseUrl;
}

class MihonBridgeUnavailableException implements Exception {
  const MihonBridgeUnavailableException();

  @override
  String toString() => Platform.isIOS
      ? 'The on-device Mihon bridge could not be restarted. Return to the app '
            'foreground and try the source again.'
      : 'The Mihon bridge could not be started. Check the configured JRE and '
            'extension-server JAR, then try again.';
}
