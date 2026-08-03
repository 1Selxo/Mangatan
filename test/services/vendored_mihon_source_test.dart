import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('vendored Mihon source', () {
    test('keeps the server implementation inside Mangatan', () {
      final serverMain = File(
        'third_party/mihon_server/server/src/main/kotlin/'
        'mextensionserver/Main.kt',
      ).readAsStringSync();
      expect(serverMain, contains('bindHost = "127.0.0.1"'));
      expect(
        File('third_party/mihon_server/VENDORED.md').readAsStringSync(),
        allOf(contains('1Selxo/M-Extension-Server'), contains('68645ae')),
      );
      expect(
        File('third_party/newpipe_extractor/VENDORED.md').readAsStringSync(),
        allOf(contains('TeamNewPipe/NewPipeExtractor'), contains('caae86c')),
      );
      expect(
        File(
          'third_party/newpipe_extractor/extractor/src/main/java/'
          'org/schabi/newpipe/extractor/NewPipe.java',
        ).existsSync(),
        isTrue,
        reason: 'GPL corresponding production source must ship with Mangatan',
      );
    });

    test('builds and packages the server from the vendored tree', () {
      final unixBuilder = File(
        'scripts/build_vendored_mihon_server.sh',
      ).readAsStringSync();
      final windowsBuilder = File(
        'scripts/build_vendored_mihon_server.ps1',
      ).readAsStringSync();
      final iosPreparation = File(
        'tool/prepare_embedded_mihon_ios.sh',
      ).readAsStringSync();
      final releaseWorkflow = File(
        '.github/workflows/release.yml',
      ).readAsStringSync();

      expect(unixBuilder, contains('third_party/mihon_server'));
      expect(unixBuilder, contains(':server:shadowJar'));
      expect(unixBuilder, contains('jlink'));
      expect(unixBuilder, contains('NewPipe-Extractor-LICENSE.txt'));
      expect(windowsBuilder, contains('third_party\\mihon_server'));
      expect(windowsBuilder, contains(':server:shadowJar'));
      expect(windowsBuilder, contains('jlink'));
      expect(windowsBuilder, contains('NewPipe-Extractor-LICENSE.txt'));
      expect(
        iosPreparation,
        contains('scripts/build_vendored_mihon_server.sh'),
      );
      expect(iosPreparation, isNot(contains('server_jar_url=')));
      expect(
        releaseWorkflow,
        contains('Build bundled Mihon server'),
        reason: 'every desktop release must stage the JAR and portable JRE',
      );
    });
  });
}
