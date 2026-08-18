import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/anime/widgets/jimaku_subtitle_dialog.dart';

void main() {
  testWidgets('configured desktop dialog only shows the title override field', (
    tester,
  ) async {
    final titleController = TextEditingController();
    addTearDown(titleController.dispose);

    await _showDialog(
      tester,
      apiKeyConfigured: true,
      titleController: titleController,
    );

    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Title override'), findsOneWidget);
    expect(find.text('Jimaku API key'), findsNothing);
    expect(find.text('Set API key in Settings'), findsNothing);
    expect(find.text('Search'), findsOneWidget);
  });

  testWidgets('missing desktop key shows a settings action instead of search', (
    tester,
  ) async {
    final titleController = TextEditingController();
    addTearDown(titleController.dispose);

    await _showDialog(
      tester,
      apiKeyConfigured: false,
      titleController: titleController,
    );

    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Jimaku API key'), findsNothing);
    expect(find.text('Set API key in Settings'), findsOneWidget);
    expect(find.text('Search'), findsNothing);

    await tester.tap(find.text('Set API key in Settings'));
    await tester.pumpAndSettle();

    expect(
      find.text(JimakuSubtitleDialogAction.openSettings.name),
      findsOneWidget,
    );
  });

  testWidgets('legacy mobile dialog keeps API key editing and search', (
    tester,
  ) async {
    final apiKeyController = TextEditingController();
    final titleController = TextEditingController();
    addTearDown(apiKeyController.dispose);
    addTearDown(titleController.dispose);

    await _showDialog(
      tester,
      apiKeyConfigured: false,
      apiKeyController: apiKeyController,
      titleController: titleController,
    );

    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Jimaku API key'), findsOneWidget);
    expect(find.text('Set API key in Settings'), findsNothing);
    expect(find.text('Search'), findsOneWidget);
  });
}

Future<void> _showDialog(
  WidgetTester tester, {
  required bool apiKeyConfigured,
  required TextEditingController titleController,
  TextEditingController? apiKeyController,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final result = await showDialog<JimakuSubtitleDialogAction>(
                context: context,
                builder: (_) => JimakuSubtitleDialog(
                  apiKeyConfigured: apiKeyConfigured,
                  apiKeyController: apiKeyController,
                  titleController: titleController,
                  titleHint: 'Example title',
                  cancelLabel: 'Cancel',
                ),
              );
              if (!context.mounted || result == null) return;
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(body: Text(result.name)),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}
