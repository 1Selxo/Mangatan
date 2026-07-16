import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mangayomi/services/hoshidicts/hoshidicts_backend.dart';
import 'package:mangayomi/services/mining/dictionary_profile.dart';
import 'package:mangayomi/src/rust/api/hoshidicts.dart';
import 'package:mangayomi/src/rust/api/hoshidicts/native.dart';
import 'package:mangayomi/src/rust/frb_generated.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory supportDirectory;
  late _FakeRustApi rustApi;

  setUpAll(() async {
    supportDirectory = await Directory.systemTemp.createTemp(
      'hoshidicts-profile-backend-',
    );
    Hive.init(supportDirectory.path);
    final dictionaryRoot = Directory(
      p.join(supportDirectory.path, 'dictionaries'),
    );
    await _createDictionary(dictionaryRoot, 'Alpha');
    await _createDictionary(dictionaryRoot, 'Beta');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (_) async {
          return supportDirectory.path;
        });
    rustApi = _FakeRustApi();
    RustLib.initMock(api: rustApi);
  });

  setUp(() {
    rustApi.reset();
    HoshidictsLookupBackend.instance.clearSession();
  });

  tearDownAll(() async {
    HoshidictsLookupBackend.instance.clearSession();
    RustLib.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    await Hive.close();
    await supportDirectory.delete(recursive: true);
  });

  const alphaProfile = DictionaryProfile(
    id: 'shared-id',
    name: 'Alpha profile',
    enabledDictionaries: {'Alpha'},
  );
  const betaProfile = DictionaryProfile(
    id: 'shared-id',
    name: 'Beta profile',
    enabledDictionaries: {'Beta'},
  );
  const alphaFirstProfile = DictionaryProfile(
    id: 'shared-order-id',
    name: 'Alpha first',
    dictionaryOrder: ['Alpha', 'Beta'],
  );
  const betaFirstProfile = DictionaryProfile(
    id: 'shared-order-id',
    name: 'Beta first',
    dictionaryOrder: ['Beta', 'Alpha'],
  );
  const mandarinProfile = DictionaryProfile(
    id: 'shared-language-id',
    name: 'Mandarin',
    languageCode: 'zh',
    enabledDictionaries: {'Alpha'},
  );
  const japaneseProfile = DictionaryProfile(
    id: 'shared-language-id',
    name: 'Japanese',
    languageCode: 'ja',
    enabledDictionaries: {'Beta'},
  );

  test('isolates lookup caches by structural profile configuration', () async {
    final backend = HoshidictsLookupBackend.instance;

    final alpha = await backend.lookup('same text', profile: alphaProfile);
    final beta = await backend.lookup('same text', profile: betaProfile);
    final cachedAlpha = await backend.lookup(
      'same text',
      profile: alphaProfile,
    );

    expect(alpha.single.matched, 'Alpha');
    expect(beta.single.matched, 'Beta');
    expect(cachedAlpha, same(alpha));
    expect(rustApi.lookupCalls, 2);
    expect(rustApi.rebuildHistory, [
      ['Alpha'],
      ['Beta'],
    ]);
  });

  test('isolates lookup caches when only dictionary order changes', () async {
    final backend = HoshidictsLookupBackend.instance;

    final alphaFirst = await backend.lookup(
      'same text',
      profile: alphaFirstProfile,
    );
    final betaFirst = await backend.lookup(
      'same text',
      profile: betaFirstProfile,
    );

    expect(alphaFirst.single.matched, 'Alpha,Beta');
    expect(betaFirst.single.matched, 'Beta,Alpha');
    expect(rustApi.lookupCalls, 2);
  });

  test('isolates lookup caches and sessions when profile language changes', () async {
    final backend = HoshidictsLookupBackend.instance;

    final mandarin = await backend.lookup(
      'same text',
      profile: mandarinProfile,
    );
    final japanese = await backend.lookup(
      'same text',
      profile: japaneseProfile,
    );
    final mandarinAgain = await backend.lookup(
      'same text',
      profile: mandarinProfile,
    );

    expect(mandarin.single.matched, 'Alpha');
    expect(japanese.single.matched, 'Beta');
    expect(mandarinAgain.single.matched, 'Alpha');
    expect(rustApi.lookupCalls, 3);
    expect(rustApi.rebuildHistory, [
      ['Alpha'],
      ['Beta'],
      ['Alpha'],
    ]);
  });

  test('isolates style caches by structural profile configuration', () async {
    final backend = HoshidictsLookupBackend.instance;

    final alpha = await backend.getStyles(profile: alphaProfile);
    final beta = await backend.getStyles(profile: betaProfile);
    final cachedAlpha = await backend.getStyles(profile: alphaProfile);

    expect(alpha.single.dictName, 'Alpha');
    expect(beta.single.dictName, 'Beta');
    expect(cachedAlpha, same(alpha));
    expect(rustApi.styleCalls, 2);
  });

  test('keeps explicitly rebuilt paths for profile-less lookups', () async {
    final backend = HoshidictsLookupBackend.instance;
    final customPath = p.join(supportDirectory.path, 'Custom');
    const activeProfile = DictionaryProfile(
      id: 'mangatan-default',
      name: 'Default',
    );

    await backend.rebuildQuery(termPaths: [customPath]);
    final directResult = await backend.lookup('same text');
    final directStyles = await backend.getStyles();
    final profileResult = await backend.lookup(
      'same text',
      profile: activeProfile,
    );
    final profileStyles = await backend.getStyles(profile: activeProfile);

    expect(directResult.single.matched, 'Custom');
    expect(directStyles.single.dictName, 'Custom');
    expect(profileResult.single.matched, 'Alpha,Beta');
    expect(profileStyles.map((style) => style.dictName), ['Alpha', 'Beta']);
    expect(rustApi.lookupCalls, 2);
    expect(rustApi.styleCalls, 2);
    expect(rustApi.rebuildHistory, [
      ['Custom'],
      ['Alpha', 'Beta'],
    ]);
  });
}

