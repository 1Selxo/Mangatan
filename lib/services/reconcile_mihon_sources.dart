import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/mihon/bridge_protocol.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupPreference.pb.dart';
import 'package:mangayomi/services/fetch_sources_list.dart';
import 'package:mangayomi/services/http/m_client.dart';
import 'package:mangayomi/services/m_extension_server.dart';
import 'package:mangayomi/services/mihon_source_preferences.dart';
import 'package:mangayomi/services/sync/chimahon_source_preferences_adapter.dart';

final refreshInstalledMihonFactorySourcesProvider =
    FutureProvider<MihonFactoryRefreshResult>(
      refreshInstalledMihonFactorySources,
    );

class MihonFactoryReconcileResult {
  const MihonFactoryReconcileResult({
    this.sourcesByNativeId = const {},
    this.created = 0,
    this.updated = 0,
    this.unavailable = 0,
    this.rebound = 0,
    this.detached = 0,
  });

  final Map<String, Source> sourcesByNativeId;
  final int created;
  final int updated;
  final int unavailable;
  final int rebound;
  final int detached;

  MihonFactoryReconcileResult operator +(MihonFactoryReconcileResult other) =>
      MihonFactoryReconcileResult(
        sourcesByNativeId: {...sourcesByNativeId, ...other.sourcesByNativeId},
        created: created + other.created,
        updated: updated + other.updated,
        unavailable: unavailable + other.unavailable,
        rebound: rebound + other.rebound,
        detached: detached + other.detached,
      );
}

class MihonFactoryRefreshResult {
  const MihonFactoryRefreshResult({
    this.groupsReconciled = 0,
    this.reconciliation = const MihonFactoryReconcileResult(),
    this.unresolvedGroups = 0,
  });

  final int groupsReconciled;
  final MihonFactoryReconcileResult reconciliation;
  final int unresolvedGroups;
}

