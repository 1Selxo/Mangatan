import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/utils/url_protocol/linux_protocol.dart';
import 'package:path/path.dart' as p;

void main() {
  const oauthScheme = 'app.chimahon.google.oauth';

  test('builds a shell-free desktop Exec command with one URL field code', () {
    final command = LinuxProtocolHandler.buildExecCommand(
      r'/tmp/Mangatan App;$(touch)%',
      const [r'--flag=`value`', '%s'],
    );

    expect(
      command,
      r'"/tmp/Mangatan App;\\$(touch)%%" "--flag=\\`value\\`" %u',
    );
    expect(
      () => LinuxProtocolHandler.buildExecCommand('/opt/mangayomi', const [
        '--callback=%s',
      ]),
      throwsArgumentError,
    );
    expect(
      () => LinuxProtocolHandler.buildExecCommand('/opt/mangayomi', const [
        '%s',
        '%s',
      ]),
      throwsArgumentError,
    );
  });

  test('installs and activates an exact per-user scheme with argv only', () {
    final fixture = _LinuxProtocolFixture();
    addTearDown(fixture.dispose);
    final handler = fixture.handler();

    handler.register(oauthScheme);

    final desktop = fixture.desktopFile(oauthScheme);
    expect(desktop.existsSync(), isTrue);
    final content = desktop.readAsStringSync();
    expect(
      content,
      contains('MimeType=x-scheme-handler/app.chimahon.google.oauth;'),
    );
    expect(content, contains('Exec="/tmp/.mount_mangatan/mangayomi" %u'));
    expect(
      LinuxProtocolHandler.isOwnedDesktopEntry(content, scheme: oauthScheme),
      isTrue,
    );
    expect(
      fixture.commands.any(
        (command) =>
            command.$1 == 'xdg-mime' &&
            command.$2.join('|') ==
                [
                  'default',
                  LinuxProtocolHandler.desktopIdForScheme(oauthScheme),
                  LinuxProtocolHandler.mimeTypeForScheme(oauthScheme),
                ].join('|'),
      ),
      isTrue,
    );
    expect(fixture.commands.any((command) => command.$1 == 'sh'), isFalse);

    handler.unregister(oauthScheme);
    expect(desktop.existsSync(), isTrue, reason: 'cold-start handler remains');
  });

  test('refuses an unrelated current default without changing it', () {
    final fixture = _LinuxProtocolFixture(defaultDesktopId: 'other.desktop');
    addTearDown(fixture.dispose);
    fixture.writeDesktop(
      'other.desktop',
      '[Desktop Entry]\nType=Application\nName=Other\nExec=other %u\n',
    );

    expect(() => fixture.handler().register(oauthScheme), throwsStateError);
    expect(fixture.defaultDesktopId, 'other.desktop');
    expect(fixture.desktopFile(oauthScheme).existsSync(), isFalse);
    expect(
      fixture.commands.where(
        (command) => command.$1 == 'xdg-mime' && command.$2.first == 'default',
      ),
      isEmpty,
    );
  });

  test('accepts only the narrow package-managed Mangatan desktop shape', () {
    final fixture = _LinuxProtocolFixture(
      defaultDesktopId: 'mangayomi.desktop',
    );
    addTearDown(fixture.dispose);
    final packaged = '''[Desktop Entry]
Type=Application
Name=Mangatan
Exec=/usr/bin/mangayomi %U
MimeType=x-scheme-handler/mangayomi;x-scheme-handler/app.chimahon.google.oauth;
''';
    fixture.writeDesktop('mangayomi.desktop', packaged);

    fixture.handler().register(oauthScheme);

    expect(
      LinuxProtocolHandler.isOwnedPackagedDesktopEntry(
        desktopId: 'mangayomi.desktop',
        content: packaged,
        scheme: oauthScheme,
      ),
      isTrue,
    );
    expect(fixture.desktopFile(oauthScheme).existsSync(), isFalse);
    expect(
      LinuxProtocolHandler.isOwnedPackagedDesktopEntry(
        desktopId: 'other.desktop',
        content: packaged,
        scheme: oauthScheme,
      ),
      isFalse,
    );

    final appImagePackaged = packaged.replaceFirst(
      'Exec=/usr/bin/mangayomi %U',
      'Exec=LD_LIBRARY_PATH=usr/lib mangayomi %u',
    );
    expect(
      LinuxProtocolHandler.isOwnedPackagedDesktopEntry(
        desktopId: 'mangayomi.desktop',
        content: appImagePackaged,
        scheme: oauthScheme,
      ),
      isTrue,
    );
    expect(
      LinuxProtocolHandler.isOwnedPackagedDesktopEntry(
        desktopId: 'mangayomi.desktop',
        content: packaged.replaceFirst(
          'Exec=/usr/bin/mangayomi %U',
          'Exec=LD_PRELOAD=/tmp/other.so mangayomi %u',
        ),
        scheme: oauthScheme,
      ),
      isFalse,
    );
  });

  test('does not follow a symlink at its owned desktop-entry path', () {
    final fixture = _LinuxProtocolFixture();
    addTearDown(fixture.dispose);
    final outside = File(p.join(fixture.root.path, 'outside.desktop'))
      ..writeAsStringSync('do not replace');
    fixture.applications.createSync(recursive: true);
    Link(fixture.desktopFile(oauthScheme).path).createSync(outside.path);

    expect(() => fixture.handler().register(oauthScheme), throwsStateError);
    expect(outside.readAsStringSync(), 'do not replace');
  });

  test('re-checks ownership before xdg-mime default activation', () {
    late final _LinuxProtocolFixture fixture;
    fixture = _LinuxProtocolFixture(
      afterDesktopRefresh: () {
        fixture.defaultDesktopId = 'racing.desktop';
        fixture.writeDesktop(
          'racing.desktop',
          '[Desktop Entry]\nType=Application\nName=Racer\nExec=racer %u\n',
        );
      },
    );
    addTearDown(fixture.dispose);

    expect(() => fixture.handler().register(oauthScheme), throwsStateError);
    expect(fixture.defaultDesktopId, 'racing.desktop');
    expect(
      fixture.commands.where(
        (command) => command.$1 == 'xdg-mime' && command.$2.first == 'default',
      ),
      isEmpty,
    );
  });

  test('nested leases require balanced releases before command changes', () {
    final fixture = _LinuxProtocolFixture();
    addTearDown(fixture.dispose);
    final handler = fixture.handler();

    handler.register(oauthScheme);
    handler.register(oauthScheme);
    handler.unregister(oauthScheme);
    expect(
      () => handler.register(oauthScheme, executable: '/opt/other/mangayomi'),
      throwsStateError,
    );

    handler.unregister(oauthScheme);
    handler.register(oauthScheme, executable: '/opt/other/mangayomi');
    expect(
      fixture.desktopFile(oauthScheme).readAsStringSync(),
      contains('Exec="/opt/other/mangayomi" %u'),
    );
  });

  test(
    'prefers a validated stable APPIMAGE path over the mount executable',
    () {
      final fixture = _LinuxProtocolFixture();
      addTearDown(fixture.dispose);
      final appImage = File(
        p.join(fixture.root.path, 'Mangatan Reader.AppImage'),
      )..writeAsStringSync('fixture');
      final chmod = Process.runSync('/bin/chmod', ['700', appImage.path]);
      expect(chmod.exitCode, 0);

      fixture.handler(appImage: appImage.path).register(oauthScheme);

      final content = fixture.desktopFile(oauthScheme).readAsStringSync();
      expect(content, contains('Exec="${appImage.path}" %u'));
      expect(content, isNot(contains('/tmp/.mount_mangatan/mangayomi')));
    },
  );

  test('diagnostic Linux launcher passes the link as argv without a shell', () {
    final source = File(
      p.join(Directory.current.path, 'tool', 'chimahon_drive_diagnostic.dart'),
    ).readAsStringSync();

    expect(source, contains('Platform.isLinux'));
    expect(source, contains("'xdg-open'"));
    expect(source, contains('runInShell: false'));
    expect(source, contains('Process.start('));
    expect(source, contains('ProcessStartMode.detached'));
    expect(source, contains('link.toString()'));
  });
}

