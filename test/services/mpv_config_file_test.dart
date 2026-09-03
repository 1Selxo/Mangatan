import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/mpv_config_file.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mangatan_mpv_editor_');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('reads and writes both supported MPV configuration files', () async {
    for (final fileName in MpvConfigFile.allowedFileNames) {
      final config = MpvConfigFile(directory: directory, fileName: fileName);
      expect(await config.read(), isEmpty);
      await config.write('profile=gpu-hq\n');
      expect(await config.read(), 'profile=gpu-hq\n');
    }
  });

  test('rejects paths and unsupported MPV files', () {
    for (final fileName in ['../mpv.conf', 'scripts/test.lua', 'other.conf']) {
      expect(
        () => MpvConfigFile(directory: directory, fileName: fileName),
        throwsArgumentError,
      );
    }
  });
}
