import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mangayomi/services/dictionary/dictionary_read_backend.dart';
import 'package:mangayomi/services/dictionary/local_hoshidicts_read_backend.dart';
import 'package:mangayomi/services/hachidori/hachidori_dictionary_backend.dart';
import 'package:mangayomi/services/hachidori/hachidori_link_controller.dart';
import 'package:mangayomi/services/hachidori/hachidori_preferences.dart';
import 'package:mangayomi/services/hachidori/hachidori_protocol.dart';
import 'package:mangayomi/services/hachidori/hachidori_sharing_client.dart';
import 'package:mangayomi/services/mining/dictionary_profile.dart';
import 'package:mangayomi/src/rust/api/hoshidicts.dart';
import 'package:package_info_plus/package_info_plus.dart';

typedef HachidoriLinkClientFactory = Future<HachidoriLinkClient> Function();

class DictionaryReadFacade extends ChangeNotifier
    implements DictionaryReadBackend, HachidoriLinkController {
  DictionaryReadFacade._({
    required DictionaryReadBackend local,
    required HachidoriConfigurationStore configurationStore,
    required HachidoriLinkClientFactory clientFactory,
  }) : _local = local,
       _configurationStore = configurationStore,
       _clientFactory = clientFactory;

  factory DictionaryReadFacade.testing({
    required DictionaryReadBackend local,
    required HachidoriConfigurationStore configurationStore,
    required HachidoriLinkClientFactory clientFactory,
  }) => DictionaryReadFacade._(
    local: local,
    configurationStore: configurationStore,
    clientFactory: clientFactory,
  );

  static final DictionaryReadFacade instance = DictionaryReadFacade._(
    local: LocalHoshidictsReadBackend(),
    configurationStore: HachidoriPreferences(),
    clientFactory: _createProductionClient,
  );

  final DictionaryReadBackend _local;
  final HachidoriConfigurationStore _configurationStore;
  final HachidoriLinkClientFactory _clientFactory;

  HachidoriLinkConfiguration _configuration =
      const HachidoriLinkConfiguration.disabled();
  HachidoriLinkClient? _client;
  HachidoriDictionaryBackend? _remote;
  Future<HachidoriLinkClient>? _creatingClient;
  Future<void>? _initializing;
  bool _initialized = false;
  bool _disposed = false;
  Future<void> _configurationMutation = Future.value();

  @override
  HachidoriLinkConfiguration get configuration => _configuration;

  @override
  bool get remoteEnabled => _configuration.enabled;

  @override
  HachidoriClientState get clientState =>
      _client?.state ?? const HachidoriClientState();

  List<HachidoriDictionaryInfo> get remoteDictionaries =>
      clientState.dictionaries;

  @override
  Future<void> initialize() {
    if (_initialized) return Future.value();
    return _initializing ??= _initialize().whenComplete(() {
      _initializing = null;
    });
  }

  Future<void> _initialize() async {
    final configuration = await _configurationStore.read();
    if (_disposed) return;
    _configuration = configuration.address.isEmpty && configuration.enabled
        ? const HachidoriLinkConfiguration.disabled()
        : configuration;
    if (_configuration.enabled) {
      final client = await _ensureClient();
      client.link(_configuration.address);
    }
    _initialized = true;
    if (!_disposed) notifyListeners();
  }

  @override
  Future<HachidoriProbeResult> probe(String address) async {
    await initialize();
    HachidoriLinkAddress.parse(address);
    return (await _ensureClient()).probe(address.trim());
  }

  @override
  Future<void> link(String address) =>
      _serializeConfigurationMutation(() async {
        await initialize();
        HachidoriLinkAddress.parse(address);
        final normalized = address.trim();
        final client = await _ensureClient();
        client.link(normalized);
        final configuration = HachidoriLinkConfiguration(
          enabled: true,
          address: normalized,
        );
        try {
          await _configurationStore.write(configuration);
        } on Object {
          client.unlink();
          rethrow;
        }
        _remote?.clearCaches();
        _configuration = configuration;
        if (!_disposed) notifyListeners();
      });

  @override
  Future<void> unlink() => _serializeConfigurationMutation(() async {
    await initialize();
    final configuration = HachidoriLinkConfiguration(
      enabled: false,
      address: _configuration.address,
    );
    await _configurationStore.write(configuration);
    _client?.unlink();
    _remote?.clearCaches();
    _configuration = configuration;
    if (!_disposed) notifyListeners();
  });

  Future<void> _serializeConfigurationMutation(
    Future<void> Function() mutation,
  ) {
    final result = _configurationMutation.then((_) => mutation());
    _configurationMutation = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  Future<HachidoriLinkClient> _ensureClient() async {
    final existing = _client;
    if (existing != null) return existing;
    final pending = _creatingClient;
    if (pending != null) return pending;

    late final Future<HachidoriLinkClient> creation;
    creation = _clientFactory()
        .then((client) {
          if (_disposed) {
            client.dispose();
            throw StateError('Dictionary read facade has been disposed.');
          }
          _client = client;
          _remote = HachidoriDictionaryBackend(client);
          client.addListener(_handleClientChanged);
          return client;
        })
        .whenComplete(() {
          if (identical(_creatingClient, creation)) _creatingClient = null;
        });
    _creatingClient = creation;
    return creation;
  }

  void _handleClientChanged() {
    if (!_disposed) notifyListeners();
  }

  Future<DictionaryReadBackend> _selectedBackend() async {
    await initialize();
    if (!_configuration.enabled) return _local;
    await _ensureClient();
    return _remote!;
  }

  @override
  Future<List<HoshiLookupResult>> lookup(
    String text, {
    int maxResults = 10,
    int scanLength = 20,
    String? language,
    DictionaryProfile? profile,
  }) async => (await _selectedBackend()).lookup(
    text,
    maxResults: maxResults,
    scanLength: scanLength,
    language: language,
    profile: profile,
  );

  @override
  Future<List<HoshiLookupResult>> lookupDictionary(
    String text, {
    required String dictionary,
    int maxResults = 10,
    int scanLength = 20,
    String? language,
    DictionaryProfile? profile,
  }) async => (await _selectedBackend()).lookupDictionary(
    text,
    dictionary: dictionary,
    maxResults: maxResults,
    scanLength: scanLength,
    language: language,
    profile: profile,
  );

  @override
  Future<List<HoshiLookupResult>> lookupKanji(
    String text, {
    DictionaryProfile? profile,
  }) async => (await _selectedBackend()).lookupKanji(text, profile: profile);

  @override
  Future<List<HoshiDictionaryStyle>> getStyles({
    DictionaryProfile? profile,
  }) async => (await _selectedBackend()).getStyles(profile: profile);

  @override
  Future<Uint8List?> getMediaFile({
    required String dictName,
    required String mediaPath,
    DictionaryProfile? profile,
  }) async => (await _selectedBackend()).getMediaFile(
    dictName: dictName,
    mediaPath: mediaPath,
    profile: profile,
  );

  @override
  void dispose() {
    _disposed = true;
    final client = _client;
    if (client != null) client.removeListener(_handleClientChanged);
    _remote?.dispose();
    client?.dispose();
    super.dispose();
  }
}

Future<HachidoriLinkClient> _createProductionClient() async {
  final package = await PackageInfo.fromPlatform();
  return HachidoriSharingClient(
    clientName: 'Mangatan',
    clientVersion: package.version,
  );
}
