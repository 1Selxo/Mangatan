import 'package:mangayomi/models/video.dart' as vid;
import 'package:media_kit/media_kit.dart';

/// Builds a player track from the playable media URL, not the source URL.
VideoTrack videoTrackFromVideo(vid.Video video) =>
    VideoTrack(video.url, video.quality, video.quality);
