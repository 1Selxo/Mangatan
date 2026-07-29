import 'package:isar_community/isar.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/video.dart' as mangatan;
import 'package:mangayomi/services/youtube/youtube_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as youtube;

export 'youtube_preferences.dart';

const youtubeSourceName = 'youtube';

enum YouTubeBrowseItemType { video, channel, playlist }

class YouTubeBrowseItem {
  const YouTubeBrowseItem({
    required this.id,
    required this.type,
    required this.title,
    required this.url,
    this.subtitle = '',
    this.description = '',
    this.thumbnailUrl = '',
    this.channelId,
    this.duration,
  });

  final String id;
  final YouTubeBrowseItemType type;
  final String title;
  final String url;
  final String subtitle;
  final String description;
  final String thumbnailUrl;
  final String? channelId;
  final Duration? duration;

  bool get isVideo => type == YouTubeBrowseItemType.video;
}

class YouTubeService {
  YouTubeService({youtube.YoutubeExplode? client})
    : _client = client ?? youtube.YoutubeExplode();

  final youtube.YoutubeExplode _client;

  void close() => _client.close();

  Future<List<YouTubeBrowseItem>> search(String input) async {
    final query = input.trim();
    if (query.isEmpty) return const [];

    final videoId = youtube.VideoId.parseVideoId(query);
    if (videoId != null) {
      return [_fromVideo(await _client.videos.get(videoId))];
    }

    if (_looksLikePlaylistUrl(query)) {
      final playlistId = youtube.PlaylistId.parsePlaylistId(query);
      if (playlistId != null) {
        final playlist = await _client.playlists.get(playlistId);
        return [
          YouTubeBrowseItem(
            id: playlist.id.value,
            type: YouTubeBrowseItemType.playlist,
            title: playlist.title,
            subtitle: '${playlist.videoCount ?? 0} videos',
            description: playlist.description,
            thumbnailUrl: playlist.thumbnails.highResUrl,
            url: playlist.url,
          ),
        ];
      }
    }

    final channel = await _channelFromUrl(query);
    if (channel != null) {
      return [
        YouTubeBrowseItem(
          id: channel.id.value,
          type: YouTubeBrowseItemType.channel,
          title: channel.title,
          subtitle: channel.subscribersCount == null
              ? 'YouTube channel'
              : '${channel.subscribersCount} subscribers',
          thumbnailUrl: channel.logoUrl,
          url: channel.url,
        ),
      ];
    }

    final results = await _client.search.searchContent(query);
    return results.map(_fromSearchResult).toList();
  }

  Future<List<YouTubeBrowseItem>> loadCollection(
    YouTubeBrowseItem collection, {
    int limit = 100,
  }) async {
    final stream = switch (collection.type) {
      YouTubeBrowseItemType.channel => _client.channels.getUploads(
        collection.id,
      ),
      YouTubeBrowseItemType.playlist => _client.playlists.getVideos(
        collection.id,
      ),
      YouTubeBrowseItemType.video => const Stream<youtube.Video>.empty(),
    };
    return (await stream.take(limit).toList()).map(_fromVideo).toList();
  }

  Future<int> prepareVideoForPlayback(YouTubeBrowseItem item) async {
    final video = await _client.videos.get(item.id);
    return _prepareVideoForPlayback(video);
  }

  Future<int> prepareVideoUrlForPlayback(String url) async {
    final videoId = youtube.VideoId.parseVideoId(url);
    if (videoId == null) {
      throw ArgumentError.value(url, 'url', 'Not a YouTube video URL');
    }
    final video = await _client.videos.get(videoId);
    return _prepareVideoForPlayback(video);
  }

