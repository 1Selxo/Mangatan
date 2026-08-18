import 'package:isar_community/isar.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:mangayomi/services/fetch_sources_list.dart';
import 'package:mangayomi/services/m_extension_server.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'fetch_item_sources.g.dart';

@Riverpod(keepAlive: true)
Future<void> fetchItemSourcesList(
  Ref ref, {
  int? id,
  required bool reFresh,
  required ItemType itemType,
}) async {
  if (ref.watch(checkForExtensionsUpdateStateProvider) || reFresh) {
    Source? mihonSource;
    if (id != null) {
      mihonSource = isar.sources.getSync(id);
    } else {
      final installedMihonSources = await isar.sources
          .filter()
          .sourceCodeLanguageEqualTo(SourceCodeLanguage.mihon)
          .isAddedEqualTo(true)
          .findAll();
      mihonSource = installedMihonSources.firstOrNull;
    }
    if (mihonSource != null) {
      await prepareMihonBridge(ref, mihonSource);
      if (!ref.mounted) return;
    }
    final repos = ref.watch(extensionsRepoStateProvider(itemType));
    Object? lastInstallError;
    for (Repo repo in repos) {
      try {
        await fetchSourcesList(
          repo: repo,
          refresh: reFresh,
          id: id,
          androidProxyServer: ref.watch(androidProxyServerStateProvider),
          autoUpdateExtensions: ref.watch(autoUpdateExtensionsStateProvider),
          itemType: itemType,
        );
      } catch (error) {
        if (id != null) lastInstallError = error;
      }
    }

    if (id != null) {
      final installed = await isar.sources.get(id);
      if (!extensionInstallIsComplete(installed)) {
        throw ExtensionInstallException(
          lastInstallError?.toString() ??
              'The extension repository did not install this source.',
        );
      }
    }
  }
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
