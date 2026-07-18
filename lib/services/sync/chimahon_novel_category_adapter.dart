import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fixnum/fixnum.dart';
import 'package:mangayomi/models/category.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';

/// Projects Mangatan's parent-level novel categories onto Chimahon's
/// per-EPUB string category model.
///
/// Mangatan database IDs are device-local auto-incrementing integers, so they
/// must never be written to the Chimahon wire format. A scoped hash of the
/// normalized category name gives independently configured desktops the same
/// portable identity. Chimahon's built-in uncategorized category remains the
/// special `default` ID and is represented locally by an empty category list.
class ChimahonNovelCategoryAdapter {
  const ChimahonNovelCategoryAdapter();

  static const uncategorizedId = 'default';
  static const uncategorizedName = 'Default';

  String stableId(String? name) {
    final normalized = normalizeName(name);
    return md5
        .convert(utf8.encode('mangatan|novel-category|$normalized'))
        .toString();
  }

  String normalizeName(String? name) => (name ?? '').trim().toLowerCase();

  List<String> normalizeIds(Iterable<String> ids) {
    final result = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (result.any((id) => id != uncategorizedId)) {
      result.remove(uncategorizedId);
    }
    return result;
  }

  ChimahonNovelCategoryExportProjection buildExportProjection({
    required Iterable<Category> categories,
    required Iterable<Manga> mangas,
  }) {
    final orderedCategories =
        categories
            .where(
              (category) =>
                  category.forItemType == ItemType.novel &&
                  category.id != null &&
                  normalizeName(category.name).isNotEmpty,
            )
            .toList()
          ..sort((left, right) {
            final order = (left.pos ?? 0).compareTo(right.pos ?? 0);
            if (order != 0) return order;
            return left.id!.compareTo(right.id!);
          });

    final wireIdByLocalId = <int, String>{};
    final categoryByWireId = <String, BackupNovelCategory>{};
    for (final category in orderedCategories) {
      final wireId = stableId(category.name);
      wireIdByLocalId[category.id!] = wireId;
      categoryByWireId.putIfAbsent(
        wireId,
        () => BackupNovelCategory(
          id: wireId,
          name: category.name ?? '',
          order: Int64(category.pos ?? categoryByWireId.length),
          // Chimahon category flags have no equivalent in Mangatan. Leaving
          // the field absent lets the wire merger retain an existing remote
          // value instead of projecting an invented one.
        ),
      );
    }

    final categoryIdsByMangaId = <int, List<String>>{};
    for (final manga in mangas) {
      final mangaId = manga.id;
      if (mangaId == null || manga.itemType != ItemType.novel) continue;
      final ids = normalizeIds(
        (manga.categories ?? const <int>[]).map(
          (localId) => wireIdByLocalId[localId] ?? '',
        ),
      );
      categoryIdsByMangaId[mangaId] = ids.isEmpty
          ? const [uncategorizedId]
          : ids;
    }

    return ChimahonNovelCategoryExportProjection(
      categories: [
        BackupNovelCategory(
          id: uncategorizedId,
          name: uncategorizedName,
          order: Int64(-1),
        ),
        ...categoryByWireId.values,
      ],
      categoryIdsByMangaId: categoryIdsByMangaId,
    );
  }
}

class ChimahonNovelCategoryExportProjection {
  const ChimahonNovelCategoryExportProjection({
    required this.categories,
    required this.categoryIdsByMangaId,
  });

  final List<BackupNovelCategory> categories;
  final Map<int, List<String>> categoryIdsByMangaId;
}