/// Refreshes the children exposed by installed Mihon source factories.
///
/// Factory extensions can derive their children from preferences. Jellyfin,
/// for example, exposes one source per configured server/library. A Chimahon
/// restore updates those preferences without visiting the extension screen,
/// so discovery must also run as part of restore before native source IDs can
/// be rebound to local [Source] rows.
Future<MihonFactoryRefreshResult> refreshInstalledMihonFactorySources(
  Ref ref, {
  Iterable<BackupSourcePreferences> remoteSourcePreferences = const [],
  bool replacePresentPreferences = false,
}) async {
  final candidates = isar.sources
      .where()
      .findAllSync()
      .where(
        (source) =>
            source.sourceCodeLanguage == SourceCodeLanguage.mihon &&
            source.isAdded == true &&
            source.sourceCode?.isNotEmpty == true &&
            mihonSourceMetadata(source) != null,
      )
      .toList(growable: false);
  final groups = <String, List<Source>>{};
  for (final source in candidates) {
    groups.putIfAbsent(mihonExtensionGroupKey(source), () => []).add(source);
  }

  final client = MClient.init(reqcopyWith: {'useDartHttpClient': true});
  var reconciledGroups = 0;
  var unresolvedGroups = 0;
  var aggregate = const MihonFactoryReconcileResult();
  const sourcePreferencesAdapter = ChimahonSourcePreferencesAdapter();
  for (final sources in groups.values) {
    sources.sort((left, right) {
      final active =
          (right.isActive == true ? 1 : 0) - (left.isActive == true ? 1 : 0);
      if (active != 0) return active;
      return (left.id ?? 0).compareTo(right.id ?? 0);
    });
    var template = sources.first;
    Set<String>? previousDescriptorIds;
    var groupReconciled = false;
    var groupFailed = false;
    try {
      final proxyServer = await prepareMihonBridge(ref, template);
      for (var pass = 0; pass < 3; pass++) {
        final currentGroup =
            (await isar.sources
                    .filter()
                    .sourceCodeUrlEqualTo(template.sourceCodeUrl)
                    .findAll())
                .where(
                  (source) => belongsToSameMihonExtension(template, source),
                )
                .toList();
        if (currentGroup.isEmpty) break;
        template = currentGroup.firstWhere(
          (source) => source.id == template.id,
          orElse: () => currentGroup.first,
        );

        // New factory children have no local schema yet. Query it first so a
        // deferred Chimahon store can be decoded and persisted for that child.
        for (final source in currentGroup) {
          final persisted = loadPersistedMihonSourcePreferences(isar, source);
          final fresh = await fetchPreferencesDalvik(
            client,
            source,
            proxyServer,
            preferences: persisted,
            preferenceApplyMode: replacePresentPreferences
                ? MihonPreferenceApplyMode.replacePresent
                : MihonPreferenceApplyMode.bootstrap,
          );
          if (fresh == null) continue;
          final merged = mergeMihonPreferenceValues(fresh, persisted);
          source.preferenceList = jsonEncode(
            merged.map((preference) => preference.toJson()).toList(),
          );
          await isar.writeTxn(() => isar.sources.put(source));
        }
        if (remoteSourcePreferences.isNotEmpty) {
          sourcePreferencesAdapter.importInto(
            database: isar,
            sourcePreferences: remoteSourcePreferences,
          );
        }

        List<MihonSourceDescriptor>? descriptors;
        for (final source in currentGroup) {
          final refreshed = await fetchMihonSourceDescriptors(
            client,
            source,
            proxyServer,
            preferences: loadPersistedMihonSourcePreferences(isar, source),
            preferenceApplyMode: replacePresentPreferences
                ? MihonPreferenceApplyMode.replacePresent
                : MihonPreferenceApplyMode.bootstrap,
          );
          if (refreshed != null && refreshed.isNotEmpty) {
            descriptors = refreshed;
          }
        }
        if (descriptors == null || descriptors.isEmpty) break;
        final descriptorIds = descriptors.map((item) => item.id).toSet();
        aggregate += await reconcileMihonFactorySources(template, descriptors);
        groupReconciled = true;
        if (previousDescriptorIds != null &&
            previousDescriptorIds.length == descriptorIds.length &&
            previousDescriptorIds.containsAll(descriptorIds)) {
          break;
        }
        previousDescriptorIds = descriptorIds;
      }
    } on Object {
      groupFailed = true;
    }
    if (groupReconciled) {
      reconciledGroups++;
    } else {
      unresolvedGroups++;
    }
    if (groupFailed && groupReconciled) unresolvedGroups++;
  }
  return MihonFactoryRefreshResult(
    groupsReconciled: reconciledGroups,
    reconciliation: aggregate,
    unresolvedGroups: unresolvedGroups,
  );
}

