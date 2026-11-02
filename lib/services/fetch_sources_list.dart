import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:http_interceptor/http_interceptor.dart';
import 'package:mangayomi/eval/aidoku/service.dart';
import 'package:mangayomi/eval/model/filter.dart';
import 'package:mangayomi/eval/model/source_preference.dart';
import 'package:mangayomi/eval/mihon/bridge_http_client.dart';
import 'package:mangayomi/eval/mihon/bridge_protocol.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/repositories/db_write_queue.dart';
import 'package:mangayomi/repositories/source_repository.dart';
import 'package:mangayomi/services/extension_catalog_reconciler.dart';
import 'package:mangayomi/services/extension_repository_catalog.dart';
import 'package:mangayomi/services/extension_store_service.dart';
import 'package:mangayomi/services/extension_update.dart';
import 'package:mangayomi/services/http/m_client.dart';
import 'package:mangayomi/services/isolate_service.dart';
import 'package:mangayomi/services/mihon_source_preferences.dart';
import 'package:mangayomi/utils/error_toast.dart';
import 'package:mangayomi/utils/extension_language_defaults.dart';
import 'package:mangayomi/utils/log/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:isar_community/isar.dart';

/// The extensions [repo] lists for [itemType] that this version of the app
/// can run. A Mihon APK becomes one row per source it holds, all sharing the
/// APK; the catalog loader reads Mihon, LNReader and Mangayomi indexes, and
/// the store parser the rest.
Future<List<Source>> fetchRepoSources({
  required Repo repo,
  required ItemType itemType,
}) async {
  final http = MClient.init(reqcopyWith: {'useDartHttpClient': true});
  final url = repo.jsonUrl;
  if (url == null) return [];

  if (repo.name == null ||
      repo.name!.isEmpty ||
      repo.name == '.dist' ||
      repo.name == 'dist') {
    final uri = Uri.tryParse(url);
    if (uri != null &&
        uri.host == 'raw.githubusercontent.com' &&
        uri.pathSegments.length >= 2) {
      repo.name = uri.pathSegments[1];
    }
  }

  ExtensionRepositoryCatalog? catalog;
  Object? catalogError;
  StackTrace? catalogStackTrace;
  try {
    catalog = await loadExtensionRepositoryCatalog(Uri.parse(url), (uri) async {
      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Extension repository returned HTTP ${response.statusCode}.',
          uri: uri,
        );
      }
      return response.bodyBytes;
    });
  } catch (error, stackTrace) {
    catalogError = error;
    catalogStackTrace = stackTrace;
  }
  final info = await PackageInfo.fromPlatform();

  final allSources = (catalog?.entries ?? const <Map<String, dynamic>>[])
      .expand((e) sync* {
        if (e['name'] != null &&
            e['pkg'] != null &&
            e['version'] != null &&
            e['code'] != null &&
            e['lang'] != null &&
            e['nsfw'] != null &&
            e['sources'] != null &&
            e['apk'] != null) {
          final repoUrl = catalog!.indexUri
              .resolve('.')
              .toString()
              .replaceFirst(RegExp(r'/$'), '');
          final sources = e['sources'] as List;
          for (final source in sources) {
            final src = Source.fromJson(e)
              ..apiUrl = ''
              ..appMinVerReq = ''
              ..dateFormat = ''
              ..dateFormatLocale = ''
              ..hasCloudflare = false
              ..headers = ''
              ..isActive = true
              ..isAdded = false
              ..isFullData = false
              ..isNsfw = e['nsfw'] == 1
              ..isPinned = false
              ..lastUsed = false
              ..sourceCode = ''
              ..typeSource = ''
              ..versionLast = '0.0.1'
              ..isObsolete = false
              ..isLocal = false
              ..name = source['name']
              ..lang = source['lang']
              ..baseUrl = source['baseUrl']
              ..sourceCodeUrl =
                  e['_apkUrl']?.toString() ?? "$repoUrl/apk/${e['apk']}"
              ..sourceCodeLanguage = SourceCodeLanguage.mihon
              ..repo = repo
              ..additionalParams = encodeMihonSourceMetadata(
                sourceId: source['id'],
                packageName: e['pkg'],
                extensionName: (e['name'] as String).replaceFirst(
                  RegExp(r'^(Tachiyomi|Aniyomi):\s*'),
                  '',
                ),
                packageLang: e['lang'],
              )
              ..itemType =
                  (e['pkg'] as String).startsWith(
                    "eu.kanade.tachiyomi.animeextension",
                  )
                  ? ItemType.anime
                  : ItemType.manga
              ..iconUrl =
                  e['_iconUrl']?.toString() ?? "$repoUrl/icon/${e['pkg']}.png"
              ..notes = Platform.isAndroid
                  ? null
                  : "Requires Android Proxy Server (ApkBridge) for installing and using the extensions!";
            src.id = mihonLocalSourceId(source['id']);
            yield src;
          }
        } else if (e['id'] is String &&
            e['name'] != null &&
            e['site'] != null &&
            e['lang'] != null &&
            e['version'] != null &&
            e['url'] != null &&
            e['iconUrl'] != null) {
          final src = Source.fromJson(e)
            ..apiUrl = ''
            ..appMinVerReq = ''
            ..dateFormat = ''
            ..dateFormatLocale = ''
            ..hasCloudflare = false
            ..headers = ''
            ..isActive = true
            ..isAdded = false
            ..isFullData = false
            ..isNsfw = false
            ..isPinned = false
            ..lastUsed = false
            ..sourceCode = ''
            ..typeSource = ''
            ..versionLast = '0.0.1'
            ..isObsolete = false
            ..isLocal = false
            ..lang = _convertLang(e)
            ..baseUrl = e['site']
            ..sourceCodeUrl = e['url']
            ..sourceCodeLanguage = SourceCodeLanguage.lnreader
            ..itemType = ItemType.novel
            ..notes = "Performance might be poor due to limited engine";
          src.id = 'lnreader-plugin-"${src.name}"."${src.lang}"'.hashCode;
          yield src;
        } else {
          yield Source.fromJson(e);
        }
      })
      .where(
        (source) =>
            source.sourceCodeLanguage == SourceCodeLanguage.lnreader ||
            source.appMinVerReq == null ||
            source.appMinVerReq!.isEmpty ||
            compareVersions(info.version, source.appMinVerReq!) > -1,
      )
      .toList();
  if (allSources.isEmpty) {
    // Stores the catalog loader does not read (Aidoku indexes, protobuf
    // stores) come from the upstream store parser. Mihon listings keep the
    // catalog's path, which records what one APK's sources share.
    final store = await ExtensionStoreService.fetchStore(url, http);
    allSources.addAll(
      store?.sources.where(
            (source) => source.sourceCodeLanguage != SourceCodeLanguage.mihon,
          ) ??
          const <Source>[],
    );
  }
  if (allSources.isEmpty && catalogError != null) {
    Error.throwWithStackTrace(catalogError, catalogStackTrace!);
  }
  return allSources.where((source) => source.itemType == itemType).toList();
}

