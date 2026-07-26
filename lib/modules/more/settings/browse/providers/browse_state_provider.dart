import 'dart:convert';
import 'package:http/http.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/eval/mihon/bridge_http_client.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/services/fetch_item_sources.dart';
import 'package:mangayomi/services/http/m_client.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'browse_state_provider.g.dart';

@riverpod
class AndroidProxyServerState extends _$AndroidProxyServerState {
  @override
  String build() {
    final savedAddress = isar.settings.getSync(227)!.androidProxyServer;
    return normalizeMihonBridgeBaseUrl(
      savedAddress == null || savedAddress.trim().isEmpty
          ? "http://127.0.0.1:8080"
          : savedAddress,
    );
  }

  void set(String value) {
    final proxyServer = normalizeMihonBridgeBaseUrl(value);
    final settings = isar.settings.getSync(227);
    state = proxyServer;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..androidProxyServer = proxyServer
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// Changes the address used by the running app without overwriting the
  /// user's external bridge fallback in the database.
  void setRuntime(String value) {
    state = normalizeMihonBridgeBaseUrl(value);
  }

  void restoreSaved() {
    final savedAddress = isar.settings.getSync(227)!.androidProxyServer;
    state = normalizeMihonBridgeBaseUrl(
      savedAddress == null || savedAddress.trim().isEmpty
          ? "http://127.0.0.1:8080"
          : savedAddress,
    );
  }
}

@riverpod
class OnlyIncludePinnedSourceState extends _$OnlyIncludePinnedSourceState {
  @override
  bool build() {
    return isar.settings.getSync(227)!.onlyIncludePinnedSources!;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(227);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..onlyIncludePinnedSources = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class ShowNSFWState extends _$ShowNSFWState {
  @override
  bool build() {
    return isar.settings.getSync(227)!.showNSFW ?? false;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(227);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..showNSFW = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class ExtensionsRepoState extends _$ExtensionsRepoState {
  @override
  List<Repo> build(ItemType itemType) {
    final settings = isar.settings.getSync(227)!;
    return switch (itemType) {
          ItemType.manga => settings.mangaExtensionsRepo,
          ItemType.anime => settings.animeExtensionsRepo,
          _ => settings.novelExtensionsRepo,
        } ??
        [];
  }

  void setVisibility(Repo repo, bool hidden) {
    final value = state.map((e) {
      if (e == repo) {
        e.hidden = hidden;
      }
      return e;
    }).toList();
    set(value);
  }

  void set(List<Repo> value) {
    final settings = isar.settings.getSync(227)!;
    state = value;
    isar.writeTxnSync(() {
      final a = switch (itemType) {
        ItemType.manga => isar.settings.putSync(
          settings
            ..mangaExtensionsRepo = value
            ..updatedAt = DateTime.now().millisecondsSinceEpoch,
        ),
        ItemType.anime => isar.settings.putSync(
          settings
            ..animeExtensionsRepo = value
            ..updatedAt = DateTime.now().millisecondsSinceEpoch,
        ),
        _ => isar.settings.putSync(
          settings
            ..novelExtensionsRepo = value
            ..updatedAt = DateTime.now().millisecondsSinceEpoch,
        ),
      };
      a;
    });
    try {
      final a = ref.refresh(
        fetchItemSourcesListProvider(
          id: null,
          reFresh: false,
          itemType: itemType,
        ).future,
      );
      Future.wait([a]);
    } catch (_) {}
  }
}

@riverpod
class AutoUpdateExtensionsState extends _$AutoUpdateExtensionsState {
  @override
  bool build() {
    return isar.settings.getSync(227)!.autoExtensionsUpdates ?? false;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(227);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..autoExtensionsUpdates = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
class CheckForExtensionsUpdateState extends _$CheckForExtensionsUpdateState {
  @override
  bool build() {
    return isar.settings.getSync(227)!.checkForExtensionUpdates ?? true;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(227);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..checkForExtensionUpdates = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

@riverpod
Future<Repo?> getRepoInfos(Ref ref, {required String jsonUrl}) async {
  final http = MClient.init(reqcopyWith: {'useDartHttpClient': true});

  Map<String, dynamic> infos = {};
  final match = RegExp(r'^(.*)/[^/]+\.json$').firstMatch(jsonUrl);

  final res = await http.get(Uri.parse(jsonUrl));
  if (!_checkValidUrl(res)) {
    return null;
  }

  if (match != null) {
    String url = match.group(1)!;
    final res = await http.get(Uri.parse("$url/repo.json"));
    if (res.statusCode == 200) {
      infos.addAll(jsonDecode(res.body));
    }
  }

  infos["jsonUrl"] = jsonUrl;
  return Repo.fromJson(infos);
}

bool _checkValidUrl(Response res) {
  try {
    final sourceList = (jsonDecode(res.body) as List).map(
      (e) => Source.fromJson(e),
    );
    if (sourceList.firstOrNull?.name == null) {
      return false;
    }
  } catch (err) {
    return false;
  }
  return true;
}
