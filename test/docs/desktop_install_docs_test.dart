import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression guard for issue #56 ("README download step missed").
///
/// Issue #56 reported that the install instructions omitted a required
/// download step. It was filed against the old "💻 For PC/Desktop (Node.js)"
/// section of the pre-rewrite userscript era, which no longer exists: Mangatan
/// is now a Flutter desktop app distributed as prebuilt release assets. The
/// current README download section, however, only said "get it from the
/// releases page" without naming the per-platform asset to download or how to
/// run it — the same "missed download step" class of gap, now for the desktop
/// app.
///
/// This test pins the resolved behaviour so the download instructions can never
/// silently drift away from the platforms the release workflow actually ships.
/// The source of truth is `.github/workflows/release.yml`: every desktop
/// platform it builds-and-uploads MUST have a documented download+run step in
/// `docs/desktop_install.md`, and the README must point at that guide.
void main() {
  final docFile = File('docs/desktop_install.md');
  final readmeFile = File('README.md');
  final releaseWorkflow = File('.github/workflows/release.yml');

  /// Desktop platforms Mangatan publishes prebuilt release assets for. Derived
  /// from the `build-and-release-*` jobs in the release workflow so the
  /// expectation stays anchored to what CI actually produces.
  Set<String> desktopPlatformsFromReleaseWorkflow() {
    final workflow = releaseWorkflow.readAsStringSync();
    final platforms = <String>{};
    if (workflow.contains('build-and-release-macos')) {
      platforms.add('macOS');
    }
    if (workflow.contains('build-and-release-windows')) {
      platforms.add('Windows');
    }
    if (workflow.contains('build-and-release-linux')) {
      platforms.add('Linux');
    }
    return platforms;
  }

  test('desktop install guide exists', () {
    expect(
      docFile.existsSync(),
      isTrue,
      reason:
          'docs/desktop_install.md must document the per-platform desktop '
          'download+run steps (issue #56).',
    );
  });

  test('release workflow builds at least one desktop platform', () {
    // Sanity: the source of truth must not be empty, or the drift guard below
    // would pass vacuously.
    expect(
      desktopPlatformsFromReleaseWorkflow(),
      isNotEmpty,
      reason:
          'Expected the release workflow to define desktop build jobs; the '
          'download-step drift guard relies on this as its source of truth.',
    );
  });

  test(
    'guide documents a download step for every shipped desktop platform',
    () {
      final contents = docFile.readAsStringSync();
      for (final platform in desktopPlatformsFromReleaseWorkflow()) {
        expect(
          contents.contains(platform),
          isTrue,
          reason:
              'docs/desktop_install.md must document the download+run step for '
              '$platform. The release workflow publishes a $platform asset, so '
              'omitting it recreates the "missed download step" gap from issue '
              '#56. Update the guide whenever a desktop platform is added or '
              'removed.',
        );
      }
    },
  );

  test('guide names the concrete release asset for each desktop platform', () {
    final contents = docFile.readAsStringSync();
    // The exact asset shapes the release workflow uploads. Documenting these
    // is the "missed step" the issue was about: users must know which file to
    // grab, not just that a releases page exists.
    const expectedAssetHints = <String>['.dmg', '.exe', '.zip', '.tar.gz'];
    for (final hint in expectedAssetHints) {
      expect(
        contents.contains(hint),
        isTrue,
        reason:
            'docs/desktop_install.md must name the "$hint" release asset so the '
            'download step is unambiguous (issue #56).',
      );
    }
  });

  test('README links to the desktop install guide', () {
    final readme = readmeFile.readAsStringSync();
    expect(
      readme.contains('docs/desktop_install.md'),
      isTrue,
      reason:
          'README.md must link to docs/desktop_install.md from its Download '
          'section so users find the per-platform steps (issue #56).',
    );
  });
}
