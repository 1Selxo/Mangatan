import 'dart:async';

import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/epub_book_progress.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/modules/mining/widgets/dictionary_lookup_popup.dart';
import 'package:mangayomi/services/mining/dictionary_profile_resolver.dart';
import 'package:mangayomi/services/mining/mining_models.dart';
import 'package:mangayomi/services/sync/chimahon_novel_progress_adapter.dart';

/// Adds native text selection and a Hoshi dictionary action to novel content.
///
/// This deliberately wraps the rendered HTML instead of trying to guess which
/// HTML element was tapped. As a result text in paragraphs, headings, tables,
/// links, and custom EPUB markup all remains selectable and lookupable.
class NovelDictionarySelection extends StatefulWidget {
  const NovelDictionarySelection({
    super.key,
    required this.chapter,
    required this.child,
  });

  final Chapter chapter;
  final Widget child;

  @override
  State<NovelDictionarySelection> createState() =>
      _NovelDictionarySelectionState();
}

class _NovelDictionarySelectionState extends State<NovelDictionarySelection> {
  String _selectedText = '';

  Future<void> _lookup(SelectableRegionState selectableRegionState) async {
    final query = _selectedText.trim();
    if (query.isEmpty) return;

    final anchor = selectableRegionState.contextMenuAnchors.primaryAnchor;
    ContextMenuController.removeAny();
    final manga = widget.chapter.manga.value;
    final source = manga?.sourceId == null
        ? null
        : isar.sources.getSync(manga!.sourceId!);
    final archivePath = widget.chapter.archivePath ?? '';
    final progress = manga?.id == null || archivePath.isEmpty
        ? null
        : isar.epubBookProgress
              .filter()
              .mangaIdEqualTo(manga!.id!)
              .archivePathEqualTo(archivePath)
              .findFirstSync();
    final isLocalNovel = progress != null;
    await DictionaryLookupPopup.show(
      context: context,
      anchor: Rect.fromCenter(center: anchor, width: 1, height: 1),
      text: query,
      miningContext: MiningContext(
        mediaType: MiningMediaType.novel,
        mangaId: isLocalNovel ? null : manga?.id,
        sourceId: isLocalNovel
            ? null
            : DictionaryProfileResolver.overrideIdForSource(source),
        sourceLanguage: isLocalNovel
            ? progress.lang ?? ''
            : DictionaryProfileResolver.sourceLanguageForSource(
                source,
                fallback: manga?.lang ?? '',
              ),
        novelId: progress == null
            ? null
            : const ChimahonNovelProgressAdapter().stableId(
                title: progress.title,
                author: progress.author,
              ),
        sourceTitle: manga?.name ?? '',
        chapterTitle: widget.chapter.name ?? '',
        sentence: query,
        sourceUri: Uri.tryParse(widget.chapter.archivePath ?? ''),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      onSelectionChanged: (selection) {
        _selectedText = selection?.plainText.trim() ?? '';
      },
      contextMenuBuilder: (context, selectableRegionState) {
        final buttons = <ContextMenuButtonItem>[
          if (_selectedText.isNotEmpty)
            ContextMenuButtonItem(
              type: ContextMenuButtonType.lookUp,
              label: 'Dictionary',
              onPressed: () => unawaited(_lookup(selectableRegionState)),
            ),
          ...selectableRegionState.contextMenuButtonItems,
        ];
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: selectableRegionState.contextMenuAnchors,
          buttonItems: buttons,
        );
      },
      child: widget.child,
    );
  }
}
