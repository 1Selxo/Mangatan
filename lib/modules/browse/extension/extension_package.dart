import 'package:mangayomi/eval/mihon/bridge_protocol.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/services/fetch_sources_list.dart';

/// A single installable artifact behind one or more Extensions-tab rows.
///
/// Mihon APKs can expose many runtime [Source]s. Those sources remain separate
/// in the database and Sources tab. Available packages are presented once per
/// enabled source language; installed and update packages are presented once.
class ExtensionPackage {
  ExtensionPackage._(this.sources)
    : source = _selectSource(sources),
      _metadata = _selectMetadata(sources);

  final List<Source> sources;
  final Source source;
  final MihonSourceMetadata? _metadata;

  String get name {
    final extensionName = _metadata?.extensionName;
    return extensionName?.isNotEmpty == true
        ? extensionName!
        : source.name ?? '';
  }

  String get installedLang {
    final sourceLanguages = sources
        .map((source) => source.lang)
        .whereType<String>()
        .where((lang) => lang.isNotEmpty)
        .toSet();
    if (sourceLanguages.length > 1) return 'all';
    if (sourceLanguages.length == 1) return sourceLanguages.single;

    final packageLang = _metadata?.packageLang;
    if (packageLang?.isNotEmpty == true) return packageLang!;
    if ((_metadata?.packageName ?? '').contains('.all.')) return 'all';
    return '';
  }

  bool get hasInstalledCode =>
      sources.any((source) => source.sourceCode?.isNotEmpty ?? false);

  bool get isInstalled =>
      hasInstalledCode || sources.any((source) => source.isAdded ?? false);

  bool get updateAvailable => sources.any(_sourceHasUpdate);

  bool get isNsfw => sources.any((source) => source.isNsfw ?? false);

  ExtensionCatalogEntry get installedEntry => ExtensionCatalogEntry._(
    package: this,
    source: source,
    name: name,
    lang: installedLang,
    section: updateAvailable
        ? ExtensionCatalogSection.update
        : ExtensionCatalogSection.installed,
  );

  Iterable<ExtensionCatalogEntry> get availableEntries => sources
      .where((source) => source.isActive ?? false)
      .map(
        (source) => ExtensionCatalogEntry._(
          package: this,
          source: source,
          name: source.name?.isNotEmpty == true ? source.name! : name,
          lang: source.lang ?? '',
          section: ExtensionCatalogSection.available,
        ),
      );

  Iterable<ExtensionCatalogEntry> get catalogEntries =>
      isInstalled ? [installedEntry] : availableEntries;

  bool matchesQuery(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    if (name.toLowerCase().contains(normalized)) return true;

    return sources.any((source) {
      final metadata = mihonSourceMetadata(source);
      return (source.name?.toLowerCase().contains(normalized) ?? false) ||
          (source.baseUrl?.toLowerCase().contains(normalized) ?? false) ||
          (metadata?.sourceId.toLowerCase().contains(normalized) ?? false);
    });
  }
}

class ExtensionCatalogEntry {
  const ExtensionCatalogEntry._({
    required this.package,
    required this.source,
    required this.name,
    required this.lang,
    required this.section,
  });

  final ExtensionPackage package;
  final Source source;
  final String name;
  final String lang;
  final ExtensionCatalogSection section;
}

enum ExtensionCatalogSection { update, installed, available }

List<ExtensionPackage> groupExtensionPackages(Iterable<Source> sources) {
  final grouped = <String, List<Source>>{};
  for (final source in sources) {
    final key = source.sourceCodeLanguage == SourceCodeLanguage.mihon
        ? 'mihon:${mihonExtensionGroupKey(source)}'
        : 'source:${source.id}';
    grouped.putIfAbsent(key, () => []).add(source);
  }
  return grouped.values.map(ExtensionPackage._).toList();
}

Source _selectSource(List<Source> sources) {
  return sources.firstWhere(
    _sourceHasUpdate,
    orElse: () => sources.firstWhere(
      (source) => source.isAdded ?? false,
      orElse: () => sources.firstWhere(
        (source) => source.sourceCode?.isNotEmpty ?? false,
        orElse: () => sources.firstWhere(
          (source) => source.isActive ?? false,
          orElse: () => sources.first,
        ),
      ),
    ),
  );
}

bool _sourceHasUpdate(Source source) {
  final isInstalled =
      (source.isAdded ?? false) || (source.sourceCode?.isNotEmpty ?? false);
  final installed = source.version;
  final latest = source.versionLast;
  if (!isInstalled || installed == null || latest == null) return false;
  return compareVersions(installed, latest) < 0;
}

MihonSourceMetadata? _selectMetadata(List<Source> sources) {
  for (final source in sources) {
    final metadata = mihonSourceMetadata(source);
    if (metadata?.extensionName?.isNotEmpty == true ||
        metadata?.packageLang?.isNotEmpty == true) {
      return metadata;
    }
  }
  return mihonSourceMetadata(sources.first);
}
