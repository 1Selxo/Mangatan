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

  test('orders installed dictionaries from persisted manifest order', () async {
    final root = await Directory.systemTemp.createTemp('dictionary-storage-');
    addTearDown(() => root.delete(recursive: true));
    final jmdict = await _createDictionary(root, 'JMdict');
    final frequency = await _createDictionary(root, 'Frequency');
    final pitch = await _createDictionary(root, 'Pitch');
    await File(p.join(root.path, '.mangayomi-dictionaries.json')).writeAsString(
      '{"JMdict":{"terms":true,"frequencies":false,"pitch":false,"order":1},'
      '"Frequency":{"terms":true,"frequencies":true,"pitch":false,"order":0},'
      '"Pitch":{"terms":true,"frequencies":false,"pitch":true,"order":2}}',
    );

    final installed = await DictionaryStorage.instance.installed(root: root);
    final paths = await DictionaryStorage.instance.paths(root: root);

    expect(installed.map((dictionary) => dictionary.name), [
      'Frequency',
      'JMdict',
      'Pitch',
    ]);
    expect(paths.termPaths, [frequency.path, jmdict.path, pitch.path]);
    expect(paths.frequencyPaths, [frequency.path]);
    expect(paths.pitchPaths, [pitch.path]);
  });

  test('reorders installed dictionaries and query paths', () async {
    final root = await Directory.systemTemp.createTemp('dictionary-storage-');
    addTearDown(() => root.delete(recursive: true));
    final alpha = await _createDictionary(root, 'Alpha');
    final beta = await _createDictionary(root, 'Beta');
    final gamma = await _createDictionary(root, 'Gamma');

    await DictionaryStorage.instance.reorder([
      'Gamma',
      'Alpha',
      'Beta',
    ], root: root);

    final installed = await DictionaryStorage.instance.installed(root: root);
    final paths = await DictionaryStorage.instance.paths(root: root);

    expect(installed.map((dictionary) => dictionary.name), [
      'Gamma',
      'Alpha',
      'Beta',
    ]);
    expect(paths.termPaths, [gamma.path, alpha.path, beta.path]);
  });

  test('appends newly imported dictionaries after the current order', () async {
    final root = await Directory.systemTemp.createTemp('dictionary-storage-');
    addTearDown(() => root.delete(recursive: true));
    await _createDictionary(root, 'Alpha');
    await _createDictionary(root, 'Beta');
    await DictionaryStorage.instance.reorder(['Beta', 'Alpha'], root: root);
    final gamma = await _createDictionary(root, 'Gamma');

    await DictionaryStorage.instance.recordImport(
      name: 'Gamma',
      termCount: BigInt.one,
      frequencyCount: BigInt.zero,
      pitchCount: BigInt.zero,
      root: root,
    );

    final installed = await DictionaryStorage.instance.installed(root: root);
    final paths = await DictionaryStorage.instance.paths(root: root);

    expect(installed.map((dictionary) => dictionary.name), [
      'Beta',
      'Alpha',
      'Gamma',
    ]);
    expect(paths.termPaths.last, gamma.path);
  });

  test(
    'applies profile order and enabled dictionaries without rewriting disk order',
    () async {
      final root = await Directory.systemTemp.createTemp('dictionary-storage-');
      addTearDown(() => root.delete(recursive: true));
      final alpha = await _createDictionary(root, 'Alpha');
      await _createDictionary(root, 'Beta');
      final gamma = await _createDictionary(root, 'Gamma');

      final installed = await DictionaryStorage.instance.installed(
        root: root,
        order: const ['Gamma', 'Alpha', 'Beta'],
      );
      final paths = await DictionaryStorage.instance.paths(
        root: root,
        order: const ['Gamma', 'Alpha', 'Beta'],
        enabled: const {'Gamma', 'Alpha'},
      );

      expect(installed.map((dictionary) => dictionary.name), [
        'Gamma',
        'Alpha',
        'Beta',
      ]);
      expect(paths.termPaths, [gamma.path, alpha.path]);
    },
  );
}

Future<Directory> _createDictionary(Directory root, String name) async {
  final dictionary = Directory(p.join(root.path, name));
  await dictionary.create();
  await File(p.join(dictionary.path, 'index.json')).writeAsString('{}');
  return dictionary;
}
