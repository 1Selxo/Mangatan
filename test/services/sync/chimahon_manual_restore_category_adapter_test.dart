import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/category.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupCategory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/services/sync/chimahon_manual_restore_category_adapter.dart';

void main() {
  test(
    'reuses matching local rows and preserves local-only category state',
    () {
      final localManga = Category(
        id: 10,
        name: 'Reading',
        forItemType: ItemType.manga,
        pos: 90,
        hide: true,
        shouldUpdate: false,
        updatedAt: 123,
      )..forManga = true;
      final localOnly = Category(
        id: 11,
        name: 'On this computer',
        forItemType: ItemType.manga,
        pos: 7,
        hide: false,
        shouldUpdate: true,
        updatedAt: 456,
      );
      final localAnime = Category(
        id: 12,
        name: 'Reading',
        forItemType: ItemType.anime,
        pos: 8,
        hide: true,
      );
      final localNovel = Category(
        id: 13,
        name: 'Books',
        forItemType: ItemType.novel,
        pos: 6,
        shouldUpdate: false,
      );
      final unrelated = Category(
        id: 14,
        name: 'Not retained',
        forItemType: ItemType.manga,
        pos: 10,
      );
      final matchingButUnreferenced = Category(
        id: 15,
        name: 'Remote only',
        forItemType: ItemType.manga,
        pos: 11,
        hide: true,
        shouldUpdate: false,
        updatedAt: 789,
      );

      final plan = const ChimahonManualRestoreCategoryAdapter().build(
        localCategories: [
          localManga,
          localOnly,
          localAnime,
          localNovel,
          unrelated,
          matchingButUnreferenced,
        ],
        retainedLocalCategoryIds: {10, 11, 12, 13},
        mangaCategories: [
          BackupCategory(name: 'Reading', order: Int64(2), hidden: true),
          BackupCategory(name: 'Remote only', order: Int64(3), hidden: true),
        ],
        animeCategories: [BackupCategory(name: 'Reading', order: Int64(4))],
        novelCategories: [
          BackupNovelCategory(id: 'default', name: 'Default', order: Int64(-1)),
          BackupNovelCategory(id: 'books', name: 'Books', order: Int64(5)),
        ],
      );

      expect(plan.records, hasLength(5));
      expect(
        plan.records.where((record) => record.category.name == 'Reading'),
        hasLength(2),
      );
      expect(
        plan.records.any((record) => record.category.name == unrelated.name),
        isFalse,
      );

      final restoredManga = plan.records.singleWhere(
        (record) =>
            record.category.name == 'Reading' &&
            record.category.forItemType == ItemType.manga,
      );
      expect(restoredManga.category.id, 10);
      expect(restoredManga.category.pos, 2);
      expect(restoredManga.category.hide, isTrue);
      expect(restoredManga.category.shouldUpdate, isFalse);
      expect(restoredManga.category.updatedAt, 123);
      expect(restoredManga.category.forManga, isTrue);

      final restoredLocalOnly = plan.records.singleWhere(
        (record) => record.category.name == localOnly.name,
      );
      expect(restoredLocalOnly.category.id, 11);
      expect(restoredLocalOnly.category.pos, 7);
      expect(restoredLocalOnly.category.shouldUpdate, isTrue);

      final restoredMatchingButUnreferenced = plan.records.singleWhere(
        (record) => record.category.name == 'Remote only',
      );
      expect(restoredMatchingButUnreferenced.category.id, 15);
      expect(restoredMatchingButUnreferenced.category.pos, 3);
      expect(restoredMatchingButUnreferenced.category.hide, isTrue);
      expect(restoredMatchingButUnreferenced.category.shouldUpdate, isFalse);
      expect(restoredMatchingButUnreferenced.category.updatedAt, 789);
      expect(plan.remapLocalIds([10, 11]), [10, 11]);
      expect(plan.idsForBackupOrders(ItemType.manga, [2, 3]), [10, 15]);
      expect(plan.idsForBackupOrders(ItemType.anime, [4]), [12]);
      expect(plan.idsForBackupOrders(ItemType.novel, [5]), [13]);
      expect(plan.idsForNovelBackupIds(['default', 'books']), [13]);
      expect(
        plan.records.any(
          (record) =>
              record.category.forItemType == ItemType.novel &&
              record.category.name == 'Default',
        ),
        isFalse,
      );
      expect(
        plan.idsForRetainedTitle(
          localIds: [10, 11],
          itemType: ItemType.manga,
          backupOrders: [2, 3],
        ),
        unorderedEquals([10, 11, 15]),
      );
      expect(
        plan.idsForRetainedNovelTitle(
          localIds: [13],
          backupIds: ['default', 'books'],
        ),
        [13],
      );
    },
  );

  test(
    'collapses same-name same-type duplicates and remaps every local ID',
    () {
      final plan = const ChimahonManualRestoreCategoryAdapter().build(
        localCategories: [
          Category(
            id: 30,
            name: ' Favorites ',
            forItemType: ItemType.manga,
            pos: 8,
            hide: true,
          ),
          Category(
            id: 31,
            name: 'favorites',
            forItemType: ItemType.manga,
            pos: 9,
            hide: false,
          ),
        ],
        retainedLocalCategoryIds: {30, 31},
        mangaCategories: [
          BackupCategory(name: 'Favorites', order: Int64(1), hidden: true),
          BackupCategory(name: ' favorites ', order: Int64(6), hidden: true),
        ],
        animeCategories: const [],
        novelCategories: const [],
      );

      expect(plan.records, hasLength(1));
      expect(plan.records.single.localIds, {30, 31});
      expect(plan.records.single.backupOrders, {1, 6});
      expect(plan.records.single.category.id, 30);
      expect(plan.records.single.category.hide, isTrue);
      expect(plan.remapLocalIds([30]), [30]);
      expect(plan.remapLocalIds([31]), [30]);
      expect(plan.idsForBackupOrders(ItemType.manga, [6]), [30]);
    },
  );
}
