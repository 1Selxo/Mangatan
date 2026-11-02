import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/model/m_bridge.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/epub_book_progress.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/modules/library/providers/local_archive.dart';
import 'package:mangayomi/repositories/history_repository.dart';
import 'package:mangayomi/modules/more/providers/incognito_mode_state_provider.dart';
import 'package:mangayomi/providers/l10n_providers.dart';
import 'package:mangayomi/utils/extensions/chapter_extensions.dart';
import 'package:mangayomi/services/epub_chapter_metadata.dart';
import 'package:mangayomi/services/sync/chimahon_novel_materializer.dart';
import 'package:shiori/shiori.dart';

class ContinueReaderButton extends ConsumerWidget {
  final Manga entry;

  const ContinueReaderButton({super.key, required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The button looks the same regardless of history, so the last-read
    // chapter is resolved on tap — a live watch per grid cell made scrolling
    // large libraries churn dozens of query subscriptions.
    final tokens = context.shiori;
    final c = tokens.color;
    final size = tokens.scaled(32);
    return Semantics(
      button: true,
      label: context.l10n.resume,
      child: Material(
        color: c.accent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _resume(context, ref),
          child: SizedBox.square(
            dimension: size,
            child: Icon(
              Symbols.play_arrow_rounded,
              fill: 1,
              size: size * 0.6,
              color: c.onAccent,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _resume(BuildContext context, WidgetRef ref) async {
    // A Chimahon novel synced without its EPUB is imported first.
    final isMissingEpub =
        entry.itemType == ItemType.novel &&
        entry.isLocalArchive == true &&
        isar.epubBookProgress
            .filter()
            .mangaIdEqualTo(entry.id!)
            .archivePathEqualTo('')
            .isNotEmptySync();
    if (isMissingEpub) {
      botToast(chimahonMissingEpubGuidance, second: 4);
      try {
        await ref.read(
          importArchivesFromFileProvider(
            itemType: ItemType.novel,
            entry,
            init: false,
            splitChapters: false,
          ).future,
        );
      } catch (error) {
        botToast('Import failed: $error');
      }
      return;
    }
    if (isLocalEpubManga(entry)) {
      await repairLocalEpubChapterMetadata(entry);
      final shortcuts = epubNavigationChaptersInSpineOrder(
        isar.chapters.filter().mangaIdEqualTo(entry.id).findAllSync(),
      );
      if (context.mounted && shortcuts.isNotEmpty) {
        shortcuts.first.pushToReaderView(context);
      }
      return;
    }
    if (!context.mounted) return;
    final incognitoMode = ref.read(incognitoModeStateProvider);
    final history = incognitoMode
        ? null
        : historyRepository.findByMangaId(entry.id!);
    if (history != null && !history.chapter.isLoaded) {
      history.chapter.loadSync();
    }
    final lastReadChapter = history?.chapter.value;
    if (lastReadChapter != null) {
      lastReadChapter.pushToReaderView(context);
    } else {
      // A title whose chapters were never fetched has nothing to open.
      userFacingChapters(entry).firstOrNull?.pushToReaderView(context);
    }
  }
}
