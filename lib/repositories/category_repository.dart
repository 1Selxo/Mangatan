import 'dart:async';

import 'package:isar_community/isar.dart';
import 'package:mangayomi/services/category_service.dart';
import 'package:mangayomi/repositories/db.dart';
import 'package:mangayomi/models/category.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/repositories/db_write_queue.dart';

class CategoryRepository {
  Category? findById(int id) => isar.categorys.getSync(id);

  Stream<List<Category>> watchAll() =>
      isar.categorys.where().watch(fireImmediately: true);

  List<Category> getAll() =>
      isar.categorys.filter().idIsNotNull().findAllSync();

  List<Category> getChangedSince(int since) => isar.categorys
      .filter()
      .updatedAtGreaterThan(since, include: true)
      .findAllSync();

  Category? getByClientId(int clientId) => isar.categorys
      .filter()
      .clientIdEqualTo(clientId)
      .or()
      .idEqualTo(clientId)
      .findFirstSync();

  // Async twin, for callers already inside an async writeTxn/writeTransactionAsync
  // — Isar rejects a sync findAllSync() call from inside an async transaction.
  Future<List<Category>> getAllAsync() =>
      isar.categorys.filter().idIsNotNull().findAll();

  bool isNotEmptyByItemType(ItemType itemType) => isar.categorys
      .filter()
      .idIsNotNull()
      .and()
      .forItemTypeEqualTo(itemType)
      .isNotEmptySync();

  List<Category> getByItemType(ItemType itemType) =>
      isar.categorys.filter().forItemTypeEqualTo(itemType).findAllSync();

  Stream<List<Category>> watchByItemTypeSimple(ItemType itemType) => isar
      .categorys
      .filter()
      .forItemTypeEqualTo(itemType)
      .watch(fireImmediately: true);

  Stream<List<Category>> watchByItemType(ItemType itemType) => isar.categorys
      .filter()
      .idIsNotNull()
      .and()
      .forItemTypeEqualTo(itemType)
      .watch(fireImmediately: true);

  Future<void> setHidden(Category category, bool hidden) => dbWriteQueue.run(
    () {
      isar.writeTxnSync(() => isar.categorys.putSync(category..hide = hidden));
    },
  );

  // Stamps updatedAt for callers that just want to persist a mutated Category
  // they already hold, without setting the timestamp themselves.
  Future<void> save(Category category) => dbWriteQueue.run(() {
    isar.writeTxnSync(() {
      category.updatedAt = DateTime.now().millisecondsSinceEpoch;
      isar.categorys.putSync(category);
    });
  });

  Future<void> putAll(List<Category> categories) => dbWriteQueue.run(
    () => isar.writeTxn(() => isar.categorys.putAll(categories)),
  );

  // Uncategorizes every manga that had this category, then deletes it.
  /// Deletes [category], takes it off the entries of its media type, and
  /// closes the gap it leaves in that type's category order.
  Future<void> remove(Category category) => dbWriteQueue.run(
    () => isar.writeTxn(() async {
      final itemType = category.forItemType;
      final items = await isar.mangas
          .filter()
          .categoriesElementEqualTo(category.id!)
          .and()
          .itemTypeEqualTo(itemType)
          .findAll();
      for (final item in items) {
        CategoryService.removeMembership(item, category.id!);
      }
      await isar.mangas.putAll(items);
      await isar.categorys.delete(category.id!);
      await isar.categorys.putAll(
        CategoryService.normalizePositions(
          await isar.categorys.filter().forItemTypeEqualTo(itemType).findAll(),
        ),
      );
    }),
  );

  /// Adds [category] after the last category of its media type.
  Future<void> create(Category category) => dbWriteQueue.run(() {
    isar.writeTxnSync(() {
      final siblings = CategoryService.ordered(
        isar.categorys
            .filter()
            .forItemTypeEqualTo(category.forItemType)
            .findAllSync(),
      );
      isar.categorys.putSync(
        category
          ..pos = siblings.isEmpty ? 0 : (siblings.last.pos ?? 0) + 1
          ..hide ??= false
          ..shouldUpdate ??= true,
      );
    });
  });

  // Sync/async primitives below are for callers already inside a write
  // transaction opened by transaction()/writeTransaction() — they don't
  // queue on their own.
  Future<int> putAsync(Category category) => isar.categorys.put(category);

  Future<bool> deleteAsync(int id) => isar.categorys.delete(id);

  int putSync(Category category) => isar.categorys.putSync(category);

  void deleteSync(int id) => isar.categorys.deleteSync(id);

  void putAllSync(List<Category> categories) =>
      isar.categorys.putAllSync(categories);

  void clearSync() => isar.categorys.clearSync();

  // Escape hatch for category-rooted transactions too specific to name.
  Future<T> transaction<T>(FutureOr<T> Function() body) =>
      dbWriteQueue.run(body);

  Future<T> writeTransaction<T>(T Function() body) =>
      dbWriteQueue.run(() => isar.writeTxnSync(body));

  Future<T> writeTransactionAsync<T>(Future<T> Function() body) =>
      dbWriteQueue.run(() => isar.writeTxn(body));
}

final categoryRepository = CategoryRepository();
