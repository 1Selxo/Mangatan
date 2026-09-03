import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/l10n/generated/app_localizations.dart';
import 'package:mangayomi/repositories/chapter_repository.dart';
import 'package:mangayomi/repositories/download_repository.dart';
import 'package:mangayomi/models/download.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/modules/manga/detail/widgets/custom_floating_action_btn.dart';
import 'package:mangayomi/modules/manga/download/providers/download_provider.dart';
import 'package:mangayomi/providers/l10n_providers.dart';
import 'package:mangayomi/services/download_manager/download_queue_order.dart';
import 'package:mangayomi/utils/extensions/chapter_extensions.dart';
import 'package:mangayomi/utils/global_style.dart';
import 'package:mangayomi/modules/widgets/tv_menu.dart';
import 'package:mangayomi/utils/platform_utils.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/chapter.dart';

class DownloadQueueScreen extends ConsumerStatefulWidget {
  const DownloadQueueScreen({super.key});

  @override
  ConsumerState<DownloadQueueScreen> createState() =>
      _DownloadQueueScreenState();
}

class _DownloadQueueScreenState extends ConsumerState<DownloadQueueScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    return StreamBuilder(
      stream: isar.downloads.filter().idIsNotNull().watch(
        fireImmediately: true,
      ),
      builder: (context, snapshot) {
        final resolved = (snapshot.data ?? const <Download>[])
            .map(resolveDownloadedChapter)
            .nonNulls
            .toList();
        final completed = resolved
            .where((entry) => entry.download.isDownload ?? false)
            .toList();
        final queued = DownloadQueueOrder.sorted(
          resolved
              .where(
                (entry) =>
                    !(entry.download.isDownload ?? false) &&
                    (entry.download.isStartDownload ?? false),
              )
              .map((entry) => entry.download)
              .toList(),
        );

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(l10n.downloads),
              leading: isTv
                  ? IconButton(
                      autofocus: true,
                      icon: const BackButtonIcon(),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  : null,
              bottom: TabBar(
                tabs: [
                  Tab(text: l10n.downloaded),
                  Tab(text: l10n.download_queue),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildCompletedDownloads(context, l10n, completed),
                _buildQueue(context, l10n, queued),
              ],
            ),
            floatingActionButton: queued.isEmpty
                ? null
                : CustomFloatingActionBtn(
                    isExtended: false,
                    label: l10n.download_queue,
                    onPressed: () => ref.read(processDownloadsProvider()),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildCompletedDownloads(
    BuildContext context,
    AppLocalizations l10n,
    List<DownloadedChapterEntry> entries,
  ) {
    if (entries.isEmpty) return Center(child: Text(l10n.no_downloads));
    final groups = <int, List<DownloadedChapterEntry>>{};
    for (final entry in entries) {
      groups.putIfAbsent(entry.manga.id!, () => []).add(entry);
    }
    return ListView(
      children: [
        for (final group in groups.values)
          ExpansionTile(
            key: ValueKey('downloaded-manga-${group.first.manga.id}'),
            leading: const Icon(Icons.download_done),
            title: Text(group.first.manga.name ?? ''),
            subtitle: Text(l10n.n_chapters(group.length)),
            trailing: PopupMenuButton<String>(
              tooltip: l10n.delete,
              onSelected: (_) async {
                for (final entry in group.toList()) {
                  await entry.chapter.deleteDownloadedFiles();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
              ],
            ),
            children: [
              for (final entry in group)
                ListTile(
                  title: Text(entry.chapter.name ?? ''),
                  leading: const Icon(Icons.menu_book_outlined),
                  onTap: () => _openDownloadedChapter(context, entry),
                  trailing: IconButton(
                    tooltip: l10n.delete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: entry.chapter.deleteDownloadedFiles,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  void _openDownloadedChapter(
    BuildContext context,
    DownloadedChapterEntry entry,
  ) {
    final route = switch (entry.manga.itemType) {
      ItemType.anime => '/animePlayerView',
      ItemType.novel => '/novelReaderView',
      _ => '/mangaReaderView',
    };
    context.push(route, extra: entry.chapter.id);
  }

  Widget _buildQueue(
    BuildContext context,
    AppLocalizations l10n,
    List<Download> entries,
  ) {
    if (entries.isEmpty) return Center(child: Text(l10n.no_downloads));
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: entries.length,
      onReorderItem: (oldIndex, newIndex) {
        final ids = entries.map((entry) => entry.id!).toList();
        final moved = ids.removeAt(oldIndex);
        ids.insert(newIndex, moved);
        DownloadQueueOrder.setOrder(ids);
        setState(() {});
      },
      itemBuilder: (context, index) =>
          _buildRow(context, l10n, entries, entries[index], index),
    );
  }

  Widget _buildRow(
    BuildContext context,
    AppLocalizations l10n,
    List<Download> entries,
    Download element,
    int index,
  ) {
    return SizedBox(
      key: ValueKey(element.id),
      height: 60,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.drag_handle),
            ),
          ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      element.chapter.value?.manga.value?.name ?? "",
                      style: const TextStyle(fontSize: 16),
                    ),
                    Text(
                      "${element.succeeded}/${element.total}",
                      style: const TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                Text(
                  element.chapter.value?.name ?? "",
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  tween: Tween<double>(
                    begin: 0,
                    end: element.succeeded! / element.total!,
                  ),
                  builder: (context, value, _) =>
                      LinearProgressIndicator(value: value),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: isTv
                // An anchored dropdown is a poor remote target, so pop the same
                // actions in the centre on TV.
                ? IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () async {
                      final picked = await showTvMenu(
                        context,
                        title: element.chapter.value?.manga.value?.name ?? '',
                        options: [
                          TvMenuOption(l10n.cancel),
                          TvMenuOption(l10n.cancel_all_for_this_series),
                        ],
                      );
                      if (picked != null && context.mounted) {
                        await _onDownloadAction(
                          context,
                          picked == 0 ? 'Cancel' : 'CancelAll',
                          element,
                          entries,
                        );
                      }
                    },
                  )
                : PopupMenuButton(
                    popUpAnimationStyle: popupAnimationStyle,
                    child: const Icon(Icons.more_vert),
                    onSelected: (value) => _onDownloadAction(
                      context,
                      value.toString(),
                      element,
                      entries,
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'Cancel', child: Text(l10n.cancel)),
                      PopupMenuItem(
                        value: 'CancelAll',
                        child: Text(l10n.cancel_all_for_this_series),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// The per-download actions, shared by the popup menu off-TV and the centred
  /// TV menu.
  Future<void> _onDownloadAction(
    BuildContext context,
    String value,
    Download element,
    List<Download> entries,
  ) async {
    if (value == 'Cancel') {
      if (element.chapter.value != null) {
        element.chapter.value!.cancelDownloads(element.id!);
      } else {
        // Orphaned download: just delete the record.
        downloadRepository.delete(element.id!);
      }
    } else if (value == 'CancelAll') {
      final a = entries
          .where(
            (e) =>
                '${e.chapter.value?.manga.value?.name}' ==
                    '${element.chapter.value?.manga.value?.name}' &&
                '${e.chapter.value?.manga.value?.source}' ==
                    '${element.chapter.value?.manga.value?.source}',
          )
          .map((e) => (e.id, e.chapter.value?.id))
          .toList();
      for (var ids in a) {
        final (downloadId, chapterId) = ids;
        final chapter = chapterRepository.findByIdSync(chapterId!);
        chapter?.cancelDownloads(downloadId!);
      }
    }
  }
}

class DownloadedChapterEntry {
  const DownloadedChapterEntry(this.download, this.chapter, this.manga);

  final Download download;
  final Chapter chapter;
  final Manga manga;
}

/// Resolves the persisted links needed to represent a download after an app
/// restart. Isar links are lazy, so a null value before [loadSync] does not mean
/// the download is orphaned.
@visibleForTesting
DownloadedChapterEntry? resolveDownloadedChapter(Download download) {
  if (!download.chapter.isLoaded) download.chapter.loadSync();
  final chapter = download.chapter.value;
  if (chapter == null) return null;
  if (!chapter.manga.isLoaded) chapter.manga.loadSync();
  final manga = chapter.manga.value;
  if (manga == null) return null;
  return DownloadedChapterEntry(download, chapter, manga);
}
