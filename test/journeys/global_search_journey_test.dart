// Journeys through the global search in Browse.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/eval/model/m_manga.dart';
import 'package:mangayomi/eval/model/m_pages.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/services/get_popular.dart';
import 'package:mangayomi/services/search.dart';

import 'harness/journey.dart';

/// Every source the search asked, by name, and a page of one result each.
(List<String>, List<Override>) _recordingSources() {
  final asked = <String>[];
  Future<MPages> answer(Source source) async {
    asked.add(source.name!);
    return MPages(
      list: [MManga(name: 'Found on ${source.name}', link: '/m', imageUrl: '')],
      hasNextPage: false,
    );
  }

  return (
    asked,
    [
      searchProvider.overrideWith((ref, a) => answer(a.source)),
      getPopularProvider.overrideWith((ref, a) => answer(a.source)),
    ],
  );
}

Future<void> _install(
  Isar db,
  String name, {
  required int id,
  bool enabled = true,
  bool pinned = false,
  bool nsfw = false,
}) => db.writeTxn(
  () => db.sources.put(
    Source(
      id: id,
      name: name,
      lang: 'en',
      baseUrl: 'https://$id.example',
      isAdded: true,
      isActive: enabled,
      isPinned: pinned,
      isNsfw: nsfw,
      itemType: ItemType.manga,
    ),
  ),
);

void main() {
  testWidgets('a search asks only the sources enabled in Browse', (
    tester,
  ) async {
    // Was: sources whose language was turned off in Browse were searched too.
    // On the profiled library that made a search of 73 visible sources query
    // 247, about two minutes at three requests at a time.
    final (asked, overrides) = _recordingSources();
    final j = await Journey.start(
      tester,
      overrides: overrides,
      arrange: (seed) async {
        await _install(seed.db, 'Shown Source', id: 1);
        await _install(seed.db, 'Hidden Source', id: 2, enabled: false);
      },
    );

    await j.push('globalSearch', extra: ('love', ItemType.manga));
    await j.waitFor(find.text('Found on Shown Source'));

    expect(find.text('Shown Source'), findsOneWidget);
    expect(find.text('Hidden Source'), findsNothing);
    expect(asked, ['Shown Source']);
  });

  testWidgets('with every source hidden, the search says so', (tester) async {
    final (asked, overrides) = _recordingSources();
    final j = await Journey.start(
      tester,
      overrides: overrides,
      arrange: (seed) =>
          _install(seed.db, 'Hidden Source', id: 2, enabled: false),
    );

    await j.push('globalSearch', extra: ('love', ItemType.manga));

    expect(find.textContaining('hidden in Browse'), findsOneWidget);
    expect(asked, isEmpty);
  });

  testWidgets('pinned-only and hidden NSFW narrow what is asked', (
    tester,
  ) async {
    final (asked, overrides) = _recordingSources();
    final j = await Journey.start(
      tester,
      overrides: overrides,
      arrange: (seed) async {
        await seed.settings(
          (s) => s
            ..onlyIncludePinnedSources = true
            ..showNSFW = false,
        );
        await _install(seed.db, 'Pinned Source', id: 1, pinned: true);
        await _install(seed.db, 'Unpinned Source', id: 2);
        await _install(
          seed.db,
          'Pinned NSFW Source',
          id: 3,
          pinned: true,
          nsfw: true,
        );
      },
    );

    await j.push('globalSearch', extra: ('love', ItemType.manga));
    await j.waitFor(find.text('Found on Pinned Source'));

    expect(asked, ['Pinned Source']);
  });
}
