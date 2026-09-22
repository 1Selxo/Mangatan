import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/settings/dictionary/hachidori_link_section.dart';
import 'package:mangayomi/services/hachidori/hachidori_link_controller.dart';
import 'package:mangayomi/services/hachidori/hachidori_models.dart';
import 'package:mangayomi/services/hachidori/hachidori_preferences.dart';

void main() {
  testWidgets(
    'probe then link shows a host-managed library and unlink restores local controls',
    (tester) async {
      final controller = _FakeLinkController();
      await tester.pumpWidget(
        _app(
          HachidoriDictionaryLibraryPanel(
            controller: controller,
            localControls: const Column(
              children: [
                Text('Update dictionaries automatically'),
                Text('Import Yomitan dictionary'),
                Text('Enable dictionary'),
                Text('Reorder dictionary'),
                Text('Remove dictionary'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hachidori shared library'), findsOneWidget);
      expect(
        find.textContaining('sharing through hachidori-anki'),
        findsOneWidget,
      );
      expect(find.text('Import Yomitan dictionary'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Link library'),
            )
            .onPressed,
        isNull,
      );

      await tester.enterText(
        find.byKey(const ValueKey('hachidori-address-field')),
        'reader.test:8771',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.textContaining('Hachidori host 1.0.0'), findsOneWidget);
      expect(find.textContaining('2 dictionaries'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Link library'),
            )
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.text('Link library'));
      await tester.pumpAndSettle();

      expect(
        find.text('Manage shared dictionaries in the Hachidori host.'),
        findsOneWidget,
      );
      expect(find.text('JMdict English'), findsOneWidget);
      expect(find.text('Pitch accents'), findsOneWidget);
      expect(find.text('Enabled'), findsOneWidget);
      expect(find.text('Disabled'), findsOneWidget);
      expect(find.text('Import Yomitan dictionary'), findsNothing);
      expect(find.text('Update dictionaries automatically'), findsNothing);
      expect(find.text('Enable dictionary'), findsNothing);
      expect(find.text('Reorder dictionary'), findsNothing);
      expect(find.text('Remove dictionary'), findsNothing);

      await tester.tap(find.text('Unlink'));
      await tester.pumpAndSettle();

      expect(find.text('Import Yomitan dictionary'), findsOneWidget);
      expect(find.text('Remove dictionary'), findsOneWidget);
    },
  );

  testWidgets('shows an actionable probe failure without enabling link', (
    tester,
  ) async {
    final controller = _FakeLinkController()..probeError = 'Host unavailable';
    await tester.pumpWidget(
      _app(
        HachidoriDictionaryLibraryPanel(
          controller: controller,
          localControls: const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('hachidori-address-field')),
      'offline.test',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.textContaining('Host unavailable'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Link library'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('ignores a probe failure after the address changes', (
    tester,
  ) async {
    final probe = Completer<HachidoriProbeResult>();
    final controller = _FakeLinkController()..pendingProbe = probe;
    await tester.pumpWidget(
      _app(
        HachidoriDictionaryLibraryPanel(
          controller: controller,
          localControls: const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = find.byKey(const ValueKey('hachidori-address-field'));
    await tester.enterText(field, 'old.test');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.enterText(field, 'new.test');
    probe.completeError(StateError('obsolete failure'));
    await tester.pumpAndSettle();

    expect(find.textContaining('obsolete failure'), findsNothing);
  });
}

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: ListView(children: [child])),
);

class _FakeLinkController extends ChangeNotifier
    implements HachidoriLinkController {
  HachidoriLinkConfiguration _configuration =
      const HachidoriLinkConfiguration.disabled();
  HachidoriClientState _state = const HachidoriClientState();
  String? probeError;
  Completer<HachidoriProbeResult>? pendingProbe;

  @override
  HachidoriLinkConfiguration get configuration => _configuration;

  @override
  HachidoriClientState get clientState => _state;

  @override
  bool get remoteEnabled => _configuration.enabled;

  @override
  Future<void> initialize() async {}

  @override
  Future<HachidoriProbeResult> probe(String address) async {
    if (probeError case final String error) throw StateError(error);
    if (pendingProbe case final pending?) return pending.future;
    return const HachidoriProbeResult(
      host: HachidoriHostIdentity(
        version: '1.0.0',
        name: 'Hachidori host',
        dictionaryCount: 2,
        capabilities: [],
      ),
      snapshot: {},
      dictionaries: [
        HachidoriDictionaryInfo(
          id: 'jmdict',
          title: 'JMdict',
          displayName: 'JMdict English',
          enabled: true,
          favorite: false,
          revision: '1',
          termCount: 100,
          frequencyCount: 0,
          pitchCount: 0,
          kanjiCount: 0,
          mediaCount: 2,
        ),
        HachidoriDictionaryInfo(
          id: 'pitch',
          title: 'Pitch accents',
          displayName: null,
          enabled: false,
          favorite: false,
          revision: '1',
          termCount: 0,
          frequencyCount: 0,
          pitchCount: 50,
          kanjiCount: 0,
          mediaCount: 0,
        ),
      ],
    );
  }

  @override
  Future<void> link(String address) async {
    final probe = await this.probe(address);
    _configuration = HachidoriLinkConfiguration(
      enabled: true,
      address: address,
    );
    _state = HachidoriClientState(
      linked: true,
      ready: true,
      host: probe.host,
      snapshot: probe.snapshot,
      dictionaries: probe.dictionaries,
    );
    notifyListeners();
  }

  @override
  Future<void> unlink() async {
    _configuration = HachidoriLinkConfiguration(
      enabled: false,
      address: _configuration.address,
    );
    _state = const HachidoriClientState();
    notifyListeners();
  }
}
