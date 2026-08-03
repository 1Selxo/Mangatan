import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangayomi/modules/more/settings/browse/extension_server/extension_server_utils.dart';
import 'package:mangayomi/services/extension_server_auto_installer.dart';
import 'package:path/path.dart' as path;

void main() {
  group('desktop extension server automatic installer', () {
    late Directory temp;
    const assetName = 'linux-x64-bundle.zip';
    final bundle = _bundleBytes();

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('mangatan-auto-server-');
    });

    tearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    test('installs and validates the matching release bundle', () async {
      final installer = ExtensionServerAutoInstaller(
        client: _releaseClient(assetName: assetName, bundle: bundle),
        assetName: assetName,
        makeExecutable: (_) async {},
      );
      final installDirectory = Directory(path.join(temp.path, 'server'));

      final installed = await installer.ensureInstalled(installDirectory);

      expect(await File(installed.jrePath).readAsString(), 'test-java');
      expect(await File(installed.jarPath).readAsString(), 'test-jar');
      expect(File('${installDirectory.path}.download').existsSync(), isFalse);
      expect(
        Directory('${installDirectory.path}.installing').existsSync(),
        isFalse,
      );
      expect(
        Directory('${installDirectory.path}.previous').existsSync(),
        isFalse,
      );
    });

    test(
      'an offline first launch remains eligible for the next launch',
      () async {
        var online = false;
        var releaseAttempts = 0;
        final client = MockClient((request) async {
          if (request.url.toString() == extensionServerReleaseApiUrl) {
            releaseAttempts++;
            if (!online) throw const SocketException('offline');
            return _releaseResponse(assetName: assetName, bundle: bundle);
          }
          return http.Response.bytes(bundle, 200);
        });
        final installer = ExtensionServerAutoInstaller(
          client: client,
          assetName: assetName,
          makeExecutable: (_) async {},
        );
        final installDirectory = Directory(path.join(temp.path, 'server'));

        await expectLater(
          installer.ensureInstalled(installDirectory),
          throwsA(isA<SocketException>()),
        );
        online = true;
        final installed = await installer.ensureInstalled(installDirectory);

        expect(releaseAttempts, 2);
        expect(File(installed.jarPath).existsSync(), isTrue);
      },
    );

    test(
      'cleans interrupted artifacts before an offline release lookup',
      () async {
        final installDirectory = Directory(path.join(temp.path, 'server'));
        await File('${installDirectory.path}.download').create(recursive: true);
        await Directory(
          '${installDirectory.path}.installing',
        ).create(recursive: true);
        final installer = ExtensionServerAutoInstaller(
          client: MockClient(
            (_) async => throw const SocketException('offline'),
          ),
          assetName: assetName,
          makeExecutable: (_) async {},
        );

        await expectLater(
          installer.ensureInstalled(installDirectory),
          throwsA(isA<SocketException>()),
        );

        expect(File('${installDirectory.path}.download').existsSync(), isFalse);
        expect(
          Directory('${installDirectory.path}.installing').existsSync(),
          isFalse,
        );
      },
    );

    test(
      'a digest failure is not promoted and can retry successfully',
      () async {
        var validDigest = false;
        final client = MockClient((request) async {
          if (request.url.toString() == extensionServerReleaseApiUrl) {
            return _releaseResponse(
              assetName: assetName,
              bundle: bundle,
              digestOverride: validDigest ? null : 'sha256:${'0' * 64}',
            );
          }
          return http.Response.bytes(bundle, 200);
        });
        final installer = ExtensionServerAutoInstaller(
          client: client,
          assetName: assetName,
          makeExecutable: (_) async {},
        );
        final installDirectory = Directory(path.join(temp.path, 'server'));

        await expectLater(
          installer.ensureInstalled(installDirectory),
          throwsA(isA<FormatException>()),
        );
        expect(installDirectory.existsSync(), isFalse);
        validDigest = true;

        final installed = await installer.ensureInstalled(installDirectory);
        expect(File(installed.jarPath).existsSync(), isTrue);
      },
    );

    test('rejects archive paths that escape the install directory', () async {
      final unsafeBundle = _unsafeBundleBytes();
      final installer = ExtensionServerAutoInstaller(
        client: _releaseClient(assetName: assetName, bundle: unsafeBundle),
        assetName: assetName,
        makeExecutable: (_) async {},
      );
      final installDirectory = Directory(path.join(temp.path, 'server'));

      await expectLater(
        installer.ensureInstalled(installDirectory),
        throwsA(isA<FormatException>()),
      );

      expect(File(path.join(temp.path, 'escaped.txt')).existsSync(), isFalse);
      expect(installDirectory.existsSync(), isFalse);
    });

    test('rejects bundles whose extracted size exceeds the limit', () async {
      final installer = ExtensionServerAutoInstaller(
        client: _releaseClient(assetName: assetName, bundle: bundle),
        assetName: assetName,
        makeExecutable: (_) async {},
        maximumExtractedBytes: 1,
      );
      final installDirectory = Directory(path.join(temp.path, 'server'));

      await expectLater(
        installer.ensureInstalled(installDirectory),
        throwsA(isA<FormatException>()),
      );
      expect(installDirectory.existsSync(), isFalse);
    });

    test('bounds actual decompressed bytes, not forged ZIP metadata', () async {
      final forgedBundle = _forgedSizeBundleBytes();
      final installer = ExtensionServerAutoInstaller(
        client: _releaseClient(assetName: assetName, bundle: forgedBundle),
        assetName: assetName,
        makeExecutable: (_) async {},
        maximumExtractedBytes: 100,
      );
      final installDirectory = Directory(path.join(temp.path, 'server'));

      await expectLater(
        installer.ensureInstalled(installDirectory),
        throwsA(isA<FormatException>()),
      );
      expect(installDirectory.existsSync(), isFalse);
    });

    test(
      'rejects a forged central-directory entry count before decoding',
      () async {
        final forgedBundle = _bundleBytes().toList();
        _forgeEndOfCentralDirectoryEntryCount(forgedBundle, 1);
        final installer = ExtensionServerAutoInstaller(
          client: _releaseClient(assetName: assetName, bundle: forgedBundle),
          assetName: assetName,
          makeExecutable: (_) async {},
        );
        final installDirectory = Directory(path.join(temp.path, 'server'));

        await expectLater(
          installer.ensureInstalled(installDirectory),
          throwsA(isA<FormatException>()),
        );
        expect(installDirectory.existsSync(), isFalse);
      },
    );

    test(
      'recovers the prior install after an interrupted atomic swap',
      () async {
        final installDirectory = Directory(path.join(temp.path, 'server'));
        final previous = Directory('${installDirectory.path}.previous');
        await _writeInstall(previous);
        await Directory(
          '${installDirectory.path}.installing',
        ).create(recursive: true);
        final installer = ExtensionServerAutoInstaller(
          client: MockClient(
            (_) async => throw StateError('must not download'),
          ),
          assetName: assetName,
          makeExecutable: (_) async {},
        );

        final installed = await installer.ensureInstalled(installDirectory);

        expect(File(installed.jarPath).existsSync(), isTrue);
        expect(previous.existsSync(), isFalse);
        expect(
          Directory('${installDirectory.path}.installing').existsSync(),
          isFalse,
        );
      },
    );

    test(
      'keeps an existing configured server ahead of discovery and download',
      () async {
        final configured = Directory(path.join(temp.path, 'configured'));
        await _writeInstall(configured);
        var discoveryCalls = 0;
        var installCalls = 0;

        final resolved = await resolveDesktopExtensionServerPaths(
          configuredJrePath: path.join(
            configured.path,
            'jre',
            'jre',
            'bin',
            'java',
          ),
          configuredJarPath: path.join(
            configured.path,
            'MExtensionServer-v1.jar',
          ),
          findSystemInstall: () async {
            discoveryCalls++;
            return null;
          },
          autoInstall: () async {
            installCalls++;
            throw StateError('must not install');
          },
        );

        expect(resolved.jarPath, endsWith('MExtensionServer-v1.jar'));
        expect(discoveryCalls, 0);
        expect(installCalls, 0);
      },
    );

    test(
      'uses automatic installation after package discovery misses',
      () async {
        var installCalls = 0;
        final expected = SystemExtensionServerPaths(
          jrePath: path.join(temp.path, 'java'),
          jarPath: path.join(temp.path, 'server.jar'),
        );

        final resolved = await resolveDesktopExtensionServerPaths(
          configuredJrePath: '',
          configuredJarPath: '',
          findSystemInstall: () async => null,
          autoInstall: () async {
            installCalls++;
            return expected;
          },
        );

        expect(resolved.jarPath, expected.jarPath);
        expect(installCalls, 1);
      },
    );
  });
}

