/// Quiet stand-ins for the native plugins the screens call on desktop.
///
/// A journey runs without a platform side, so every plugin call would fail.
/// These reply the way an idle desktop would (not full screen, wakelock
/// toggled, nothing to report) so the screens get past them. Anything the
/// tests need to observe is recorded in [platformCalls].
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every plugin call made during the current test, as `channel.method`.
final platformCalls = <String>[];

/// Where path_provider points the app (documents, support, cache,
/// downloads): the journey's temporary directory.
String? platformDirectory;

const _pathMethods = {
  'getTemporaryDirectory': 'temp',
  'getApplicationSupportDirectory': 'support',
  'getLibraryDirectory': 'library',
  'getApplicationDocumentsDirectory': 'documents',
  'getApplicationCacheDirectory': 'cache',
  'getDownloadsDirectory': 'downloads',
  'getStorageDirectory': 'storage',
};

/// Window state a test can set before the app reads it.
var windowIsFullScreen = false;

const _methodDefaults = <String, Object?>{
  'isFullScreen': false,
  'isMaximized': false,
  'isMinimized': false,
  'isVisible': true,
  'isFocused': true,
  'isAlwaysOnTop': false,
  'isPreventClose': false,
  'isResizable': true,
  'getBounds': {'x': 0.0, 'y': 0.0, 'width': 1280.0, 'height': 800.0},
  'getSize': {'width': 1280.0, 'height': 800.0},
  'getPosition': {'x': 0.0, 'y': 0.0},
  'getOpacity': 1.0,
  'getTitle': 'Mangatan',
  'getTitleBarHeight': 32,
  'getDevicePixelRatio': 1.0,
};

const _methodChannels = [
  'window_manager',
  'screen_retriever',
  'plugins.flutter.io/path_provider',
  'plugins.flutter.io/url_launcher',
  'plugins.flutter.io/shared_preferences',
  'flutter_keyboard_visibility',
  'dev.fluttercommunity.plus/device_info',
  'dev.fluttercommunity.plus/package_info',
  'dev.fluttercommunity.plus/connectivity',
  'dev.fluttercommunity.plus/share',
  'com.kodjodevf.mangayomi.device',
  'com.kodjodevf.mangayomi.volume_keys',
  'com.kodjodevf.mangayomi.apk_install',
  'com.selxo.mangatan.ankimobile',
  'mangayomi/remote_webview_interceptor',
  'plugins.it_nomads.com/flutter_secure_storage',
  'plugins.flutter.io/local_auth',
  'flutter.baseflow.com/permissions/methods',
  'screen_brightness',
  'xyz.luan/audioplayers',
  'flutter_local_notifications',
  'com.alexmercerind/media_kit_video',
  'com.alexmercerind/media_kit_libs_windows_video',
];

/// Pigeon-generated channels answer a list: `[result]` is success.
const _pigeonChannels = [
  'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
  'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.isEnabled',
  'dev.flutter.pigeon.path_provider_foundation.PathProviderApi.getDirectoryPath',
  'dev.flutter.pigeon.url_launcher_windows.UrlLauncherApi.launchUrl',
  'dev.flutter.pigeon.url_launcher_windows.UrlLauncherApi.canLaunchUrl',
];

void stubPlatformPlugins() {
  platformCalls.clear();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final name in _methodChannels) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
      platformCalls.add('$name.${call.method}');
      if (call.method == 'isFullScreen') return windowIsFullScreen;
      final folder = _pathMethods[call.method];
      if (folder != null && platformDirectory != null) {
        final dir = Directory(
          '$platformDirectory${Platform.pathSeparator}$folder',
        )..createSync(recursive: true);
        return dir.path;
      }
      if (call.method.startsWith('getExternal')) return <String>[];
      return _methodDefaults[call.method];
    });
  }
  const codec = StandardMessageCodec();
  for (final name in _pigeonChannels) {
    messenger.setMockMessageHandler(name, (message) async {
      platformCalls.add(name.split('.').last);
      return codec.encodeMessage(<Object?>[
        name.endsWith('isEnabled') ? false : null,
      ]);
    });
  }
}
