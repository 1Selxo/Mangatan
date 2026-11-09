import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mangayomi/modules/manga/reader/u_chap_data_preload.dart';
import 'package:mangayomi/utils/extensions/others.dart';
import 'package:shiori/shiori.dart';

/// A grid of [pages], the chapter's, in a sheet: tapping one closes the
/// sheet and hands it to [onSelected].
Future<void> showReaderPagePreviews({
  required BuildContext context,
  required List<UChapDataPreload> pages,
  required void Function(UChapDataPreload page) onSelected,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (sheetContext) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(sheetContext).height * 0.72,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          ShioriSpace.s12,
          0,
          ShioriSpace.s12,
          ShioriSpace.s24,
        ),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 150,
          childAspectRatio: 0.68,
          crossAxisSpacing: ShioriSpace.s8,
          mainAxisSpacing: ShioriSpace.s8,
        ),
        itemCount: pages.length,
        itemBuilder: (context, index) => _PagePreview(
          page: pages[index],
          number: index + 1,
          onTap: () {
            Navigator.pop(sheetContext);
            onSelected(pages[index]);
          },
        ),
      ),
    ),
  ),
);

class _PagePreview extends ConsumerWidget {
  const _PagePreview({
    required this.page,
    required this.number,
    required this.onTap,
  });

  final UChapDataPreload page;
  final int number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.shiori.color;
    return InkWell(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.ink1,
              border: Border.all(color: colors.hairline),
            ),
            child: Image(
              image: page.getImageProvider(ref, true),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  Icon(Symbols.broken_image_rounded, color: colors.fgMuted),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: ShioriScrim.underText,
              padding: const EdgeInsets.symmetric(vertical: ShioriSpace.s4),
              child: Text(
                '$number',
                textAlign: TextAlign.center,
                // shiori: a label over a page image, on its dark scrim
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
