import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:m_extension_server/m_extension_server.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:mangayomi/utils/log/logger.dart';
import 'package:mangayomi/utils/platform_utils.dart';
import 'package:path/path.dart' as path;

class MExtensionServerPlatform {
  static const _unavailableBaseUrl = 'http://127.0.0.1:0';
  static const _launchAttempts = 3;
  static Future<void>? _pendingStart;
  static Process? _windowsProcess;
  static StreamSubscription<String>? _windowsStdout;
  static StreamSubscription<String>? _windowsStderr;
  static int _lifecycleGeneration = 0;
  static int? _preferredRestartPort;
  static Timer? _restartTimer;
  static final List<DateTime> _automaticRestartHistory = [];
  static String Function()? _stableReadBaseUrl;
  static void Function(String)? _stableWriteBaseUrl;

  late final String Function() _readBaseUrl;
  late final void Function(String) _writeBaseUrl;

  MExtensionServerPlatform(WidgetRef ref, {bool persistent = false}) {
    _readBaseUrl = () => ref.read(androidProxyServerStateProvider);
    _writeBaseUrl = (value) =>
        ref.read(androidProxyServerStateProvider.notifier).set(value);
    if (persistent) {
      _stableReadBaseUrl = _readBaseUrl;
      _stableWriteBaseUrl = _writeBaseUrl;
    }
  }

  MExtensionServerPlatform.fromRef(Ref ref) {
    _readBaseUrl = () => ref.read(androidProxyServerStateProvider);
    _writeBaseUrl = (value) =>
        ref.read(androidProxyServerStateProvider.notifier).set(value);
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

  Future<void> startServer({int? preferredPort}) {
    final pending = _pendingStart;
    if (pending != null) return pending;

    final generation = _lifecycleGeneration;
    final requestedPort = preferredPort ?? _preferredRestartPort;
    _preferredRestartPort = null;
    late final Future<void> operation;
    operation = _startServer(generation, requestedPort).whenComplete(() {
      if (identical(_pendingStart, operation)) {
        _pendingStart = null;
      }
    });
    _pendingStart = operation;
    return operation;
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

  Future<bool> _waitForMangatanMihonBridge(
    String baseUrl,
    int generation,
  ) async {
    // A portable JRE can be cold and antivirus/OneDrive scanning can delay the
    // first class load substantially on Windows.
    final deadline = Stopwatch()..start();
    while (deadline.elapsed < const Duration(seconds: 20)) {
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

Future<String> prepareMihonBridge(Ref ref, Source? source) async {
  final server = MExtensionServerPlatform.fromRef(ref);
  if (isDesktop && source?.sourceCodeLanguage == SourceCodeLanguage.mihon) {
    await server.startServer();
  }
  final baseUrl = server.baseUrl;
  if (isDesktop &&
      source?.sourceCodeLanguage == SourceCodeLanguage.mihon &&
      baseUrl == MExtensionServerPlatform._unavailableBaseUrl) {
    throw const MihonBridgeUnavailableException();
  }
  return baseUrl;
}

class MihonBridgeUnavailableException implements Exception {
  const MihonBridgeUnavailableException();

  @override
  String toString() =>
      'The Mihon bridge could not be started. Check the configured JRE and '
      'extension-server JAR, then try again.';
}
