import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/model/source_preference.dart';
import 'package:mangayomi/eval/mihon/bridge_protocol.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/source.dart';

class UninstallExtensionResult {
  const UninstallExtensionResult({required this.removedObsoleteSourceIds});

  final List<int> removedObsoleteSourceIds;
}

UninstallExtensionResult uninstallExtension(Source selectedSource) {
  final sources = _extensionSources(selectedSource);
  final sourceIds = sources.map((source) => source.id).nonNulls.toList();
  final preferenceIds = isar.sourcePreferences
      .filter()
      .anyOf(sourceIds, (query, id) => query.sourceIdEqualTo(id))
      .findAllSync()
      .map((preference) => preference.id)
      .nonNulls
      .toList();
  final stringPreferenceIds = isar.sourcePreferenceStringValues
      .filter()
      .anyOf(sourceIds, (query, id) => query.sourceIdEqualTo(id))
      .findAllSync()
      .map((preference) => preference.id)
      .toList();
  final obsoleteIds = sources
      .where((source) => source.isObsolete ?? false)
      .map((source) => source.id)
      .nonNulls
      .toList();

  isar.writeTxnSync(() {
    for (final source in sources) {
      if (source.id == null) continue;
      if (source.isObsolete ?? false) {
        isar.sources.deleteSync(source.id!);
      } else {
        isar.sources.putSync(
          source
            ..sourceCode = ''
            ..isAdded = false
            ..isPinned = false
            ..updatedAt = DateTime.now().millisecondsSinceEpoch,
        );
      }
    }
    isar.sourcePreferences.deleteAllSync(preferenceIds);
    isar.sourcePreferenceStringValues.deleteAllSync(stringPreferenceIds);
  });

  return UninstallExtensionResult(removedObsoleteSourceIds: obsoleteIds);
}

List<Source> _extensionSources(Source selectedSource) {
  if (selectedSource.sourceCodeLanguage != SourceCodeLanguage.mihon) {
    return [selectedSource];
  }
  return isar.sources
      .filter()
      .sourceCodeUrlEqualTo(selectedSource.sourceCodeUrl)
      .findAllSync()
      .where((source) => belongsToSameMihonExtension(selectedSource, source))
      .toList();
}
