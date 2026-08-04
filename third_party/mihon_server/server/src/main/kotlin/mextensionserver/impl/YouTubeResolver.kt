package mextensionserver.impl

import io.github.oshai.kotlinlogging.KotlinLogging
import mextensionserver.model.YouTubeResolveResponse
import mextensionserver.model.YouTubeStream
import mextensionserver.model.YouTubeTrack
import okhttp3.OkHttpClient
import okhttp3.RequestBody.Companion.toRequestBody
import org.schabi.newpipe.extractor.MediaFormat
import org.schabi.newpipe.extractor.NewPipe
import org.schabi.newpipe.extractor.ServiceList
import org.schabi.newpipe.extractor.downloader.Downloader
import org.schabi.newpipe.extractor.downloader.Request
import org.schabi.newpipe.extractor.downloader.Response
import org.schabi.newpipe.extractor.stream.AudioStream
import org.schabi.newpipe.extractor.stream.VideoStream

fun interface YouTubeVideoResolver {
    fun resolve(url: String): YouTubeResolveResponse
}

object NewPipeYouTubeResolver : YouTubeVideoResolver {
    private val logger = KotlinLogging.logger {}
    private val resolveLock = Any()
    private val client = OkHttpClient()

    @Volatile
    private var initialized = false

    override fun resolve(url: String): YouTubeResolveResponse =
        synchronized(resolveLock) {
            ensureInitialized()
            val extractor = ServiceList.YouTube.getStreamExtractor(url)
            extractor.fetchPage()

            val subtitles =
                listOf(
                    runCatching { extractor.subtitlesDefault }.getOrDefault(emptyList()),
                    runCatching { extractor.getSubtitles(MediaFormat.VTT) }.getOrDefault(emptyList()),
                    runCatching { extractor.getSubtitles(MediaFormat.SRT) }.getOrDefault(emptyList()),
                    runCatching { extractor.getSubtitles(MediaFormat.TTML) }.getOrDefault(emptyList()),
                ).flatten()
                    .filter { it.content.isNotBlank() }
                    .map { subtitle ->
                        YouTubeTrack(
                            url = subtitle.content,
                            label =
                                subtitle.displayLanguageName
                                    ?: subtitle.languageTag
                                    ?: subtitle.locale?.displayLanguage
                                    ?: "Subtitle",
                        )
                    }.distinctBy { it.url to it.label }

            val audios =
                extractor.audioStreams
                    .filter { it.content.isNotBlank() }
                    .sortedWith(
                        compareByDescending<AudioStream> {
                            it.audioTrackName?.contains("original", ignoreCase = true) == true ||
                                it.audioLocale?.displayName?.contains("original", ignoreCase = true) == true ||
                                it.quality?.contains("original", ignoreCase = true) == true
                        }.thenByDescending { it.averageBitrate },
                    ).map { audio ->
                        YouTubeTrack(
                            url = audio.content,
                            label =
                                audio.audioTrackName
                                    ?: audio.audioLocale?.displayLanguage
                                    ?: audio.quality
                                    ?: "Audio",
                        )
                    }.distinctBy { it.url to it.label }
            val playableAudios =
                audios.ifEmpty {
                    extractor.videoStreams
                        .firstOrNull { it.content.isNotBlank() && !it.isVideoOnly }
                        ?.let {
                            listOf(
                                YouTubeTrack(
                                    url = it.content,
                                    label = "Original audio (muxed fallback)",
                                ),
                            )
                        }.orEmpty()
                }

            logger.info {
                "NewPipe ${extractor.id}: " +
                    "muxed=${extractor.videoStreams.size} " +
                    "(url=${extractor.videoStreams.count { it.content.isNotBlank() }}), " +
                    "videoOnly=${extractor.videoOnlyStreams.size} " +
                    "(url=${extractor.videoOnlyStreams.count { it.content.isNotBlank() }}), " +
                    "audio=${extractor.audioStreams.size} " +
                    "(url=${extractor.audioStreams.count { it.content.isNotBlank() }})"
            }

            val streams =
                (extractor.videoStreams + extractor.videoOnlyStreams)
                    .filter { it.content.isNotBlank() }
                    .filter { !it.isVideoOnly || playableAudios.isNotEmpty() }
                    .sortedWith(
                        compareByDescending<VideoStream> {
                            parseResolution(it.resolution.ifBlank { it.quality.orEmpty() })
                        }.thenBy { it.isVideoOnly },
                    ).distinctBy { it.content }
                    .map { stream ->
                        val resolution = stream.resolution.ifBlank { stream.quality ?: "Video" }
                        val videoOnly = stream.isVideoOnly
                        YouTubeStream(
                            url = stream.content,
                            quality = resolution,
                            height = parseResolution(resolution).takeIf { it > 0 },
                            videoOnly = videoOnly,
                            subtitles = subtitles,
                            audios = if (videoOnly) playableAudios else emptyList(),
                        )
                    }

            check(streams.isNotEmpty()) { "NewPipe returned no playable streams for $url" }

            val channelId = extractor.uploaderUrl.substringAfterLast("/")
            YouTubeResolveResponse(
                videoId = extractor.id,
                title = extractor.name,
                url = extractor.url,
                durationSeconds = extractor.length,
                uploadDateMillis =
                    extractor.uploadDate
                        ?.offsetDateTime()
                        ?.toInstant()
                        ?.toEpochMilli(),
                thumbnailUrl =
                    extractor.thumbnails
                        .maxByOrNull { it.width }
                        ?.url
                        .orEmpty(),
                description = extractor.description.content,
                channelId = channelId,
                channelName = extractor.uploaderName,
                channelUrl = extractor.uploaderUrl,
                streams = streams,
            )
        }

    private fun ensureInitialized() {
        if (initialized) return
        synchronized(this) {
            if (initialized) return
            NewPipe.init(
                object : Downloader() {
                    override fun execute(request: Request): Response {
                        val call =
                            okhttp3.Request
                                .Builder()
                                .url(request.url())
                                .method(
                                    request.httpMethod(),
                                    request.dataToSend()?.toRequestBody(null),
                                ).apply {
                                    request.headers().forEach { (name, values) ->
                                        values.forEach { value -> addHeader(name, value) }
                                    }
                                }.build()
                        client.newCall(call).execute().use { response ->
                            return Response(
                                response.code,
                                response.message,
                                response.headers.toMultimap(),
                                response.body.string(),
                                response.request.url.toString(),
                            )
                        }
                    }
                },
            )
            initialized = true
        }
    }

    private fun parseResolution(value: String): Int =
        Regex("""(\d{3,4})\s*[pP]""")
            .find(value)
            ?.groupValues
            ?.get(1)
            ?.toIntOrNull() ?: 0
}