/// Takes in what [repo] lists: an extension seen for the first time is
/// added, one already known takes the listing's metadata and language state,
/// and one it no longer lists is marked obsolete.
Future<void> recordRepoSources(
  List<Source> sourceList,
  Repo repo,
  ItemType itemType,
) async {
  final languageStates = await _savedExtensionLanguageStates(itemType);
  final deviceLocales = PlatformDispatcher.instance.locales;
  // Read every stored source in one query and save this refresh's changes
  // in one transaction instead of one of each per source. A source written
  // earlier in the loop is read back from `pending`, as it would have been
  // from the database, and pending writes are saved even if the loop
  // throws, like the writes made before the throw used to be.
  final knownIds = [
    for (final source in sourceList)
      if (source.id != null) source.id!,
  ];
  final storedById = <int, Source?>{};
  final stored = await isar.sources.getAll(knownIds);
  for (var i = 0; i < knownIds.length; i++) {
    storedById[knownIds[i]] = stored[i];
  }
  final pending = <int, Source>{};
  try {
    for (var source in sourceList) {
      final id = source.id!;
      final existingSource = pending[id] ?? storedById[id];
      if (existingSource == null) {
        final isActive = extensionLanguageEnabledForNewSource(
          source.lang,
          savedLanguageStates: languageStates,
          deviceLocales: deviceLocales,
        );
        pending[id] = _newSource(source, repo, itemType, isActive: isActive)
          ..updatedAt = DateTime.now().millisecondsSinceEpoch;
        continue;
      }
      final metadataChanged = applyExtensionCatalogMetadata(
        existingSource,
        source,
        repo: repo,
      );
      final isActive = extensionLanguageEnabledForCatalogSource(
        source.lang,
        isInstalled: existingSource.isAdded ?? false,
        currentValue: existingSource.isActive,
        savedLanguageStates: languageStates,
        deviceLocales: deviceLocales,
      );
      final activationChanged = existingSource.isActive != isActive;
      if (activationChanged) existingSource.isActive = isActive;
      if (metadataChanged || activationChanged) {
        _markPending(pending, existingSource);
      }
    }
  } finally {
    if (pending.isNotEmpty) {
      final writes = pending.values.toList();
      await dbWriteQueue.run(
        () => isar.writeTxn(() => isar.sources.putAll(writes)),
      );
    }
  }

  unawaited(
    checkIfSourceIsObsolete(sourceList, repo, itemType).catchError((
      Object error,
      StackTrace stack,
    ) {
      AppLogger.log(
        'Could not check for obsolete sources: $error\n$stack',
        logLevel: LogLevel.warning,
      );
    }),
  );
}