  Future<int> _prepareVideoForPlayback(youtube.Video video) async {
    final channelUrl = 'https://www.youtube.com/channel/${video.channelId}';
    var manga = isar.mangas
        .filter()
        .sourceEqualTo(youtubeSourceName)
        .and()
        .linkEqualTo(channelUrl)
        .findFirstSync();

    if (manga == null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final shouldFavorite = await YouTubePreferences.autoAddChannels();
      manga = Manga(
        source: youtubeSourceName,
        author: video.author,
        artist: video.author,
        genre: const ['YouTube'],
        imageUrl: video.thumbnails.highResUrl,
        lang: 'all',
        link: channelUrl,
        name: video.author,
        status: Status.ongoing,
        description: 'YouTube channel',
        sourceId: null,
        isManga: false,
        itemType: ItemType.anime,
        favorite: shouldFavorite,
        dateAdded: now,
        lastUpdate: now,
      );
      final createdManga = manga;
      isar.writeTxnSync(() => isar.mangas.putSync(createdManga));
    }

    var chapter = isar.chapters
        .filter()
        .mangaIdEqualTo(manga.id)
        .and()
        .urlEqualTo(video.url)
        .findFirstSync();
    if (chapter == null) {
      chapter = Chapter(
        mangaId: manga.id,
        name: video.title,
        url: video.url,
        dateUpload: video.uploadDate?.toIso8601String() ?? '',
        thumbnailUrl: video.thumbnails.highResUrl,
        description: video.description,
        duration: _formatDuration(video.duration),
      )..manga.value = manga;
      final createdChapter = chapter;
      isar.writeTxnSync(() {
        isar.chapters.putSync(createdChapter);
        createdChapter.manga.saveSync();
      });
    }
    return chapter.id!;
  }

  static Future<List<mangatan.Video>> resolveVideoStreams(String url) async {
    final client = youtube.YoutubeExplode();
    try {
      final id = youtube.VideoId.parseVideoId(url);
      if (id == null) {
        throw ArgumentError.value(url, 'url', 'Not a YouTube video URL');
      }
      final preferredQuality = await YouTubePreferences.preferredQuality();
      final preferredHeight =
          int.tryParse(preferredQuality.replaceAll('p', '')) ?? 1080;
      final manifest = await client.videos.streams.getManifest(id);

      final audioStreams = manifest.audioOnly.toList()
        ..sort((a, b) {
          final defaultOrder =
              (b.audioTrack?.audioIsDefault == true ? 1 : 0) -
              (a.audioTrack?.audioIsDefault == true ? 1 : 0);
          return defaultOrder != 0
              ? defaultOrder
              : b.bitrate.compareTo(a.bitrate);
        });
      final seenAudioLanguages = <String>{};
      final audioTracks = <mangatan.Track>[];
      for (final stream in audioStreams) {
        final key =
            stream.audioTrack?.id ??
            stream.audioTrack?.displayName ??
            'original';
        if (!seenAudioLanguages.add(key)) continue;
        audioTracks.add(
          mangatan.Track(
            file: stream.url.toString(),
            label: stream.audioTrack?.displayName ?? 'Original audio',
          ),
        );
      }

      final subtitleTracks = <mangatan.Track>[];
      try {
        final captions = await client.videos.closedCaptions.getManifest(
          id,
          formats: const [youtube.ClosedCaptionFormat.vtt],
        );
        for (final caption in captions.tracks) {
          final automatic = caption.isAutoGenerated ? ' (auto)' : '';
          subtitleTracks.add(
            mangatan.Track(
              file: caption.url.toString(),
              label: '${caption.language.name}$automatic',
            ),
          );
        }
      } catch (_) {
        // Captions are optional; stream playback should still work without them.
      }

      final videoOnly = manifest.videoOnly.toList()
        ..sort((a, b) {
          final aDistance = (a.videoResolution.height - preferredHeight).abs();
          final bDistance = (b.videoResolution.height - preferredHeight).abs();
          final distanceOrder = aDistance.compareTo(bDistance);
          return distanceOrder != 0
              ? distanceOrder
              : b.bitrate.compareTo(a.bitrate);
        });
      final resolved = <mangatan.Video>[
        for (final stream in videoOnly)
          mangatan.Video(
            stream.url.toString(),
            _qualityLabel(stream),
            url,
            subtitles: subtitleTracks,
            audios: audioTracks,
          ),
      ];

      final muxed = manifest.muxed.toList()
        ..sort((a, b) => b.bitrate.compareTo(a.bitrate));
      for (final stream in muxed) {
        resolved.add(
          mangatan.Video(
            stream.url.toString(),
            'YouTube - ${stream.qualityLabel} (compatible)',
            url,
            subtitles: subtitleTracks,
          ),
        );
      }

      final hlsMuxed = manifest.hls.whereType<youtube.HlsMuxedStreamInfo>();
      for (final stream in hlsMuxed) {
        resolved.add(
          mangatan.Video(
            stream.url.toString(),
            'YouTube live - ${stream.qualityLabel}',
            url,
            subtitles: subtitleTracks,
          ),
        );
      }

      if (resolved.isEmpty) {
        throw StateError('YouTube returned no playable streams for $url');
      }
      return resolved;
    } finally {
      client.close();
    }
  }