Future<void> _createDictionary(Directory root, String name) async {
  final dictionary = Directory(p.join(root.path, name));
  await dictionary.create(recursive: true);
  await File(p.join(dictionary.path, 'index.json')).writeAsString('{}');
}

class _FakeHoshiLookupSession implements HoshiLookupSession {
  bool _disposed = false;

  @override
  void dispose() => _disposed = true;

  @override
  bool get isDisposed => _disposed;
}

class _FakeRustApi implements RustLibApi {
  final _session = _FakeHoshiLookupSession();
  List<String> _configuredDictionaries = const [];
  final List<List<String>> rebuildHistory = [];
  int lookupCalls = 0;
  int styleCalls = 0;

  void reset() {
    _configuredDictionaries = const [];
    rebuildHistory.clear();
    lookupCalls = 0;
    styleCalls = 0;
  }

  @override
  Future<HoshiLookupSession> crateApiHoshidictsNativeCreateLookupSession() {
    return Future.value(_session);
  }

  @override
  Future<void> crateApiHoshidictsNativeRebuildQuery({
    required HoshiLookupSession session,
    required List<String> termPaths,
    required List<String> freqPaths,
    required List<String> pitchPaths,
  }) async {
    _configuredDictionaries = [for (final path in termPaths) p.basename(path)];
    rebuildHistory.add([..._configuredDictionaries]);
  }

  @override
  Future<List<HoshiLookupResult>> crateApiHoshidictsNativeLookup({
    required HoshiLookupSession session,
    required String text,
    required int maxResults,
    required BigInt scanLength,
  }) async {
    lookupCalls++;
    final configured = _configuredDictionaries.join(',');
    return [
      HoshiLookupResult(
        matched: configured,
        deinflected: configured,
        trace: const [],
        preprocessorSteps: 0,
        term: HoshiTermResult(
          expression: configured,
          reading: '',
          rules: '',
          score: 1,
          glossaries: const [],
          frequencies: const [],
          pitches: const [],
        ),
      ),
    ];
  }

  @override
  Future<List<HoshiDictionaryStyle>> crateApiHoshidictsNativeGetStyles({
    required HoshiLookupSession session,
  }) async {
    styleCalls++;
    return [
      for (final dictionary in _configuredDictionaries)
        HoshiDictionaryStyle(dictName: dictionary, styles: '/* $dictionary */'),
    ];
  }

  @override
  Future<Uint8List?> crateApiHoshidictsNativeGetMediaFile({
    required HoshiLookupSession session,
    required String dictName,
    required String mediaPath,
  }) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
