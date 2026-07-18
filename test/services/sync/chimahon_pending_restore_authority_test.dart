import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupAnime.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupCategory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/services/sync/chimahon_pending_restore_authority.dart';

void main() {
  test(
    'pending restore preserves exact colliding manga and anime categories',
    () {
      final pending = BackupMihon(
        backupCategories: [
          BackupCategory(name: 'Reading', order: Int64.ZERO),
          BackupCategory(name: ' reading ', order: Int64.ONE),
        ],
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/selected-manga',
            title: 'Selected manga',
            categories: [Int64.ZERO, Int64.ONE],
          ),
        ],
        backupAnimeCategories: [
          BackupCategory(name: 'Reading', order: Int64.ZERO),
          BackupCategory(name: ' reading ', order: Int64.ONE),
        ],
        backupAnime: [
          BackupAnime(
            source: Int64(2),
            url: '/selected-anime',
            title: 'Selected anime',
            categories: [Int64.ZERO, Int64.ONE],
          ),
        ],
      );
      final localIntent = pending.deepCopy();
      final merged = localIntent.deepCopy()
        ..backupCategories.add(
          BackupCategory(name: 'Cloud-only', order: Int64.ONE),
        )
        ..backupManga.add(
          BackupManga(
            source: Int64(3),
            url: '/cloud-only-manga',
            title: 'Cloud-only manga',
            categories: [Int64.ONE],
          ),
        )
        ..backupAnimeCategories.add(
          BackupCategory(name: 'Cloud-only', order: Int64.ONE),
        )
        ..backupAnime.add(
          BackupAnime(
            source: Int64(4),
            url: '/cloud-only-anime',
            title: 'Cloud-only anime',
            categories: [Int64.ONE],
          ),
        );
      final authority = ChimahonPendingRestoreAuthority();

      final applied = authority.apply(
        pending: pending,
        localIntent: localIntent,
        remote: null,
        merged: merged,
      );

      final mangaCategoryOrders = {
        for (final category in applied.backupCategories)
          category.name: category.order,
      };
      expect(mangaCategoryOrders.keys, ['Reading', ' reading ', 'Cloud-only']);
      expect(mangaCategoryOrders.values.toSet(), hasLength(3));
      expect(mangaCategoryOrders['Reading'], Int64.ZERO);
      expect(mangaCategoryOrders[' reading '], Int64.ONE);
      expect(
        applied.backupManga
            .singleWhere((manga) => manga.url == '/selected-manga')
            .categories,
        [Int64.ZERO, Int64.ONE],
      );
      expect(
        applied.backupManga
            .singleWhere((manga) => manga.url == '/cloud-only-manga')
            .categories,
        [mangaCategoryOrders['Cloud-only']],
      );

      final animeCategoryOrders = {
        for (final category in applied.backupAnimeCategories)
          category.name: category.order,
      };
      expect(animeCategoryOrders.keys, ['Reading', ' reading ', 'Cloud-only']);
      expect(animeCategoryOrders.values.toSet(), hasLength(3));
      expect(animeCategoryOrders['Reading'], Int64.ZERO);
      expect(animeCategoryOrders[' reading '], Int64.ONE);
      expect(
        applied.backupAnime
            .singleWhere((anime) => anime.url == '/selected-anime')
            .categories,
        [Int64.ZERO, Int64.ONE],
      );
      expect(
        applied.backupAnime
            .singleWhere((anime) => anime.url == '/cloud-only-anime')
            .categories,
        [animeCategoryOrders['Cloud-only']],
      );
      expect(
        authority.containsSelectedIntent(
          uploaded: applied,
          pending: pending,
          localIntent: localIntent,
        ),
        isTrue,
      );
    },
  );
}
