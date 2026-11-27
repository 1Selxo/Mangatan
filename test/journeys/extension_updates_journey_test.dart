// Journeys about extension updates as the navigation and Browse show them.
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/modules/widgets/entry_badge_chip.dart';
import 'package:material_ui/material_ui.dart';

import 'harness/journey.dart';

Future<void> _source(
  Isar db, {
  required int id,
  required String version,
  required String newest,
  bool installed = true,
  bool obsolete = false,
}) => db.writeTxn(
  () => db.sources.put(
    Source(
      id: id,
      name: 'Source $id',
      lang: 'en',
      isAdded: installed,
      isActive: true,
      isObsolete: obsolete,
      version: version,
      versionLast: newest,
      itemType: ItemType.manga,
    ),
  ),
);

void main() {
  testWidgets(
    'the Browse badges count installed extensions with an update waiting',
    (tester) async {
      // The badges now read only the two versions of each source; this
      // guards that they still count what they counted.
      final j = await Journey.start(
        tester,
        arrange: (seed) async {
          // The check itself reads the repositories over the network, which a
          // journey has not got; the badges only read what is stored.
          await seed.settings((s) => s.checkForExtensionUpdates = false);
          await _source(seed.db, id: 1, version: '1.4.1', newest: '1.4.2');
          await _source(seed.db, id: 2, version: '1.4.2', newest: '1.4.2');
          // Neither counts: a listing nobody installed, and an extension
          // its repository no longer offers.
          await _source(
            seed.db,
            id: 3,
            version: '1.0',
            newest: '2.0',
            installed: false,
          );
          await _source(
            seed.db,
            id: 4,
            version: '1.0',
            newest: '2.0',
            obsolete: true,
          );
        },
      );

      final navBadge = find.descendant(
        of: find.byType(Badge),
        matching: find.text('1'),
      );
      await j.waitFor(navBadge);

      // The Extensions tab carries its own count; opening it would read the
      // repositories over the network.
      await j.go('/browse');
      await j.waitFor(
        find.descendant(
          of: find.byType(EntryBadgeChip),
          matching: find.text('1'),
        ),
      );

      // An update arriving shows without leaving the screen.
      expect(
        await j.drive(_source(j.db, id: 2, version: '1.4.2', newest: '1.5.0')),
        isTrue,
      );
      await j.waitFor(
        find.descendant(of: find.byType(Badge), matching: find.text('2')),
      );
    },
  );
}
