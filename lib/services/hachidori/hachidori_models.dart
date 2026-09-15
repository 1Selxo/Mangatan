import 'package:flutter/foundation.dart';
import 'package:mangayomi/services/hachidori/hachidori_protocol.dart';
import 'package:mangayomi/src/rust/api/hoshidicts.dart';

class HachidoriException implements Exception {
  const HachidoriException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HachidoriConnectionException extends HachidoriException {
  const HachidoriConnectionException(super.message);
}

class HachidoriProtocolException extends HachidoriException {
  const HachidoriProtocolException(super.message);
}

class HachidoriRemoteException extends HachidoriException {
  const HachidoriRemoteException(super.message, {this.code});

  final String? code;
}

@immutable
class HachidoriClientState {
  const HachidoriClientState({
    this.linked = false,
    this.address,
    this.ready = false,
    this.connecting = false,
    this.error,
    this.host,
    this.snapshot = const <String, Object?>{},
    this.dictionaries = const <HachidoriDictionaryInfo>[],
  });

  final bool linked;
  final HachidoriLinkAddress? address;
  final bool ready;
  final bool connecting;
  final String? error;
  final HachidoriHostIdentity? host;
  final Map<String, Object?> snapshot;
  final List<HachidoriDictionaryInfo> dictionaries;
}

@immutable
class HachidoriHostIdentity {
  const HachidoriHostIdentity({
    required this.version,
    required this.name,
    required this.dictionaryCount,
    required this.capabilities,
  });

  final String version;
  final String name;
  final int dictionaryCount;
  final List<String> capabilities;
}

@immutable
class HachidoriProbeResult {
  const HachidoriProbeResult({
    required this.host,
    required this.snapshot,
    required this.dictionaries,
  });

  final HachidoriHostIdentity host;
  final Map<String, Object?> snapshot;
  final List<HachidoriDictionaryInfo> dictionaries;
}

@immutable
class HachidoriDictionaryInfo {
  const HachidoriDictionaryInfo({
    required this.id,
    required this.title,
    required this.displayName,
    required this.enabled,
    required this.favorite,
    required this.revision,
    required this.termCount,
    required this.frequencyCount,
    required this.pitchCount,
    required this.kanjiCount,
    required this.mediaCount,
  });

  final String id;
  final String title;
  final String? displayName;
  final bool enabled;
  final bool favorite;
  final String revision;
  final int termCount;
  final int frequencyCount;
  final int pitchCount;
  final int kanjiCount;
  final int mediaCount;
}

@immutable
class HachidoriEngineStatus {
  const HachidoriEngineStatus({
    required this.ready,
    required this.loading,
    required this.dictionaryCount,
    required this.failedDictionaries,
    required this.generation,
    required this.storageBackend,
    required this.threaded,
  });

  final bool ready;
  final bool loading;
  final int dictionaryCount;
  final List<Object?> failedDictionaries;
  final int generation;
  final String storageBackend;
  final bool threaded;
}

enum HachidoriFrequencyOrder { auto, ascending, descending, disabled }

@immutable
class HachidoriLookupOptions {
  const HachidoriLookupOptions({
    this.frequencyDictionary = '',
    this.frequencyOrder = HachidoriFrequencyOrder.auto,
    this.primaryReading = '',
  });

  final String frequencyDictionary;
  final HachidoriFrequencyOrder frequencyOrder;
  final String primaryReading;

  Map<String, Object?> toJson() => {
    'frequencyDictionary': frequencyDictionary,
    'frequencyOrder': frequencyOrder.name,
    'primaryReading': primaryReading,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HachidoriLookupOptions &&
          frequencyDictionary == other.frequencyDictionary &&
          frequencyOrder == other.frequencyOrder &&
          primaryReading == other.primaryReading;

  @override
  int get hashCode =>
      Object.hash(frequencyDictionary, frequencyOrder, primaryReading);
}

enum HachidoriLibraryEventKind { hello, storage, disconnected }

@immutable
class HachidoriLibraryEvent {
  const HachidoriLibraryEvent({
    required this.kind,
    this.changedKeys = const <String>{},
  });

  final HachidoriLibraryEventKind kind;
  final Set<String> changedKeys;
}

abstract interface class HachidoriReadClient {
  HachidoriClientState get state;

  Stream<HachidoriLibraryEvent> get libraryEvents;

  Future<List<HoshiLookupResult>> lookup(
    String text, {
    int maxResults = 10,
    int scanLength = 20,
    HachidoriLookupOptions options = const HachidoriLookupOptions(),
  });

  Future<List<HoshiLookupResult>> lookupDictionary(
    String text, {
    required String dictionary,
    int maxResults = 10,
    int scanLength = 20,
    HachidoriLookupOptions options = const HachidoriLookupOptions(),
  });

  Future<List<HoshiLookupResult>> lookupKanji(String character);

  Future<List<HoshiDictionaryStyle>> styles();

  Future<Uint8List?> media({required String dictionary, required String path});
}

abstract interface class HachidoriLinkClient
    implements HachidoriReadClient, Listenable {
  Future<HachidoriProbeResult> probe(String address);

  void link(String address);

  void unlink();

  void dispose();
}
