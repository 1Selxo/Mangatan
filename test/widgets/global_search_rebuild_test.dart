import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/model/m_manga.dart';
import 'package:mangayomi/eval/model/m_pages.dart';
import 'package:mangayomi/l10n/generated/app_localizations.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/modules/browse/global_search/global_search_screen.dart';
import 'package:mangayomi/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:mangayomi/services/search.dart';
import 'package:mangayomi/utils/headers.dart';

import '../test_utils/isar_library.dart';

/// Global search keeps showing the same thing while doing less work when a
/// source finishes: the "no results" group fills in, the result rows stay as
/// they are, and a result card keeps its one library lookup across rebuilds.
void main() {
  late Directory directory;

  // Sources in installation order. "Broken" ones fail, "Empty" ones find
  // nothing, and the others return results.
  const names = ['Works A', 'Broken B', 'Works C', 'Empty D', 'Broken E'];

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): await isarTestLibraryPath()},
    );
    directory = Directory.systemTemp.createTempSync('global_search_rebuild');
    isar = await Isar.open(
      [SourceSchema, MangaSchema, ChapterSchema],
      directory: directory.path,
      name: 'global_search_rebuild',
    );
    isar.writeTxnSync(
      () => isar.sources.putAllSync([
        for (var i = 0; i < names.length; i++)
          Source(
            id: 100 + i,
            name: names[i],
            lang: 'en',
            isAdded: true,
            itemType: ItemType.manga,
          ),
      ]),
    );
  });

  tearDownAll(() async {
    await isar.close(deleteFromDisk: true);
    directory.deleteSync(recursive: true);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // Let the cards' library queries finish on real time, then unmount so
    // their watches are cancelled. Otherwise closing the database waits on
    // them forever.
    addTearDown(() async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pumpWidget(const SizedBox());
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          showNSFWStateProvider.overrideWithValue(true),
          onlyIncludePinnedSourceStateProvider.overrideWithValue(false),
          headersProvider.overrideWith((ref, args) => const {}),
          searchProvider.overrideWith((ref, args) async {
            final name = args.source.name!;
            // Sources answer one after another, so the group fills in over
            // several frames while results are on screen.
            await Future<void>.delayed(
              Duration(milliseconds: 10 * (names.indexOf(name) + 1)),
            );
            if (name.startsWith('Broken')) {
              throw Exception('$name failed:\n  HTTP 500');
            }
            if (name.startsWith('Empty')) return MPages(list: []);
            return MPages(
              list: [
                for (var i = 0; i < 3; i++)
                  MManga(name: '$name result $i', link: '/$name/$i'),
              ],
            );
          }),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GlobalSearchScreen(search: 'query', itemType: ItemType.manga),
        ),
      ),
    );
  }

  List<Stream<List<Manga>>?> cardStreams(WidgetTester tester) => [
    for (final builder in tester.widgetList<StreamBuilder<List<Manga>>>(
      find.byType(StreamBuilder<List<Manga>>),
    ))
      builder.stream,
  ];

  testWidgets('results, the no-results group and its order', (tester) async {
    await pumpScreen(tester);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    await tester.pump();

    for (final name in ['Works A', 'Works C']) {
      expect(find.text(name), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        expect(find.text('$name result $i'), findsOneWidget);
      }
    }
    expect(find.byType(MangaGlobalImageCard), findsNWidgets(6));
    expect(find.text('3 sources with no results'), findsOneWidget);
    // Collapsed: the failed sources are not listed yet.
    expect(find.text('Broken B'), findsNothing);

    await tester.tap(find.text('3 sources with no results'));
    await tester.pumpAndSettle();
    final listed = [
      for (final tile in tester.widgetList<ListTile>(
        find.descendant(
          of: find.byType(ExpansionTile),
          matching: find.byType(ListTile),
        ),
      ))
        if (tile.subtitle != null)
          ((tile.title as Text).data, (tile.subtitle as Text).data),
    ];
    // In the order the sources finished, with the error on one line.
    expect(listed, [
      ('Broken B', 'Failed! Exception: Broken B failed: HTTP 500'),
      ('Empty D', 'No result'),
      ('Broken E', 'Failed! Exception: Broken E failed: HTTP 500'),
    ]);
  });

  testWidgets('a result card keeps its library lookup across rebuilds', (
    tester,
  ) async {
    await pumpScreen(tester);
    // Only the first source has answered.
    await tester.pump(const Duration(milliseconds: 15));
    await tester.pump();
    final first = cardStreams(tester);
    expect(first, hasLength(3));
    expect(first.toSet(), hasLength(3));

    // The rest answer, including the failures that fill in the group.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    await tester.pump();
    final later = cardStreams(tester);
    expect(later, hasLength(6));
    for (var i = 0; i < 3; i++) {
      expect(identical(later[i], first[i]), isTrue);
    }

    // A card rebuilding on its own, as on a focus change.
    for (final element in find.byType(MangaGlobalImageCard).evaluate()) {
      (element as StatefulElement).markNeedsBuild();
    }
    await tester.pump();
    final rebuilt = cardStreams(tester);
    for (var i = 0; i < later.length; i++) {
      expect(identical(rebuilt[i], later[i]), isTrue);
    }
  });
}