  static bool _looksLikePlaylistUrl(String input) {
    final uri = Uri.tryParse(input);
    return uri != null &&
        (uri.host.contains('youtube.com') || uri.host == 'youtu.be') &&
        uri.queryParameters['list']?.isNotEmpty == true;
  }

  Future<youtube.Channel?> _channelFromUrl(String input) async {
    final uri = Uri.tryParse(input);
    if (uri == null ||
        !(uri.host.contains('youtube.com') || uri.host == 'youtu.be')) {
      return null;
    }
    final channelId = youtube.ChannelId.parseChannelId(input);
    if (channelId != null) return _client.channels.get(channelId);
    final handle = youtube.ChannelHandle.parseChannelHandle(input);
    if (handle != null) return _client.channels.getByHandle(handle);
    final segments = uri.pathSegments;
    final userIndex = segments.indexOf('user');
    if (userIndex >= 0 && userIndex + 1 < segments.length) {
      return _client.channels.getByUsername(segments[userIndex + 1]);
    }
    return null;
  }

  static YouTubeBrowseItem _fromSearchResult(youtube.SearchResult result) {
    return switch (result) {
      youtube.SearchVideo video => YouTubeBrowseItem(
        id: video.id.value,
        type: YouTubeBrowseItemType.video,
        title: video.title,
        subtitle: '${video.author} • ${video.duration}',
        description: video.description,
        thumbnailUrl: video.thumbnails.isEmpty
            ? ''
            : video.thumbnails.last.url.toString(),
        channelId: video.channelId,
        url: 'https://www.youtube.com/watch?v=${video.id}',
      ),
      youtube.SearchChannel channel => YouTubeBrowseItem(
        id: channel.id.value,
        type: YouTubeBrowseItemType.channel,
        title: channel.name,
        subtitle: '${channel.videoCount} videos',
        description: channel.description,
        thumbnailUrl: channel.thumbnails.isEmpty
            ? ''
            : channel.thumbnails.last.url.toString(),
        url: 'https://www.youtube.com/channel/${channel.id}',
      ),
      youtube.SearchPlaylist playlist => YouTubeBrowseItem(
        id: playlist.id.value,
        type: YouTubeBrowseItemType.playlist,
        title: playlist.title,
        subtitle: '${playlist.videoCount} videos',
        thumbnailUrl: playlist.thumbnails.isEmpty
            ? ''
            : playlist.thumbnails.last.url.toString(),
        url: 'https://www.youtube.com/playlist?list=${playlist.id}',
      ),
      _ => throw UnsupportedError(
        'Unsupported YouTube search result: ${result.runtimeType}',
      ),
    };
  }

  static YouTubeBrowseItem _fromVideo(youtube.Video video) {
    return YouTubeBrowseItem(
      id: video.id.value,
      type: YouTubeBrowseItemType.video,
      title: video.title,
      subtitle:
          '${video.author}${video.duration == null ? '' : ' • ${_formatDuration(video.duration)}'}',
      description: video.description,
      thumbnailUrl: video.thumbnails.highResUrl,
      channelId: video.channelId.value,
      duration: video.duration,
      url: video.url,
    );
  }

  static String _qualityLabel(youtube.VideoOnlyStreamInfo stream) {
    final fps = stream.framerate.framesPerSecond;
    return 'YouTube - ${stream.qualityLabel}${fps > 30 ? ' ${fps}fps' : ''}';
  }

  static String _formatDuration(Duration? duration) {
    if (duration == null) return '';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final tail =
        '${minutes.toString().padLeft(hours > 0 ? 2 : 1, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
    return hours > 0 ? '$hours:$tail' : tail;
  }
}
