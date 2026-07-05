import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/modules/manga/reader/u_chap_data_preload.dart';
import 'package:mangayomi/modules/mining/widgets/mining_lookup_sheet.dart';
import 'package:mangayomi/services/mining/mining_models.dart';
import 'package:mangayomi/services/mining/mokuro_parser.dart';
import 'package:mangayomi/services/mining/ocr_models.dart';
import 'package:mangayomi/utils/extensions/build_context_extensions.dart';

class OcrOverlaySheet extends StatelessWidget {
  final Uint8List imageBytes;
  final UChapDataPreload data;
  final Manga manga;
  final String chapterName;

  const OcrOverlaySheet({
    super.key,
    required this.imageBytes,
    required this.data,
    required this.manga,
    required this.chapterName,
  });

  static Future<void> show({
    required BuildContext context,
    required Uint8List imageBytes,
    required UChapDataPreload data,
    required Manga manga,
    required String chapterName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(maxWidth: context.width(1)),
      builder: (_) => OcrOverlaySheet(
        imageBytes: imageBytes,
        data: data,
        manga: manga,
        chapterName: chapterName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: context.themeData.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.84,
          minChildSize: 0.45,
          maxChildSize: 0.96,
          builder: (context, controller) {
            return FutureBuilder<_OcrPageData>(
              future: _loadOcrData(),
              builder: (context, snapshot) {
                final result = snapshot.data;
                return ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  children: [
                    Center(
                      child: Container(
                        height: 7,
                        width: 35,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: context.secondaryColor.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'OCR overlay',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Lookup text',
                          onPressed: () => MiningLookupSheet.show(
                            context: context,
                            text: '',
                            miningContext: _contextFor(''),
                          ),
                          icon: const Icon(Icons.manage_search),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (snapshot.connectionState != ConnectionState.done)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (snapshot.hasError)
                      _MessageWithImage(
                        imageBytes: imageBytes,
                        text: 'OCR data could not be loaded: ${snapshot.error}',
                      )
                    else if (result == null || result.blocks.isEmpty)
                      _MessageWithImage(
                        imageBytes: imageBytes,
                        text:
                            'No Mokuro OCR data found for this page. Place a .mokuro or mokuro.json file beside the chapter/archive.',
                      )
                    else
                      _OcrOverlayImage(
                        imageBytes: imageBytes,
                        page: result.page!,
                        blocks: result.blocks,
                        onTapBlock: (block) => MiningLookupSheet.show(
                          context: context,
                          text: block.text,
                          miningContext: _contextFor(block.text),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  MiningContext _contextFor(String sentence) {
    return MiningContext(
      mediaType: MiningMediaType.manga,
      sourceTitle: manga.name ?? '',
      chapterTitle: chapterName,
      sentence: sentence,
      pageIndex: data.pageIndex,
      sourceUri: Uri.tryParse(data.pageUrl?.url ?? ''),
      imageBytesLoader: () async => imageBytes,
    );
  }

  Future<_OcrPageData> _loadOcrData() async {
    const parser = MokuroParser();
    final volume = await parser.findForReaderPage(data);
    if (volume == null) return const _OcrPageData.empty();
    final page = parser.resolvePage(volume, data: data);
    if (page == null) return const _OcrPageData.empty();
    return _OcrPageData(page: page, blocks: parser.convertPage(page));
  }
}

class _OcrOverlayImage extends StatelessWidget {
  final Uint8List imageBytes;
  final MokuroPage page;
  final List<OcrTextBlock> blocks;
  final void Function(OcrTextBlock block) onTapBlock;

  const _OcrOverlayImage({
    required this.imageBytes,
    required this.page,
    required this.blocks,
    required this.onTapBlock,
  });

  @override
  Widget build(BuildContext context) {
    final aspectRatio = page.imageWidth > 0 && page.imageHeight > 0
        ? page.imageWidth / page.imageHeight
        : 0.7;
    return InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(imageBytes, fit: BoxFit.fill),
                for (final block in blocks)
                  Positioned(
                    left: block.xmin * constraints.maxWidth,
                    top: block.ymin * constraints.maxHeight,
                    width: (block.xmax - block.xmin) * constraints.maxWidth,
                    height: (block.ymax - block.ymin) * constraints.maxHeight,
                    child: Builder(
                      builder: (context) {
                        return GestureDetector(
                          onTap: () => onTapBlock(block),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.12),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 1.2,
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MessageWithImage extends StatelessWidget {
  final Uint8List imageBytes;
  final String text;

  const _MessageWithImage({required this.imageBytes, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: context.height(0.55)),
          child: Image.memory(imageBytes, fit: BoxFit.contain),
        ),
        const SizedBox(height: 16),
        Text(text, textAlign: TextAlign.center),
      ],
    );
  }
}

class _OcrPageData {
  final MokuroPage? page;
  final List<OcrTextBlock> blocks;

  const _OcrPageData({required this.page, required this.blocks});

  const _OcrPageData.empty() : page = null, blocks = const [];
}
