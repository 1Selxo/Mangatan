import 'package:mangayomi/models/category.dart';
import 'package:mangayomi/models/manga.dart';

/// Shared category rules for the desktop editor and assignment dialogs.
/// The implicit Default/uncategorized shelf is represented by an empty
/// membership list and is never persisted as a Category row.
abstract final class CategoryService {
  static String normalizeName(String value) => value.trim().toLowerCase();

  static bool hasDuplicateName(
    Iterable<Category> categories,
    String name, {
    int? exceptId,
  }) {
    final normalized = normalizeName(name);
    return normalized.isEmpty ||
        categories.any(
          (category) =>
              category.id != exceptId &&
              normalizeName(category.name ?? '') == normalized,
        );
  }

  static List<Category> ordered(List<Category> categories) {
    return [...categories]
      ..sort((a, b) {
        final byPosition = (a.pos ?? 0).compareTo(b.pos ?? 0);
        return byPosition == 0
            ? (a.id ?? 0).compareTo(b.id ?? 0)
            : byPosition;
      });
  }

  static List<Category> normalizePositions(List<Category> categories) {
    final result = ordered(categories);
    for (var index = 0; index < result.length; index++) {
      result[index].pos = index;
    }
    return result;
  }

  static List<int> moveMembership(
    Iterable<int>? current,
    int categoryId,
    bool assigned,
  ) {
    final result = {...?current};
    if (assigned) {
      result.add(categoryId);
    } else {
      result.remove(categoryId);
    }
    return result.toList()..sort();
  }

  static void removeMembership(Manga item, int categoryId) {
    item.categories = moveMembership(item.categories, categoryId, false);
  }

  static int membershipState(Iterable<Manga> items, int categoryId) {
    final list = items.toList();
    if (list.isEmpty) return 0;
    final assigned = list
        .where((item) => item.categories?.contains(categoryId) ?? false)
        .length;
    if (assigned == 0) return 0;
    if (assigned == list.length) return 1;
    return 2;
  }
}
