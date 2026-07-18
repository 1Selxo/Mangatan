import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/mihon/bridge_protocol.dart';
import 'package:mangayomi/eval/model/source_preference.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupPreference.pb.dart';
import 'package:mangayomi/services/sync/chimahon_preferences.dart';
import 'package:mangayomi/services/sync/chimahon_source_preferences_adapter.dart';

void main() {
  const adapter = ChimahonSourcePreferencesAdapter();
  const codec = ChimahonPreferenceCodec();
  late Directory databaseDirectory;
  late Isar database;

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): await _isarLibraryPath()},
    );
  });

  setUp(() async {
    databaseDirectory = await Directory.systemTemp.createTemp(
      'mangatan-source-preferences-',
    );
    database = await Isar.open(
      [SourceSchema, SourcePreferenceSchema],
      directory: databaseDirectory.path,
      name: 'source_preferences_test',
    );
  });

  tearDown(() async {
    await database.close(deleteFromDisk: true);
    if (await databaseDirectory.exists()) {
      await databaseDirectory.delete(recursive: true);
    }
  });

  test('exports supported values under Chimahon native source identity', () {
    final source = _mihonSource(
      localId: 991,
      nativeId: '8743284448117690086',
      preferences: [
        SourcePreference(
          key: 'checkbox',
          checkBoxPreference: CheckBoxPreference(value: true),
        ),
        SourcePreference(
          key: 'edit',
          editTextPreference: EditTextPreference(value: 'https://example'),
        ),
        SourcePreference(
          key: 'list',
          listPreference: ListPreference(
            valueIndex: 1,
            entryValues: const ['primary', 'mirror'],
          ),
        ),
        SourcePreference(
          key: 'multi',
          multiSelectListPreference: MultiSelectListPreference(
            entryValues: const ['a', 'b', 'c'],
            values: const ['a', 'c'],
          ),
        ),
        SourcePreference(
          key: 'switch',
          switchPreferenceCompat: SwitchPreferenceCompat(value: false),
        ),
        SourcePreference(key: 'unsupported'),
      ],
    );
    final nonMihon = Source(id: 777, preferenceList: source.preferenceList);

    final result = adapter.export(sources: [source, nonMihon]);

    expect(result, hasLength(1));
    expect(result.single.sourceKey, 'source_8743284448117690086');
    expect(result.single.sourceKey, isNot(contains('991')));
    final decoded = {
      for (final preference in result.single.prefs)
        preference.key: codec.decode(preference),
    };
    expect(decoded.keys, ['checkbox', 'edit', 'list', 'multi', 'switch']);
    expect(decoded['checkbox']!.value, isTrue);
    expect(decoded['edit']!.value, 'https://example');
    expect(decoded['list']!.value, 'mirror');
    expect(decoded['multi']!.value, {'a', 'c'});
    expect(decoded['switch']!.value, isFalse);
  });

  test('falls back to normalized rows and omits malformed values', () {
    final source = _mihonSource(
      localId: 42,
      nativeId: ' 00042 ',
      preferences: const [],
    )..preferenceList = '{not valid json';
    final stored = [
      SourcePreference(
        sourceId: 42,
        key: 'valid',
        checkBoxPreference: CheckBoxPreference(value: true),
      ),
      SourcePreference(
        sourceId: 42,
        key: 'invalid_list',
        listPreference: ListPreference(
          valueIndex: 7,
          entryValues: const ['only'],
        ),
      ),
    ];

    final result = adapter.export(sources: [source], storedPreferences: stored);

    expect(result.single.sourceKey, 'source_42');
    expect(result.single.prefs.map((preference) => preference.key), ['valid']);
    expect(codec.decode(result.single.prefs.single).value, isTrue);
  });

  test('imports only installed definitions with compatible wire types', () {
    final source = _mihonSource(
      localId: 321,
      nativeId: '3707487231227345638',
      preferences: [
        SourcePreference(
          key: 'same_bool',
          checkBoxPreference: CheckBoxPreference(value: true),
        ),
        SourcePreference(
          key: 'list',
          listPreference: ListPreference(
            valueIndex: 0,
            entryValues: const ['first', 'second'],
          ),
        ),
        SourcePreference(
          key: 'invalid_list',
          listPreference: ListPreference(
            valueIndex: 0,
            entryValues: const ['known'],
          ),
        ),
        SourcePreference(
          key: 'multi',
          multiSelectListPreference: MultiSelectListPreference(
            entryValues: const ['a', 'b'],
            values: const ['a'],
          ),
        ),
        SourcePreference(
          key: 'text',
          editTextPreference: EditTextPreference(value: 'old', text: 'old'),
        ),
        SourcePreference(
          key: 'strict_bool',
          checkBoxPreference: CheckBoxPreference(value: false),
        ),
      ],
    );
    final existingStrict = SourcePreference(
      sourceId: 321,
      key: 'strict_bool',
      checkBoxPreference: CheckBoxPreference(value: false),
    );
    database.writeTxnSync(() {
      database.sources.putSync(source);
      database.sourcePreferences.putSync(existingStrict);
    });

    adapter.importInto(
      database: database,
      sourcePreferences: [
        BackupSourcePreferences(
          sourceKey: 'source_3707487231227345638',
          prefs: [
            codec.encode('same_bool', true),
            codec.encode('list', 'second'),
            codec.encode('invalid_list', 'not-an-entry'),
            codec.encode('multi', {'b', 'future-value'}),
            codec.encode('text', 'new'),
            codec.encode('strict_bool', 'wrong type'),
            codec.encode('unknown_key', true),
          ],
        ),
        BackupSourcePreferences(
          sourceKey: 'source_999',
          prefs: [codec.encode('same_bool', false)],
        ),
      ],
    );

    final restored = database.sources.getSync(321)!;
    final definitions = (jsonDecode(restored.preferenceList!) as List)
        .cast<Map>()
        .map(
          (value) => SourcePreference.fromJson(
            value.map((key, item) => MapEntry(key.toString(), item)),
          ),
        );
    SourcePreference definition(String key) =>
        definitions.firstWhere((preference) => preference.key == key);
    expect(definition('same_bool').checkBoxPreference!.value, isTrue);
    expect(definition('list').listPreference!.valueIndex, 1);
    expect(definition('invalid_list').listPreference!.valueIndex, 0);
    expect(definition('multi').multiSelectListPreference!.values, [
      'b',
      'future-value',
    ]);
    expect(definition('text').editTextPreference!.value, 'new');
    expect(definition('text').editTextPreference!.text, 'new');
    expect(definition('strict_bool').checkBoxPreference!.value, isFalse);

    final storedByKey = {
      for (final preference in database.sourcePreferences.where().findAllSync())
        preference.key: preference,
    };
    expect(
      storedByKey.keys,
      containsAll(['same_bool', 'list', 'multi', 'text']),
    );
    expect(storedByKey['same_bool']!.checkBoxPreference!.value, isTrue);
    expect(storedByKey['strict_bool']!.id, existingStrict.id);
    expect(storedByKey['strict_bool']!.checkBoxPreference!.value, isFalse);
    expect(storedByKey, isNot(contains('invalid_list')));
    expect(storedByKey, isNot(contains('unknown_key')));
  });
}

