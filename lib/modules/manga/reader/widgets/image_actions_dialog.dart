import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shiori/shiori.dart';
import 'package:mangayomi/eval/model/m_bridge.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/utils/manga_cover_actions.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/modules/manga/reader/u_chap_data_preload.dart';
import 'package:mangayomi/modules/mining/widgets/mining_lookup_sheet.dart';
import 'package:mangayomi/modules/mining/widgets/reader_ocr_overlay.dart';
import 'package:mangayomi/modules/widgets/image_actions_sheet.dart';
import 'package:mangayomi/providers/l10n_providers.dart';
import 'package:mangayomi/providers/storage_provider.dart';
import 'package:mangayomi/services/mining/dictionary_profile_resolver.dart';
import 'package:mangayomi/services/mining/mining_models.dart';
import 'package:mangayomi/utils/downloaded_page_file.dart';
import 'package:mangayomi/utils/extensions/others.dart';
import 'package:mangayomi/utils/share.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;

/// Bottom sheet dialog for long-press actions on manga images.
///
/// Provides options to:
/// - Set image as cover
/// - Share image
/// - Save image to gallery
class ImageActionsDialog {
  /// Shows the image actions dialog.
  ///
  /// Parameters:
  /// - [context]: Build context
  /// - [data]: The page data containing the image
  /// - [manga]: The manga the image belongs to
  /// - [chapterName]: Name of the chapter (for file naming)
  static Future<void> show({
    required BuildContext context,
    required UChapDataPreload data,
    required Manga manga,
    required String chapterName,
  }) async {
    final imageBytes = await data.getImageBytes;
    if (imageBytes == null || !context.mounted) return;

    final name = "${manga.name} $chapterName - ${data.pageIndex}".replaceAll(
      RegExp(r'[^a-zA-Z0-9 .()\-\s]'),
      '_',
    );

    showShioriSheet<void>(
      context,
      builder: (context) => _ImageActionsSheet(
        imageBytes: Uint8List.fromList(imageBytes),
        data: data,
        manga: manga,
        chapterName: chapterName,
        fileName: name,
      ),
    );
  }
}

class _ImageActionsSheet extends StatelessWidget {
  final Uint8List imageBytes;
  final UChapDataPreload data;
  final Manga manga;
  final String chapterName;
  final String fileName;

  const _ImageActionsSheet({
    required this.imageBytes,
    required this.data,
    required this.manga,
    required this.chapterName,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return ImageActionsSheet(
      onSetCover: _setAsCover,
      onShare: _shareImage,
      onSave: _saveImage,
      footer: Row(
        children: [
          ImageSheetActionButton(
            label: 'Lookup',
            icon: Symbols.manage_search_rounded,
            onPressed: () => _lookupText(context),
          ),
          ImageSheetActionButton(
            label: 'OCR',
            icon: Symbols.document_scanner_rounded,
            onPressed: () => _showOcrOverlay(context),
          ),
        ],
      ),
    );
  }

  Future<void> _setAsCover(BuildContext context) async {
    final confirmed = await confirmUseAsMangaCover(context);
    if (!confirmed || !context.mounted) return;
    await applyMangaCover(context, manga, imageBytes);
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _shareImage(BuildContext context) async {
    if (!context.mounted) return;

    final ext = detectImageExtension(imageBytes);
    final mime = mimeTypeForImageExtension(ext);

    final box = context.findRenderObject() as RenderBox?;
    await shareOrCopy(
      ShareParams(
        files: [
          XFile.fromData(imageBytes, name: '$fileName$ext', mimeType: mime),
        ],
        sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
      ),
      fallbackName: '$fileName$ext',
    );
  }

  Future<void> _saveImage(BuildContext context) async {
    final dir = await StorageProvider().getGalleryDirectory();
    if (dir == null) return;
    final ext = detectImageExtension(imageBytes);

    final file = File(p.join(dir.path, "$fileName$ext"));
    await file.writeAsBytes(imageBytes, flush: true);

    if (context.mounted) botToast(context.l10n.picture_saved, second: 3);
  }

  Future<void> _lookupText(BuildContext context) async {
    final source = manga.sourceId == null
        ? null
        : isar.sources.getSync(manga.sourceId!);
    await MiningLookupSheet.show(
      context: context,
      text: '',
      miningContext: MiningContext(
        mediaType: MiningMediaType.manga,
        mangaId: manga.id,
        sourceId: DictionaryProfileResolver.overrideIdForSource(source),
        sourceLanguage: DictionaryProfileResolver.sourceLanguageForSource(
          source,
          fallback: manga.lang ?? '',
        ),
        sourceTitle: manga.name ?? '',
        chapterTitle: chapterName,
        pageIndex: data.pageIndex,
        sourceUri: Uri.tryParse(data.pageUrl?.url ?? ''),
        imageBytesLoader: () async => Uint8List.fromList(imageBytes),
      ),
    );
  }

  Future<void> _showOcrOverlay(BuildContext context) async {
    await ReaderOcrState.setEnabled(true);
    if (context.mounted) Navigator.pop(context);
  }
}
