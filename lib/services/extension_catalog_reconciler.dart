import 'package:mangayomi/eval/mihon/bridge_protocol.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';

/// Applies repository-owned metadata without overwriting installation state,
/// source preferences, or other values produced while an extension is in use.
///
/// Returns whether any persisted value changed.
bool applyExtensionCatalogMetadata(
  Source existing,
  Source catalog, {
  required Repo? repo,
}) {
  var changed = false;

  void update<T>(T? current, T? incoming, void Function(T? value) assign) {
    if (current != incoming) {
      assign(incoming);
      changed = true;
    }
  }

  final existingMihonMetadata = mihonSourceMetadata(existing);
  final catalogMihonMetadata = mihonSourceMetadata(catalog);
  final additionalParams = catalogMihonMetadata == null
      ? catalog.additionalParams
      : encodeMihonSourceMetadata(
          sourceId: catalogMihonMetadata.sourceId,
          packageName: catalogMihonMetadata.packageName,
          factoryAvailable: existingMihonMetadata?.factoryAvailable ?? true,
          extensionName: catalogMihonMetadata.extensionName,
          packageLang: catalogMihonMetadata.packageLang,
        );

  update(existing.name, catalog.name, (value) => existing.name = value);
  update(
    existing.baseUrl,
    catalog.baseUrl,
    (value) => existing.baseUrl = value,
  );
  update(existing.lang, catalog.lang, (value) => existing.lang = value);
  update(existing.isNsfw, catalog.isNsfw, (value) => existing.isNsfw = value);
  update(
    existing.sourceCodeUrl,
    catalog.sourceCodeUrl,
    (value) => existing.sourceCodeUrl = value,
  );
  update(
    existing.typeSource,
    catalog.typeSource,
    (value) => existing.typeSource = value,
  );
  update(
    existing.iconUrl,
    catalog.iconUrl,
    (value) => existing.iconUrl = value,
  );
  update(
    existing.isFullData,
    catalog.isFullData,
    (value) => existing.isFullData = value,
  );
  update(
    existing.hasCloudflare,
    catalog.hasCloudflare,
    (value) => existing.hasCloudflare = value,
  );
  update(
    existing.dateFormat,
    catalog.dateFormat,
    (value) => existing.dateFormat = value,
  );
  update(
    existing.dateFormatLocale,
    catalog.dateFormatLocale,
    (value) => existing.dateFormatLocale = value,
  );
  update(existing.apiUrl, catalog.apiUrl, (value) => existing.apiUrl = value);
  update(
    existing.appMinVerReq,
    catalog.appMinVerReq,
    (value) => existing.appMinVerReq = value,
  );
  update(
    existing.additionalParams,
    additionalParams,
    (value) => existing.additionalParams = value,
  );
  update(existing.notes, catalog.notes, (value) => existing.notes = value);

  if (existing.itemType != catalog.itemType) {
    existing.itemType = catalog.itemType;
    changed = true;
  }
  if (existing.sourceCodeLanguage != catalog.sourceCodeLanguage) {
    existing.sourceCodeLanguage = catalog.sourceCodeLanguage;
    changed = true;
  }
  if (!_sameRepo(existing.repo, repo)) {
    existing.repo = repo;
    changed = true;
  }
  if (existing.isObsolete != false) {
    existing.isObsolete = false;
    changed = true;
  }

  // For entries that have not been installed yet, both versions describe the
  // catalog artifact. Installed entries keep their installed version so the
  // existing update detection can compare it with the latest catalog version.
  if (!(existing.isAdded ?? false)) {
    update(
      existing.version,
      catalog.version,
      (value) => existing.version = value,
    );
    update(
      existing.versionLast,
      catalog.version,
      (value) => existing.versionLast = value,
    );
  }

  return changed;
}

bool _sameRepo(Repo? first, Repo? second) {
  if (identical(first, second)) return true;
  if (first == null || second == null) return false;
  return first.name == second.name &&
      first.website == second.website &&
      first.jsonUrl == second.jsonUrl &&
      first.hidden == second.hidden;
}