/// Installs the sources of an installed Mihon APK that [sourceList] lists
/// but that are not installed yet, as when an extension gained a source.
Future<void> installMissingMihonSiblings(
  List<Source> sourceList,
  String androidProxyServer,
  Repo repo,
  ItemType itemType,
) async {
  final mihonGroups = <String, List<Source>>{};
  for (final source in sourceList.where(
    (source) => source.sourceCodeLanguage == SourceCodeLanguage.mihon,
  )) {
    mihonGroups
        .putIfAbsent(mihonExtensionGroupKey(source), () => [])
        .add(source);
  }
  // Read every group's stored state at once. Installing a group changes
  // the database, so after an install the remaining groups are read again
  // one at a time, as before.
  final mihonIds = [
    for (final group in mihonGroups.values)
      for (final source in group) source.id!,
  ];
  var prefetched = <int, Source?>{};
  final mihonStored = await isar.sources.getAll(mihonIds);
  for (var i = 0; i < mihonIds.length; i++) {
    prefetched[mihonIds[i]] = mihonStored[i];
  }
  for (final group in mihonGroups.values) {
    final installedStates = prefetched.isEmpty
        ? await Future.wait(group.map((source) => isar.sources.get(source.id!)))
        : [for (final source in group) prefetched[source.id!]];
    final hasInstalledSource = installedStates.any(
      (source) => source?.isAdded ?? false,
    );
    final hasMissingSibling = installedStates.any(
      (source) => !(source?.isAdded ?? false),
    );
    if (hasInstalledSource && hasMissingSibling) {
      prefetched = {};
      await _updateSources(group, androidProxyServer, repo, itemType);
    }
  }
}

/// Points extensions installed from an address [repos] no longer has at the
/// repository it moved to. Only the old address itself is believed: it names
/// its replacement ([resolveIndexUrl], by default following its index's
/// redirect), which a repository merely wearing the same name cannot do.
Future<void> followMovedRepos({
  required List<Repo> repos,
  required Map<int, List<ExtensionOffer>> offers,
  required ItemType itemType,
  Future<String?> Function(String url)? resolveIndexUrl,
}) async {
  final installed = sourceRepository.getAddedByItemType(itemType);
  final resolve = resolveIndexUrl ?? _resolveIndexUrl;
  for (final url in movedOriginCandidates(installed, repos, offers)) {
    final resolved = await resolve(url);
    if (resolved == null) continue;
    final current = repos
        .where((r) => isSameRepo(r, Repo(jsonUrl: resolved)))
        .firstOrNull;
    if (current == null) continue;
    for (final source in installed) {
      if (source.repo?.jsonUrl != url) continue;
      await sourceRepository.save(source..repo = current);
    }
  }
}

Future<String?> _resolveIndexUrl(String url) async {
  final http = MClient.init(reqcopyWith: {'useDartHttpClient': true});
  return (await ExtensionStoreService.fetchStore(url, http))?.indexUrl;
}

/// Sets each installed extension's update from what the repositories offer
/// ([offers], by extension id), as [chooseUpdate] picks it, and installs it
/// straight away under [autoUpdate] when it comes from the extension's own
/// repository. One from another repository waits for the reader.
///
/// [readRepos] are the indexes that were read: an update is only taken back
/// once the repository it came from was read and no longer has it, not
/// because that repository could not be reached this time.
Future<void> applyExtensionUpdates({
  required Map<int, List<ExtensionOffer>> offers,
  required Set<String> readRepos,
  required bool autoUpdate,
  required String androidProxyServer,
  required ItemType itemType,
}) async {
  // A Mihon APK's sources are installed together: once per APK.
  final installedMihonGroups = <String>{};
  for (final installed in sourceRepository.getAddedByItemType(itemType)) {
    if (installed.isLocal ?? false) continue;
    final offer = chooseUpdate(installed, offers[installed.id] ?? const []);
    if (offer == null) {
      final from = (installed.updateRepo ?? installed.repo)?.jsonUrl;
      final pending =
          installed.updateRepo != null ||
          compareVersions(
                installed.version ?? '',
                installed.versionLast ?? '',
              ) <
              0;
      if (pending && (from == null || readRepos.contains(from))) {
        await sourceRepository.save(
          installed
            ..versionLast = installed.version
            ..updateRepo = null,
        );
      }
      continue;
    }
    final foreign =
        installed.repo != null && !isSameRepo(offer.repo, installed.repo);
    if (autoUpdate && !foreign) {
      if (installed.sourceCodeLanguage == SourceCodeLanguage.mihon &&
          !installedMihonGroups.add(mihonExtensionGroupKey(installed))) {
        continue;
      }
      await updateSource(
        offer.listing,
        androidProxyServer,
        offer.repo,
        itemType,
        listing: [
          for (final repoOffers in offers.values)
            for (final other in repoOffers)
              if (isSameRepo(other.repo, offer.repo)) other.listing,
        ],
      );
      continue;
    }
    if (installed.versionLast == offer.listing.version &&
        isSameRepo(installed.updateRepo, offer.repo)) {
      continue;
    }
    await sourceRepository.save(
      installed
        ..versionLast = offer.listing.version
        ..updateRepo = offer.repo,
    );
  }
}

