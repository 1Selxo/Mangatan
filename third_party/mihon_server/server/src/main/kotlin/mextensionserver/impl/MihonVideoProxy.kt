package mextensionserver.impl

import eu.kanade.tachiyomi.animesource.model.Track
import eu.kanade.tachiyomi.animesource.model.Video
import eu.kanade.tachiyomi.animesource.online.AnimeHttpSource
import okhttp3.Headers
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import java.nio.charset.StandardCharsets
import java.util.UUID
import java.util.concurrent.TimeUnit

/**
 * Keeps extension video requests inside the bridge.
 *
 * Some anime extensions return a localhost HLS proxy or require their OkHttp
 * interceptors and request headers for every playlist and segment. Neither is
 * directly reachable from an iOS client, so media URLs are registered here and
 * recursively rewritten through the bridge.
 */
internal object MihonVideoProxy {
    private const val MAX_ENTRIES = 32768
    private val uriAttribute = Regex("""URI=(["'])(.*?)\1""")
    private val mediaExtension = Regex("""\.([A-Za-z0-9]{1,8})$""")

    data class VideoData(
        val statusCode: Int,
        val contentType: String,
        val bytes: ByteArray,
        val responseHeaders: Map<String, String>,
    )

    private data class Entry(
        val key: String,
        val client: OkHttpClient,
        val url: HttpUrl,
        val headers: Headers,
    )

    private val loopbackClient =
        OkHttpClient
            .Builder()
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(2, TimeUnit.MINUTES)
            .callTimeout(2, TimeUnit.MINUTES)
            .build()

    private val lock = Any()
    private val entriesByToken = LinkedHashMap<String, Entry>(16, 0.75f, true)
    private val tokensByKey = mutableMapOf<String, String>()

    @Volatile
    private var port: Int = 0

    fun configure(port: Int) {
        require(port > 0) { "Video proxy port must be positive" }
        this.port = port
    }

    fun proxy(
        source: AnimeHttpSource,
        video: Video,
    ): Video {
        val client = source.client
        val headers =
            video.headers
                ?: runCatching { source.headers }.getOrDefault(Headers.Builder().build())
        val proxiedVideoUrl =
            video.videoUrl?.let { register(client, it, headers, suffixHint = video.url.mediaFileSuffix()) }
                ?: video.videoUrl
        return Video(
            url = video.url,
            quality = video.quality,
            videoUrl = proxiedVideoUrl,
            headers = video.headers,
            subtitleTracks = video.subtitleTracks.map { proxyTrack(client, headers, it) },
            audioTracks = video.audioTracks.map { proxyTrack(client, headers, it) },
        )
    }

    internal fun register(
        client: OkHttpClient,
        url: String,
        headers: Headers = Headers.Builder().build(),
        suffixHint: String? = null,
    ): String? {
        val currentPort = port
        val target = url.toHttpUrlOrNull()
        if (currentPort <= 0 || target == null || target.scheme !in setOf("http", "https")) {
            return null
        }

        val key =
            buildString {
                append(System.identityHashCode(client))
                append('\u0000')
                append(target)
                append('\u0000')
                append(suffixHint.orEmpty())
                headers.forEach { (name, value) ->
                    append('\u0000')
                    append(name)
                    append(':')
                    append(value)
                }
            }
        val token =
            synchronized(lock) {
                tokensByKey[key]?.let { existingToken ->
                    entriesByToken[existingToken] = Entry(key, client, target, headers)
                    return@synchronized existingToken
                }

                while (entriesByToken.size >= MAX_ENTRIES) {
                    val iterator = entriesByToken.entries.iterator()
                    val eldest = iterator.next()
                    iterator.remove()
                    tokensByKey.remove(eldest.value.key)
                }

                UUID.randomUUID().toString().also { newToken ->
                    entriesByToken[newToken] = Entry(key, client, target, headers)
                    tokensByKey[key] = newToken
                }
            }
        return proxyUrl(currentPort, token, target, suffixHint)
    }

