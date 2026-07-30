import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/settings/browse/extension_server/extension_server_utils.dart';
import 'package:mangayomi/services/m_extension_server.dart';
import 'package:path/path.dart' as path;

/// Builds the layout a distro package installs: the JAR at the root plus a
/// `java` symlink at `jre/jre/bin/java`, the only place the app looks first.
Future<Directory> _writeManagedInstall(
  Directory parent, {
  String jarName = 'MExtensionServer-v1.0.6.0.jar',
  bool withJava = true,
  bool withJar = true,
}) async {
  final root = Directory(path.join(parent.path, 'extension_server'));
  await root.create(recursive: true);
  if (withJar) {
    await File(path.join(root.path, jarName)).writeAsString('jar');
  }
  if (withJava) {
    final bin = Directory(path.join(root.path, 'jre', 'jre', 'bin'));
    await bin.create(recursive: true);
    // Mirror the package exactly: a symlink to a system JRE, not a real file.
    // File.exists() follows links, so the preferred-path probe finds it; the
    // recursive fallback uses followLinks: false and would not.
    final target = File(path.join(parent.path, 'system-java'));
    await target.writeAsString('#!/bin/sh\n');
    await Link(path.join(bin.path, 'java')).create(target.path);
  }
  return root;
}

void main() {
  group('package-managed extension server discovery', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('managed-server-');
    });

    tearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    test('resolves a JAR and a symlinked java from a packaged layout', () async {
      final root = await _writeManagedInstall(temp);

      final resolved = await findSystemExtensionServer(
        directories: [root.path],
      );

      expect(resolved, isNotNull);
      expect(
        resolved!.jrePath,
        path.join(root.path, 'jre', 'jre', 'bin', 'java'),
        reason: 'the packaged java lives at the preferred path, as a symlink',
      );
      expect(
        resolved.jarPath,
        path.join(root.path, 'MExtensionServer-v1.0.6.0.jar'),
      );
    }, skip: !Platform.isLinux);

    test('reports the packaged version rather than the fallback', () async {
      final root = await _writeManagedInstall(temp);
      final resolved = await findSystemExtensionServer(
        directories: [root.path],
      );

      expect(
        resolveInstalledExtensionServerVersion(resolved!.jarPath),
        '1.0.6.0',
        reason: 'a basename without a parseable version offers a bogus update',
      );
    }, skip: !Platform.isLinux);

    test('skips a partially removed package instead of half-adopting it', () async {
      final noJar = await _writeManagedInstall(
        temp,
        withJar: false,
      );
      expect(
        await findSystemExtensionServer(directories: [noJar.path]),
        isNull,
      );

      final other = await Directory.systemTemp.createTemp('managed-nojre-');
      addTearDown(() async {
        if (await other.exists()) await other.delete(recursive: true);
      });
      final noJava = await _writeManagedInstall(other, withJava: false);
      expect(
        await findSystemExtensionServer(directories: [noJava.path]),
        isNull,
      );
    }, skip: !Platform.isLinux);

    test('falls through to a later candidate directory', () async {
      final root = await _writeManagedInstall(temp);

      final resolved = await findSystemExtensionServer(
        directories: [path.join(temp.path, 'absent'), root.path],
      );

      expect(resolved, isNotNull);
      expect(resolved!.jarPath, contains('MExtensionServer-'));
    }, skip: !Platform.isLinux);

    test('returns null when nothing is installed', () async {
      expect(
        await findSystemExtensionServer(
          directories: [path.join(temp.path, 'absent')],
        ),
        isNull,
      );
    }, skip: !Platform.isLinux);
  });

  group('managed directory guard', () {
    test('recognises the documented system locations', () {
      for (final directory in extensionServerSystemDirectories) {
        expect(isManagedExtensionServerDirectory(directory), isTrue);
        expect(
          isManagedExtensionServerDirectory('$directory/'),
          isTrue,
          reason: 'a trailing separator must not defeat the wipe guard',
        );
        expect(
          isManagedExtensionServerDirectory('$directory/../extension_server'),
          isTrue,
          reason: 'the path is normalized before comparison',
        );
      }
    });

    test('leaves user-chosen directories writable', () {
      expect(isManagedExtensionServerDirectory(''), isFalse);
      expect(
        isManagedExtensionServerDirectory('/home/user/Mangatan/extension_server'),
        isFalse,
      );
      expect(
        isManagedExtensionServerDirectory('/usr/share/mangatan'),
        isFalse,
        reason: 'only the server directory itself is package-owned',
      );
    });

    test('the installer refuses to wipe a package-managed directory', () {
      final screenSource = File(
        'lib/modules/more/settings/browse/extension_server_screen.dart',
      ).readAsStringSync().replaceAll('\r\n', '\n');

      expect(
        screenSource,
        contains('_resolveDownloadDirectory(l10n)'),
        reason: 'the download path must redirect away from /usr',
      );
      expect(
        screenSource,
        contains(
          'Future<void> _prepareInstallDirectory(Directory installDir) async {\n'
          '    // Last line of defence for the recursive delete below: callers are expected\n'
          '    // to have gone through _resolveDownloadDirectory already.\n'
          '    if (isManagedExtensionServerDirectory(installDir.path)) {',
        ),
        reason: 'delete(recursive: true) must be unreachable for /usr paths',
      );
    });
  });

  group('JRE version pre-flight', () {
    test('parses the runtime the Arch package depends on', () {
      // Verbatim from `java -version` under Arch jre21-openjdk 21.0.12.u8-1.
      expect(
        parseJreMajorVersion(
          'openjdk version "21.0.12" 2026-07-21\n'
          'OpenJDK Runtime Environment (build 21.0.12+8)\n'
          'OpenJDK 64-Bit Server VM (build 21.0.12+8, mixed mode, sharing)',
        ),
        21,
      );
    });

    test('parses a too-old runtime so the launch can be refused', () {
      expect(
        parseJreMajorVersion(
          'openjdk version "17.0.19" 2026-07-15\n'
          'OpenJDK Runtime Environment Temurin-17.0.19+7 (build 17.0.19+7)',
        ),
        17,
      );
      // The legacy scheme puts the feature version second: 1.8 means Java 8.
      expect(
        parseJreMajorVersion('java version "1.8.0_452"'),
        8,
      );
    });

    test('returns null on unparseable output so a probe never blocks', () {
      expect(parseJreMajorVersion(''), isNull);
      expect(parseJreMajorVersion('command not found'), isNull);
    });

    test('the service refuses to launch an unsupported runtime', () {
      final serviceSource = File(
        'lib/services/m_extension_server.dart',
      ).readAsStringSync().replaceAll('\r\n', '\n');

      expect(
        serviceSource,
        contains('static const _minimumJreMajorVersion = 21;'),
        reason: 'the server JAR entry point is Java 21 bytecode',
      );
      expect(
        serviceSource,
        contains('final incompatibility = await _describeJreIncompatibility('),
        reason:
            'the plugin discards the JVM stderr, so the mismatch must be '
            'detected before launching rather than surfacing as a timeout',
      );
      expect(
        serviceSource,
        contains('final system = await findSystemExtensionServer();'),
        reason: 'an unconfigured desktop must adopt a distro install',
      );
      expect(
        serviceSource,
        contains('_persistResolvedServerPaths(jrePath, serverJarPath);'),
        reason: 'the Settings screen must reflect the adopted paths',
      );
    });
  });

  group('Arch packaging contract', () {
    String read(String relativePath) =>
        File(relativePath).readAsStringSync().replaceAll('\r\n', '\n');

    test('the app package pulls in the startup dependency', () {
      final template = read('packaging/arch/PKGBUILD.template');

      expect(
        template,
        contains("'xdg-user-dirs'"),
        reason:
            'path_provider_linux shells out to the xdg-user-dir binary for the '
            'documents directory, and throws when it is absent — which also '
            'breaks the database directory, not just the extension server',
      );
      expect(
        template,
        contains('mangatan-extension-server: '),
        reason: 'the bridge must be discoverable but stay optional',
      );
    });

    test('the server package installs the layout the app probes', () {
      final template = read('packaging/arch/PKGBUILD-extension-server.template');

      expect(
        template,
        contains(r'_jar="MExtensionServer-v${pkgver}.jar"'),
        reason:
            'detection requires the MExtensionServer- prefix, a .jar suffix, '
            'and a parseable version in the basename',
      );
      expect(
        template,
        contains(r'"${pkgdir}/${_serverdir}/jre/jre/bin/java"'),
        reason: 'findExtensionServerJavaExecutable only probes this path first',
      );
      expect(
        template,
        contains("depends=('jre21-openjdk')"),
        reason:
            'java-runtime>=21 can be satisfied by a newer JVM installed at a '
            'different prefix, which would dangle the symlink above',
      );
      expect(
        template,
        contains(r'noextract=("${_bundle}")'),
        reason: 'the vendored JRE in the bundle must never reach the package',
      );
    });
  });
}