/// Updates or reinstalls the installed [installed] from the repository its
/// update was found in ([reposForUpdate]), installing exactly that
/// repository's build. Says whether anything was installed; when the
/// repository no longer has anything newer, the update is taken back.
Future<bool> installExtensionUpdate({
  required Source installed,
  required List<Repo> repos,
  required String androidProxyServer,
  required ItemType itemType,
}) async {
  final anyVersion = (installed.sourceCode ?? '').isEmpty;
  final toAsk = reposForUpdate(repos, installed, anyVersion: anyVersion);
  Object? failure;
  StackTrace? failureStack;
  for (final repo in toAsk) {
    final List<Source> listed;
    try {
      listed = await fetchRepoSources(repo: repo, itemType: itemType);
    } catch (e, st) {
      failure = e;
      failureStack = st;
      continue;
    }
    final listing = listed.where((s) => s.id == installed.id).firstOrNull;
    if (listing == null || (listing.sourceCodeUrl ?? '').isEmpty) continue;
    final newer =
        compareVersions(installed.version ?? '', listing.version ?? '') < 0;
    if (!anyVersion && !newer) continue;
    await updateSource(
      listing,
      androidProxyServer,
      repo,
      itemType,
      listing: listed,
    );
    return true;
  }
  // Nothing reached: the update may still be there, so it stays offered and
  // the reason is told.
  if (failure != null) {
    Error.throwWithStackTrace(failure, failureStack!);
  }
  await sourceRepository.save(
    installed
      ..versionLast = installed.version
      ..updateRepo = null,
  );
  return false;
}

/// Installs [source] from [repo]. A Mihon source is installed with every
/// source of its APK that [listing] (the repository's listing) or the
/// database knows, since they share one install.
Future<void> updateSource(
  Source source,
  String androidProxyServer,
  Repo? repo,
  ItemType itemType, {
  Iterable<Source> listing = const [],
}) {
  final group = source.sourceCodeLanguage == SourceCodeLanguage.mihon
      ? [
          source,
          for (final sibling in listing)
            if (sibling.id != source.id &&
                belongsToSameMihonExtension(source, sibling))
              sibling,
        ]
      : [source];
  return _updateSources(group, androidProxyServer, repo, itemType);
}

