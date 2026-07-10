import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:http_interceptor/http_interceptor.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/model/filter.dart';
import 'package:mangayomi/eval/model/source_preference.dart';
import 'package:mangayomi/eval/mihon/bridge_protocol.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/services/http/m_client.dart';
import 'package:mangayomi/services/isolate_service.dart';
import 'package:mangayomi/utils/extension_language_defaults.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<void> fetchSourcesList({
  int? id,
  required bool refresh,
  required String androidProxyServer,
  required bool autoUpdateExtensions,
  required ItemType itemType,
  required Repo? repo,
}) async {
  final http = MClient.init(reqcopyWith: {'useDartHttpClient': true});
  final url = repo?.jsonUrl;
  if (url == null) return;

  final req = await http.get(Uri.parse(url));
  final info = await PackageInfo.fromPlatform();

  final sourceList = (jsonDecode(req.body) as List)
      .expand((e) sync* {
        if (e['name'] != null &&
            e['pkg'] != null &&
            e['version'] != null &&
            e['code'] != null &&
            e['lang'] != null &&
            e['nsfw'] != null &&
            e['sources'] != null &&
            e['apk'] != null) {
          final repoUrl = url.replaceAll("/index.min.json", "");
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
              ..sourceCodeUrl = "$repoUrl/apk/${e['apk']}"
              ..sourceCodeLanguage = SourceCodeLanguage.mihon
              ..repo = repo
              ..additionalParams = encodeMihonSourceMetadata(
                sourceId: source['id'],
                packageName: e['pkg'],
              )
              ..itemType =
                  (e['pkg'] as String).startsWith(
                    "eu.kanade.tachiyomi.animeextension",
                  )
                  ? ItemType.anime
                  : ItemType.manga
              ..iconUrl = "$repoUrl/icon/${e['pkg']}.png"
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
            source.itemType == itemType &&
            source.appMinVerReq != null &&
            compareVersions(info.version, source.appMinVerReq!) > -1,
      )
      .toList();

  if (id != null) {
    final matchingSource = sourceList.firstWhere(
      (source) => source.id == id,
      orElse: () => Source(),
    );
    if (matchingSource.id != null && matchingSource.sourceCodeUrl!.isNotEmpty) {
      final installGroup =
          matchingSource.sourceCodeLanguage == SourceCodeLanguage.mihon
          ? sourceList
                .where(
                  (source) =>
                      belongsToSameMihonExtension(matchingSource, source),
                )
                .toList()
          : [matchingSource];
      await _updateSources(installGroup, androidProxyServer, repo, itemType);
    }
  } else {
    final languageStates = await _savedExtensionLanguageStates(itemType);
    final deviceLocales = PlatformDispatcher.instance.locales;
    final updateGroups = <String, List<Source>>{};
    for (var source in sourceList) {
      final existingSource = await isar.sources.get(source.id!);
      if (existingSource == null) {
        final isActive = extensionLanguageEnabledForNewSource(
          source.lang,
          savedLanguageStates: languageStates,
          deviceLocales: deviceLocales,
        );
        await _addNewSource(source, repo, itemType, isActive: isActive);
        continue;
      }
      final existingMihonMetadata = mihonSourceMetadata(existingSource);
      final catalogMihonMetadata = mihonSourceMetadata(source);
      final updatedAdditionalParams = catalogMihonMetadata == null
          ? source.additionalParams
          : encodeMihonSourceMetadata(
              sourceId: catalogMihonMetadata.sourceId,
              packageName: catalogMihonMetadata.packageName,
              factoryAvailable: existingMihonMetadata?.factoryAvailable ?? true,
            );
      if (source.sourceCodeLanguage == SourceCodeLanguage.mihon &&
          existingSource.additionalParams != updatedAdditionalParams) {
        await isar.writeTxn(() async {
          isar.sources.put(
            existingSource
              ..additionalParams = updatedAdditionalParams
              ..sourceCodeUrl = source.sourceCodeUrl
              ..repo = repo,
          );
        });
      }
      final shouldUpdate =
          (existingSource.isAdded ?? false) &&
          compareVersions(existingSource.version!, source.version!) < 0;
      if (!shouldUpdate) continue;
      if (autoUpdateExtensions) {
        final groupKey = source.sourceCodeLanguage == SourceCodeLanguage.mihon
            ? mihonExtensionGroupKey(source)
            : source.id.toString();
        updateGroups.putIfAbsent(groupKey, () => []).add(source);
      } else {
        await isar.writeTxn(() async {
          isar.sources.put(existingSource..versionLast = source.version);
        });
      }
    }
    for (final group in updateGroups.values) {
      final fullGroup =
          group.first.sourceCodeLanguage == SourceCodeLanguage.mihon
          ? sourceList
                .where(
                  (source) => belongsToSameMihonExtension(group.first, source),
                )
                .toList()
          : group;
      await _updateSources(fullGroup, androidProxyServer, repo, itemType);
    }

    final mihonGroups = <String, List<Source>>{};
    for (final source in sourceList.where(
      (source) => source.sourceCodeLanguage == SourceCodeLanguage.mihon,
    )) {
      mihonGroups
          .putIfAbsent(mihonExtensionGroupKey(source), () => [])
          .add(source);
    }
    for (final group in mihonGroups.values) {
      final installedStates = await Future.wait(
        group.map((source) => isar.sources.get(source.id!)),
      );
      final hasInstalledSource = installedStates.any(
        (source) => source?.isAdded ?? false,
      );
      final hasMissingSibling = installedStates.any(
        (source) => !(source?.isAdded ?? false),
      );
      if (hasInstalledSource && hasMissingSibling) {
        await _updateSources(group, androidProxyServer, repo, itemType);
      }
    }
  }

  checkIfSourceIsObsolete(sourceList, repo!, itemType);
}

Future<void> _updateSources(
  List<Source> sources,
  String androidProxyServer,
  Repo? repo,
  ItemType itemType,
) async {
  if (sources.isEmpty) return;
  final sourcesToUpdate = List<Source>.of(sources);
  if (sources.first.sourceCodeLanguage == SourceCodeLanguage.mihon) {
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
  final req = await http.get(Uri.parse(sources.first.sourceCodeUrl!));
  final sourceCode =
      sources.first.sourceCodeLanguage == SourceCodeLanguage.mihon
      ? base64.encode(req.bodyBytes)
      : req.body;

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
            factoryAvailable:
                installedMetadata?.factoryAvailable ??
                incomingMetadata.factoryAvailable,
          );
    final existingPreferences = _decodePreferences(
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
            existingSource?.isActive ??
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
        ..versionLast = source.version
        ..itemType = itemType
        ..isFullData = source.isFullData ?? false
        ..appMinVerReq = source.appMinVerReq
        ..sourceCodeLanguage = source.sourceCodeLanguage
        ..additionalParams = additionalParams
        ..isObsolete = false
        ..notes = source.notes
        ..repo = repo
        ..updatedAt = DateTime.now().millisecondsSinceEpoch,
    );
  }

  await isar.writeTxn(() async => isar.sources.putAll(updatedSources));
}

List<SourcePreference> _decodePreferences(String? preferenceList) {
  if (preferenceList == null || preferenceList.isEmpty) return [];
  try {
    return (jsonDecode(preferenceList) as List)
        .map((preference) => SourcePreference.fromJson(preference))
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> _addNewSource(
  Source source,
  Repo? repo,
  ItemType itemType, {
  required bool isActive,
}) async {
  final newSource = Source()
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
    ..repo = repo
    ..updatedAt = DateTime.now().millisecondsSinceEpoch;
  await isar.writeTxn(() async => isar.sources.put(newSource));
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

  final sources = await isar.sources
      .filter()
      .idIsNotNull()
      .itemTypeEqualTo(itemType)
      .and()
      .isLocalEqualTo(false)
      .findAll();

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
  for (var source in sources) {
    final belongsToKnownMihonPackage =
        source.sourceCodeLanguage == SourceCodeLanguage.mihon &&
        mihonExtensionGroups.contains(mihonExtensionGroupKey(source));
    final isNowObsolete =
        !sourceIds.contains(source.id) &&
        !belongsToKnownMihonPackage &&
        source.repo?.jsonUrl == repo.jsonUrl;

    if (source.isObsolete != isNowObsolete) {
      source.isObsolete = isNowObsolete;
      source.updatedAt = DateTime.now().millisecondsSinceEpoch;
      toUpdate.add(source);
    }
  }
  if (toUpdate.isEmpty) return;

  await isar.writeTxn(() => isar.sources.putAll(toUpdate));
}

int compareVersions(String version1, String version2) {
  final v1Parts = version1.split('.');
  final v2Parts = version2.split('.');
  final minLength = v1Parts.length < v2Parts.length
      ? v1Parts.length
      : v2Parts.length;

  for (var i = 0; i < minLength; i++) {
    final v1Value = int.parse(v1Parts[i].padRight(2, '0'));
    final v2Value = int.parse(v2Parts[i].padRight(2, '0'));

    final comparison = v1Value.compareTo(v2Value);
    if (comparison != 0) return comparison;
  }

  return v1Parts.length.compareTo(v2Parts.length);
}

Future<Map<String, String>> fetchHeadersDalvik(
  InterceptedClient client,
  Source source,
  String androidProxyServer, {
  List<SourcePreference> preferences = const [],
}) async {
  try {
    final name = source.itemType == ItemType.anime ? "Anime" : "Manga";
    final res = await client.post(
      Uri.parse("$androidProxyServer/dalvik"),
      body: jsonEncode({
        "method": "headers$name",
        "data": source.sourceCode,
        "preferences": mihonPreferencePayload(source, preferences),
      }),
    );
    final data = jsonDecode(res.body) as List;
    final Map<String, String> headers = {};
    for (var i = 0; i + 1 < data.length; i += 2) {
      headers[data[i]] = data[i + 1];
    }
    return headers;
  } catch (_) {
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
    final res = await client.post(
      Uri.parse("$androidProxyServer/dalvik"),
      body: jsonEncode({
        "method": "supportLatest$name",
        "data": source.sourceCode,
        "preferences": mihonPreferencePayload(source, preferences),
      }),
    );
    return res.body.trim() == "true";
  } catch (_) {
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
    final res = await client.post(
      Uri.parse("$androidProxyServer/dalvik"),
      body: jsonEncode({
        "method": "filters$name",
        "data": source.sourceCode,
        "preferences": mihonPreferencePayload(source, preferences),
      }),
    );
    final data = jsonDecode(res.body) as List;

    return FilterList(filtersFromJson(data));
  } catch (_) {
    return null;
  }
}

List<dynamic> filtersFromJson(List<dynamic> json) {
  return json.expand((e) sync* {
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
}) async {
  try {
    final name = source.itemType == ItemType.anime ? "Anime" : "Manga";
    final res = await client.post(
      Uri.parse("$androidProxyServer/dalvik"),
      body: jsonEncode({
        "method": changedPreferenceKey == null
            ? "preferences$name"
            : "setPreference$name",
        "data": source.sourceCode,
        "preferences": mihonPreferencePayload(
          source,
          preferences,
          changedPreferenceKey: changedPreferenceKey,
        ),
      }),
    );
    final data = jsonDecode(res.body) as List;
    return data
        .map(
          (e) => SourcePreference.fromJson(e)
            ..id = null
            ..sourceId = source.id,
        )
        .toList();
  } catch (_) {
    return null;
  }
}

Future<List<MihonSourceDescriptor>?> fetchMihonSourceDescriptors(
  InterceptedClient client,
  Source source,
  String androidProxyServer, {
  List<SourcePreference> preferences = const [],
}) async {
  try {
    final name = source.itemType == ItemType.anime ? 'Anime' : 'Manga';
    final res = await client.post(
      Uri.parse('$androidProxyServer/dalvik'),
      body: jsonEncode({
        'method': 'sources$name',
        'data': source.sourceCode,
        'preferences': mihonPreferencePayload(source, preferences),
      }),
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

String _convertLang(dynamic e) {
  final lang = e['lang'];
  if (lang is String) {
    switch (lang) {
      case "‎العربية":
        return "ar";
      case "中文, 汉语, 漢語":
        return "zh";
      case "English":
        return "en";
      case "Français":
        return "fr";
      case "Bahasa Indonesia":
        return "id";
      case "日本語":
        return "ja";
      case "조선말, 한국어":
        return "ko";
      case "Polski":
        return "pl";
      case "Português":
        return "pt";
      case "Русский":
        return "ru";
      case "Español":
        return "es";
      case "ไทย":
        return "th";
      case "Türkçe":
        return "tr";
      case "Українська":
        return "uk";
      case "Tiếng Việt":
        return "vi";
      default:
        return "all";
    }
  }
  return "all";
}
