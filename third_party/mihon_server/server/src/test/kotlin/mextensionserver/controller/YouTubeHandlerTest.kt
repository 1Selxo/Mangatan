package mextensionserver.controller

import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import com.fasterxml.jackson.module.kotlin.readValue
import fi.iki.elonen.NanoHTTPD
import mextensionserver.impl.YouTubeVideoResolver
import mextensionserver.model.YouTubeResolveResponse
import mextensionserver.model.YouTubeStream
import mextensionserver.model.YouTubeTrack
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class YouTubeHandlerTest {
    private val resolved =
        YouTubeResolveResponse(
            videoId = "gpXIS_yI7HM",
            title = "Trip to Okayama",
            url = "https://www.youtube.com/watch?v=gpXIS_yI7HM",
            durationSeconds = 671,
            uploadDateMillis = 1_785_283_200_000,
            thumbnailUrl = "https://i.ytimg.com/vi/gpXIS_yI7HM/maxresdefault.jpg",
            description = "Test description",
            channelId = "UC-test",
            channelName = "Test channel",
            channelUrl = "https://www.youtube.com/channel/UC-test",
            streams =
                listOf(
                    YouTubeStream(
                        url = "https://video.example/stream",
                        quality = "1080p",
                        height = 1080,
                        videoOnly = true,
                        subtitles = listOf(YouTubeTrack("https://text.example/en.vtt", "English")),
                        audios = listOf(YouTubeTrack("https://audio.example/stream", "Original audio")),
                    ),
                ),
        )

    @Test
    fun `returns NewPipe metadata and tracks as JSON`() {
        val handler = YouTubeHandler(YouTubeVideoResolver { resolved })
        val response = handler.serveUrl(resolved.url)

        assertEquals(NanoHTTPD.Response.Status.OK, response.status)
        val body =
            response.data.bufferedReader().use {
                jacksonObjectMapper().readValue<Map<String, Any?>>(it.readText())
            }
        assertEquals("gpXIS_yI7HM", body["videoId"])
        assertEquals("Trip to Okayama", body["title"])
        val streams = body["streams"] as List<*>
        val stream = streams.single() as Map<*, *>
        assertEquals("1080p", stream["quality"])
        assertTrue((stream["audios"] as List<*>).isNotEmpty())
        assertTrue((stream["subtitles"] as List<*>).isNotEmpty())
    }

    @Test
    fun `rejects an empty URL without invoking NewPipe`() {
        val handler =
            YouTubeHandler(
                YouTubeVideoResolver {
                    error("Resolver should not be called")
                },
            )

        assertEquals(NanoHTTPD.Response.Status.BAD_REQUEST, handler.serveUrl(" ").status)
    }
}
