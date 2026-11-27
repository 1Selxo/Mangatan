import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// A journey takes seconds (the longest about 90 s). A hung one fails after
/// 3 minutes instead of holding the run for flutter's default 10; testWidgets
/// takes its limit from the binding, not from `--timeout`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  if (binding is AutomatedTestWidgetsFlutterBinding) {
    binding.defaultTestTimeout = const Timeout(Duration(minutes: 3));
  }
  await _loadFonts();
  await testMain();
}

/// Text is measured with the app's own fonts: Figtree, the interface face
/// of the bundled shiori design package, plus Roboto for anything that asks
/// Material's default. Without them flutter_test draws every letter as a full
/// square, far wider than any real font, and reports overflows a person never
/// sees.
Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final file in files) {
      if (!File(file).existsSync()) throw StateError('Font not found: $file');
      loader.addFont(
        Future.value(ByteData.sublistView(File(file).readAsBytesSync())),
      );
    }
    await loader.load();
  }

  await load('packages/shiori/Figtree', [
    p.join(
      'packages',
      'shiori',
      'assets',
      'fonts',
      'Figtree',
      'Figtree-Variable.ttf',
    ),
  ]);
  // flutter_tester.exe lives in <flutter>/bin/cache/artifacts/engine/<os>/;
  // Flutter ships Roboto beside it.
  final material = p.join(
    p.dirname(p.dirname(p.dirname(Platform.resolvedExecutable))),
    'material_fonts',
  );
  await load('Roboto', [
    for (final name in ['regular', 'medium', 'bold', 'light', 'italic'])
      p.join(material, 'roboto-$name.ttf'),
  ]);
}
