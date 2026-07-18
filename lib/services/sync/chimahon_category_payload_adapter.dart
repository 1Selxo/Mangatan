import 'package:fixnum/fixnum.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupCategory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:protobuf/protobuf.dart';

/// The three category tables selected for a Chimahon sync payload.
///
/// Mangatan has one shared local category model, while Chimahon has two wire
/// shapes: manga/anime sync by exact name and use `order` as their membership
/// key, while novels use stable string identities. Keeping the three lists
/// explicit makes future category work type-safe without introducing a second
/// local category store.
class ChimahonCategoryPayload {
  ChimahonCategoryPayload({
    required Iterable<BackupCategory> manga,
    required Iterable<BackupCategory> anime,
    required Iterable<BackupNovelCategory> novel,
  }) : manga = List.unmodifiable(manga),
       anime = List.unmodifiable(anime),
       novel = List.unmodifiable(novel);

  final List<BackupCategory> manga;
  final List<BackupCategory> anime;
  final List<BackupNovelCategory> novel;
}

/// Lossless sync boundary for category payloads that Mangatan only partly
/// represents today.
///
/// A missing local category is not a deletion signal. Every remote-only row
/// therefore passes through, including protobuf fields that this build does
/// not know yet. When a projected local row matches a remote row, Chimahon's
/// opaque ID/flags and future fields survive independently of the represented
/// name/order values.
///
/// This adapter intentionally adds no category UI or database fields. Future
/// Chimahon-style category behavior should extend this boundary and the
/// existing `Category` model rather than create a parallel category system.
class ChimahonCategoryPayloadAdapter {
  const ChimahonCategoryPayloadAdapter();

  ChimahonCategoryPayload merge({
    required BackupMihon local,
    required BackupMihon remote,
  }) => ChimahonCategoryPayload(
    manga: mergeOrderedCategories(
      local.backupCategories,
      remote.backupCategories,
    ),
    anime: mergeOrderedCategories(
      local.backupAnimeCategories,
      remote.backupAnimeCategories,
    ),
    novel: mergeNovelCategories(
      local.backupNovelCategories,
      remote.backupNovelCategories,
    ),
  );

  /// Merges manga or anime categories by their exact display name.
  ///
  /// Chimahon uses [BackupCategory.order] as the membership key and conflict
  /// clock, and its sync service keys these two category tables by the exact
  /// name string. Remote wins an order tie, matching Chimahon. Remote IDs and
  /// flags are opaque to Mangatan and remain authoritative for a shared name.
  List<BackupCategory> mergeOrderedCategories(
    Iterable<BackupCategory> local,
    Iterable<BackupCategory> remote,
  ) {
    final remoteCategories = remote.toList(growable: false);
    final remoteExactNamesByNormalizedName = <String, Set<String>>{};
    for (final category in remoteCategories) {
      remoteExactNamesByNormalizedName
          .putIfAbsent(_normalized(category.name), () => <String>{})
          .add(category.name);
    }
    final result = <String, BackupCategory>{};
    final localOrder = <String, bool>{};
    final remoteOrder = <String, bool>{};

    void add(BackupCategory category, {required bool isRemote}) {
      final key = category.name;
      if (!isRemote &&
          (remoteExactNamesByNormalizedName[_normalized(key)]?.length ?? 0) >
              1) {
        // Mangatan's local category store is case/whitespace insensitive. A
        // single local row can therefore be the projection of several exact
        // Chimahon identities, and its order/flags cannot safely target one
        // of them. Keep the remote rows authoritative for this collision.
        return;
      }
      (isRemote ? remoteOrder : localOrder).putIfAbsent(key, () => true);
      final existing = result[key];
      if (existing == null) {
        result[key] = category.deepCopy();
        return;
      }

      // Remote rows are visited after local projections, so equality chooses
      // the Chimahon representation. A higher order remains Chimahon's
      // existing field-specific conflict rule.
      final categoryWins = category.order >= existing.order;
      final merged = _copyWithMergedUnknownFields(
        categoryWins ? category : existing,
        categoryWins ? existing : category,
      );
      if (category.hasId()) merged.id = category.id;
      if (category.hasFlags()) merged.flags = category.flags;
      result[key] = merged;
    }

    for (final category in local) {
      add(category, isRemote: false);
    }
    for (final category in remoteCategories) {
      add(category, isRemote: true);
    }
    final orderedKeys = _remoteAnchoredKeys(
      remoteOrder,
      localOrder,
    ).toList(growable: false);
    return _allocateLocalOnlyOrders(
      orderedKeys: orderedKeys,
      categoriesByName: result,
      remoteNames: remoteOrder.keys.toSet(),
    );
  }