class _LinuxProtocolFixture {
  _LinuxProtocolFixture({this.defaultDesktopId, this.afterDesktopRefresh})
    : root = Directory.systemTemp.createTempSync('mangatan-linux-protocol-') {
    applications.createSync(recursive: true);
  }

  final Directory root;
  final void Function()? afterDesktopRefresh;
  final commands = <(String, List<String>)>[];
  String? defaultDesktopId;

  Directory get dataHome => Directory(p.join(root.path, 'data'));
  Directory get applications =>
      Directory(p.join(dataHome.path, 'applications'));

  LinuxProtocolHandler handler({String? appImage}) => LinuxProtocolHandler(
    enabled: true,
    environment: {
      'XDG_DATA_HOME': dataHome.path,
      'HOME': root.path,
      'APPIMAGE': ?appImage,
    },
    resolvedExecutable: '/tmp/.mount_mangatan/mangayomi',
    processRunner: _run,
  );

  File desktopFile(String scheme) => File(
    p.join(applications.path, LinuxProtocolHandler.desktopIdForScheme(scheme)),
  );

  void writeDesktop(String id, String content) {
    applications.createSync(recursive: true);
    File(p.join(applications.path, id)).writeAsStringSync(content);
  }

  ProcessResult _run(String executable, List<String> arguments) {
    commands.add((executable, List<String>.of(arguments)));
    if (executable == 'update-desktop-database') {
      afterDesktopRefresh?.call();
      return ProcessResult(1, 0, '', '');
    }
    expect(executable, 'xdg-mime');
    if (arguments case ['query', 'default', _]) {
      return ProcessResult(1, 0, defaultDesktopId ?? '', '');
    }
    if (arguments case ['default', final desktopId, _]) {
      defaultDesktopId = desktopId;
      return ProcessResult(1, 0, '', '');
    }
    return ProcessResult(1, 1, '', 'unexpected command');
  }

  void dispose() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}
