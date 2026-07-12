import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:mangayomi/eval/model/m_bridge.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/modules/library/providers/local_archive.dart';
import 'package:mangayomi/modules/widgets/progress_center.dart';
import 'package:mangayomi/providers/l10n_providers.dart';
import 'package:mangayomi/utils/platform_utils.dart';

typedef LocalArchiveDropImporter =
    Future<void> Function(List<String> filePaths);

/// Adds native file drag-and-drop importing to a desktop library screen.
class LibraryFileDropTarget extends StatefulWidget {
  const LibraryFileDropTarget({
    super.key,
    required this.itemType,
    required this.onImport,
    required this.child,
  });

  final ItemType itemType;
  final LocalArchiveDropImporter onImport;
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
      await widget.onImport(filePaths);
    } catch (error) {
      botToast(error.toString());
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }
}

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