Source _mihonSource({
  required int localId,
  required String nativeId,
  required List<SourcePreference> preferences,
}) => Source(
  id: localId,
  name: 'Mihon source',
  additionalParams: encodeMihonSourceMetadata(
    sourceId: nativeId,
    packageName: 'eu.kanade.tachiyomi.extension.test',
  ),
  preferenceList: jsonEncode(
    preferences.map((preference) => preference.toJson()).toList(),
  ),
)..sourceCodeLanguage = SourceCodeLanguage.mihon;

Future<String> _isarLibraryPath() async {
  final packageConfig = File(
    '${Directory.current.path}/.dart_tool/package_config.json',
  );
  final config = jsonDecode(await packageConfig.readAsString());
  final packages = (config['packages'] as List).cast<Map<String, dynamic>>();
  final package = packages
      .where((entry) => entry['name'] == 'isar_community_flutter_libs')
      .firstOrNull;
  if (package == null) {
    throw StateError('Could not locate isar_community_flutter_libs');
  }
  final rootUri = Uri.parse(package['rootUri'] as String);
  final packageDirectory = Directory.fromUri(
    rootUri.isAbsolute ? rootUri : packageConfig.parent.uri.resolveUri(rootUri),
  );
  if (Platform.isMacOS) {
    return '${packageDirectory.path}/macos/libisar.dylib';
  }
  if (Platform.isLinux) {
    return '${packageDirectory.path}/linux/libisar.so';
  }
  if (Platform.isWindows) {
    return '${packageDirectory.path}/windows/libisar.dll';
  }
  throw UnsupportedError('Isar test is unsupported on this platform');
}
