import 'dart:convert';
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

  static const _manifestName = '.mangayomi-dictionaries.json';

  Future<DictionaryPaths> paths({Directory? root}) async {
    final directory = root ?? await rootDirectory;
    final dictionaries = await _installedFromRoot(directory);
    return DictionaryPaths(
      termPaths: [
        for (final dictionary in dictionaries)
          if (dictionary.hasTerms) p.join(directory.path, dictionary.name),
      ],
      frequencyPaths: [
        for (final dictionary in dictionaries)
          if (dictionary.hasFrequencies)
            p.join(directory.path, dictionary.name),
      ],
      pitchPaths: [
        for (final dictionary in dictionaries)
          if (dictionary.hasPitch) p.join(directory.path, dictionary.name),
      ],
    );
  }

  Future<List<InstalledDictionary>> installed({Directory? root}) async {
    return _installedFromRoot(root ?? await rootDirectory);
  }

  Future<void> recordImport({
    required String name,
    required BigInt termCount,
    required BigInt frequencyCount,
    required BigInt pitchCount,
  }) async {
    final root = await rootDirectory;
    final manifest = await _readManifest(root);
    manifest[name] = {
      'terms': termCount > BigInt.zero,
      'frequencies': frequencyCount > BigInt.zero,
      'pitch': pitchCount > BigInt.zero,
    };
    await _writeManifest(root, manifest);
  }

  Future<void> delete(String name) async {
    final root = await rootDirectory;
    final directory = Directory(p.join(root.path, name));
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    final manifest = await _readManifest(root);
    if (manifest.remove(name) != null) await _writeManifest(root, manifest);
  }

  Future<List<InstalledDictionary>> _installedFromRoot(Directory root) async {
    if (!await root.exists()) return const [];
    final manifest = await _readManifest(root);
    final directories = await root
        .list()
        .where((entity) => entity is Directory)
        .cast<Directory>()
        .toList();
    directories.removeWhere((directory) {
      final name = p.basename(directory.path);
      return const {'term', 'frequency', 'pitch'}.contains(name) ||
          !File(p.join(directory.path, 'index.json')).existsSync();
    });
    directories.sort(
      (a, b) => p.basename(a.path).compareTo(p.basename(b.path)),
    );

    return [
      for (final directory in directories)
        _dictionaryFromMetadata(
          p.basename(directory.path),
          manifest[p.basename(directory.path)],
        ),
    ];
  }

  InstalledDictionary _dictionaryFromMetadata(
    String name,
    Map<String, dynamic>? metadata,
  ) {
    // Imports made before the manifest was introduced are overwhelmingly term
    // dictionaries. This fallback also repairs existing JMdict installations.
    return InstalledDictionary(
      name: name,
      hasTerms: metadata?['terms'] as bool? ?? true,
      hasFrequencies: metadata?['frequencies'] as bool? ?? false,
      hasPitch: metadata?['pitch'] as bool? ?? false,
    );
  }

  Future<Map<String, Map<String, dynamic>>> _readManifest(
    Directory root,
  ) async {
    final file = File(p.join(root.path, _manifestName));
    if (!await file.exists()) return {};
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return {};
      return decoded.map(
        (key, value) => MapEntry(
          key,
          value is Map<String, dynamic> ? value : <String, dynamic>{},
        ),
      );
    } on FormatException {
      return {};
    }
  }

  Future<void> _writeManifest(
    Directory root,
    Map<String, Map<String, dynamic>> manifest,
  ) async {
    await root.create(recursive: true);
    await File(
      p.join(root.path, _manifestName),
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));
  }
}
