package mextensionserver.impl

import mextensionserver.model.AnimeData
import org.jsoup.Jsoup
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class UniqueStreamCompatTest {
    @Test
    fun `parses current browse cards`() {
        val document =
            Jsoup.parse(
                """
                <a href="/tvshows/example/" class="ts-poster-card">
                  <div class="poster-wrap">
                    <img src="https://media.example/poster.webp" alt="Example Show">
                  </div>
                </a>
                """.trimIndent(),
                "https://uniquestream.net/tvshows/",
            )

        val anime = UniqueStreamCompat.parseCards(document, "a.ts-poster-card").single()

        assertEquals("/tvshows/example/", anime.url)
        assertEquals("Example Show", anime.title)
        assertEquals("https://media.example/poster.webp", anime.thumbnail_url)
    }

    @Test
    fun `parses current JSON-LD details`() {
        val document =
            Jsoup.parse(
                """
                <script type="application/ld+json">
                  {"@type":"TVSeries","name":"Example Show","description":"Synopsis","image":"https://media.example/poster.webp","genre":["Drama","Action"]}
                </script>
                """.trimIndent(),
                "https://uniquestream.net/tvshows/example/",
            )

        val anime =
            UniqueStreamCompat.parseDetails(
                document,
                AnimeData(null, null, null, null, null, null, null, null, null),
            )

        assertEquals("/tvshows/example/", anime.url)
        assertEquals("Example Show", anime.title)
        assertEquals("Synopsis", anime.description)
        assertEquals("Drama, Action", anime.genre)
        assertTrue(anime.initialized)
    }

    @Test
    fun `parses current season episode cards`() {
        val document =
            Jsoup.parse(
                """
                <div class="season-carousel-panel" data-season-number="2">
                  <a href="/episodes/example-s2e3/" class="ep-card">
                    <span class="ep-card-badge">E3</span>
                    <h3 class="ep-card-title">The Return</h3>
                    <div class="ep-card-meta"><span>24 min</span><span>Jul 24, 2026</span></div>
                  </a>
                </div>
                """.trimIndent(),
                "https://uniquestream.net/tvshows/example/",
            )

        val episode = UniqueStreamCompat.parseEpisodes(document).single()

        assertEquals("/episodes/example-s2e3/", episode.url)
        assertEquals("S02E3 - The Return", episode.name)
        assertEquals(3f, episode.episode_number)
        assertTrue(episode.date_upload > 0)
    }

    @Test
    fun `extracts current signed master playlist`() {
        val html =
            """
            <script>
              var MASTER_URL = "https://edge.example/video/master.m3u8?exp=1&sig=abc";
            </script>
            """.trimIndent()

        assertEquals(
            "https://edge.example/video/master.m3u8?exp=1&sig=abc",
            UniqueStreamCompat.extractMasterUrl(html),
        )
    }
}
