// Regression coverage for the community-driven extension-repo entry point.
//
// Historical issue #37 ("Community-driven wiki/repo for non-suwayomi sites?")
// asked for a way to share and pull site/source configurations from a
// community-maintained place instead of hand-editing a userscript's
// "Site Configurations" field. In the current Mangayomi-based rewrite that
// request is served by the extension-repository system: anyone can host a repo
// of sources and distribute it through a `mangayomi://add-repo` deep link whose
// `manga_url` / `anime_url` / `novel_url` query parameters carry the repo JSON
// URLs the app then subscribes to.
//
// The cold-start deep-link parser (initialDesktopAppLinkFromArguments) already
// has coverage for the host, but nothing pins the repo-URL payload that the
// community-driven feature actually depends on. These tests lock that in so a
// future change to argument parsing or query handling cannot silently drop the
// community repo URLs.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/main.dart';

void main() {
  group('community-driven add-repo deep link', () {
    test('preserves the community repo URLs for each content type', () {
      final uri = initialDesktopAppLinkFromArguments(const [
        'mangayomi://add-repo?repo_name=Community'
            '&manga_url=https://example.test/manga.json'
            '&anime_url=https://example.test/anime.json'
            '&novel_url=https://example.test/novel.json',
      ], platform: TargetPlatform.linux);

      expect(uri, isNotNull);
      final repoUrls = communityRepoUrlsFromAppLink(uri!);

      expect(repoUrls.mangaUrls, ['https://example.test/manga.json']);
      expect(repoUrls.animeUrls, ['https://example.test/anime.json']);
      expect(repoUrls.novelUrls, ['https://example.test/novel.json']);
    });

    test('collects every repeated repo URL of the same content type', () {
      final uri = Uri.parse(
        'mangayomi://add-repo'
        '?manga_url=https://a.test/one.json'
        '&manga_url=https://b.test/two.json',
      );

      final repoUrls = communityRepoUrlsFromAppLink(uri);

      expect(repoUrls.mangaUrls, [
        'https://a.test/one.json',
        'https://b.test/two.json',
      ]);
      expect(repoUrls.animeUrls, isEmpty);
      expect(repoUrls.novelUrls, isEmpty);
      expect(repoUrls.isEmpty, isFalse);
    });

    test('reports empty when no repo URLs are supplied', () {
      final repoUrls = communityRepoUrlsFromAppLink(
        Uri.parse('mangayomi://add-repo?repo_name=NoUrls'),
      );

      expect(repoUrls.mangaUrls, isEmpty);
      expect(repoUrls.animeUrls, isEmpty);
      expect(repoUrls.novelUrls, isEmpty);
      expect(repoUrls.isEmpty, isTrue);
    });

    test('ignores repo URLs on unrelated deep-link hosts', () {
      final repoUrls = communityRepoUrlsFromAppLink(
        Uri.parse('mangayomi://add-button?manga_url=https://x.test/repo.json'),
      );

      expect(repoUrls.isEmpty, isTrue);
    });
  });
}
