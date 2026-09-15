import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/dictionary/dictionary_read_backend.dart';
import 'package:mangayomi/services/dictionary/dictionary_read_facade.dart';
import 'package:mangayomi/services/hachidori/hachidori_models.dart';
import 'package:mangayomi/services/hachidori/hachidori_preferences.dart';
import 'package:mangayomi/services/hachidori/hachidori_protocol.dart';
import 'package:mangayomi/src/rust/api/hoshidicts.dart';

void main() {
  test(
    'disabled configuration stays local without creating a remote client',
    () async {
      final local = _FacadeBackend('local');
      final store = _MemoryConfigurationStore(
        const HachidoriLinkConfiguration.disabled(),
      );
      var factoryCalls = 0;
      final facade = DictionaryReadFacade.testing(
        local: local,
        configurationStore: store,
        clientFactory: () async {
          factoryCalls++;
          return _FacadeClient();
        },
      );

      await facade.initialize();
      expect((await facade.lookup('word')).single.matched, 'local');
      expect(factoryCalls, 0);
      expect(facade.remoteEnabled, isFalse);
      facade.dispose();
    },
  );

  test('restores an enabled link and routes reads only to the host', () async {
    final local = _FacadeBackend('local');
    final client = _FacadeClient();
    final facade = DictionaryReadFacade.testing(
      local: local,
      configurationStore: _MemoryConfigurationStore(
        const HachidoriLinkConfiguration(
          enabled: true,
          address: 'host.test:8771',
        ),
      ),
      clientFactory: () async => client,
    );

    await facade.initialize();

    expect(client.linkedAddresses, ['host.test:8771']);
    expect((await facade.lookup('word')).single.matched, 'remote');
    expect(local.lookupCalls, 0);
    expect(facade.remoteEnabled, isTrue);
    facade.dispose();
  });

  test(
    'probe is non-persistent; link and unlink atomically switch sources',
    () async {
      final local = _FacadeBackend('local');
      final client = _FacadeClient();
      final store = _MemoryConfigurationStore(
        const HachidoriLinkConfiguration(enabled: false, address: 'old.test'),
      );
      final facade = DictionaryReadFacade.testing(
        local: local,
        configurationStore: store,
        clientFactory: () async => client,
      );
      await facade.initialize();

      final probe = await facade.probe('new.test');
      expect(probe.host.name, 'Hachidori host');
      expect(store.writes, isEmpty);
      expect(facade.remoteEnabled, isFalse);

      await facade.link('new.test');
      expect(
        store.writes.single,
        const HachidoriLinkConfiguration(enabled: true, address: 'new.test'),
      );
      expect(client.linkedAddresses, ['new.test']);
      expect((await facade.lookup('word')).single.matched, 'remote');

      await facade.unlink();
      expect(
        store.writes.last,
        const HachidoriLinkConfiguration(enabled: false, address: 'new.test'),
      );
      expect(client.unlinkCalls, 1);
      expect((await facade.lookup('word')).single.matched, 'local');
      facade.dispose();
    },
  );
}

class _MemoryConfigurationStore implements HachidoriConfigurationStore {
  _MemoryConfigurationStore(this.value);

  HachidoriLinkConfiguration value;
  final List<HachidoriLinkConfiguration> writes = [];

  @override
  Future<HachidoriLinkConfiguration> read() async => value;

  @override
  Future<void> write(HachidoriLinkConfiguration configuration) async {
    value = configuration;
    writes.add(configuration);
  }
}

class _FacadeBackend implements DictionaryReadBackend {
  _FacadeBackend(this.name);

  final String name;
  int lookupCalls = 0;

  @override
  Future<List<HoshiLookupResult>> lookup(
    String text, {
    int maxResults = 10,
    int scanLength = 20,
    String? language,
    dynamic profile,
  }) async {
    lookupCalls++;
    return [_result(name)];
  }

  @override
  Future<List<HoshiLookupResult>> lookupDictionary(
    String text, {
    required String dictionary,
    int maxResults = 10,
    int scanLength = 20,
    String? language,
    dynamic profile,
  }) => lookup(text, profile: profile);

  @override
  Future<List<HoshiLookupResult>> lookupKanji(String text, {dynamic profile}) =>
      lookup(text, profile: profile);

  @override
  Future<List<HoshiDictionaryStyle>> getStyles({dynamic profile}) async =>
      const [];

  @override
  Future<Uint8List?> getMediaFile({
    required String dictName,
    required String mediaPath,
    dynamic profile,
  }) async => null;
}

class _FacadeClient extends ChangeNotifier implements HachidoriLinkClient {
  HachidoriClientState _state = const HachidoriClientState();
  final List<String> linkedAddresses = [];
  int unlinkCalls = 0;

  @override
  HachidoriClientState get state => _state;

  @override
  Stream<HachidoriLibraryEvent> get libraryEvents =>
      const Stream<HachidoriLibraryEvent>.empty();

  @override
  void link(String address) {
    HachidoriLinkAddress.parse(address);
    linkedAddresses.add(address);
    _state = const HachidoriClientState(linked: true, ready: true);
    notifyListeners();
  }

  @override
  void unlink() {
    unlinkCalls++;
    _state = const HachidoriClientState();
    notifyListeners();
  }

  @override
  Future<HachidoriProbeResult> probe(String address) async {
    HachidoriLinkAddress.parse(address);
    return const HachidoriProbeResult(
      host: HachidoriHostIdentity(
        version: '1.0.0',
        name: 'Hachidori host',
        dictionaryCount: 1,
        capabilities: [],
      ),
      snapshot: {},
      dictionaries: [],
    );
  }

  @override
  Future<List<HoshiLookupResult>> lookup(
    String text, {
    int maxResults = 10,
    int scanLength = 20,
    HachidoriLookupOptions options = const HachidoriLookupOptions(),
  }) async => [_result('remote')];

  @override
  Future<List<HoshiLookupResult>> lookupDictionary(
    String text, {
    required String dictionary,
    int maxResults = 10,
    int scanLength = 20,
    HachidoriLookupOptions options = const HachidoriLookupOptions(),
  }) => lookup(text);

  @override
  Future<List<HoshiLookupResult>> lookupKanji(String character) =>
      lookup(character);

  @override
  Future<List<HoshiDictionaryStyle>> styles() async => const [];

  @override
  Future<Uint8List?> media({
    required String dictionary,
    required String path,
  }) async => null;
}

HoshiLookupResult _result(String matched) => HoshiLookupResult(
  matched: matched,
  deinflected: matched,
  trace: const [],
  preprocessorSteps: 0,
  term: HoshiTermResult(
    expression: matched,
    reading: '',
    rules: '',
    score: 0,
    glossaries: const [],
    frequencies: const [],
    pitches: const [],
  ),
);
