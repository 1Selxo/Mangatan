import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/eval/model/m_manga.dart';
import 'package:mangayomi/eval/model/m_pages.dart';
import 'package:mangayomi/modules/manga/home/manga_home_pagination.dart';

void main() {
  group('Manga home pagination', () {
    test('loads two source pages for the initial Popular batch', () async {
      final pagination = MangaHomePagination(isFullData: false)
        ..initialize(_page(10, hasNextPage: true, prefix: 'first'));
      final requestedPages = <int>[];

      await pagination.loadThroughPage(popularInitialPageTarget, (page) async {
        requestedPages.add(page);
        return _page(7, hasNextPage: true, prefix: 'second');
      });

      expect(requestedPages, [2]);
      expect(pagination.items.length, greaterThanOrEqualTo(15));
      expect(pagination.items, hasLength(17));
      expect(pagination.currentPage, 2);
      expect(pagination.hasNextPage, isTrue);
    });

    test(
      'does not request another page when the first page is terminal',
      () async {
        final pagination = MangaHomePagination(isFullData: false)
          ..initialize(_page(12, hasNextPage: false));
        var requests = 0;

        await pagination.loadThroughPage(popularInitialPageTarget, (
          page,
        ) async {
          requests++;
          return _page(12, hasNextPage: false);
        });

        expect(requests, 0);
        expect(pagination.items, hasLength(12));
        expect(pagination.hasNextPage, isFalse);
      },
    );

    test(
      'empty next page ends pagination even if the source says otherwise',
      () async {
        final pagination = MangaHomePagination(isFullData: false)
          ..initialize(_page(10, hasNextPage: true));

        final advanced = await pagination.loadNext(
          (page) async => MPages(list: [], hasNextPage: true),
        );

        expect(advanced, isFalse);
        expect(pagination.currentPage, 2);
        expect(pagination.hasNextPage, isFalse);
        expect(pagination.canLoadMore, isFalse);
      },
    );

    test('prevents concurrent requests for the same next page', () async {
      final pagination = MangaHomePagination(isFullData: false)
        ..initialize(_page(10, hasNextPage: true));
      final response = Completer<MPages?>();
      var requests = 0;

      final first = pagination.loadNext((page) {
        requests++;
        return response.future;
      });
      final second = pagination.loadNext((page) async {
        requests++;
        return _page(10, hasNextPage: false);
      });
      response.complete(_page(10, hasNextPage: false));

      expect(await first, isTrue);
      expect(await second, isFalse);
      expect(requests, 1);
      expect(pagination.items, hasLength(20));
    });

    test('allows a failed page to be retried', () async {
      final pagination = MangaHomePagination(isFullData: false)
        ..initialize(_page(10, hasNextPage: true));

      await expectLater(
        pagination.loadNext((page) async => throw Exception('network error')),
        throwsException,
      );

      expect(pagination.currentPage, 1);
      expect(pagination.isLoading, isFalse);
      expect(pagination.canLoadMore, isTrue);
    });

    test('reveals full-data sources in bounded local batches', () async {
      final pagination = MangaHomePagination(
        isFullData: true,
        fullDataInitialItemCount: popularFullDataInitialItemCount,
        fullDataBatchSize: 50,
      )..initialize(_page(120, hasNextPage: false));

      expect(pagination.visibleItemCount, 75);
      expect(pagination.hasNextPage, isTrue);

      await pagination.loadNext((page) async => fail('must not fetch'));

      expect(pagination.visibleItemCount, 120);
      expect(pagination.hasNextPage, isFalse);
    });
  });
}

MPages _page(int length, {bool hasNextPage = false, String prefix = 'item'}) =>
    MPages(
      list: List.generate(length, (index) => MManga(name: '$prefix-$index')),
      hasNextPage: hasNextPage,
    );
