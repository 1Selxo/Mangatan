import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mangayomi/modules/anime/youtube/youtube_browser_screen.dart';
import 'package:mangayomi/services/youtube/youtube_service.dart';

void main() {
  test('uses Chimahon-compatible YouTube quality choices', () {
    expect(youtubePreferredQualities, const [
      '2160p',
      '1440p',
      '1080p',
      '720p',
      '480p',
      '360p',
    ]);
  });

  test('distinguishes playable videos from browsable collections', () {
    const video = YouTubeBrowseItem(
      id: 'video',
      type: YouTubeBrowseItemType.video,
      title: 'Video',
      url: 'https://www.youtube.com/watch?v=video',
    );
    const channel = YouTubeBrowseItem(
      id: 'channel',
      type: YouTubeBrowseItemType.channel,
      title: 'Channel',
      url: 'https://www.youtube.com/channel/channel',
    );

    expect(video.isVideo, isTrue);
    expect(channel.isVideo, isFalse);
  });

  test('uses safe defaults before deferred Hive startup completes', () async {
    expect(await YouTubePreferences.preferredQuality(), '1080p');
    expect(await YouTubePreferences.autoAddChannels(), isFalse);
    expect(await YouTubePreferences.searchHistory(), isEmpty);
  });

  testWidgets('browser opens before deferred Hive startup completes', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: YouTubeBrowserScreen()));
    await tester.pumpAndSettle();

    expect(find.text('YouTube'), findsOneWidget);
    expect(find.text('Search videos, channels and playlists'), findsOneWidget);
  });

  test('persists YouTube preferences after Hive startup', () async {
    final directory = await Directory.systemTemp.createTemp(
      'mangatan-youtube-preferences-',
    );
    Hive.init(directory.path);
    YouTubePreferences.markStorageReady();
    try {
      await YouTubePreferences.setPreferredQuality('720p');
      await YouTubePreferences.setAutoAddChannels(true);
      await YouTubePreferences.rememberSearch('Japanese listening');

      expect(await YouTubePreferences.preferredQuality(), '720p');
      expect(await YouTubePreferences.autoAddChannels(), isTrue);
      expect(await YouTubePreferences.searchHistory(), ['Japanese listening']);
    } finally {
      await Hive.close();
      await directory.delete(recursive: true);
    }
  });
}
