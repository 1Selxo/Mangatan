import 'dart:async';

import 'package:isar_community/isar.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/repositories/db_write_queue.dart';

class SettingsRepository {
  Settings get current => isar.settings.getSync(227)!;

  Settings? get currentOrNull {
    try {
      return isar.settings.getSync(227);
    } catch (_) {
      return null;
    }
  }

  /// Reads one stored field of the settings row, with the same result as
  /// reading that field from [current].
  ///
  /// [current] deserializes the whole row, including per-entry lists that grow
  /// with the library (chapter page indexes, chapter filters and sorts), which
  /// many providers pay for at startup to read a single value. This reads only
  /// the selected property. When the row is missing it throws exactly as
  /// [current] does.
  T field<T>(
    QueryBuilder<Settings, T, QQueryOperations> Function(
      QueryBuilder<Settings, Settings, QQueryProperty> settings,
    )
    property,
  ) {
    final values = property(isar.settings.where().idEqualTo(227)).findAllSync();
    if (values.isEmpty) {
      // No settings row: `current` fails with its usual null-check error.
      current;
      throw StateError('The settings row is missing.');
    }
    return values.first;
  }

  /// Reads one stored field of the settings row, with the same result as
  /// `currentOrNull?.<field>`: null when the row is missing, when the value is
  /// null, or when reading fails.
  T? fieldOrNull<T>(
    QueryBuilder<Settings, T?, QQueryOperations> Function(
      QueryBuilder<Settings, Settings, QQueryProperty> settings,
    )
    property,
  ) {
    try {
      return property(isar.settings.where().idEqualTo(227)).findFirstSync();
    } catch (_) {
      return null;
    }
  }

  Future<Settings?> get currentAsync => isar.settings.get(227);

  List<Settings> getAll() => isar.settings.filter().idIsNotNull().findAllSync();

  Stream<Settings> watch() => isar.settings
      .where()
      .idEqualTo(227)
      .watch(fireImmediately: true)
      .map((l) => l.first);

  Future<void> update(void Function(Settings s) mutate) => dbWriteQueue.run(() {
    isar.writeTxnSync(() {
      // A damaged/partially-created database must not turn every settings
      // control into a null-check crash. Recreate the singleton row with its
      // model defaults and apply the requested change in the same transaction.
      final s = currentOrNull ?? Settings();
      mutate(s);
      s.updatedAt = DateTime.now().millisecondsSinceEpoch;
      isar.settings.putSync(s);
    });
  });

  // For callers that already hold the Settings instance to mutate (e.g. a family
  // provider's cached param) rather than wanting a freshly-fetched one.
  Future<void> save(Settings s) => dbWriteQueue.run(() {
    isar.writeTxnSync(() {
      s.updatedAt = DateTime.now().millisecondsSinceEpoch;
      isar.settings.putSync(s);
    });
  });

  // Sync primitive below is for callers already inside a write transaction
  // opened by transaction()/writeTransaction() — it doesn't queue on its own.
  void putSync(Settings s) => isar.settings.putSync(s);

  Future<int> putAsync(Settings s) => isar.settings.put(s);

  void putAllSync(List<Settings> settingsList) =>
      isar.settings.putAllSync(settingsList);

  void clearSync() => isar.settings.clearSync();

  // Escape hatch for Settings-rooted transactions too specific to name
  // (e.g. first-run seeding).
  Future<T> transaction<T>(FutureOr<T> Function() body) =>
      dbWriteQueue.run(body);

  // Same, but opens the write transaction too, so callers never touch isar.
  Future<T> writeTransaction<T>(T Function() body) =>
      dbWriteQueue.run(() => isar.writeTxnSync(body));

  Future<T> writeTransactionAsync<T>(Future<T> Function() body) =>
      dbWriteQueue.run(() => isar.writeTxn(body));
}

final settingsRepository = SettingsRepository();