    fun fetch(
        token: String,
        range: String? = null,
    ): VideoData? {
        val registryToken = token.substringBefore('.')
        val entry = synchronized(lock) { entriesByToken[registryToken] } ?: return null
        val request =
            Request
                .Builder()
                .url(entry.url)
                .headers(entry.headers)
                .apply {
                    if (!range.isNullOrBlank()) {
                        header("Range", range)
                    }
                }.build()

        val requestClient = if (entry.url.isLoopback()) loopbackClient else entry.client
        return requestClient.newCall(request).execute().use { response ->
            val body = requireNotNull(response.body) { "Extension returned an empty video response" }
            val bytes = body.bytes()
            val contentType = body.contentType()?.toString() ?: "application/octet-stream"
            val rewritten =
                if (response.isSuccessful && isHlsManifest(contentType, bytes)) {
                    rewriteManifest(
                        client = entry.client,
                        baseUrl = response.request.url,
                        headers = entry.headers,
                        bytes = bytes,
                    )
                } else {
                    bytes
                }
            VideoData(
                statusCode = response.code,
                contentType =
                    if (rewritten !== bytes) {
                        "application/vnd.apple.mpegurl"
                    } else {
                        contentType
                    },
                bytes = rewritten,
                responseHeaders =
                    listOf("Accept-Ranges", "Content-Range", "Cache-Control")
                        .mapNotNull { name -> response.header(name)?.let { name to it } }
                        .toMap(),
            )
        }
    }

    private fun proxyTrack(
        client: OkHttpClient,
        headers: Headers,
        track: Track,
    ): Track =
        Track(
            url = register(client, track.url, headers) ?: track.url,
            lang = track.lang,
        )

    private fun rewriteManifest(
        client: OkHttpClient,
        baseUrl: HttpUrl,
        headers: Headers,
        bytes: ByteArray,
    ): ByteArray {
        val text = bytes.toString(StandardCharsets.UTF_8)
        val segmentSuffix = if (text.contains("#EXT-X-MAP")) ".m4s" else ".ts"
        var pendingSegmentUri = false
        val rewritten =
            text
                .lineSequence()
                .map { line ->
                    when {
                        line.isBlank() -> line
                        line.startsWith("#") -> {
                            if (line.startsWith("#EXTINF")) pendingSegmentUri = true
                            val suffixHint =
                                when {
                                    line.startsWith("#EXT-X-KEY") -> ".key"
                                    line.startsWith("#EXT-X-MAP") -> ".mp4"
                                    line.startsWith("#EXT-X-MEDIA") ||
                                        line.startsWith("#EXT-X-I-FRAME-STREAM-INF") -> ".m3u8"
                                    else -> null
                                }
                            uriAttribute.replace(line) { match ->
                                val quote = match.groupValues[1]
                                val original = match.groupValues[2]
                                val proxy =
                                    registerResolved(client, baseUrl, original, headers, suffixHint)
                                        ?: original
                                "URI=$quote$proxy$quote"
                            }
                        }
                        else -> {
                            val suffixHint = if (pendingSegmentUri) segmentSuffix else ".m3u8"
                            pendingSegmentUri = false
                            registerResolved(client, baseUrl, line.trim(), headers, suffixHint) ?: line
                        }
                    }
                }.joinToString("\n")
        return rewritten.toByteArray(StandardCharsets.UTF_8)
    }

    private fun registerResolved(
        client: OkHttpClient,
        baseUrl: HttpUrl,
        url: String,
        headers: Headers,
        suffixHint: String?,
    ): String? {
        val resolved = baseUrl.resolve(url) ?: return null
        val absoluteProxy = register(client, resolved.toString(), headers, suffixHint) ?: return null
        return absoluteProxy.toHttpUrl().encodedPath
    }

    private fun isHlsManifest(
        contentType: String,
        bytes: ByteArray,
    ): Boolean {
        if (contentType.contains("mpegurl", ignoreCase = true)) {
            return true
        }
        val prefixLength = minOf(bytes.size, 64)
        return bytes
            .copyOfRange(0, prefixLength)
            .toString(StandardCharsets.UTF_8)
            .trimStart('\uFEFF', ' ', '\t', '\r', '\n')
            .startsWith("#EXTM3U")
    }

    private fun HttpUrl.isLoopback(): Boolean = host == "localhost" || host == "127.0.0.1" || host == "::1"

    private fun proxyUrl(
        currentPort: Int,
        token: String,
        target: HttpUrl,
        suffixHint: String?,
    ): String = "http://127.0.0.1:$currentPort/video/$token${target.mediaFileSuffix().ifEmpty { suffixHint.orEmpty() }}"

    private fun String.mediaFileSuffix(): String = toHttpUrlOrNull()?.mediaFileSuffix().orEmpty()

    private fun HttpUrl.mediaFileSuffix(): String {
        val fileName = pathSegments.lastOrNull().orEmpty()
        val extension = mediaExtension.find(fileName)?.groupValues?.get(1) ?: return ""
        return ".${extension.lowercase()}"
    }

    fun clear() {
        synchronized(lock) {
            entriesByToken.clear()
            tokensByKey.clear()
        }
        port = 0
    }
}
