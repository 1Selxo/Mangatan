package mextensionserver.model

data class YouTubeResolveResponse(
    val videoId: String,
    val title: String,
    val url: String,
    val durationSeconds: Long,
    val uploadDateMillis: Long?,
    val thumbnailUrl: String,
    val description: String,
    val channelId: String,
    val channelName: String,
    val channelUrl: String,
    val streams: List<YouTubeStream>,
)

data class YouTubeStream(
    val url: String,
    val quality: String,
    val height: Int?,
    val videoOnly: Boolean,
    val subtitles: List<YouTubeTrack>,
    val audios: List<YouTubeTrack>,
)

data class YouTubeTrack(
    val url: String,
    val label: String,
)