MockClient _releaseClient({
  required String assetName,
  required List<int> bundle,
}) {
  return MockClient((request) async {
    if (request.url.toString() == extensionServerReleaseApiUrl) {
      return _releaseResponse(assetName: assetName, bundle: bundle);
    }
    return http.Response.bytes(bundle, 200);
  });
}

http.Response _releaseResponse({
  required String assetName,
  required List<int> bundle,
  String? digestOverride,
}) {
  return http.Response(
    jsonEncode([
      {
        'draft': false,
        'prerelease': false,
        'assets': [
          {
            'name': assetName,
            'size': bundle.length,
            'digest': digestOverride ?? 'sha256:${sha256.convert(bundle)}',
            'browser_download_url':
                'https://github.com/1Selxo/M-Extension-Server/releases/download/v1/$assetName',
          },
        ],
      },
    ]),
    200,
  );
}

List<int> _bundleBytes() {
  final archive = Archive()
    ..addFile(ArchiveFile.string('MExtensionServer-v1.jar', 'test-jar'))
    ..addFile(ArchiveFile.string('jre/jre/bin/java', 'test-java'));
  return ZipEncoder().encode(archive);
}

List<int> _unsafeBundleBytes() {
  final archive = Archive()
    ..addFile(ArchiveFile.string('../escaped.txt', 'escape'))
    ..addFile(ArchiveFile.string('MExtensionServer-v1.jar', 'test-jar'))
    ..addFile(ArchiveFile.string('jre/jre/bin/java', 'test-java'));
  return ZipEncoder().encode(archive);
}

