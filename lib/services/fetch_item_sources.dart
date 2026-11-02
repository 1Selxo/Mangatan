import 'package:isar_community/isar.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/providers/browse_state_provider.dart';
import 'package:mangayomi/repositories/source_repository.dart';
import 'package:mangayomi/services/extension_update.dart';
import 'package:mangayomi/services/fetch_sources_list.dart';
import 'package:mangayomi/services/m_extension_server.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mangayomi/utils/log/logger.dart';
part 'fetch_item_sources.g.dart';

/// Reads the extension repositories of [itemType], or acts on the one
/// extension [id]: installs it, or installs the update the last read found
/// for it, from where it was found. Installing [id] fails with
/// [ExtensionInstallException] when it did not end up installed.
@Riverpod(keepAlive: true)
Future<void> fetchItemSourcesList(
  Ref ref, {
  int? id,
  required bool reFresh,
  required ItemType itemType,
}) async {
  if (!(ref.watch(checkForExtensionsUpdateStateProvider) || reFresh)) return;

  // Mihon extensions are read through the bridge, which may still have to
  // start (the embedded iOS runtime starts on first use).
  final mihonSource = id != null
      ? isar.sources.getSync(id)
      : (await isar.sources
                .filter()
                .sourceCodeLanguageEqualTo(SourceCodeLanguage.mihon)
                .isAddedEqualTo(true)
                .findAll())
            .firstOrNull;
  if (mihonSource != null &&
      mihonSource.sourceCodeLanguage == SourceCodeLanguage.mihon) {
    await prepareMihonBridge(ref, mihonSource);
    if (!ref.mounted) return;
  }

  final repos = ref.watch(extensionsRepoStateProvider(itemType));
  final androidProxyServer = ref.watch(androidProxyServerStateProvider);

  if (id != null) {
    Object? installError;
    try {
      await _installOne(
        id: id,
        repos: repos,
        androidProxyServer: androidProxyServer,
        itemType: itemType,
      );
    } catch (error) {
      installError = error;
    }
    final installed = await isar.sources.get(id);
    if (!extensionInstallIsComplete(installed)) {
      throw ExtensionInstallException(
        installError?.toString() ??
            'The extension repository did not install this source.',
      );
    }
    return;
  }

  // Every repository is read before any update is chosen, so the choice is
  // made among all of them rather than by whichever was read first.
  final offers = <int, List<ExtensionOffer>>{};
  final readRepos = <String>{};
  final listings = <(Repo, List<Source>)>[];
  for (final repo in repos) {
    try {
      final listed = await fetchRepoSources(repo: repo, itemType: itemType);
      await recordRepoSources(listed, repo, itemType);
      readRepos.add(repo.jsonUrl!);
      listings.add((repo, listed));
      for (final source in listed) {
        if (source.id == null) continue;
        (offers[source.id!] ??= []).add(ExtensionOffer(repo, source));
      }
    } catch (e, st) {
      // The user just sees no sources for the repo.
      AppLogger.log(
        'fetchItemSources: repo fetch failed: $e\n$st',
        logLevel: LogLevel.error,
      );
    }
  }
  await followMovedRepos(repos: repos, offers: offers, itemType: itemType);
  await applyExtensionUpdates(
    offers: offers,
    readRepos: readRepos,
    autoUpdate: ref.watch(autoUpdateExtensionsStateProvider),
    androidProxyServer: androidProxyServer,
    itemType: itemType,
  );
  for (final (repo, listed) in listings) {
    try {
      await installMissingMihonSiblings(
        listed,
        androidProxyServer,
        repo,
        itemType,
      );
    } catch (e, st) {
      AppLogger.log(
        'fetchItemSources: installing new Mihon sources failed: $e\n$st',
        logLevel: LogLevel.error,
      );
    }
  }
}

Future<void> _installOne({
  required int id,
  required List<Repo> repos,
  required String androidProxyServer,
  required ItemType itemType,
}) async {
  final existingSource = await sourceRepository.findByIdAsync(id);
  if (existingSource != null && (existingSource.isAdded ?? false)) {
    await installExtensionUpdate(
      installed: existingSource,
      repos: repos,
      androidProxyServer: androidProxyServer,
      itemType: itemType,
    );
    return;
  }
  if (existingSource != null &&
      (existingSource.sourceCodeUrl ?? '').isNotEmpty) {
    // Direct install: the listing is already known, so the indexes need not
    // be read again. A Mihon source's siblings are known from the database.
    await updateSource(
      existingSource,
      androidProxyServer,
      existingSource.repo,
      itemType,
    );
    return;
  }
  // Not known here yet: the first repository that lists it, so a Mihon
  // source is installed with the rest of its APK's sources.
  Object? failure;
  StackTrace? failureStack;
  final origin = existingSource?.repo;
  for (final repo in [
    ?origin,
    for (final repo in repos)
      if (!isSameRepo(repo, origin)) repo,
  ]) {
    final List<Source> listed;
    try {
      listed = await fetchRepoSources(repo: repo, itemType: itemType);
    } catch (e, st) {
      failure = e;
      failureStack = st;
      continue;
    }
    final listing = listed.where((s) => s.id == id).firstOrNull;
    if (listing == null || (listing.sourceCodeUrl ?? '').isEmpty) continue;
    await updateSource(
      listing,
      androidProxyServer,
      repo,
      itemType,
      listing: listed,
    );
    return;
  }
  if (failure != null) Error.throwWithStackTrace(failure, failureStack!);
}

bool extensionInstallIsComplete(Source? source) =>
    source != null &&
    (source.isAdded ?? false) &&
    (source.sourceCode?.isNotEmpty ?? false);

class ExtensionInstallException implements Exception {
  const ExtensionInstallException(this.message);

  final String message;

  @override
  String toString() => message;
}
