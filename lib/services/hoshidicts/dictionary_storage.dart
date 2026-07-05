import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DictionaryPaths {
  final List<String> termPaths;
  final List<String> frequencyPaths;
  final List<String> pitchPaths;

  const DictionaryPaths({
    this.termPaths = const [],
    this.frequencyPaths = const [],
    this.pitchPaths = const [],
  });
}

class InstalledDictionary {
  final String name;
  final bool hasTerms;
  final bool hasFrequencies;
  final bool hasPitch;

  const InstalledDictionary({
    required this.name,
    required this.hasTerms,
    required this.hasFrequencies,
    required this.hasPitch,
  });
}

class DictionaryStorage {
  DictionaryStorage._();

  static final DictionaryStorage instance = DictionaryStorage._();

  Future<Directory> get rootDirectory async {
    final support = await getApplicationSupportDirectory();
    final root = Directory(p.join(support.path, 'dictionaries'));
    await root.create(recursive: true);
    return root;
  }

  Future<DictionaryPaths> paths() async {
    final root = await rootDirectory;
    return DictionaryPaths(
      termPaths: await _typePaths(root, 'term'),
      frequencyPaths: await _typePaths(root, 'frequency'),
      pitchPaths: await _typePaths(root, 'pitch'),
    );
  }

  Future<List<InstalledDictionary>> installed() async {
    final paths = await this.paths();
    final terms = paths.termPaths.map(p.basename).toSet();
    final frequencies = paths.frequencyPaths.map(p.basename).toSet();
    final pitches = paths.pitchPaths.map(p.basename).toSet();
    final names = {...terms, ...frequencies, ...pitches}.toList()..sort();
    return names
        .map(
          (name) => InstalledDictionary(
            name: name,
            hasTerms: terms.contains(name),
            hasFrequencies: frequencies.contains(name),
            hasPitch: pitches.contains(name),
          ),
        )
        .toList();
  }

  Future<void> delete(String name) async {
    final root = await rootDirectory;
    for (final type in const ['term', 'frequency', 'pitch']) {
      final directory = Directory(p.join(root.path, type, name));
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  }

  Future<List<String>> _typePaths(Directory root, String type) async {
    final typeDirectory = Directory(p.join(root.path, type));
    if (!await typeDirectory.exists()) return const [];
    final directories = await typeDirectory
        .list()
        .where((entity) => entity is Directory)
        .cast<Directory>()
        .toList();
    directories.sort(
      (a, b) => p.basename(a.path).compareTo(p.basename(b.path)),
    );
    return directories.map((directory) => directory.path).toList();
  }
}