Future<void> _updateSources(
  List<Source> sources,
  String androidProxyServer,
  Repo? repo,
  ItemType itemType, {
  String? sourceCodeOverride,
  bool includeStoredMihonSiblings = true,
  bool preserveInstalledFactoryAvailability = true,
  bool useProvidedVersionLast = false,
  bool reactivateUninstalledSources = false,
}) async {
  if (sources.isEmpty) return;
  final sourcesToUpdate = List<Source>.of(sources);
  if (includeStoredMihonSiblings &&
      sources.first.sourceCodeLanguage == SourceCodeLanguage.mihon) {
    final knownIds = sources.map((source) => source.id).toSet();
    final storedGroup = await isar.sources
        .filter()
        .sourceCodeUrlEqualTo(sources.first.sourceCodeUrl)
        .findAll();
    for (final storedSource in storedGroup) {
      if (knownIds.contains(storedSource.id) ||
          !belongsToSameMihonExtension(sources.first, storedSource)) {
        continue;
      }
      storedSource
        ..sourceCodeUrl = sources.first.sourceCodeUrl
        ..version = sources.first.version
        ..versionLast = sources.first.version
        ..iconUrl = sources.first.iconUrl
        ..appMinVerReq = sources.first.appMinVerReq
        ..repo = repo;
      sourcesToUpdate.add(storedSource);
    }
  }

  final http = MClient.init(reqcopyWith: {'useDartHttpClient': true});
  late final String sourceCode;
  if (sourceCodeOverride != null) {
    sourceCode = sourceCodeOverride;
  } else {
    final req = await http.get(Uri.parse(sources.first.sourceCodeUrl!));
    sourceCode =
        sources.first.sourceCodeLanguage == SourceCodeLanguage.mihon ||
            sources.first.sourceCodeLanguage == SourceCodeLanguage.aidoku
        ? base64.encode(req.bodyBytes)
        : req.body;
  }

  final updatedSources = <Source>[];
  for (final source in sourcesToUpdate) {
    final existingSource = await isar.sources.get(source.id!);
    final incomingMetadata = mihonSourceMetadata(source);
    final installedMetadata = existingSource == null
        ? null
        : mihonSourceMetadata(existingSource);
    final additionalParams = incomingMetadata == null
        ? source.additionalParams ?? ''
        : encodeMihonSourceMetadata(
            sourceId: incomingMetadata.sourceId,
            packageName: incomingMetadata.packageName,
            factoryAvailable: preserveInstalledFactoryAvailability
                ? installedMetadata?.factoryAvailable ??
                      incomingMetadata.factoryAvailable
                : incomingMetadata.factoryAvailable,
            extensionName: incomingMetadata.extensionName,
            packageLang: incomingMetadata.packageLang,
          );
    final existingPreferences = decodeMihonSourcePreferences(
      existingSource?.preferenceList,
    );

    Map<String, String> headers = {};
    bool? supportLatest;
    FilterList? filterList;
    List<SourcePreference>? preferenceList;
    source.sourceCode = sourceCode;
    if (source.sourceCodeLanguage == SourceCodeLanguage.mihon) {
      headers = await fetchHeadersDalvik(
        http,
        source,
        androidProxyServer,
        preferences: existingPreferences,
      );
      supportLatest = await fetchSupportLatestDalvik(
        http,
        source,
        androidProxyServer,
        preferences: existingPreferences,
      );
      filterList = await fetchFilterListDalvik(
        http,
        source,
        androidProxyServer,
        preferences: existingPreferences,
      );
      final freshPreferences = await fetchPreferencesDalvik(
        http,
        source,
        androidProxyServer,
        preferences: existingPreferences,
      );
      preferenceList = freshPreferences == null
          ? existingPreferences
          : mergeMihonPreferenceValues(freshPreferences, existingPreferences);
    } else if (source.sourceCodeLanguage == SourceCodeLanguage.aidoku) {
      final service = AidokuExtensionService(source);
      try {
        headers = service.getHeaders();
        supportLatest = service.supportsLatest;
        filterList = await service.fetchFilterList();
      } finally {
        service.dispose();
      }
    } else {
      headers = await getIsolateService.get<Map<String, String>>(
        source: source,
        serviceType: 'getHeaders',
      );
    }

    updatedSources.add(
      Source()
        ..headers = jsonEncode(headers)
        ..supportLatest = supportLatest
        ..filterList = filterList != null
            ? jsonEncode(filterList.toJson())
            : null
        ..preferenceList = preferenceList != null
            ? jsonEncode(preferenceList.map((e) => e.toJson()).toList())
            : null
        ..isAdded = true
        ..isActive =
            reactivateUninstalledSources && existingSource?.isAdded != true
            ? source.isActive ?? true
            : existingSource?.isActive ??
                  shouldEnableExtensionLanguageByDefault(
                    source.lang,
                    PlatformDispatcher.instance.locales,
                  )
        ..isPinned = existingSource?.isPinned ?? false
        ..lastUsed = existingSource?.lastUsed ?? false
        ..sourceCode = sourceCode
        ..sourceCodeUrl = source.sourceCodeUrl
        ..id = source.id
        ..apiUrl = source.apiUrl
        ..baseUrl = source.baseUrl
        ..dateFormat = source.dateFormat
        ..dateFormatLocale = source.dateFormatLocale
        ..hasCloudflare = source.hasCloudflare
        ..iconUrl = source.iconUrl
        ..typeSource = source.typeSource
        ..lang = source.lang
        ..isNsfw = source.isNsfw
        ..name = source.name
        ..version = source.version
        ..versionLast = useProvidedVersionLast
            ? source.versionLast ?? source.version
            : source.version
        ..itemType = itemType
        ..isFullData = source.isFullData ?? false
        ..appMinVerReq = source.appMinVerReq
        ..sourceCodeLanguage = source.sourceCodeLanguage
        ..additionalParams = additionalParams
        ..isObsolete = false
        ..notes = source.notes
        ..repo = repo ?? existingSource?.repo
        ..updatedAt = DateTime.now().millisecondsSinceEpoch,
    );
  }

  await dbWriteQueue.run(
    () => isar.writeTxn(() async => isar.sources.putAll(updatedSources)),
  );
}

Future<void> installMihonApkSources({
  required List<Source> sources,
  required String apkBase64,
  required String androidProxyServer,
  required ItemType itemType,
}) {
  if (sources.any(
    (source) => source.sourceCodeLanguage != SourceCodeLanguage.mihon,
  )) {
    throw ArgumentError.value(
      sources,
      'sources',
      'Every local APK source must use the Mihon bridge.',
    );
  }
  return _updateSources(
    sources,
    androidProxyServer,
    null,
    itemType,
    sourceCodeOverride: apkBase64,
    includeStoredMihonSiblings: false,
    preserveInstalledFactoryAvailability: false,
    useProvidedVersionLast: true,
    reactivateUninstalledSources: true,
  );
}

