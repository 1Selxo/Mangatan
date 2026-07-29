import 'dart:io';

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

  test('wraps YouTube library writes in explicit Isar transactions', () {
    final source = File(
      'lib/services/youtube/youtube_service.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('isar.writeTxnSync(() => isar.mangas.putSync(createdManga))'),
    );
    expect(source, contains('isar.writeTxnSync(() {'));
    expect(source, contains('isar.chapters.putSync(createdChapter)'));
    expect(source, contains('createdChapter.manga.saveSync()'));
  });

  test('uses safe defaults before deferred Hive startup completes', () async {
    expect(await YouTubePreferences.preferredQuality(), '1080p');
    expect(await YouTubePreferences.autoAddChannels(), isFalse);
    expect(await YouTubePreferences.searchHistory(), isEmpty);
  });

  test('recognizes every YouTube page shape intercepted by Chimahon', () {
    const id = 'dQw4w9WgXcQ';
    expect(directYouTubeVideoId('https://www.youtube.com/watch?v=$id&t=4'), id);
    expect(directYouTubeVideoId('https://m.youtube.com/shorts/$id'), id);
    expect(directYouTubeVideoId('https://youtube.com/live/$id'), id);
    expect(directYouTubeVideoId('https://youtube-nocookie.com/embed/$id'), id);
    expect(directYouTubeVideoId('https://youtu.be/$id'), id);
    expect(directYouTubeVideoId('https://youtube.com/@channel'), isNull);
    expect(directYouTubeVideoId('https://notyoutube.com/watch?v=$id'), isNull);
  });

  test('browser script intercepts clicks and YouTube SPA history changes', () {
    expect(youtubeInterceptScript, contains("addEventListener('click'"));
    expect(youtubeInterceptScript, contains('history.pushState'));
    expect(youtubeInterceptScript, contains('history.replaceState'));
    expect(youtubeInterceptScript, contains("addEventListener('popstate'"));
    expect(youtubeInterceptScript, contains('openYouTubeVideo'));
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
