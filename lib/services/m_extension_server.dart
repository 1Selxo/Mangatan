import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:m_extension_server/m_extension_server.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:mangayomi/utils/platform_utils.dart';

class MExtensionServerPlatform {
  WidgetRef ref;
  MExtensionServerPlatform(this.ref);

  Future<bool> check() async {
    return _checkHealth(_baseUrl);
  }

  Future<bool> _checkHealth(String baseUrl) async {
    if (baseUrl == "http://127.0.0.1:0") return false;
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

  Future<void> startServer() async {
    try {
      final currentBaseUrl = _baseUrl;
      var isRunning = await _checkHealth(currentBaseUrl);
      if (isDesktop &&
          isRunning &&
          _isLoopbackServer(currentBaseUrl) &&
          !await _supportsMangatanMihonBridge(currentBaseUrl)) {
        await _stopDesktopServer(currentBaseUrl);
        isRunning = false;
      }
      if (!isRunning) {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final port = server.port;
        await server.close();
        if (isDesktop) {
          final settings = isar.settings.getSync(227);
          final jrePath = settings?.jrePath;
          final serverJarPath = settings?.extensionServerPath;
          if ((jrePath?.isEmpty ?? true) || (serverJarPath?.isEmpty ?? true)) {
            return;
          }
          if (!await File(jrePath!).exists() ||
              !await File(serverJarPath!).exists()) {
            return;
          }
          await MExtensionServer().startServer(
            port,
            jvmPath: jrePath,
            serverJarPath: serverJarPath,
          );
        } else {
          await MExtensionServer().startServer(port);
        }
        final baseUrl = "http://127.0.0.1:$port";
        if (isDesktop && !await _waitForMangatanMihonBridge(baseUrl)) {
          await _stopDesktopServer(baseUrl);
          ref
              .read(androidProxyServerStateProvider.notifier)
              .set("http://127.0.0.1:0");
          return;
        }
        ref.read(androidProxyServerStateProvider.notifier).set(baseUrl);
      }
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  Future<void> stopServer() async {
    try {
      await MExtensionServer().stopServer();
    } catch (_) {}
  }

  String get _baseUrl => ref.watch(androidProxyServerStateProvider);

  bool _isLoopbackServer(String baseUrl) {
    final host = Uri.tryParse(baseUrl)?.host;
    return host == InternetAddress.loopbackIPv4.address || host == 'localhost';
  }

  Future<bool> _supportsMangatanMihonBridge(String baseUrl) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/capabilities'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) return false;
      final capabilities = jsonDecode(response.body) as Map<String, dynamic>;
      return (capabilities['mangatanMihonBridge'] as num?)?.toInt() == 1 &&
          capabilities['sourceFactory'] == true &&
          capabilities['preferenceCallbacks'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _waitForMangatanMihonBridge(String baseUrl) async {
    for (var attempt = 0; attempt < 40; attempt++) {
      if (await _supportsMangatanMihonBridge(baseUrl)) return true;
      await Future<void>.delayed(const Duration(milliseconds: 100));
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
    for (var attempt = 0; attempt < 20; attempt++) {
      if (!await _checkHealth(baseUrl)) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}
