import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('presents a frame before warming optional isolate services', () {
    final source = File('lib/main.dart').readAsStringSync();
    final mainStart = source.indexOf('void main(List<String> args)');
    final startupErrorApp = source.indexOf('class _StartupErrorApp');

    expect(mainStart, greaterThanOrEqualTo(0));
    expect(startupErrorApp, greaterThan(mainStart));
    final mainSection = source.substring(mainStart, startupErrorApp);
    expect(mainSection, contains('runApp('));
    expect(
      mainSection,
      contains('WidgetsBinding.instance.addPostFrameCallback'),
    );
    expect(mainSection, isNot(contains('await getIsolateService.start()')));
    expect(mainSection, isNot(contains('await ffiImageDecoder.start()')));

    final postLaunchStart = source.indexOf(
      'Future<void> _postLaunchInit(StorageProvider storage)',
    );
    expect(postLaunchStart, greaterThan(startupErrorApp));
    final postLaunchSection = source.substring(postLaunchStart);
    expect(postLaunchSection, contains('unawaited(getIsolateService.start())'));
    expect(postLaunchSection, contains('unawaited(ffiImageDecoder.start())'));
  });

  test('renders a startup error instead of leaving iOS without a frame', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains('runZonedGuarded('));
    expect(source, matches(RegExp(r'\}\s*,\s*_handleUncaughtError\s*\);')));
    expect(
      source,
      contains('runApp(_StartupErrorApp(error: error.toString()))'),
    );
  });

  test('always finishes the Flutter application delegate launch', () {
    // Code only: a comment may name the call that was removed.
    final source = File('ios/Runner/AppDelegate.swift')
        .readAsLinesSync()
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');

    expect(source, isNot(contains('AppLinks.shared.getLink')));
    expect(source, isNot(contains('return true')));
    expect(
      source,
      contains(
        'return super.application(application, '
        'didFinishLaunchingWithOptions: launchOptions)',
      ),
    );
  });
}