Source _newSource(
  Source source,
  Repo? repo,
  ItemType itemType, {
  required bool isActive,
}) => Source()
  ..sourceCodeUrl = source.sourceCodeUrl
  ..id = source.id
  ..sourceCode = source.sourceCode
  ..apiUrl = source.apiUrl
  ..baseUrl = source.baseUrl
  ..dateFormat = source.dateFormat
  ..dateFormatLocale = source.dateFormatLocale
  ..hasCloudflare = source.hasCloudflare
  ..iconUrl = source.iconUrl
  ..typeSource = source.typeSource
  ..lang = source.lang
  ..isNsfw = source.isNsfw
  ..isActive = isActive
  ..name = source.name
  ..version = source.version
  ..versionLast = source.version
  ..itemType = itemType
  ..sourceCodeLanguage = source.sourceCodeLanguage
  ..isFullData = source.isFullData ?? false
  ..appMinVerReq = source.appMinVerReq
  ..additionalParams = source.additionalParams
  ..isObsolete = false
  ..notes = source.notes
  ..repo = repo;

/// Queues [source] for the refresh's single write, stamped with the time it
/// would have been written on its own. A later write of the same source
/// replaces the earlier one but keeps its place in the write order.
void _markPending(Map<int, Source> pending, Source source) {
  pending[source.id!] = source
    ..updatedAt = DateTime.now().millisecondsSinceEpoch;
}

Future<Map<String, bool>> _savedExtensionLanguageStates(
  ItemType itemType,
) async {
  final sources = await isar.sources
      .filter()
      .itemTypeEqualTo(itemType)
      .findAll();
  final states = <String, bool>{};
  for (final source in sources) {
    final language = normalizeExtensionLanguageTag(source.lang);
    states.update(
      language,
      (isActive) => isActive || (source.isActive ?? false),
      ifAbsent: () => source.isActive ?? false,
    );
  }
  return states;
}

Future<void> checkIfSourceIsObsolete(
  List<Source> sourceList,
  Repo repo,
  ItemType itemType,
) async {
  if (sourceList.isEmpty) return;

  final sources = await sourceRepository.getNonLocalByItemType(itemType);

  if (sources.isEmpty) return;

  final sourceIds = sourceList
      .where((e) => e.id != null)
      .map((e) => e.id!)
      .toSet();

  if (sourceIds.isEmpty) return;

  final mihonExtensionGroups = sourceList
      .where((source) => source.sourceCodeLanguage == SourceCodeLanguage.mihon)
      .map(mihonExtensionGroupKey)
      .toSet();

  final toUpdate = <Source>[];
  final toDelete = <int>[];
  for (var source in sources) {
    final belongsToKnownMihonPackage =
        source.sourceCodeLanguage == SourceCodeLanguage.mihon &&
        mihonExtensionGroups.contains(mihonExtensionGroupKey(source));
    final isNowObsolete =
        !sourceIds.contains(source.id) &&
        !belongsToKnownMihonPackage &&
        source.repo?.jsonUrl == repo.jsonUrl;

    if (!(source.isAdded ?? false) && isNowObsolete) {
      // Not installed and gone from the repo: nothing to install, so
      // remove the dead row instead of leaving it in the browse list.
      toDelete.add(source.id!);
      continue;
    }
    if (source.isObsolete != isNowObsolete) {
      source.isObsolete = isNowObsolete;
      source.updatedAt = DateTime.now().millisecondsSinceEpoch;
      toUpdate.add(source);
    }
  }
  if (toUpdate.isNotEmpty) {
    await sourceRepository.putAll(toUpdate);
  }
  if (toDelete.isNotEmpty) {
    await sourceRepository.deleteAll(toDelete);
  }
}

/// Compares two versions, a pre-release such as `1.0.0-beta.1` coming before
/// `1.0.0` and `-beta.2` after `-beta.1`. Build metadata (`+127`) is ignored.
int compareVersions(String version1, String version2) {
  final (core1, preRelease1) = _splitVersion(version1);
  final (core2, preRelease2) = _splitVersion(version2);

  final v1Parts = core1.split('.');
  final v2Parts = core2.split('.');
  final maxLength = v1Parts.length > v2Parts.length
      ? v1Parts.length
      : v2Parts.length;

  for (var i = 0; i < maxLength; i++) {
    final v1Value = i < v1Parts.length ? _parseVersionPart(v1Parts[i]) : 0;
    final v2Value = i < v2Parts.length ? _parseVersionPart(v2Parts[i]) : 0;

    final comparison = v1Value.compareTo(v2Value);
    if (comparison != 0) return comparison;
  }

  return _comparePreReleases(preRelease1, preRelease2);
}

