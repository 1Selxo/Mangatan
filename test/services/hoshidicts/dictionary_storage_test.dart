import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/hoshidicts/dictionary_storage.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'finds existing Hoshidicts imports in the flat output directory',
    () async {
      final root = await Directory.systemTemp.createTemp('dictionary-storage-');
      addTearDown(() => root.delete(recursive: true));
      final dictionary = Directory(p.join(root.path, 'JMdict [test]'));
      await dictionary.create();
      await File(p.join(dictionary.path, 'index.json')).writeAsString('{}');

      final paths = await DictionaryStorage.instance.paths(root: root);
      final installed = await DictionaryStorage.instance.installed(root: root);

      expect(paths.termPaths, [dictionary.path]);
      expect(paths.frequencyPaths, isEmpty);
      expect(installed.single.name, 'JMdict [test]');
      expect(installed.single.hasTerms, isTrue);
    },
  );

  test('uses persisted import capabilities for flat dictionaries', () async {
    final root = await Directory.systemTemp.createTemp('dictionary-storage-');
    addTearDown(() => root.delete(recursive: true));
    final dictionary = Directory(p.join(root.path, 'Frequency'));
    await dictionary.create();
    await File(p.join(dictionary.path, 'index.json')).writeAsString('{}');
    await File(p.join(root.path, '.mangayomi-dictionaries.json')).writeAsString(
      '{"Frequency":{"terms":false,"frequencies":true,"pitch":false}}',
    );

    final paths = await DictionaryStorage.instance.paths(root: root);

    expect(paths.termPaths, isEmpty);
    expect(paths.frequencyPaths, [dictionary.path]);
  });
}
