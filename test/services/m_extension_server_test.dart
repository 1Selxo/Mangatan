import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/m_extension_server.dart';

void main() {
  group('embedded iOS Mihon bridge response', () {
    test('accepts a valid loopback port', () {
      expect(
        embeddedMihonBaseUrlFromResponse({
          'port': 49321,
          'baseUrl': 'http://127.0.0.1:49321',
        }),
        'http://127.0.0.1:49321',
      );
    });

    test('constructs the URL when native code only returns a port', () {
      expect(
        embeddedMihonBaseUrlFromResponse({'port': 8080}),
        'http://127.0.0.1:8080',
      );
    });

    test('rejects remote, invalid, and mismatched responses', () {
      expect(
        embeddedMihonBaseUrlFromResponse({
          'port': 8080,
          'baseUrl': 'https://bridge.example',
        }),
        isNull,
      );
      expect(
        embeddedMihonBaseUrlFromResponse({
          'port': 8080,
          'baseUrl': 'http://127.0.0.1:8081',
        }),
        isNull,
      );
      expect(embeddedMihonBaseUrlFromResponse({'port': 0}), isNull);
      expect(embeddedMihonBaseUrlFromResponse({'port': 70000}), isNull);
    });
  });

  test('keeps the iOS VM outside the app launch image and UI thread', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final mainScreenSource = File(
      'lib/modules/main_view/main_screen.dart',
    ).readAsStringSync();
    final nativeSource = File(
      'ios/Runner/MihonEmbeddedBridge.mm',
    ).readAsStringSync();
    final runtimeBuilder = File(
      'tool/build_lazy_openjdk_ios.sh',
    ).readAsStringSync();
    final xcodeProject = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(
      mainSource,
      contains(
        'if (!Platform.isIOS) {\n'
        '        MExtensionServerPlatform(ref, persistent: true).startServer();',
      ),
    );
    expect(
      nativeSource,
      contains('dlopen(runtimePath.UTF8String, RTLD_NOW | RTLD_GLOBAL)'),
    );
    expect(nativeSource, isNot(contains('RTLD_NOW | RTLD_LOCAL')));
    expect(nativeSource, contains('dlsym(RTLD_DEFAULT, symbol)'));
    for (final symbol in [
      'JDK_Canonicalize',
      'JIMAGE_Open',
      'JIMAGE_Close',
      'JIMAGE_FindResource',
      'JIMAGE_GetResource',
    ]) {
      expect(
        nativeSource,
        contains('"$symbol",'),
        reason: '$symbol must be visible to static OpenJDK lookups',
      );
    }
    expect(
      nativeSource,
      contains('dlsym(handle, "MangatanOpenJDKLoadFunctions")'),
    );
    expect(
      nativeSource,
      contains('self.stackSize = 8 * 1024 * 1024;'),
      reason:
          'the Zero interpreter needs more stack than an iOS dispatch worker',
    );
    expect(nativeSource, contains('[EmbeddedMihonThread() enqueueBlock:^{'));
    expect(
      nativeSource,
      isNot(contains('dispatch_async(EmbeddedMihonQueue()')),
    );
    expect(nativeSource, contains('"-XX:+AllowUserSignalHandlers",'));
    expect(nativeSource, contains('MANGATAN_JVM_SIGNAL sig='));
    expect(
      mainScreenSource,
      contains(
        'void _initializeProviders() {\n'
        '    // Mihon sources start the embedded OpenJDK runtime.',
      ),
    );
    expect(mainScreenSource, contains('if (Platform.isIOS) return;'));
    expect(
      nativeSource,
      contains('stringByAppendingPathComponent:@"lib/modules"'),
    );
    expect(
      nativeSource,
      contains('std::string("-Djava.home=") + runtimeHome.UTF8String'),
    );
    expect(
      runtimeBuilder,
      contains(r'cp "$runtime_modules" "$output_framework/lib/lib/modules"'),
    );
    expect(xcodeProject, isNot(contains('OpenJDK.xcframework in Frameworks')));
    expect(
      xcodeProject,
      contains('OpenJDKRuntime.framework in Embed Lazy OpenJDK Runtime'),
    );
  });
}
