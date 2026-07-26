import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String relativePath) =>
      File('${Directory.current.path}/$relativePath').readAsStringSync();

  test(
    'Windows runner forwards a second-instance link before Flutter starts',
    () {
      final runner = source('windows/runner/main.cpp');
      final forwarding = runner.indexOf('SendAppLinkToInstance()');
      final flutterStartup = runner.indexOf('flutter::DartProject project');

      expect(runner, contains('app_links/app_links_plugin_c_api.h'));
      expect(forwarding, greaterThanOrEqualTo(0));
      expect(flutterStartup, greaterThan(forwarding));
    },
  );

  test('persistent app scheme is separate from the temporary OAuth lease', () {
    final main = source('lib/main.dart');
    final oauth = source('lib/services/sync/google_drive_oauth.dart');

    expect(main, contains('registerPersistentProtocolHandler("mangayomi")'));
    expect(main, contains('A protocol collision must not prevent Mangatan'));
    expect(oauth, contains('_registerProtocol(expectedRedirectUri.scheme)'));
    expect(oauth, isNot(contains('registerPersistentProtocolHandler')));
  });

  test(
    'Windows generated build wiring includes link and secure-store plugins',
    () {
      final registrant = source(
        'windows/flutter/generated_plugin_registrant.cc',
      );
      final plugins = source('windows/flutter/generated_plugins.cmake');

      expect(registrant, contains('AppLinksPluginCApiRegisterWithRegistrar'));
      expect(
        registrant,
        contains('FlutterSecureStorageWindowsPluginRegisterWithRegistrar'),
      );
      expect(plugins, contains(RegExp(r'^  app_links$', multiLine: true)));
      expect(
        plugins,
        contains(
          RegExp(r'^  flutter_secure_storage_windows$', multiLine: true),
        ),
      );
    },
  );

  test('dependency floor matches the native single-instance API in use', () {
    final pubspec = source('pubspec.yaml');

    expect(pubspec, contains('app_links: ^7.2.0'));
    expect(pubspec, contains('flutter_secure_storage: ^10.3.1'));
  });

  test('Windows secure-storage resource identity is present and stable', () {
    final resources = source('windows/runner/Runner.rc');

    expect(resources, contains('BLOCK "040904e4"'));
    expect(resources, contains('VALUE "CompanyName", "kodjodevf"'));
    expect(resources, contains('VALUE "ProductName", "Mangatan"'));
  });

  test('Windows OAuth protocol registration is ownership-safe', () {
    final protocol = source('lib/utils/url_protocol/windows_protocol.dart');

    expect(protocol, contains('Mangatan will not overwrite it'));
    expect(protocol, contains('currentCommand == registration.command'));
    expect(protocol, contains('stillOwnsTemporaryRegistration'));
    expect(protocol, contains('ownsAbandonedTemporaryRegistration'));
    expect(protocol, contains('if (!registration.deleteOnRelease) return'));
    expect(protocol, contains('int depth = 1'));
  });
}
