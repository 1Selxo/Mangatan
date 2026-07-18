import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String relativePath) =>
      File('${Directory.current.path}/$relativePath').readAsStringSync();

  test('Linux runner supports cold and running-instance command lines', () {
    final runner = source('linux/my_application.cc');

    expect(runner, contains('G_APPLICATION_HANDLES_COMMAND_LINE'));
    expect(runner, contains('fl_dart_project_set_dart_entrypoint_arguments'));
    expect(runner, contains('self->dart_entrypoint_arguments'));
  });

  test('Linux desktop entry advertises both app-link callbacks', () {
    final desktopEntry = source('linux/mangayomi.desktop');

    expect(desktopEntry, contains('Exec=/usr/bin/mangayomi %u'));
    expect(
      desktopEntry,
      contains(
        'MimeType=x-scheme-handler/mangayomi;'
        'x-scheme-handler/app.chimahon.google.oauth;',
      ),
    );
    expect(
      desktopEntry,
      contains(
        'X-Mangatan-Protocol-Owner='
        'com.kodjodevf.mangayomi/persistent/v1',
      ),
    );
    expect(
      desktopEntry,
      contains(
        'X-Mangatan-Protocol-Schemes='
        'mangayomi;app.chimahon.google.oauth;',
      ),
    );
  });

  test(
    'Linux package metadata preserves callbacks and native dependencies',
    () {
      final deb = source('linux/packaging/deb/make_config.yaml');
      final appImage = source('linux/packaging/appimage/make_config.yaml');

      expect(deb, contains(RegExp(r'^dependencies:$', multiLine: true)));
      expect(deb, isNot(contains('depencencies:')));
      expect(deb, contains(RegExp(r'^  - libsecret-1-0$', multiLine: true)));
      expect(deb, contains(RegExp(r'^  - xdg-utils$', multiLine: true)));
      for (final config in [deb, appImage]) {
        expect(
          config,
          contains(RegExp(r'^supported_mime_type:$', multiLine: true)),
        );
        expect(
          config,
          contains(
            RegExp(r'^  - x-scheme-handler/mangayomi$', multiLine: true),
          ),
        );
        expect(
          config,
          contains(
            RegExp(
              r'^  - x-scheme-handler/app\.chimahon\.google\.oauth$',
              multiLine: true,
            ),
          ),
        );
      }
    },
  );

  test('tracked AppImage launcher forwards every URI argument', () {
    final appRun = source('linux/packaging/appimage/AppRun');
    final packagingScript = source('scripts/package_linux_appimage.sh');

    expect(appRun, contains(r'exec "$app_dir/usr/bin/mangayomi" "$@"'));
    expect(packagingScript, contains('linux/packaging/appimage/AppRun'));
    expect(packagingScript, contains(r'ARCH="$appimage_arch"'));
    expect(packagingScript, contains('[--arch x86_64]'));
    expect(packagingScript, isNot(contains('x86_64 | aarch64')));
    expect(packagingScript, isNot(contains('flutter build')));
    expect(packagingScript, isNot(contains('curl ')));
    expect(packagingScript, isNot(contains('wget ')));
  });

  test('Linux build wires secure storage and GTK app links', () {
    final registrant = source('linux/flutter/generated_plugin_registrant.cc');
    final plugins = source('linux/flutter/generated_plugins.cmake');

    expect(
      registrant,
      contains('flutter_secure_storage_linux_plugin_register_with_registrar'),
    );
    expect(
      plugins,
      contains(RegExp(r'^  flutter_secure_storage_linux$', multiLine: true)),
    );
    expect(registrant, contains('gtk_plugin_register_with_registrar'));
    expect(plugins, contains(RegExp(r'^  gtk$', multiLine: true)));
  });

  test(
    'UI and app diagnostic use the shared desktop availability boundary',
    () {
      final main = source('lib/main.dart');
      final syncScreen = source('lib/modules/more/settings/sync/sync.dart');

      expect(
        main,
        contains('supportsGoogleDriveChimahonSyncOnCurrentPlatform'),
      );
      expect(main, contains('Platform.isWindows || Platform.isLinux'));
      expect(main, contains('registerPersistentProtocolHandler("mangayomi")'));
      expect(main, contains('initialDesktopAppLinkFromArguments'));
      expect(
        syncScreen,
        contains('supportsGoogleDriveChimahonSyncOnCurrentPlatform'),
      );
      expect(syncScreen, contains('Available on macOS, Windows, and Linux.'));
    },
  );
}
