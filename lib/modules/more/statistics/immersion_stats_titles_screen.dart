import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/modules/more/statistics/immersion_stats_data.dart';
import 'package:mangayomi/modules/more/statistics/immersion_stats_provider.dart';
import 'package:mangayomi/modules/more/statistics/widgets/immersion_stats_format.dart';
import 'package:mangayomi/utils/cached_network.dart';
import 'package:mangayomi/utils/constant.dart';
import 'package:mangayomi/utils/headers.dart';

/// The drill-down from the "In library" card: every title with its recorded
/// reading, searchable and sortable, opening a single-title stats view.
class ImmersionStatsTitlesScreen extends ConsumerStatefulWidget {
  const ImmersionStatsTitlesScreen({super.key, required this.query});

  final ImmersionStatsQuery query;

  @override
  ConsumerState<ImmersionStatsTitlesScreen> createState() =>
      _ImmersionStatsTitlesScreenState();
}

class _ImmersionStatsTitlesScreenState
    extends ConsumerState<ImmersionStatsTitlesScreen> {
  final _searchController = TextEditingController();
  var _sort = ImmersionStatsTitlesSort.lastRead;
  var _searching = false;
  String? _search;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titles = ref.watch(
      immersionStatsTitlesProvider(
        query: widget.query,
        sort: _sort,
        search: _search,
      ),
    );
    final scopeLabel = widget.query.includeNonLibrary
        ? 'All read'
        : 'In library';

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search',
                ),
                onChanged: (value) => setState(() => _search = value),
              )
            : Text('Statistics - $scopeLabel'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) {
                _searchController.clear();
                _search = null;
              }
            }),
          ),
          PopupMenuButton<ImmersionStatsTitlesSort>(
            icon: const Icon(Icons.sort),
            onSelected: (sort) => setState(() => _sort = sort),
            itemBuilder: (context) => [
              for (final sort in ImmersionStatsTitlesSort.values)
                PopupMenuItem(
                  value: sort,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_sortLabel(sort)),
                      if (_sort == sort) const Icon(Icons.check, size: 18),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: titles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Err: $error')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('No titles found matching this filter.'))
            : ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) => _TitleTile(
                  item: items[index],
                  onTap: () => context.push(
                    '/statistics/title',
                    extra: items[index],
                  ),
                ),
              ),
      ),
    );
  }

  static String _sortLabel(ImmersionStatsTitlesSort sort) => switch (sort) {
    ImmersionStatsTitlesSort.alphabetical => 'Alphabetically',
    ImmersionStatsTitlesSort.lastRead => 'Last read',
    ImmersionStatsTitlesSort.dateAdded => 'Date added',
  };
}

class _TitleTile extends ConsumerWidget {
  const _TitleTile({required this.item, required this.onTap});

  final ImmersionStatsTitle item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SizedBox(
          height: 80,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(4)),
                child: SizedBox(
                  width: 56,
                  height: 80,
                  child: _Cover(mangaId: item.mangaId),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.author?.isNotEmpty == true)
                      Text(
                        item.author!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _subtitle(item),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Reading time when there is any, else the last-read date, else unread.
  static String _subtitle(ImmersionStatsTitle item) {
    if (item.readDurationMs > 0) {
      final duration = formatShortDuration(item.readDurationMs);
      if (item.charactersRead > 0) {
        return '$duration read • ${formatCount(item.charactersRead)} characters';
      }
      return '$duration read';
    }
    if (item.lastReadDate != null) {
      return 'Last read: ${formatStatsDate(item.lastReadDate!)}';
    }
    return 'Unread';
  }
}

class _Cover extends ConsumerWidget {
  const _Cover({this.mangaId});

  final int? mangaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.book_outlined, size: 20)),
    );
    final id = mangaId;
    if (id == null) return placeholder;
    final manga = isar.mangas.getSync(id);
    if (manga == null) return placeholder;
    if (manga.customCoverImage != null) {
      return Image.memory(
        manga.customCoverImage as Uint8List,
        fit: BoxFit.cover,
      );
    }
    final imageUrl = manga.customCoverFromTracker ?? manga.imageUrl ?? '';
    if (imageUrl.isEmpty || manga.source == null || manga.lang == null) {
      return placeholder;
    }
    return cachedCompressedNetworkImage(
      headers: ref.watch(
        headersProvider(
          source: manga.source!,
          lang: manga.lang!,
          sourceId: manga.sourceId,
        ),
      ),
      imageUrl: toImgUrl(imageUrl),
      width: 56,
      height: 80,
      fit: BoxFit.cover,
    );
  }
}
