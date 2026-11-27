// The mouse wheel in every reading mode (2026-11-08: "in horizontal
// continuous mode the scroll wheel does not advance", "in vertical mode the
// scroll has too much resistance") and the library's multi-select bar
// ("Selecting several library entries and using the bottom bar works",
// upstream fc4a0136 "fix library select between option").
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'harness/journey.dart';
import 'harness/reader.dart';

extension on Journey {
  /// Turns the mouse wheel [notches] times over the middle of the window,
  /// downwards for positive values, at a person's pace.
  Future<void> wheel(int notches) async {
    final center = tester.getCenter(find.byType(MaterialApp).first);
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    for (var i = 0; i < notches.abs(); i++) {
      await tester.sendEventToBinding(mouse.hover(center));
      await tester.sendEventToBinding(
        mouse.scroll(Offset(0, notches > 0 ? 120 : -120)),
      );
      await wait(const Duration(milliseconds: 400));
    }
  }
}

void main() {
  group('the mouse wheel', () {
    for (final mode in ReaderMode.values) {
      testWidgets('${mode.name}: a few notches down turn forward, up turns '
          'back', (tester) async {
        final j = await Journey.start(
          tester,
          arrange: (seed) async {
            await seed.settings((s) => s.defaultReaderMode = mode);
            final manga = await seed.manga('Kuso Onna');
            await seed.chapters(manga, 1, pages: 12);
          },
        );
        await j.tapText('Kuso Onna');
        await j.openChapter('Chapter 1');
        expect(j.pageIndicator, '1 / 12');
        int page() => int.parse(j.pageIndicator!.split(RegExp('[ -]')).first);
        // A notch scrolls a screen's fraction in continuous modes, a page in
        // paged ones: wheel on until the page moves, as a person does.
        var notches = 0;
        while (page() == 1 && notches < 30) {
          await j.wheel(1);
          notches++;
        }
        await j.wheel(2);
        final forward = page();
        expect(
          forward,
          greaterThan(1),
          reason: '${mode.name}: $notches notches down',
        );
        notches = 0;
        while (page() >= forward && notches < 30) {
          await j.wheel(-1);
          notches++;
        }
        expect(
          page(),
          lessThan(forward),
          reason: '${mode.name}: $notches notches up',
        );
      });
    }
  });

  group('library selection', () {
    Future<(Journey, Map<String, int>)> library(WidgetTester tester) async {
      final ids = <String, int>{};
      final j = await Journey.start(
        tester,
        arrange: (seed) async {
          await seed.category('Romance');
          for (final name in ['Alpha', 'Bravo', 'Charlie', 'Delta']) {
            final manga = await seed.manga(name);
            await seed.chapters(manga, 2);
            ids[name] = manga.id!;
          }
        },
      );
      return (j, ids);
    }

    Future<List<Chapter>> chaptersOf(Journey j, int mangaId) async =>
        (await j.tester.runAsync(
          () => j.db.chapters.filter().mangaIdEqualTo(mangaId).findAll(),
        ))!;

    testWidgets('selecting two series and marking them read', (tester) async {
      final (j, ids) = await library(tester);
      await j.longPress(find.text('Alpha'));
      await j.tap(find.text('Charlie'));
      await j.tapTooltip('Mark as read');
      await j.settle(rounds: 10);
      for (final name in ['Alpha', 'Charlie']) {
        expect(
          (await chaptersOf(j, ids[name]!)).every((c) => c.isRead!),
          isTrue,
          reason: name,
        );
      }
      expect(
        (await chaptersOf(j, ids['Bravo']!)).any((c) => c.isRead!),
        isFalse,
      );
      // The selection is over.
      expect(find.byTooltip('Mark as read').hitTestable(), findsNothing);
    });

    testWidgets('select between selects the series in between', (tester) async {
      final (j, ids) = await library(tester);
      await j.longPress(find.text('Alpha'));
      await j.tap(find.text('Delta'));
      await j.tapTooltip('Select between');
      await j.tapTooltip('Mark as read');
      await j.settle(rounds: 10);
      for (final name in ['Alpha', 'Bravo', 'Charlie', 'Delta']) {
        expect(
          (await chaptersOf(j, ids[name]!)).every((c) => c.isRead!),
          isTrue,
          reason: name,
        );
      }
    });

    testWidgets('invert selection selects the others', (tester) async {
      final (j, ids) = await library(tester);
      await j.longPress(find.text('Alpha'));
      await j.tapTooltip('Invert selection');
      await j.tapTooltip('Mark as read');
      await j.settle(rounds: 10);
      expect(
        (await chaptersOf(j, ids['Alpha']!)).any((c) => c.isRead!),
        isFalse,
      );
      expect(
        (await chaptersOf(j, ids['Delta']!)).every((c) => c.isRead!),
        isTrue,
      );
    });

    testWidgets('setting a category for selected series moves them to its '
        'tab', (tester) async {
      final (j, _) = await library(tester);
      await j.longPress(find.text('Bravo'));
      await j.tapTooltip('Set categories');
      await j.tap(find.text('Romance').hitTestable().last);
      await j.confirm(['OK', 'Save', 'Done']);
      await j.settle(rounds: 10);
      await j.tapText('Romance');
      expect(find.text('Bravo').hitTestable(), findsWidgets);
    });

    testWidgets(
      'S12: Escape ends a library selection on desktop',
      skip: true, // Suspected bug S12: only the close button ends it.
      (tester) async {
        final (j, _) = await library(tester);
        await j.longPress(find.text('Alpha'));
        expect(find.byTooltip('Mark as read').hitTestable(), findsWidgets);
        await j.key(LogicalKeyboardKey.escape);
        expect(find.byTooltip('Mark as read').hitTestable(), findsNothing);
      },
    );
  });
}

extension on Journey {
  Future<void> confirm(List<String> labels) async {
    await settle(rounds: 4);
    for (final label in labels) {
      final button = find.text(label).hitTestable();
      if (button.evaluate().isNotEmpty) {
        await tap(button.last);
        return;
      }
    }
  }
}