void _forgeEndOfCentralDirectoryEntryCount(
  List<int> bytes,
  int declaredEntries,
) {
  for (var index = bytes.length - 22; index >= 0; index--) {
    if (bytes[index] == 0x50 &&
        bytes[index + 1] == 0x4b &&
        bytes[index + 2] == 0x05 &&
        bytes[index + 3] == 0x06) {
      bytes[index + 8] = declaredEntries & 0xff;
      bytes[index + 9] = (declaredEntries >> 8) & 0xff;
      bytes[index + 10] = declaredEntries & 0xff;
      bytes[index + 11] = (declaredEntries >> 8) & 0xff;
      return;
    }
  }
  throw StateError('ZIP end-of-central-directory record not found');
}

List<int> _forgedSizeBundleBytes() {
  final large = List<int>.filled(1024 * 1024, 65);
  final archive = Archive()
    ..addFile(ArchiveFile('MExtensionServer-v1.jar', large.length, large))
    ..addFile(ArchiveFile('jre/jre/bin/java', large.length, large));
  final bytes = ZipEncoder().encode(archive).toList();
  _forgeCentralDirectorySize(bytes, 'MExtensionServer-v1.jar', 1);
  _forgeCentralDirectorySize(bytes, 'jre/jre/bin/java', 1);
  return bytes;
}

void _forgeCentralDirectorySize(
  List<int> bytes,
  String fileName,
  int declaredSize,
) {
  final nameBytes = utf8.encode(fileName);
  for (var index = 0; index + 46 + nameBytes.length <= bytes.length; index++) {
    if (bytes[index] != 0x50 ||
        bytes[index + 1] != 0x4b ||
        bytes[index + 2] != 0x01 ||
        bytes[index + 3] != 0x02) {
      continue;
    }
    final nameLength = bytes[index + 28] | (bytes[index + 29] << 8);
    if (nameLength != nameBytes.length) continue;
    var matches = true;
    for (var offset = 0; offset < nameLength; offset++) {
      if (bytes[index + 46 + offset] != nameBytes[offset]) {
        matches = false;
        break;
      }
    }
    if (!matches) continue;
    for (var byte = 0; byte < 4; byte++) {
      bytes[index + 24 + byte] = (declaredSize >> (byte * 8)) & 0xff;
    }
    return;
  }
  throw StateError('ZIP central directory entry not found: $fileName');
}

Future<void> _writeInstall(Directory root) async {
  final java = File(path.join(root.path, 'jre', 'jre', 'bin', 'java'));
  await java.create(recursive: true);
  await java.writeAsString('test-java');
  final jar = File(path.join(root.path, 'MExtensionServer-v1.jar'));
  await jar.create(recursive: true);
  await jar.writeAsString('test-jar');
}
