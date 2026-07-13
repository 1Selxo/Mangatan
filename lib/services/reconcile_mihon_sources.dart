import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/mihon/bridge_protocol.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/source.dart';

Future<void> reconcileMihonFactorySources(
  Source template,
  List<MihonSourceDescriptor> descriptors,
) async {
  if (template.sourceCodeLanguage != SourceCodeLanguage.mihon ||
      descriptors.isEmpty) {
    return;
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
    }
  }

  await isar.writeTxn(() => isar.sources.putAll(updates));
}
