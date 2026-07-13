import 'dart:math';

import 'package:mangayomi/eval/model/m_manga.dart';
import 'package:mangayomi/eval/model/m_pages.dart';

/// Extension APIs choose their own page size, so loading two source pages is
/// the smallest reliable way to make the initial Popular result meaningfully
/// larger. Most sources return similarly sized pages, making this roughly a
/// 100% increase while still keeping the initial request count bounded.
const popularInitialPageTarget = 2;
const popularFullDataInitialItemCount = 75;

typedef MangaPageFetcher = Future<MPages?> Function(int page);

class MangaHomePagination {
  MangaHomePagination({
    required this.isFullData,
    this.fullDataInitialItemCount = 50,
    this.fullDataBatchSize = 50,
  }) : assert(fullDataInitialItemCount > 0),
       assert(fullDataBatchSize > 0);

  final bool isFullData;
  final int fullDataInitialItemCount;
  final int fullDataBatchSize;
  final List<MManga> items = [];

  int currentPage = 0;
  bool hasNextPage = false;
  bool isLoading = false;
  int _fullDataVisibleCount = 0;

  bool get isInitialized => currentPage > 0;
  bool get canLoadMore => isInitialized && hasNextPage && !isLoading;
  int get visibleItemCount =>
      isFullData ? min(_fullDataVisibleCount, items.length) : items.length;

  void initialize(MPages page) {
    if (isInitialized) return;

    items.addAll(page.list);
    currentPage = 1;
    if (isFullData) {
      _fullDataVisibleCount = min(fullDataInitialItemCount, items.length);
      hasNextPage = _fullDataVisibleCount < items.length;
    } else {
      hasNextPage = page.hasNextPage;
    }
  }

  Future<bool> loadNext(MangaPageFetcher fetchPage) async {
    if (!canLoadMore) return false;

    isLoading = true;
    try {
      if (isFullData) {
        _fullDataVisibleCount = min(
          _fullDataVisibleCount + fullDataBatchSize,
          items.length,
        );
        currentPage++;
        hasNextPage = _fullDataVisibleCount < items.length;
        return true;
      }

      final nextPage = currentPage + 1;
      final result = await fetchPage(nextPage);
      if (result == null) return false;

      currentPage = nextPage;
      items.addAll(result.list);
      // A source that returns an empty page while claiming another page exists
      // would otherwise be requested forever at the end of the list.
      hasNextPage = result.list.isNotEmpty && result.hasNextPage;
      return result.list.isNotEmpty;
    } finally {
      isLoading = false;
    }
  }

  Future<void> loadThroughPage(
    int targetPage,
    MangaPageFetcher fetchPage,
  ) async {
    while (currentPage < targetPage && canLoadMore) {
      final advanced = await loadNext(fetchPage);
      if (!advanced) return;
    }
  }
}
