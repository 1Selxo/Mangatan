import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/settings/dictionary/dictionary_screen.dart';

void main() {
  test('dictionary drops accept ZIP paths case-insensitively', () {
    expect(
      dictionaryZipPaths(const [
        '/dictionaries/jmdict.zip',
        '/dictionaries/kanji.ZIP',
        '/dictionaries/readme.txt',
      ]),
      const ['/dictionaries/jmdict.zip', '/dictionaries/kanji.ZIP'],
    );
  });

  testWidgets('dropped dictionary ZIPs use the supplied import pipeline', (
    tester,
  ) async {
    List<String>? imported;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DictionaryZipDropTarget(
            enabled: true,
            onImport: (paths) async => imported = paths,
            child: const ListTile(title: Text('Import Yomitan dictionary')),
          ),
        ),
      ),
    );

    final target = tester.widget<DropTarget>(find.byType(DropTarget));
    target.onDragEntered!(
      DropEventDetails(localPosition: Offset.zero, globalPosition: Offset.zero),
    );
    await tester.pump();
    final highlighted = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('dictionary-zip-drop-highlight')),
    );
    expect((highlighted.decoration as BoxDecoration).border, isNotNull);

    target.onDragDone!(
      DropDoneDetails(
        files: [
          DropItemFile('/dictionaries/jmdict.zip'),
          DropItemFile('/dictionaries/ignore.txt'),
        ],
        localPosition: Offset.zero,
        globalPosition: Offset.zero,
      ),
    );
    await tester.pump();

    expect(imported, const ['/dictionaries/jmdict.zip']);
  });
}