(String, String) _splitVersion(String version) {
  final clean = version
      .trim()
      .replaceFirst(RegExp(r'^[vV]'), '')
      .split('+')
      .first;
  final dash = clean.indexOf('-');
  if (dash == -1) return (clean, '');
  return (clean.substring(0, dash), clean.substring(dash + 1).toLowerCase());
}

int _comparePreReleases(String preRelease1, String preRelease2) {
  if (preRelease1 == preRelease2) return 0;
  // The final version comes after all of its pre-releases.
  if (preRelease1.isEmpty) return 1;
  if (preRelease2.isEmpty) return -1;

  final v1Parts = preRelease1.split('.');
  final v2Parts = preRelease2.split('.');
  final minLength = v1Parts.length < v2Parts.length
      ? v1Parts.length
      : v2Parts.length;

  for (var i = 0; i < minLength; i++) {
    final v1Value = int.tryParse(v1Parts[i]);
    final v2Value = int.tryParse(v2Parts[i]);

    final int comparison;
    if (v1Value != null && v2Value != null) {
      comparison = v1Value.compareTo(v2Value);
    } else if (v1Value != null) {
      comparison = -1;
    } else if (v2Value != null) {
      comparison = 1;
    } else {
      comparison = v1Parts[i].compareTo(v2Parts[i]).sign;
    }
    if (comparison != 0) return comparison;
  }

  return v1Parts.length.compareTo(v2Parts.length);
}

int _parseVersionPart(String part) {
  if (part.isEmpty) return 0;
  // Version components can carry non-numeric suffixes (pre-release/build tags
  // like "1727-r1234" or "0-beta") when they arrive unsanitised from external
  // source.json (appMinVerReq / version) or server release tags. Parse the
  // leading numeric run and ignore the rest instead of throwing
  // FormatException, which would break source listing and the update check.
  final match = RegExp(r'^\d+').firstMatch(part);
  return match == null ? 0 : int.parse(match.group(0)!);
}

Future<Map<String, String>> fetchHeadersDalvik(
  InterceptedClient client,
  Source source,
  String androidProxyServer, {
  List<SourcePreference> preferences = const [],
}) async {
  try {
    final name = source.itemType == ItemType.anime ? "Anime" : "Manga";
    final res = await postMihonBridge(
      client,
      mihonBridgeDalvikUri(androidProxyServer),
      body: {
        "method": "headers$name",
        "data": source.sourceCode,
        "preferences": mihonPreferencePayload(source, preferences),
      },
    );
    final data = jsonDecode(res.body);
    if (data is! List) return {};
    final Map<String, String> headers = {};
    for (var i = 0; i + 1 < data.length; i += 2) {
      headers[data[i].toString()] = data[i + 1].toString();
    }
    return headers;
  } catch (error, stackTrace) {
    recordError(error, stack: stackTrace, source: 'fetch_sources_list');
    return {};
  }
}

Future<bool> fetchSupportLatestDalvik(
  InterceptedClient client,
  Source source,
  String androidProxyServer, {
  List<SourcePreference> preferences = const [],
}) async {
  try {
    final name = source.itemType == ItemType.anime ? "Anime" : "Manga";
    final res = await postMihonBridge(
      client,
      mihonBridgeDalvikUri(androidProxyServer),
      body: {
        "method": "supportLatest$name",
        "data": source.sourceCode,
        "preferences": mihonPreferencePayload(source, preferences),
      },
    );
    return res.body.trim() == "true";
  } catch (error, stackTrace) {
    recordError(error, stack: stackTrace, source: 'fetch_sources_list');
    return false;
  }
}

Future<FilterList?> fetchFilterListDalvik(
  InterceptedClient client,
  Source source,
  String androidProxyServer, {
  List<SourcePreference> preferences = const [],
}) async {
  try {
    final name = source.itemType == ItemType.anime ? "Anime" : "Manga";
    final res = await postMihonBridge(
      client,
      mihonBridgeDalvikUri(androidProxyServer),
      body: {
        "method": "filters$name",
        "data": source.sourceCode,
        "preferences": mihonPreferencePayload(source, preferences),
      },
    );
    final data = jsonDecode(res.body);
    if (data is! List) return null;

    return FilterList(filtersFromJson(data));
  } catch (error, stackTrace) {
    recordError(error, stack: stackTrace, source: 'fetch_sources_list');
    return null;
  }
}