Future<MihonFactoryReconcileResult> reconcileMihonFactorySources(
  Source template,
  List<MihonSourceDescriptor> descriptors,
) async {
  if (template.sourceCodeLanguage != SourceCodeLanguage.mihon ||
      descriptors.isEmpty) {
    return const MihonFactoryReconcileResult();
  }

  final packageName = mihonSourceMetadata(template)?.packageName ?? '';
  final extensionName = mihonSourceMetadata(template)?.extensionName;
  final packageLang = mihonSourceMetadata(template)?.packageLang;
  final group = await isar.sources
      .filter()
      .sourceCodeUrlEqualTo(template.sourceCodeUrl)
      .findAll();
  final groupSources = group
      .where((source) => belongsToSameMihonExtension(template, source))
      .toList();
  final byNativeId = <String, Source>{};
  for (final source in groupSources) {
    final metadata = mihonSourceMetadata(source);
    if (metadata != null) byNativeId[metadata.sourceId] = source;
  }
  final descriptorIds = descriptors.map((descriptor) => descriptor.id).toSet();
  final now = DateTime.now().millisecondsSinceEpoch;
  final updates = <Source>[];
  var created = 0;
  var updated = 0;
  var unavailable = 0;

  for (final descriptor in descriptors) {
    final existing = byNativeId[descriptor.id];
    if (existing != null) {
      final metadata = mihonSourceMetadata(existing);
      existing
        ..name = descriptor.name
        ..lang = descriptor.lang
        ..baseUrl = descriptor.baseUrl
        ..isActive = metadata?.factoryAvailable == false
            ? true
            : existing.isActive
        ..additionalParams = encodeMihonSourceMetadata(
          sourceId: descriptor.id,
          packageName: packageName,
          extensionName: extensionName,
          packageLang: packageLang,
        )
        ..isObsolete = false
        ..updatedAt = now;
      updates.add(existing);
      updated++;
      continue;
    }

    updates.add(
      Source()
        ..id = mihonLocalSourceId(descriptor.id)
        ..name = descriptor.name
        ..baseUrl = descriptor.baseUrl
        ..lang = descriptor.lang
        ..isActive = true
        ..isAdded = true
        ..isPinned = false
        ..isNsfw = template.isNsfw
        ..sourceCode = template.sourceCode
        ..sourceCodeUrl = template.sourceCodeUrl
        ..typeSource = template.typeSource
        ..iconUrl = template.iconUrl
        ..isFullData = template.isFullData
        ..hasCloudflare = template.hasCloudflare
        ..lastUsed = false
        ..dateFormat = template.dateFormat
        ..dateFormatLocale = template.dateFormatLocale
        ..apiUrl = template.apiUrl
        ..version = template.version
        ..versionLast = template.versionLast
        ..headers = template.headers
        ..supportLatest = template.supportLatest
        ..filterList = template.filterList
        ..preferenceList = null
        ..itemType = template.itemType
        ..appMinVerReq = template.appMinVerReq
        ..additionalParams = encodeMihonSourceMetadata(
          sourceId: descriptor.id,
          packageName: packageName,
          extensionName: extensionName,
          packageLang: packageLang,
        )
        ..isLocal = false
        ..isObsolete = false
        ..sourceCodeLanguage = SourceCodeLanguage.mihon
        ..notes = template.notes
        ..repo = template.repo
        ..updatedAt = now,
    );
    created++;
  }

  for (final source in groupSources) {
    final nativeId = mihonSourceMetadata(source)?.sourceId;
    if (nativeId != null && !descriptorIds.contains(nativeId)) {
      final metadata = mihonSourceMetadata(source);
      updates.add(
        source
          ..isActive = false
          ..additionalParams = encodeMihonSourceMetadata(
            sourceId: nativeId,
            packageName: metadata?.packageName ?? packageName,
            factoryAvailable: false,
            extensionName: metadata?.extensionName ?? extensionName,
            packageLang: metadata?.packageLang ?? packageLang,
          )
          ..updatedAt = now,
      );
      unavailable++;
    }
  }

  final reconciledByNativeId = <String, Source>{
    for (final source in updates)
      if (mihonSourceMetadata(source) case final metadata?
          when metadata.factoryAvailable)
        metadata.sourceId: source,
  };
  final localMangas = await isar.mangas.where().findAll();
  final mangaUpdates = localMangas
      .where((manga) {
        var nativeId = manga.mihonSourceId;
        var changed = false;
        if (nativeId == null && manga.sourceId != null) {
          final priorSource = groupSources
              .where((source) => source.id == manga.sourceId)
              .firstOrNull;
          nativeId = priorSource == null
              ? null
              : mihonSourceMetadata(priorSource)?.sourceId;
          manga.mihonSourceId = nativeId;
          changed = nativeId != null;
        }
        final target = nativeId == null ? null : reconciledByNativeId[nativeId];
        final priorSourceBelongsToGroup = groupSources.any(
          (source) => source.id == manga.sourceId,
        );
        if (target == null || manga.itemType != target.itemType) {
          if (nativeId != null &&
              priorSourceBelongsToGroup &&
              manga.sourceId != null) {
            manga.sourceId = null;
            changed = true;
          }
          return changed;
        }
        changed =
            changed ||
            manga.sourceId != target.id ||
            manga.source != target.name ||
            manga.lang != target.lang;
        manga
          ..sourceId = target.id
          ..source = target.name
          ..lang = target.lang;
        return changed;
      })
      .toList(growable: false);

  await isar.writeTxn(() async {
    await isar.sources.putAll(updates);
    if (mangaUpdates.isNotEmpty) await isar.mangas.putAll(mangaUpdates);
  });
  final detached = mangaUpdates
      .where((manga) => manga.sourceId == null && manga.mihonSourceId != null)
      .length;
  final rebound = mangaUpdates.length - detached;
  return MihonFactoryReconcileResult(
    sourcesByNativeId: Map.unmodifiable(reconciledByNativeId),
    created: created,
    updated: updated,
    unavailable: unavailable,
    rebound: rebound,
    detached: detached,
  );
}
