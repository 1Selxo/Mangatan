import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/mining/widgets/dictionary_lookup_popup.dart';
import 'package:mangayomi/services/mining/dictionary_profile.dart';

class _UnusedBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('A mismatched prefetch must not inspect its context');
}

void main() {
  test('route changes dismiss any root-overlay dictionary popup', () {
    var dismissals = 0;
    final observer = DictionaryPopupDismissNavigatorObserver(
      onNavigation: () => dismissals++,
    );
    final first = MaterialPageRoute<void>(builder: (_) => const SizedBox());
    final second = MaterialPageRoute<void>(builder: (_) => const SizedBox());

    observer.didPush(first, null);
    observer.didPush(second, first);
    observer.didPop(second, first);
    observer.didReplace(newRoute: second, oldRoute: first);
    observer.didRemove(second, first);

    expect(dismissals, 5);
  });

  group('dictionary popup presentation policy', () {
    test('suppresses a current lookup with no results', () async {
      final gate = DictionaryPopupPresentationGate();
      final generation = gate.begin();

      expect(
        await gate.resolve<int>(
          generation: generation,
          results: Future.value(const []),
        ),
        DictionaryPopupPresentationDecision.empty,
      );
    });

    test('presents a current lookup with results', () async {
      final gate = DictionaryPopupPresentationGate();
      final generation = gate.begin();

      expect(
        await gate.resolve<int>(
          generation: generation,
          results: Future.value(const [1]),
        ),
        DictionaryPopupPresentationDecision.present,
      );
    });

    test('preserves the retryable popup for lookup failures', () async {
      final gate = DictionaryPopupPresentationGate();
      final generation = gate.begin();

      expect(
        await gate.resolve<int>(
          generation: generation,
          results: Future.error(StateError('lookup failed')),
        ),
        DictionaryPopupPresentationDecision.present,
      );
    });

    test(
      'a slow old lookup cannot appear after a newer empty lookup',
      () async {
        final gate = DictionaryPopupPresentationGate();
        final oldResults = Completer<List<int>>();
        final oldGeneration = gate.begin();
        final oldDecision = gate.resolve<int>(
          generation: oldGeneration,
          results: oldResults.future,
        );

        final newGeneration = gate.begin();
        expect(
          await gate.resolve<int>(
            generation: newGeneration,
            results: Future.value(const []),
          ),
          DictionaryPopupPresentationDecision.empty,
        );
        oldResults.complete(const [1]);

        expect(await oldDecision, DictionaryPopupPresentationDecision.stale);
      },
    );

    test('a stale empty lookup cannot hide a newer result', () async {
      final gate = DictionaryPopupPresentationGate();
      final oldResults = Completer<List<int>>();
      final oldGeneration = gate.begin();
      final oldDecision = gate.resolve<int>(
        generation: oldGeneration,
        results: oldResults.future,
      );

      final newGeneration = gate.begin();
      expect(
        await gate.resolve<int>(
          generation: newGeneration,
          results: Future.value(const [1]),
        ),
        DictionaryPopupPresentationDecision.present,
      );
      oldResults.complete(const []);

      expect(await oldDecision, DictionaryPopupPresentationDecision.stale);
    });

    test('explicit dismissal invalidates a pending lookup', () async {
      final gate = DictionaryPopupPresentationGate();
      final results = Completer<List<int>>();
      final generation = gate.begin();
      final decision = gate.resolve<int>(
        generation: generation,
        results: results.future,
      );

      gate.cancel();
      results.complete(const [1]);

      expect(await decision, DictionaryPopupPresentationDecision.stale);
    });
  });

  group('dictionary popup profile prefetch', () {
    const profile = DictionaryProfile(
      id: 'profile-ko',
      name: 'Korean',
      languageCode: 'ko',
    );

    test(
      'keeps the normalized lookup text and exact profile together',
      () async {
        final prefetch = DictionaryLookupPopup.prefetch(
          '   ',
          profile: profile,
        );

        expect(prefetch.text, isEmpty);
        expect(await prefetch.profile, same(profile));
        expect(await prefetch.results, isEmpty);
      },
    );

    test('prepare rejects a prefetch produced for different text', () async {
      final prefetch = DictionaryLookupPopup.prefetch('', profile: profile);

      await DictionaryLookupPopup.prepare(
        context: _UnusedBuildContext(),
        text: 'different lookup',
        prefetch: prefetch,
      );
    });
  });

  group('native dictionary expansion policy', () {
    const dictionaries = ['Unordered', 'First', 'Second'];

    test('expands every available dictionary by default', () {
      const profile = DictionaryProfile(
        id: 'all',
        name: 'All',
        dictionaryOrder: ['Second', 'Missing', 'First'],
      );

      expect(
        initiallyExpandedDictionaries(
          profile: profile,
          dictionaries: dictionaries,
        ),
        {'Second', 'First', 'Unordered'},
      );
    });

    test('collapses every dictionary in collapse-all mode', () {
      const profile = DictionaryProfile(
        id: 'none',
        name: 'None',
        dictionaryCollapseMode: 'collapse_all',
      );

      expect(
        initiallyExpandedDictionaries(
          profile: profile,
          dictionaries: dictionaries,
        ),
        isEmpty,
      );
    });

    test('expands the first available dictionary in profile order', () {
      const profile = DictionaryProfile(
        id: 'first',
        name: 'First',
        dictionaryOrder: ['Missing', 'Second', 'First'],
        dictionaryCollapseMode: 'expand_first_available',
      );

      expect(
        initiallyExpandedDictionaries(
          profile: profile,
          dictionaries: dictionaries,
        ),
        {'Second'},
      );
    });

    test('applies custom overrides before the fallback cascade', () {
      const profile = DictionaryProfile(
        id: 'custom',
        name: 'Custom',
        dictionaryOrder: ['Second', 'First', 'Unordered'],
        dictionaryCollapseMode: 'custom',
        dictionaryDisplayModes: {
          'Second': 'always_collapsed',
          'Unordered': 'always_expanded',
        },
      );

      expect(
        initiallyExpandedDictionaries(
          profile: profile,
          dictionaries: dictionaries,
        ),
        {'First', 'Unordered'},
      );
    });
  });

  group('dictionary popup dismissal policy', () {
    test('Escape, Backspace, and browser back dismiss the popup', () {
      expect(dictionaryPopupIsDismissKey(LogicalKeyboardKey.escape), isTrue);
      expect(dictionaryPopupIsDismissKey(LogicalKeyboardKey.backspace), isTrue);
      expect(
        dictionaryPopupIsDismissKey(LogicalKeyboardKey.browserBack),
        isTrue,
      );
      expect(dictionaryPopupIsDismissKey(LogicalKeyboardKey.enter), isFalse);
    });

    test('an outside primary click dismisses without a modal barrier', () {
      const popup = Rect.fromLTWH(100, 100, 300, 250);

      expect(
        dictionaryPopupShouldDismissForPointer(
          visible: true,
          dismissOnOutsideTap: true,
          popupBounds: popup,
          position: const Offset(40, 40),
          buttons: kPrimaryMouseButton,
        ),
        isTrue,
      );
      expect(
        dictionaryPopupShouldDismissForPointer(
          visible: true,
          dismissOnOutsideTap: true,
          popupBounds: popup,
          position: const Offset(200, 200),
          buttons: kPrimaryMouseButton,
        ),
        isFalse,
      );
    });

    test('mouse back is reserved for the app-level popup-first handler', () {
      expect(
        dictionaryPopupShouldDismissForPointer(
          visible: true,
          dismissOnOutsideTap: true,
          popupBounds: const Rect.fromLTWH(100, 100, 300, 250),
          position: Offset.zero,
          buttons: kBackMouseButton,
        ),
        isFalse,
      );
    });

    test('outside click dismisses if no replacement popup is presented', () {
      expect(
        dictionaryPopupShouldCommitOutsideDismissal(
          visible: true,
          startedGeneration: 4,
          currentGeneration: 4,
        ),
        isTrue,
      );
    });

    test('replacement popup cancels the pending outside dismissal', () {
      expect(
        dictionaryPopupShouldCommitOutsideDismissal(
          visible: true,
          startedGeneration: 4,
          currentGeneration: 5,
        ),
        isFalse,
      );
    });

    test('stale popup handles cannot dismiss a replacement popup', () {
      expect(
        dictionaryPopupCanDismissGeneration(
          expectedGeneration: 4,
          currentGeneration: 5,
        ),
        isFalse,
      );
      expect(
        dictionaryPopupCanDismissGeneration(
          expectedGeneration: 5,
          currentGeneration: 5,
        ),
        isTrue,
      );
    });
  });

  group('dictionary popup placement', () {
    test(
      'positions recursive lookup anchors in the parent popup coordinate space',
      () {
        final anchor = dictionaryPopupChildAnchor(
          parentRect: const Rect.fromLTWH(900, 535, 540, 450),
          localSelectionRect: const Rect.fromLTWH(24, 112, 38, 22),
        );

        expect(anchor, const Rect.fromLTWH(924, 647, 38, 22));
      },
    );

    test('keeps the default popup below horizontal text', () {
      final rect = dictionaryPopupRect(
        screen: const Size(1000, 800),
        anchor: const Rect.fromLTWH(400, 300, 100, 80),
        preferredSize: const Size(320, 240),
      );

      expect(rect, const Rect.fromLTWH(290, 388, 320, 240));
    });

    test('shrinks horizontal popup instead of covering the selected word', () {
      final rect = dictionaryPopupRect(
        screen: const Size(600, 400),
        anchor: const Rect.fromLTWH(250, 170, 100, 60),
        preferredSize: const Size(320, 300),
      );

      expect(rect, const Rect.fromLTWH(140, 238, 320, 150));
      expect(rect.overlaps(const Rect.fromLTWH(250, 170, 100, 60)), isFalse);
    });

    test('places vertical text popup on the preferred right side', () {
      final rect = dictionaryPopupRect(
        screen: const Size(1000, 800),
        anchor: const Rect.fromLTWH(400, 200, 40, 300),
        preferredSize: const Size(320, 240),
        placement: DictionaryPopupPlacement.leftOrRight,
      );

      expect(rect, const Rect.fromLTWH(448, 200, 320, 240));
    });

    test('falls back to the left when the right side would overflow', () {
      final rect = dictionaryPopupRect(
        screen: const Size(1000, 800),
        anchor: const Rect.fromLTWH(850, 500, 40, 180),
        preferredSize: const Size(320, 240),
        placement: DictionaryPopupPlacement.leftOrRight,
      );

      expect(rect, const Rect.fromLTWH(522, 500, 320, 240));
    });

    test('shrinks on the larger side instead of moving above or below', () {
      final rect = dictionaryPopupRect(
        screen: const Size(600, 800),
        anchor: const Rect.fromLTWH(250, 700, 100, 80),
        preferredSize: const Size(500, 240),
        placement: DictionaryPopupPlacement.leftOrRight,
      );

      expect(rect, const Rect.fromLTWH(12, 548, 230, 240));
    });
  });
}
