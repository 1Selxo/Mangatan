import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/dictionary/dictionary_read_backend.dart';
import 'package:mangayomi/services/dictionary/dictionary_read_router.dart';
import 'package:mangayomi/services/hachidori/hachidori_dictionary_backend.dart';
import 'package:mangayomi/services/hachidori/hachidori_models.dart';
import 'package:mangayomi/src/rust/api/hoshidicts.dart';

void main() {
  group('DictionaryReadRouter', () {
    test(
      'selects one source and never falls back after a remote error',
      () async {
        final local = _FakeDictionaryBackend('local');
        final remote = _FakeDictionaryBackend('remote');
        final router = DictionaryReadRouter(local: local, remote: remote);

        expect((await router.lookup('word')).single.matched, 'local');
        expect(local.lookupCalls, 1);
        expect(remote.lookupCalls, 0);

        router.remoteEnabled = true;
        expect((await router.lookup('word')).single.matched, 'remote');
        remote.error = StateError('host unavailable');
        await expectLater(router.lookup('next'), throwsStateError);
        expect(
          local.lookupCalls,
          1,
          reason: 'linked mode must not mix libraries',
        );

        router.remoteEnabled = false;
        expect((await router.lookup('word')).single.matched, 'local');
        expect(local.lookupCalls, 2);
      },
    );
  });

  group('HachidoriDictionaryBackend', () {
    test('deduplicates and caches lookup, style, and media reads', () async {
      final client = _FakeHachidoriReadClient();
      final backend = HachidoriDictionaryBackend(client);

      final lookupA = backend.lookup('word', maxResults: 8, scanLength: 12);
      final lookupB = backend.lookup('word', maxResults: 8, scanLength: 12);
      await Future.wait([lookupA, lookupB]);
      await backend.lookup('word', maxResults: 8, scanLength: 12);
      expect(client.lookupCalls, 1);

      await Future.wait([backend.getStyles(), backend.getStyles()]);
      await backend.getStyles();
      expect(client.styleCalls, 1);

      await Future.wait([
        backend.getMediaFile(dictName: 'JMdict', mediaPath: 'image.png'),
        backend.getMediaFile(dictName: 'JMdict', mediaPath: 'image.png'),
      ]);
      await backend.getMediaFile(dictName: 'JMdict', mediaPath: 'image.png');
      expect(client.mediaCalls, 1);
      backend.dispose();
    });

    test(
      'invalidates without replaying in-flight work on host changes',
      () async {
        final client = _FakeHachidoriReadClient(deferLookups: true);
        final backend = HachidoriDictionaryBackend(client);

        final first = backend.lookup('word');
        await pumpEventQueue();
        expect(client.lookupCalls, 1);
        client.events.add(
          const HachidoriLibraryEvent(
            kind: HachidoriLibraryEventKind.storage,
            changedKeys: {'dictionaryState'},
          ),
        );
        await pumpEventQueue();
        expect(
          client.lookupCalls,
          1,
          reason: 'in-flight reads are not replayed',
        );
        client.completeLookup();
        await first;

        final second = backend.lookup('word');
        await pumpEventQueue();
        expect(client.lookupCalls, 2);
        client.completeLookup();
        await second;
        backend.dispose();
      },
    );

    test('keeps host ordering and forwards shared lookup options', () async {
      final client = _FakeHachidoriReadClient(
        results: [_result('Second'), _result('First')],
        snapshot: const {
          'options': {
            'frequencyDictionary': 'JPDB',
            'frequencyOrder': 'descending',
            'primaryReading': 'かな',
          },
        },
      );
      final backend = HachidoriDictionaryBackend(client);

      final results = await backend.lookup('word');

      expect(results.map((result) => result.matched), ['Second', 'First']);
      expect(
        client.lastOptions,
        const HachidoriLookupOptions(
          frequencyDictionary: 'JPDB',
          frequencyOrder: HachidoriFrequencyOrder.descending,
          primaryReading: 'かな',
        ),
      );
      backend.dispose();
    });

    test('caps the remote lookup LRU at 32 entries', () async {
      final client = _FakeHachidoriReadClient();
      final backend = HachidoriDictionaryBackend(client);

      for (var index = 0; index < 33; index++) {
        await backend.lookup('word-$index');
      }
      await backend.lookup('word-0');

      expect(client.lookupCalls, 34);
      backend.dispose();
    });
  });
}

class _FakeDictionaryBackend implements DictionaryReadBackend {
  _FakeDictionaryBackend(this.name);

  final String name;
  int lookupCalls = 0;
  Object? error;

  @override
  Future<List<HoshiLookupResult>> lookup(
    String text, {
    int maxResults = 10,
    int scanLength = 20,
    String? language,
    dynamic profile,
  }) async {
    lookupCalls++;
    if (error case final Object value) throw value;
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
  }) => lookup(
    text,
    maxResults: maxResults,
    scanLength: scanLength,
    language: language,
    profile: profile,
  );

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

class _FakeHachidoriReadClient implements HachidoriReadClient {
  _FakeHachidoriReadClient({
    this.deferLookups = false,
    this.results,
    Map<String, Object?> snapshot = const {},
  }) : state = HachidoriClientState(
         linked: true,
         ready: true,
         snapshot: snapshot,
       );

  final bool deferLookups;
  final List<HoshiLookupResult>? results;
  final StreamController<HachidoriLibraryEvent> events =
      StreamController<HachidoriLibraryEvent>.broadcast();
  final List<Completer<List<HoshiLookupResult>>> _pendingLookups = [];

  @override
  final HachidoriClientState state;

  int lookupCalls = 0;
  int styleCalls = 0;
  int mediaCalls = 0;
  HachidoriLookupOptions? lastOptions;

  @override
  Stream<HachidoriLibraryEvent> get libraryEvents => events.stream;

  @override
  Future<List<HoshiLookupResult>> lookup(
    String text, {
    int maxResults = 10,
    int scanLength = 20,
    HachidoriLookupOptions options = const HachidoriLookupOptions(),
  }) {
    lookupCalls++;
    lastOptions = options;
    if (!deferLookups) {
      return Future.value(results ?? [_result(text)]);
    }
    final completer = Completer<List<HoshiLookupResult>>();
    _pendingLookups.add(completer);
    return completer.future;
  }

  void completeLookup() {
    _pendingLookups.removeAt(0).complete(results ?? [_result('word')]);
  }

  @override
  Future<List<HoshiLookupResult>> lookupDictionary(
    String text, {
    required String dictionary,
    int maxResults = 10,
    int scanLength = 20,
    HachidoriLookupOptions options = const HachidoriLookupOptions(),
  }) => lookup(
    text,
    maxResults: maxResults,
    scanLength: scanLength,
    options: options,
  );

  @override
  Future<List<HoshiLookupResult>> lookupKanji(String character) async =>
      results ?? [_result(character)];

  @override
  Future<List<HoshiDictionaryStyle>> styles() async {
    styleCalls++;
    return const [
      HoshiDictionaryStyle(dictName: 'JMdict', styles: '.entry {}'),
    ];
  }

  @override
  Future<Uint8List?> media({
    required String dictionary,
    required String path,
  }) async {
    mediaCalls++;
    return Uint8List.fromList([1, 2, 3]);
  }
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
