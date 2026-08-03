package mextensionserver.impl

import okhttp3.Headers
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Protocol
import okhttp3.Response
import okhttp3.ResponseBody.Companion.toResponseBody
import java.net.URI
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class MihonVideoProxyTest {
    @AfterTest
    fun clearProxy() {
        MihonVideoProxy.clear()
    }

    @Test
    fun `rewrites nested HLS resources through the bridge`() {
        val requestedUrls = mutableListOf<String>()
        val seenReferers = mutableListOf<String?>()
        val client =
            OkHttpClient
                .Builder()
                .addInterceptor { chain ->
                    val request = chain.request()
                    requestedUrls += request.url.toString()
                    seenReferers += request.header("Referer")
                    val body =
                        when (request.url.encodedPath) {
                            "/master" ->
                                """#EXTM3U
                                    |#EXT-X-MEDIA:TYPE=AUDIO,URI="audio/list.m3u8"
                                    |#EXT-X-KEY:METHOD=AES-128,URI="https://keys.test/key.bin"
                                    |#EXTINF:6.0,
                                    |segment
                                """.trimMargin()
                            "/list.m3u8" -> "#EXTM3U\naudio.aac"
                            else -> "payload"
                        }
                    Response
                        .Builder()
                        .request(request)
                        .protocol(Protocol.HTTP_1_1)
                        .code(200)
                        .message("OK")
                        .body(
                            body.toResponseBody(
                                if (request.url.encodedPath.endsWith(".m3u8")) {
                                    "application/vnd.apple.mpegurl".toMediaType()
                                } else {
                                    "application/octet-stream".toMediaType()
                                },
                            ),
                        ).build()
                }.build()
        val headers = Headers.headersOf("Referer", "https://anime.example/")
        MihonVideoProxy.configure(39642)

        val proxyUrl = assertNotNull(MihonVideoProxy.register(client, "https://video.test/master", headers, suffixHint = ".m3u8"))
        val manifest = assertNotNull(MihonVideoProxy.fetch(proxyUrl.token())).bytes.decodeToString()

        assertTrue(proxyUrl.startsWith("http://127.0.0.1:39642/video/"))
        assertTrue(proxyUrl.endsWith(".m3u8"))
        assertTrue(manifest.lineSequence().any { it.contains("URI=\"/video/") && it.contains(".m3u8\"") })
        assertTrue(manifest.lineSequence().any { it.contains("URI=\"/video/") && it.contains(".bin\"") })
        assertTrue(manifest.lineSequence().any { it.startsWith("/video/") && it.endsWith(".ts") })
        assertFalse(manifest.contains("video.test"))
        assertFalse(manifest.contains("keys.test"))

        manifest.proxyTokens().forEach { token -> MihonVideoProxy.fetch(token) }

        assertTrue(requestedUrls.contains("https://video.test/audio/list.m3u8"))
        assertTrue(requestedUrls.contains("https://keys.test/key.bin"))
        assertTrue(requestedUrls.contains("https://video.test/segment"))
        assertTrue(seenReferers.all { it == "https://anime.example/" })
    }

    @Test
    fun `forwards byte ranges and response range headers`() {
        var seenRange: String? = null
        val bytes = byteArrayOf(1, 2, 3, 4)
        val client =
            OkHttpClient
                .Builder()
                .addInterceptor { chain ->
                    seenRange = chain.request().header("Range")
                    Response
                        .Builder()
                        .request(chain.request())
                        .protocol(Protocol.HTTP_1_1)
                        .code(206)
                        .message("Partial Content")
                        .header("Accept-Ranges", "bytes")
                        .header("Content-Range", "bytes 4-7/8")
                        .body(bytes.toResponseBody("video/mp4".toMediaType()))
                        .build()
                }.build()
        MihonVideoProxy.configure(39642)
        val proxyUrl = assertNotNull(MihonVideoProxy.register(client, "https://video.test/movie.mp4"))

        assertTrue(proxyUrl.endsWith(".mp4"))
        val response = assertNotNull(MihonVideoProxy.fetch(proxyUrl.token(), "bytes=4-7"))

        assertEquals(206, response.statusCode)
        assertEquals("bytes=4-7", seenRange)
        assertEquals("bytes", response.responseHeaders["Accept-Ranges"])
        assertEquals("bytes 4-7/8", response.responseHeaders["Content-Range"])
        assertContentEquals(bytes, response.bytes)
    }

    private fun String.token(): String = URI(this).path.substringAfterLast('/')

    private fun String.proxyTokens(): Set<String> =
        Regex("/video/([0-9a-f-]+\\.[a-z0-9]+)")
            .findAll(this)
            .map { it.groupValues[1] }
            .toSet()
}
