import 'package:mangayomi/models/settings.dart';

int doublePageViewCount(int pageCount, PageMode pageMode) {
  if (pageCount <= 0) return 0;
  if (!pageMode.isDoublePage) return pageCount;
  if (!pageMode.usesCoverOffset) return (pageCount / 2).ceil();
  if (pageCount == 1) return 1;
  return 1 + ((pageCount - 1) / 2).ceil();
}

int doublePageViewToActualIndex(
  int viewIndex,
  int pageCount,
  PageMode pageMode,
) {
  if (pageCount <= 0) return 0;
  if (!pageMode.isDoublePage) {
    return viewIndex.clamp(0, pageCount - 1).toInt();
  }
  final actualIndex = pageMode.usesCoverOffset
      ? (viewIndex <= 0 ? 0 : viewIndex * 2 - 1)
      : viewIndex * 2;
  return actualIndex.clamp(0, pageCount - 1).toInt();
}

int actualIndexToDoublePageView(int actualIndex, PageMode pageMode) {
  if (!pageMode.isDoublePage) return actualIndex;
  if (!pageMode.usesCoverOffset) return actualIndex ~/ 2;
  if (actualIndex <= 0) return 0;
  return ((actualIndex - 1) ~/ 2) + 1;
}

List<T?> doublePageSpreadItems<T>(
  List<T> pages,
  int viewIndex,
  PageMode pageMode,
) {
  if (pages.isEmpty) return const [];
  if (!pageMode.isDoublePage) {
    final index = viewIndex.clamp(0, pages.length - 1).toInt();
    return [pages[index]];
  }
  if (pageMode.usesCoverOffset && viewIndex <= 0) {
    return [pages.first, null];
  }

  final firstIndex = doublePageViewToActualIndex(
    viewIndex,
    pages.length,
    pageMode,
  );
  final secondIndex = firstIndex + 1;
  return [
    pages[firstIndex],
    secondIndex < pages.length ? pages[secondIndex] : null,
  ];
}

String doublePageIndexLabel(int viewIndex, int totalPages, PageMode pageMode) {
  if (!pageMode.isDoublePage) return '${viewIndex + 1}';
  if (totalPages <= 0) return '0';
  final first = doublePageViewToActualIndex(viewIndex, totalPages, pageMode);
  final second = first + 1;
  if (pageMode.usesCoverOffset && viewIndex <= 0) return '1';
  if (second >= totalPages) return '${first + 1}';
  return '${first + 1}-${second + 1}';
}
