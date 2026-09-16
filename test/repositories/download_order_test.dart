import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/download.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/repositories/download_repository.dart';
import 'package:mangayomi/services/download_manager/download_queue_order.dart';

void main() {
  test(
    'queue preserves episode arrival order despite descending IDs',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final overrides = HttpOverrides.current;
      HttpOverrides.global = null;
      try {
        await Isar.initializeIsarCore(download: true);
      } finally {
        HttpOverrides.global = overrides;
      }
      final dir = await Directory.systemTemp.createTemp('download_order');
      isar = await Isar.open(
      [MangaSchema, ChapterSchema, DownloadSchema, SettingsSchema, SourceSchema],
        directory: dir.path,
        name: 'order_${dir.path.hashCode}',
      );
      addTearDown(() async {
        await isar.close(deleteFromDisk: true);
        await dir.delete(recursive: true);
      });
      final chapters = [
        for (var i = 1; i <= 5; i++)
          Chapter(id: 100 - i, name: 'Episode $i', mangaId: 1),
      ];
      isar.writeTxnSync(() => isar.chapters.putAllSync(chapters));
      for (final chapter in chapters) {
        await downloadRepository.enqueue(chapter);
      }
      expect(
        DownloadQueueOrder.sorted(await downloadRepository.getPendingStarted())
            .map((d) => d.id),
        [99, 98, 97, 96, 95],
      );
      await downloadRepository.enqueue(chapters.first);
      expect(DownloadQueueOrder.order, [99, 98, 97, 96, 95]);
    },
  );
}