  /// Merges novel categories by Chimahon string ID or normalized name.
  ///
  /// For a shared identity the remote row wins even when its order moved
  /// downward. Mangatan's current name-derived ID and lack of flags must not
  /// overwrite Chimahon's UUID/flags during a round trip.
  List<BackupNovelCategory> mergeNovelCategories(
    Iterable<BackupNovelCategory> local,
    Iterable<BackupNovelCategory> remote,
  ) {
    final result = <String, BackupNovelCategory>{};
    final localOrder = <String, bool>{};
    final remoteOrder = <String, bool>{};

    void add(BackupNovelCategory category, {required bool isRemote}) {
      final matchingKey = result.entries
          .where(
            (entry) =>
                entry.value.id == category.id ||
                _normalized(entry.value.name) == _normalized(category.name),
          )
          .map((entry) => entry.key)
          .firstOrNull;
      final key = matchingKey ?? category.id;
      (isRemote ? remoteOrder : localOrder).putIfAbsent(key, () => true);
      final existing = result[key];
      if (existing == null) {
        result[key] = category.deepCopy();
        return;
      }

      final categoryWins = isRemote || category.order > existing.order;
      result[key] = _copyWithMergedUnknownFields(
        categoryWins ? category : existing,
        categoryWins ? existing : category,
      );
    }

    for (final category in local) {
      add(category, isRemote: false);
    }
    for (final category in remote) {
      add(category, isRemote: true);
    }
    return [
      for (final key in _remoteAnchoredKeys(remoteOrder, localOrder))
        result[key]!,
    ];
  }

  Iterable<K> _remoteAnchoredKeys<K>(
    Map<K, bool> remote,
    Map<K, bool> local,
  ) sync* {
    final seen = <K>{};
    for (final key in [...remote.keys, ...local.keys]) {
      if (seen.add(key)) yield key;
    }
  }

  List<BackupCategory> _allocateLocalOnlyOrders({
    required Iterable<String> orderedKeys,
    required Map<String, BackupCategory> categoriesByName,
    required Set<String> remoteNames,
  }) {
    // Duplicate order values can already exist in a valid Chimahon payload.
    // They are opaque remote state, not something Mangatan may normalize on a
    // no-edit round trip. Reserve every remote-backed order as-is, including
    // duplicates, and allocate a fresh value only for a genuinely local-only
    // identity that would otherwise make membership ambiguous.
    final usedOrders = <Int64>{
      for (final key in orderedKeys)
        if (remoteNames.contains(key)) categoriesByName[key]!.order,
    };
    var nextFreeOrder = Int64.ZERO;
    final result = <BackupCategory>[];
    for (final key in orderedKeys) {
      final value = categoriesByName[key]!;
      if (remoteNames.contains(key)) {
        result.add(value);
        continue;
      }

      if (usedOrders.add(value.order)) {
        result.add(value);
      } else {
        while (usedOrders.contains(nextFreeOrder)) {
          nextFreeOrder += 1;
        }
        final category = value.deepCopy();
        category.order = nextFreeOrder;
        usedOrders.add(nextFreeOrder);
        result.add(category);
      }
    }
    return result;
  }

  T _copyWithMergedUnknownFields<T extends GeneratedMessage>(
    T winner,
    T loser,
  ) {
    final merged = winner.deepCopy()..unknownFields.clear();
    merged
      ..mergeUnknownFields(loser.unknownFields)
      ..mergeUnknownFields(winner.unknownFields);
    return merged;
  }

  String _normalized(String value) => value.trim().toLowerCase();
}
