import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// The upstream revisions Mangatan vendors, asserted in one place so the notice
/// files, the provenance docs and the jitpack coordinate cannot drift apart.
const _serverCommit = '68645ae7a8b2ffd0954e9c6cba62427f54f95503';
const _newPipeCommit = 'caae86c943857cc6e1a762e3488d6a14e9cf7800';
const _newPipeVersion = 'v0.26.3';

String _read(String relativePath) => File(relativePath).readAsStringSync();

void main() {
  group('vendored Mihon source', () {
    test('binds the headless bridge to loopback only', () {
      final serverMain = _read(
        'third_party/mihon_server/server/src/main/kotlin/'
        'mextensionserver/Main.kt',
      );
      // Mangatan's one deliberate divergence from upstream. The bridge has no
      // authentication, so the headless path it launches must never listen on
      // a routable address, and must not fall back to a fixed port.
      expect(
        serverMain,
        contains('MExtensionServerController(bindHost = "127.0.0.1")'),
      );
      expect(
        serverMain,
        isNot(contains('0.0.0.0')),
        reason: 'the headless bridge must not bind a routable address',
      );
    });

    test('pins every statement of the vendored revisions to one value', () {
      // These four files each restate the revisions. A re-vendor that updates
      // some but not others would ship notices pointing at source that is not
      // what was built, so assert they agree rather than that each is non-empty.
      expect(
        _read('third_party/mihon_server/VENDORED.md'),
        allOf(contains('1Selxo/M-Extension-Server'), contains(_serverCommit)),
      );
      expect(
        _read('third_party/newpipe_extractor/VENDORED.md'),
        allOf(
          contains('TeamNewPipe/NewPipeExtractor'),
          contains(_newPipeCommit),
          contains(_newPipeVersion),
        ),
      );
      final iosNotices = _read('ios/EmbeddedMihon/THIRD_PARTY_NOTICES.md');
      expect(iosNotices, contains(_serverCommit));
      expect(iosNotices, contains(_newPipeCommit));
      expect(iosNotices, contains(_newPipeVersion));

      // The shipped JAR shades jitpack's build of this tag; the vendored tree
      // is that same tag's source. Bumping the coordinate without re-vendoring
      // would break the GPL correspondence, so couple them here.
      expect(
        _read('third_party/mihon_server/gradle/libs.versions.toml'),
        contains('newpipe-extractor = "$_newPipeVersion"'),
        reason:
            'the shaded NewPipe version must match the vendored source tree; '
            're-vendor third_party/newpipe_extractor when bumping it',
      );
    });

    test('ships the GPL corresponding source for the shaded classes', () {
      // A single marker file is not enough: the obligation is the *complete*
      // corresponding source of the module whose classes are shaded in.
      final extractorSources = Directory(
        'third_party/newpipe_extractor/extractor/src/main/java/org/schabi/'
        'newpipe/extractor',
      );
      expect(extractorSources.existsSync(), isTrue);
      final javaFiles = extractorSources
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.java'))
          .length;
      expect(
        javaFiles,
        greaterThan(250),
        reason: 'GPL corresponding production source must ship with Mangatan',
      );
      expect(
        File('third_party/newpipe_extractor/LICENSE').existsSync(),
        isTrue,
      );
      expect(File('third_party/mihon_server/LICENSE').existsSync(), isTrue);
    });

    test('accounts for every license in the shaded JAR, not just MPL/GPL', () {
      // The JAR is a fat JAR. logback in particular ships no license text of
      // its own, so the bundle must state its terms out of band.
      final notices = _read('third_party/mihon_server/BUNDLED_NOTICES.md');
      for (final component in [
        'logback',
        'NanoHTTPD',
        'jsoup',
        'OkHttp',
        'NewPipe Extractor',
        'M-Extension-Server',
      ]) {
        expect(notices, contains(component));
      }
      expect(notices, contains('EPL-1.0'));
      expect(notices, contains('LGPL-2.1'));

      // And the release bundles must actually carry it.
      for (final builder in [
        _read('scripts/build_vendored_mihon_server.sh'),
        _read('scripts/build_vendored_mihon_server.ps1'),
      ]) {
        expect(builder, contains('BUNDLED_NOTICES.md'));
        expect(builder, contains('THIRD_PARTY_NOTICES.md'));
      }
      expect(
        _read('tool/prepare_embedded_mihon_ios.sh'),
        contains('THIRD_PARTY_NOTICES.md'),
      );
    });

    test('both build scripts stage an identically-specified runtime', () {
      final unixBuilder = _read('scripts/build_vendored_mihon_server.sh');
      final windowsBuilder = _read('scripts/build_vendored_mihon_server.ps1');

      // A divergence here means desktop platforms ship different runtimes, which
      // is exactly the class of bug a source-text `contains` cannot catch.
      final unixModules = RegExp(r"modules='([^']+)'")
          .firstMatch(unixBuilder)!
          .group(1)!
          .split(',')
          .map((module) => module.trim())
          .toList();
      final windowsModules = RegExp(r'\$modules = @\(([\s\S]*?)\) -join')
          .firstMatch(windowsBuilder)!
          .group(1)!
          .let((block) => RegExp(r"'([^']+)'").allMatches(block))
          .map((match) => match.group(1)!)
          .toList();
      expect(windowsModules, unixModules);

      for (final builder in [unixBuilder, windowsBuilder]) {
        expect(builder, contains(':server:shadowJar'));
        expect(builder, contains('jlink'));
        expect(builder, contains('--compress=zip-6'));
        // The version lives in the basename; flattening it makes the app report
        // the 1.0.0 fallback and offer a perpetual bogus update.
        expect(
          builder,
          isNot(contains("'MExtensionServer.jar'")),
          reason: 'keep Gradle\'s versioned archive name',
        );
      }
      expect(unixBuilder, contains('third_party/mihon_server'));
      expect(windowsBuilder, contains('third_party\\mihon_server'));
    });

    test('the iOS path builds from the vendored tree, not a download', () {
      final iosPreparation = _read('tool/prepare_embedded_mihon_ios.sh');
      expect(
        iosPreparation,
        contains('scripts/build_vendored_mihon_server.sh'),
      );
      expect(iosPreparation, contains('--ios'));
      // The pinned-URL download this PR replaced must not creep back.
      expect(iosPreparation, isNot(contains('server_jar_url=')));
      expect(iosPreparation, isNot(contains('server_jar_sha256=')));
    });

    test('every desktop release job stages the bundle', () {
      // Assert per-job rather than once over the whole file: a single `contains`
      // stays green when two of the three jobs lose their staging step.
      final release =
          loadYaml(_read('.github/workflows/release.yml')) as YamlMap;
      final jobs = release['jobs'] as YamlMap;
      final desktopJobs = jobs.keys
          .cast<String>()
          .where(
            (job) =>
                job.contains('macos') ||
                job.contains('windows') ||
                job.contains('linux'),
          )
          .toList();
      expect(desktopJobs, hasLength(3));

      for (final job in desktopJobs) {
        final steps = (jobs[job] as YamlMap)['steps'] as YamlList;
        final stepNames = steps
            .cast<YamlMap>()
            .map((step) => step['name']?.toString() ?? '')
            .toList();
        expect(
          stepNames,
          contains('Build bundled Mihon server'),
          reason: '$job must stage the JAR and portable JRE',
        );
        expect(
          stepNames,
          contains('Set up Java 21'),
          reason: '$job needs a JDK to build the server',
        );
      }
    });
  });
}

extension _Let<T> on T {
  R let<R>(R Function(T) transform) => transform(this);
}