List<dynamic> filtersFromJson(List<dynamic> json) {
  return json.expand((e) sync* {
    if (e is! Map) return;
    if (e['name'] is String &&
        e['state'] is Map<String, dynamic> &&
        e['values'] is List) {
      yield SortFilter(
        "${e['name']}Filter",
        e['name'],
        SortState(e['state']['index'], e['state']['ascending'], null),
        (e['values'] as List)
            .map((e) => SelectFilterOption(e, e, null))
            .toList(),
        null,
      );
    } else if (e['name'] is String &&
        e['state'] is int &&
        (e['values'] is List || e['vals'] is List)) {
      yield SelectFilter(
        "${e['name']}Filter",
        e['name'],
        e['state'],
        e['vals'] is List
            ? (e['vals'] as List)
                  .map((e) => SelectFilterOption(e['first'], e['second'], null))
                  .toList()
            : e['values'] is List
            ? (e['values'] as List)
                  .map(
                    (e) => (e is Map)
                        ? SelectFilterOption(e['value'], e['value'], null)
                        : SelectFilterOption(e, e, null),
                  )
                  .toList()
            : [],
        "SelectFilter",
      );
    } else if (e['name'] is String && e['state'] is bool) {
      yield CheckBoxFilter(
        null,
        e['name'],
        e['id'] ?? e['name'],
        null,
        state: e['state'],
      );
    } else if (e['included'] is bool &&
        e['ignored'] is bool &&
        e['excluded'] is bool) {
      yield TriStateFilter(
        null,
        e['name'],
        e['id'] ?? e['name'],
        null,
        state: e['state'],
      );
    } else if (e['name'] is String && e['state'] is List) {
      yield GroupFilter(
        "${e['name']}Filter",
        e['name'],
        filtersFromJson((e['state'] as List)),
        "GroupFilter",
      );
    } else if (e['name'] is String && e['state'] is String) {
      yield TextFilter(
        "${e['name']}Filter",
        e['name'],
        null,
        state: e['state'],
      );
    } else if (e['name'] is String && e['state'] is int) {
      yield HeaderFilter(e['name'], "${e['name']}Filter");
    }
  }).toList();
}

Future<List<SourcePreference>?> fetchPreferencesDalvik(
  InterceptedClient client,
  Source source,
  String androidProxyServer, {
  List<SourcePreference> preferences = const [],
  String? changedPreferenceKey,
  MihonPreferenceApplyMode preferenceApplyMode =
      MihonPreferenceApplyMode.bootstrap,
}) async {
  try {
    final name = source.itemType == ItemType.anime ? "Anime" : "Manga";
    final res = await postMihonBridge(
      client,
      mihonBridgeDalvikUri(androidProxyServer),
      body: {
        "method": changedPreferenceKey == null
            ? "preferences$name"
            : "setPreference$name",
        "data": source.sourceCode,
        "preferences": mihonPreferencePayload(
          source,
          preferences,
          changedPreferenceKey: changedPreferenceKey,
          applyMode: preferenceApplyMode,
        ),
      },
    );
    final data = jsonDecode(res.body);
    if (data is! List) return null;
    return data
        .whereType<Map<String, dynamic>>()
        .map(
          (e) => SourcePreference.fromJson(e)
            ..id = null
            ..sourceId = source.id,
        )
        .toList();
  } catch (error, stackTrace) {
    recordError(error, stack: stackTrace, source: 'fetch_sources_list');
    return null;
  }
}

Future<List<MihonSourceDescriptor>?> fetchMihonSourceDescriptors(
  InterceptedClient client,
  Source source,
  String androidProxyServer, {
  List<SourcePreference> preferences = const [],
  MihonPreferenceApplyMode preferenceApplyMode =
      MihonPreferenceApplyMode.bootstrap,
}) async {
  try {
    final name = source.itemType == ItemType.anime ? 'Anime' : 'Manga';
    final res = await postMihonBridge(
      client,
      mihonBridgeDalvikUri(androidProxyServer),
      body: {
        'method': 'sources$name',
        'data': source.sourceCode,
        'preferences': mihonPreferencePayload(
          source,
          preferences,
          applyMode: preferenceApplyMode,
        ),
      },
    );
    final data = jsonDecode(res.body) as List;
    return data
        .map(
          (descriptor) => MihonSourceDescriptor.fromJson(
            descriptor as Map<String, dynamic>,
          ),
        )
        .toList();
  } catch (_) {
    return null;
  }
}

Future<MihonExtensionDescriptor> fetchMihonExtensionDescriptor(
  InterceptedClient client,
  Source source,
  String androidProxyServer,
) async {
  final res = await postMihonBridge(
    client,
    mihonBridgeDalvikUri(androidProxyServer),
    body: {
      'method': 'extensionInfo',
      'data': source.sourceCode,
      'preferences': mihonPreferencePayload(source, const []),
    },
  );
  final data = jsonDecode(res.body);
  if (data is! Map) {
    throw const FormatException(
      'Mihon bridge returned invalid extension metadata.',
    );
  }
  return MihonExtensionDescriptor.fromJson(
    data.map((key, value) => MapEntry(key.toString(), value)),
  );
}

String _convertLang(dynamic e) {
  return ExtensionStoreService.convertLnreaderLang(e);
}
