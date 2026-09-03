import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/model/m_manga.dart';
import 'package:mangayomi/eval/model/m_pages.dart';
import 'package:mangayomi/models/manga.dart';

const localSourcePageSize = 50;

Future<List<String?>> loadLocalSourceNames(
  Isar database, {
  required ItemType itemType,
}) {
  return database.mangas
      .filter()
      .itemTypeEqualTo(itemType)
      .group(
        (q) => q
            .sourceEqualTo('local')
            .or()
            .linkContains('Mangatan/local')
            .or()
            .linkContains('Mangatan\\local')
            .or()
            .linkContains('Mangayomi/local')
            .or()
            .linkContains('Mangayomi\\local'),
      )
      .nameProperty()
      .findAll();
}

/// Builds a stable page for the built-in local source.
///
/// Isar's database-level string sort and offset can produce inconsistent
/// pages for nullable Unicode titles, especially when an ASCII digit prefix is
/// mixed with Japanese titles. Sorting the complete local result set here
/// keeps every title in one deterministic order before pagination is applied.
MPages buildLocalSourcePage(
  Iterable<String?> names, {
  required int page,
  String query = '',
  int pageSize = localSourcePageSize,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final filtered = names.map((name) => name?.trim()).whereType<String>().where((
    name,
  ) {
    if (name.isEmpty) return false;
    return normalizedQuery.isEmpty ||
        name.toLowerCase().contains(normalizedQuery);
  }).toList();

  filtered.sort((a, b) {
    final nameCompare = a.toLowerCase().compareTo(b.toLowerCase());
    if (nameCompare != 0) return nameCompare;
    return a.compareTo(b);
  });

  final effectivePage = page < 1 ? 1 : page;
  final effectivePageSize = pageSize < 1 ? localSourcePageSize : pageSize;
  final start = (effectivePage - 1) * effectivePageSize;
  if (start >= filtered.length) {
    return MPages(list: const [], hasNextPage: false);
  }
  final end = (start + effectivePageSize).clamp(0, filtered.length);
  final items = filtered.sublist(start, end);

  return MPages(
    list: items.map((name) => MManga(name: name)).toList(),
    hasNextPage: end < filtered.length,
  );
}
