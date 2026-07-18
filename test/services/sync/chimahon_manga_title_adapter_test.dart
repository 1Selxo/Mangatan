import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/services/sync/chimahon_manga_title_adapter.dart';

void main() {
  const adapter = ChimahonMangaTitleAdapter();

  test('decodes Chimahon custom title field 800', () {
    // title (field 3) = "Source"; customTitle (field 800) = "Custom".
    final encoded = <int>[
      0x1a,
      0x06,
      ...'Source'.codeUnits,
      0x82,
      0x32,
      0x06,
      ...'Custom'.codeUnits,
    ];

    final manga = BackupManga.fromBuffer(encoded);
    final titles = adapter.fromBackup(manga);

    expect(manga.hasCustomTitle(), isTrue);
    expect(titles.sourceTitle, 'Source');
    expect(titles.displayTitle, 'Custom');
  });

  test('falls back to the source title when field 800 is absent', () {
    final titles = adapter.fromBackup(BackupManga(title: 'Source'));

    expect(titles.sourceTitle, 'Source');
    expect(titles.displayTitle, 'Source');
    expect(titles.customTitle, isNull);
  });

  test('source refresh preserves a custom display title', () {
    final manga = _manga(name: 'Custom', sourceTitle: 'Old source');

    manga.updateSourceTitle('New source');

    expect(manga.sourceTitle, 'New source');
    expect(manga.name, 'Custom');
  });

  test('display-title edits retain source identity and can clear override', () {
    final manga = _manga(name: 'Source', sourceTitle: 'Source');

    manga.updateDisplayTitle('Custom');

    expect(manga.name, 'Custom');
    expect(manga.sourceTitle, 'Source');
    expect(adapter.fromManga(manga).customTitle, 'Custom');

    manga.updateDisplayTitle('Source');

    expect(manga.sourceTitle, 'Source');
    expect(adapter.fromManga(manga).customTitle, isNull);
  });

  test('migration to another source resets title identity and override', () {
    final manga = _manga(name: 'Custom', sourceTitle: 'Old source');

    manga.resetTitleFromSource('Destination source');

    expect(manga.name, 'Destination source');
    expect(manga.sourceTitle, 'Destination source');
    expect(adapter.fromManga(manga).customTitle, isNull);
  });

  test('source refresh updates an uncustomized or legacy display title', () {
    final uncustomized = _manga(name: 'Old source', sourceTitle: 'Old source');
    final legacy = _manga(name: 'Legacy source')..sourceTitle = null;

    uncustomized.updateSourceTitle('New source');
    legacy.updateSourceTitle('New legacy source');

    expect(uncustomized.name, 'New source');
    expect(uncustomized.sourceTitle, 'New source');
    expect(legacy.name, 'New legacy source');
    expect(legacy.sourceTitle, 'New legacy source');
  });

  test('native JSON backup preserves the source title', () {
    final restored = Manga.fromJson(
      _manga(name: 'Custom', sourceTitle: 'Source').toJson(),
    );

    expect(restored.name, 'Custom');
    expect(restored.sourceTitle, 'Source');
  });
}

Manga _manga({required String name, String? sourceTitle}) => Manga(
  id: 1,
  source: 'Source',
  sourceId: 2,
  author: 'Author',
  artist: 'Artist',
  genre: const [],
  imageUrl: 'cover',
  lang: 'ja',
  link: '/manga',
  name: name,
  sourceTitle: sourceTitle,
  status: Status.ongoing,
  description: 'Description',
);
