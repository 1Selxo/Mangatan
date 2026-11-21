import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/l10n/generated/app_localizations.dart';
import 'package:mangayomi/repositories/chapter_repository.dart';
import 'package:mangayomi/repositories/download_repository.dart';
import 'package:mangayomi/models/download.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/modules/manga/download/providers/download_provider.dart';
import 'package:mangayomi/providers/l10n_providers.dart';
import 'package:mangayomi/services/download_manager/download_gate.dart';
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
              .where((entry) => !(entry.download.isDownload ?? false))
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
              actions: [
                // Pause while downloads run; otherwise start every download
                // in the queue again, failed ones included, from the top.
                ListenableBuilder(
                  listenable: Listenable.merge([
                    downloadsPaused,
                    scheduledDownloads,
                  ]),
                  builder: (context, _) {
                    final running =
                        !downloadsPaused.value &&
                        scheduledDownloads.value.isNotEmpty;
                    if (!running && queued.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return IconButton(
                      tooltip: running
                          ? l10n.pause
                          : l10n.resume_all_downloads,
                      onPressed: running
                          ? pauseDownloads
                          : () => _resumeAll(queued),
                      icon: Icon(running ? Icons.pause : Icons.play_arrow),
                    );
                  },
                ),
              ],
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
        // Rebuilt at once so the row stays where it was dropped, and again
        // once the order is saved, which the list is sorted by.
        setState(() {});
        DownloadQueueOrder.setOrder(ids).then((_) {
          if (mounted) setState(() {});
        });
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
                      (element.failed ?? 0) > 0
                          ? 'Failed — retry'
                          : '${element.succeeded ?? 0}%',
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
                          for (final action in _QueueAction.values)
                            TvMenuOption(action.label(l10n)),
                        ],
                      );
                      if (picked != null && context.mounted) {
                        _onDownloadAction(
                          _QueueAction.values[picked],
                          element,
                          entries,
                        );
                      }
                    },
                  )
                : PopupMenuButton<_QueueAction>(
                    popUpAnimationStyle: popupAnimationStyle,
                    child: const Icon(Icons.more_vert),
                    onSelected: (action) =>
                        _onDownloadAction(action, element, entries),
                    itemBuilder: (context) => [
                      for (final action in _QueueAction.values) ...[
                        // Moves first, then the cancels, set apart.
                        if (action == _QueueAction.cancel)
                          const PopupMenuDivider(),
                        PopupMenuItem(
                          value: action,
                          child: Text(action.label(l10n)),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Starts every queued download again, failed ones included, from the top.
  Future<void> _resumeAll(List<Download> entries) async {
    for (final entry in entries) {
      final chapter = entry.chapter.value;
      if (chapter != null) {
        await downloadRepository.enqueue(chapter);
      }
    }
    if (!mounted) return;
    resumeDownloads(ref);
  }

  /// The per-download actions, shared by the popup menu off-TV and the centred
  /// TV menu.
  void _onDownloadAction(
    _QueueAction action,
    Download element,
    List<Download> entries,
  ) {
    final mangaId = element.chapter.value?.mangaId;
    bool inSeries(Download e) =>
        mangaId != null && e.chapter.value?.mangaId == mangaId;
    switch (action) {
      case _QueueAction.moveToTop:
      case _QueueAction.moveToBottom:
      case _QueueAction.moveSeriesToTop:
      case _QueueAction.moveSeriesToBottom:
        final series =
            action == _QueueAction.moveSeriesToTop ||
            action == _QueueAction.moveSeriesToBottom;
        final seriesIds = {
          for (final e in entries)
            if (inSeries(e)) e.id!,
        };
        // The gate re-reads this order before each start, so the downloads
        // still waiting follow it at once.
        DownloadQueueOrder.setOrder(
          DownloadQueueOrder.move(
            [for (final e in entries) e.id!],
            series ? seriesIds.contains : (id) => id == element.id,
            toTop:
                action == _QueueAction.moveToTop ||
                action == _QueueAction.moveSeriesToTop,
          ),
        ).then((_) {
          if (mounted) setState(() {});
        });
      case _QueueAction.cancel:
        if (element.chapter.value != null) {
          element.chapter.value!.cancelDownloads(element.id!);
        } else {
          // Orphaned download: just delete the record.
          downloadRepository.delete(element.id!);
        }
      case _QueueAction.cancelAll:
        for (final e in entries.where(inSeries).toList()) {
          final chapter = chapterRepository.findByIdSync(e.chapter.value!.id!);
          chapter?.cancelDownloads(e.id!);
        }
    }
  }
}

/// What a queued download's menu offers, in menu order.
enum _QueueAction {
  moveToTop,
  moveSeriesToTop,
  moveToBottom,
  moveSeriesToBottom,
  cancel,
  cancelAll;

  String label(AppLocalizations l10n) => switch (this) {
    moveToTop => l10n.move_to_top,
    moveSeriesToTop => l10n.move_series_to_top,
    moveToBottom => l10n.move_to_bottom,
    moveSeriesToBottom => l10n.move_series_to_bottom,
    cancel => l10n.cancel,
    cancelAll => l10n.cancel_all_for_this_series,
  };
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
