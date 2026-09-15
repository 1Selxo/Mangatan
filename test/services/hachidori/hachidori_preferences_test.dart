import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mangayomi/services/hachidori/hachidori_preferences.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'hachidori-preferences-test-',
    );
    Hive.init(temporaryDirectory.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('persists and restores only the enabled flag and address', () async {
    final preferences = HachidoriPreferences();
    await preferences.write(
      const HachidoriLinkConfiguration(
        enabled: true,
        address: 'reader.test:8771',
      ),
    );
    await Hive.close();
    Hive.init(temporaryDirectory.path);

    expect(
      await preferences.read(),
      const HachidoriLinkConfiguration(
        enabled: true,
        address: 'reader.test:8771',
      ),
    );
    final box = await Hive.openBox<dynamic>(HachidoriPreferences.boxName);
    expect(box.keys.toSet(), {'enabled', 'address'});
  });

  test(
    'removes stale snapshot-like keys instead of persisting host state',
    () async {
      final box = await Hive.openBox<dynamic>(HachidoriPreferences.boxName);
      await box.put('snapshot', {
        'dictionaryState': {'revision': 99},
      });
      await box.put('host', {'name': 'must not persist'});

      await HachidoriPreferences().write(
        const HachidoriLinkConfiguration(
          enabled: false,
          address: 'ws://127.0.0.1:8771/link',
        ),
      );

      expect(box.keys.toSet(), {'enabled', 'address'});
      expect(box.get('enabled'), isFalse);
      expect(box.get('address'), 'ws://127.0.0.1:8771/link');
    },
  );
}
