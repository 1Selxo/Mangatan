import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/epub_book_progress.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/modules/mining/widgets/dictionary_lookup_popup.dart';
import 'package:mangayomi/services/mining/dictionary_profile_resolver.dart';
import 'package:mangayomi/services/mining/mining_models.dart';
import 'package:mangayomi/services/sync/chimahon_novel_progress_adapter.dart';

@visibleForTesting
bool novelSelectionShouldAutoLookup({
  required TargetPlatform platform,
  required PointerDeviceKind pointerKind,
  required String selectedText,
}) =>
    platform == TargetPlatform.linux &&
    pointerKind == PointerDeviceKind.mouse &&
    selectedText.trim().isNotEmpty;

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
  Timer? _lookupDebounce;
  Offset? _lastPointerPosition;
  PointerDeviceKind _lastPointerKind = PointerDeviceKind.touch;
  String _lastAutomaticLookup = '';

  @override
  void dispose() {
    _lookupDebounce?.cancel();
    super.dispose();
  }

  Future<void> _lookupAt(Offset anchor) async {
    final query = _selectedText.trim();
    if (query.isEmpty) return;

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
        novelId: const ChimahonNovelProgressAdapter().stableLocalIdOrNull(
          progress,
        ),
        sourceTitle: manga?.name ?? '',
        chapterTitle: widget.chapter.name ?? '',
        sentence: query,
        sourceUri: Uri.tryParse(widget.chapter.archivePath ?? ''),
      ),
    );
  }

  Future<void> _lookup(SelectableRegionState selectableRegionState) =>
      _lookupAt(selectableRegionState.contextMenuAnchors.primaryAnchor);

  void _selectionChanged(SelectedContent? selection) {
    _selectedText = selection?.plainText.trim() ?? '';
    _lookupDebounce?.cancel();
    if (_selectedText.isEmpty) {
      _lastAutomaticLookup = '';
      return;
    }
    if (!novelSelectionShouldAutoLookup(
      platform: defaultTargetPlatform,
      pointerKind: _lastPointerKind,
      selectedText: _selectedText,
    )) {
      return;
    }
    final query = _selectedText;
    if (query == _lastAutomaticLookup) return;
    _lookupDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted || _selectedText != query) return;
      _lastAutomaticLookup = query;
      final anchor =
          _lastPointerPosition ??
          Offset(
            MediaQuery.sizeOf(context).width / 2,
            MediaQuery.sizeOf(context).height / 2,
          );
      unawaited(_lookupAt(anchor));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        _lastPointerPosition = event.position;
        _lastPointerKind = event.kind;
      },
      child: SelectionArea(
        onSelectionChanged: _selectionChanged,
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
      ),
    );
  }
}
