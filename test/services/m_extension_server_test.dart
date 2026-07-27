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
    final serviceSource = File(
      'lib/services/m_extension_server.dart',
    ).readAsStringSync();
    final mainScreenSource = File(
      'lib/modules/main_view/main_screen.dart',
    ).readAsStringSync();
    final nativeSource = File(
      'ios/Runner/MihonEmbeddedBridge.mm',
    ).readAsStringSync();
    final runtimeBuilder = File(
      'tool/build_lazy_openjdk_ios.sh',
    ).readAsStringSync();
    final zeroRuntimePatch = File(
      'tool/openjdk/ios-zero-runtime.patch',
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
    expect(
      nativeSource,
      contains('"-Xss8m",'),
      reason:
          'NanoHTTPD request workers need the same full Zero interpreter stack',
    );
    for (final option in [
      '-XX:+UseSerialGC',
      '-Xms128m',
      '-Xmx512m',
      '-XX:NewSize=64m',
      '-XX:MaxNewSize=256m',
    ]) {
      expect(
        nativeSource,
        contains('"$option",'),
        reason: 'the embedded VM needs deterministic balanced generations',
      );
    }
    expect(
      nativeSource,
      isNot(contains('"-Xmn')),
      reason: 'the young generation must remain elastic after bootstrap',
    );
    expect(nativeSource, contains('[EmbeddedMihonThread() enqueueBlock:^{'));
    expect(
      nativeSource,
      isNot(contains('dispatch_async(EmbeddedMihonQueue()')),
    );
    expect(nativeSource, isNot(contains('AllowUserSignalHandlers')));
    expect(nativeSource, isNot(contains('JavaVMDiagnosticSignalHandler')));
    expect(
      serviceSource,
      contains(
        'if (_isLoopbackServer(_baseUrl)) {\n'
        '        // A saved desktop loopback URL points back at the iPhone',
      ),
      reason: 'iOS must not reuse a stale desktop loopback bridge',
    );
    expect(
      serviceSource,
      contains('if ((isDesktop || Platform.isIOS) &&'),
      reason: 'an unavailable embedded iOS bridge must fail before HTTP',
    );
    expect(
      nativeSource,
      contains('TraceEmbeddedMihon(@"calling JNI_CreateJavaVM");'),
      reason: 'device builds must expose the embedded VM startup boundary',
    );
    expect(
      nativeSource,
      contains('@"EmbeddedBridge.start returned %d (exception=%@)"'),
      reason: 'device builds must distinguish server errors from VM errors',
    );
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
    expect(
      zeroRuntimePatch,
      contains(
        'if (!is_init_completed() &&\n'
        '+            holder == vmClasses::Class_klass() &&\n'
        '+            callee->name()->equals("desiredAssertionStatus")',
      ),
      reason:
          'the bootstrap bypass must be limited to the primordial assertion query',
    );
    expect(
      zeroRuntimePatch,
      contains('enabled = JavaAssertions::enabled('),
      reason: 'the primordial query must use HotSpot assertion semantics',
    );
    expect(
      zeroRuntimePatch,
      contains('asserted_klass->class_loader() == nullptr'),
      reason: 'dynamic non-bootstrap assertion settings must not be bypassed',
    );
    expect(
      zeroRuntimePatch,
      contains('holder->link_class(THREAD);'),
      reason: 'extension and post-bootstrap classes must retain full linkage',
    );
    expect(
      zeroRuntimePatch,
      isNot(contains('vmClasses::Class_klass()->link_class(CHECK);')),
      reason:
          'java.lang.Class must remain on its normal bootstrap linkage lifecycle',
    );
    expect(
      zeroRuntimePatch,
      isNot(contains('holder->rewrite_class(THREAD);')),
      reason: 'the fallback must not partially rewrite java.lang.Class',
    );
    expect(
      zeroRuntimePatch,
      contains('Mangatan Rewriter: class=java.lang.Class'),
      reason: 'the Class constant-pool sizing fallback must remain observable',
    );
    expect(
      zeroRuntimePatch,
      contains('Mangatan Serial bootstrap allocation exhausted:'),
      reason: 'pre-initialization allocation failures need generation evidence',
    );
    expect(
      zeroRuntimePatch,
      contains('Mangatan Serial bootstrap Java stack:'),
      reason: 'pre-initialization exhaustion must identify its Java caller',
    );
    expect(
      zeroRuntimePatch,
      contains('Mangatan Serial raw Zero frame chain:'),
      reason: 'Zero bootstrap failures need the complete interpreter chain',
    );
    expect(
      zeroRuntimePatch,
      contains('return RTLD_DEFAULT;'),
      reason:
          'the iOS Zero runtime must resolve JNI symbols from its global framework',
    );
    expect(
      zeroRuntimePatch,
      contains('scope=RTLD_DEFAULT found=%s'),
      reason: 'bootstrap native lookup must remain observable on physical iOS',
    );
    expect(xcodeProject, isNot(contains('OpenJDK.xcframework in Frameworks')));
    expect(
      xcodeProject,
      contains('OpenJDKRuntime.framework in Embed Lazy OpenJDK Runtime'),
    );
  });
}
