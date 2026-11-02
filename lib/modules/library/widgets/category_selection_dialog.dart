import 'package:flutter/material.dart';
import 'package:shiori/shiori.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mangayomi/repositories/category_repository.dart';
import 'package:mangayomi/repositories/manga_repository.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/modules/library/providers/library_state_provider.dart';
import 'package:mangayomi/modules/manga/detail/providers/state_providers.dart';
import 'package:mangayomi/modules/manga/detail/widgets/chapter_filter_list_tile_widget.dart';
import 'package:mangayomi/providers/l10n_providers.dart';
import 'package:mangayomi/services/category_service.dart';
import 'package:mangayomi/utils/extensions/build_context_extensions.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

void showCategorySelectionDialog({
  required BuildContext context,
  required WidgetRef ref,
  required ItemType itemType,
  Manga? singleManga,
  List<Manga>? bulkMangas,
}) {
  assert(
    (singleManga != null) ^ (bulkMangas != null),
    "Provide either singleManga or bulkMangas, not both.",
  );
  final l10n = l10nLocalizations(context)!;
  final bool isBulk = bulkMangas != null;
  final bool isLibraryVisible = !isBulk && singleManga!.isVisibleInLibrary;
  List<int> categoryIds = [];
  if (!isBulk) {
    categoryIds = List<int>.from(singleManga?.categories ?? []);
  }
  // Bulk edits change only the categories touched here: true adds the
  // category to every selected entry, false removes it.
  final bulkOverrides = <int, bool>{};
  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => ShioriDialog(
        title: l10n.set_categories,
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: context.height(0.55)),
            child: StreamBuilder(
              stream: categoryRepository.watchByItemType(itemType),
              builder: (context, snapshot) {
                final empty = ShioriEmptyState(
                  icon: Symbols.category_rounded,
                  title: l10n.library_no_category_exist,
                  compact: true,
                );
                if (!snapshot.hasData || snapshot.data!.isEmpty) return empty;
                final entries = (snapshot.data!
                  ..sort((a, b) => (a.pos ?? 0).compareTo(b.pos ?? 0)));
                if (entries.isEmpty) return empty;
                return SuperListView.builder(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final category = entries[index];
                    final state = isBulk
                        ? (bulkOverrides.containsKey(category.id)
                              ? (bulkOverrides[category.id]! ? 1 : 0)
                              : CategoryService.membershipState(
                                  bulkMangas,
                                  category.id!,
                                ))
                        : (categoryIds.contains(category.id) ? 1 : 0);
                    if (!isBulk) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: ShioriSpace.s8),
                        child: ListTileChapterFilter(
                          label: category.name!,
                          onTap: () {
                            setState(() {
                              state == 1
                                  ? categoryIds.remove(category.id)
                                  : categoryIds.add(category.id!);
                            });
                          },
                          type: state,
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: ShioriSpace.s8),
                      child: ListTileChapterFilter(
                        label: category.name!,
                        type: state,
                        onTap: () {
                          setState(() {
                            bulkOverrides[category.id!] = state != 1;
                          });
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
        actions: [
          ShioriButton.quiet(
            icon: Symbols.edit_rounded,
            label: l10n.edit,
            onPressed: () {
              context.push(
                "/categories",
                extra: (
                  true,
                  itemType == ItemType.manga
                      ? 0
                      : itemType == ItemType.anime
                      ? 1
                      : 2,
                ),
              );
              Navigator.pop(context);
            },
          ),
          ShioriButton.quiet(
            label: l10n.cancel,
            onPressed: () => Navigator.pop(context),
          ),
          ShioriButton(
            label: l10n.ok,
            onPressed: () {
              if (isBulk) {
                final now = DateTime.now().millisecondsSinceEpoch;
                for (final manga in bulkMangas) {
                  final categories = List<int>.from(
                    manga.categories ?? const [],
                  );
                  for (final entry in bulkOverrides.entries) {
                    if (entry.value) {
                      if (!categories.contains(entry.key)) {
                        categories.add(entry.key);
                      }
                    } else {
                      categories.remove(entry.key);
                    }
                  }
                  manga
                    ..categories = (categories..sort())
                    ..updatedAt = now;
                }
                mangaRepository.putAll(bulkMangas);
                ref.read(mangasListStateProvider.notifier).clear();
                ref.read(isLongPressedStateProvider.notifier).update(false);
              } else {
                if (!isLibraryVisible) {
                  singleManga!.updateFavorite(true);
                  singleManga.dateAdded = DateTime.now().millisecondsSinceEpoch;
                }
                singleManga
                  ..categories = categoryIds
                  ..updatedAt = DateTime.now().millisecondsSinceEpoch;
                mangaRepository.save(singleManga);
              }
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    ),
  );
}
