import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mangayomi/modules/mining/widgets/dictionary_profile_override_dialog.dart';
import 'package:mangayomi/services/mining/dictionary_profile.dart';
import 'package:mangayomi/services/mining/dictionary_profile_resolver.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';

void main() {
  late Directory tempDirectory;
  final overrideKey = DictionaryProfileResolver.mangaOverrideKey(42);
  const japanese = DictionaryProfile(
    id: 'japanese',
    name: 'Japanese',
    languageCode: 'ja',
  );
  const english = DictionaryProfile(
    id: 'english',
    name: 'English',
    languageCode: 'en',
  );

  setUpAll(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'mangatan-profile-dialog-',
    );
    Hive.init(tempDirectory.path);
  });

  setUp(() async {
    if (Hive.isBoxOpen('mining_preferences')) {
      await Hive.box<dynamic>('mining_preferences').close();
    }
    await Hive.deleteBoxFromDisk('mining_preferences');
    await MiningPreferences.setDictionaryProfiles(const [
      japanese,
      english,
    ], activeId: japanese.id);
    await MiningPreferences.setDictionaryProfileOverride(
      overrideKey,
      'deleted-profile',
    );
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  testWidgets('stale overrides render as Auto and Cancel closes the dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showDictionaryProfileOverrideDialog(
                context: context,
                overrideKey: overrideKey,
                autoProfile: Future.value(japanese),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Auto (Japanese)'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Set dictionary profile'), findsNothing);
  });
}
