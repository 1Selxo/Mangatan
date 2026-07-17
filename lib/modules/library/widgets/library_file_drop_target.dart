import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:mangayomi/eval/model/m_bridge.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/modules/library/providers/local_archive.dart';
import 'package:mangayomi/modules/widgets/progress_center.dart';
import 'package:mangayomi/providers/l10n_providers.dart';
import 'package:mangayomi/services/epub_manga.dart';
import 'package:mangayomi/src/rust/api/epub.dart';
import 'package:mangayomi/utils/platform_utils.dart';
import 'package:path/path.dart' as p;

typedef LocalArchiveDropImporter =
    Future<void> Function(List<String> filePaths, ItemType itemType);
typedef EpubDropClassifier = Future<EpubContentKind> Function(String filePath);

Future<EpubContentKind> classifyDroppedEpub(String filePath) async {
  final book = await parseEpubFromPath(epubPath: filePath, fullData: true);
  return analyzeEpubContent(book).kind;
}

/// Adds native file drag-and-drop importing to a desktop library screen.
class LibraryFileDropTarget extends StatefulWidget {
  const LibraryFileDropTarget({
    super.key,
    required this.itemType,
    required this.onImport,
    required this.child,
    this.classifyEpub = classifyDroppedEpub,
  });

  final ItemType itemType;
  final LocalArchiveDropImporter onImport;
  final EpubDropClassifier classifyEpub;
  final Widget child;

  @override
  State<LibraryFileDropTarget> createState() => _LibraryFileDropTargetState();
}

class _LibraryFileDropTargetState extends State<LibraryFileDropTarget> {
  bool _isDragging = false;
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) return widget.child;

    final routeIsCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    return DropTarget(
      enable: routeIsCurrent && !_isImporting,
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: _handleDrop,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (_isDragging || _isImporting)
            Positioned.fill(
              child: IgnorePointer(
                child: _ImportOverlay(
                  itemType: widget.itemType,
                  isImporting: _isImporting,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    if (_isImporting) return;

    final filePaths = filterSupportedLocalArchivePaths(
      details.files.whereType<DropItemFile>().map((file) => file.path),
      widget.itemType,
    );
    setState(() => _isDragging = false);

    if (filePaths.isEmpty) {
      final extensions = _extensionLabel(widget.itemType);
      botToast('No supported files to import ($extensions).');
      return;
    }

    setState(() => _isImporting = true);
    try {
      final mismatchedEpubs = <String>[];
      ItemType? suggestedType;
      if (widget.itemType == ItemType.manga ||
          widget.itemType == ItemType.novel) {
        for (final filePath in filePaths.where(_isEpubPath)) {
          EpubContentKind kind;
          try {
            kind = await widget.classifyEpub(filePath);
          } catch (_) {
            // Validation during the actual import will surface malformed EPUBs.
            // A failed preflight is not a reason to override the user's target.
            continue;
          }
          final recommendation = switch (kind) {
            EpubContentKind.imageBased => ItemType.manga,
            EpubContentKind.textBased => ItemType.novel,
            EpubContentKind.ambiguous => null,
          };
          if (recommendation != null && recommendation != widget.itemType) {
            suggestedType = recommendation;
            mismatchedEpubs.add(filePath);
          }
        }
      }

      if (mismatchedEpubs.isEmpty || suggestedType == null) {
        await widget.onImport(filePaths, widget.itemType);
        return;
      }
      if (!mounted) return;

      final chosenType = await _showEpubLibraryChoice(
        context,
        filePaths: mismatchedEpubs,
        currentType: widget.itemType,
        suggestedType: suggestedType,
      );
      if (chosenType == null) return;
      if (chosenType == widget.itemType) {
        await widget.onImport(filePaths, widget.itemType);
        return;
      }

      final mismatchedSet = mismatchedEpubs.toSet();
      final filesForCurrentLibrary = filePaths
          .where((path) => !mismatchedSet.contains(path))
          .toList();
      if (filesForCurrentLibrary.isNotEmpty) {
        await widget.onImport(filesForCurrentLibrary, widget.itemType);
      }
      await widget.onImport(mismatchedEpubs, chosenType);
    } catch (error) {
      botToast(error.toString());
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }
}

Future<ItemType?> _showEpubLibraryChoice(
  BuildContext context, {
  required List<String> filePaths,
  required ItemType currentType,
  required ItemType suggestedType,
}) {
  final isImageBased = suggestedType == ItemType.manga;
  final fileLabel = filePaths.length == 1
      ? p.basename(filePaths.single)
      : '${filePaths.length} EPUB files';
  final currentLabel = _itemTypeLabel(context, currentType);
  final suggestedLabel = _itemTypeLabel(context, suggestedType);
  final contentDescription = isImageBased ? 'image-based' : 'text-based';

  return showDialog<ItemType>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const ValueKey('epub-library-choice-dialog'),
      title: Text('Import into $suggestedLabel?'),
      content: Text(
        '$fileLabel appears $contentDescription. '
        'Manga mode reads image pages in the EPUB\'s authored order and may '
        'omit prose; Novel mode preserves the book\'s text and layout. ',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(context.l10n.cancel),
        ),
        TextButton(
          key: ValueKey('epub-import-as-${currentType.name}'),
          onPressed: () => Navigator.pop(dialogContext, currentType),
          child: Text('${context.l10n.import} as $currentLabel'),
        ),
        FilledButton(
          key: ValueKey('epub-import-as-${suggestedType.name}'),
          onPressed: () => Navigator.pop(dialogContext, suggestedType),
          child: Text('${context.l10n.import} as $suggestedLabel'),
        ),
      ],
    ),
  );
}

String _itemTypeLabel(BuildContext context, ItemType itemType) {
  return switch (itemType) {
    ItemType.manga => context.l10n.manga,
    ItemType.novel => context.l10n.novel,
    ItemType.anime => 'Anime',
  };
}

bool _isEpubPath(String path) => p.extension(path).toLowerCase() == '.epub';

class _ImportOverlay extends StatelessWidget {
  const _ImportOverlay({required this.itemType, required this.isImporting});

  final ItemType itemType;
  final bool isImporting;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = isImporting
        ? context.l10n.import
        : '${context.l10n.import_files} (${_extensionLabel(itemType)})';

    return ColoredBox(
      key: const ValueKey('library-file-drop-overlay'),
      color: colorScheme.surface.withValues(alpha: 0.92),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.45),
            border: Border.all(color: colorScheme.primary, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isImporting)
                  const ProgressCenter()
                else
                  Icon(
                    Icons.file_download_outlined,
                    color: colorScheme.primary,
                    size: 52,
                  ),
                const SizedBox(height: 12),
                Text(label, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _extensionLabel(ItemType itemType) {
  return supportedLocalArchiveExtensions(
    itemType,
  ).map((extension) => '.$extension').join(', ');
}
