package mextensionserver.impl

import com.fasterxml.jackson.databind.JsonNode
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import eu.kanade.tachiyomi.animesource.model.SAnime
import eu.kanade.tachiyomi.animesource.model.SEpisode
import eu.kanade.tachiyomi.animesource.model.Video
import eu.kanade.tachiyomi.animesource.online.AnimeHttpSource
import eu.kanade.tachiyomi.network.GET
import eu.kanade.tachiyomi.network.HttpException
import mextensionserver.model.AnimeData
import mextensionserver.model.AnimeResponse
import mextensionserver.model.DataBody
import mextensionserver.model.JAnime
import okhttp3.FormBody
import okhttp3.Headers
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.Request
import okhttp3.Response
import org.jsoup.Jsoup
import org.jsoup.nodes.Document
import org.jsoup.nodes.Element
import java.time.LocalDate
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * Compatibility adapter for UniqueStream 14.7.
 *
 * The extension targets the retired Dooplay markup. UniqueStream replaced the
 * browse, details, episode, and player layouts without publishing a new APK, so
 * calls from the extension otherwise return empty lists or fail on old selectors.
 */
internal object UniqueStreamCompat {
    private const val SOURCE_ID = "1915898919039572670"
    private const val PLAYER_ACTION = "uniquestream_player_ajax"
    private const val BROWSER_USER_AGENT = "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/138 Mobile Safari/537.36"
    private val objectMapper = jacksonObjectMapper()
    private val playerNonceRegex = Regex(""""nonce"\s*:\s*"([^"]+)"""")
    private val masterUrlRegex = Regex("""MASTER_URL\s*=\s*["']([^"']+)""")
    private val episodeNumberRegex = Regex("""(\d+(?:\.\d+)?)""")
    private val dateFormat = DateTimeFormatter.ofPattern("MMM d, yyyy", Locale.ENGLISH)

    private val supportedMethods =
        setOf(
            "getPopularAnime",
            "getLatestAnime",
            "getSearchAnime",
            "getDetailsAnime",
            "getAnimeUrl",
            "getEpisodeList",
            "getEpisodeUrl",
            "getVideoList",
        )

    fun supports(
        source: Any,
        method: String,
    ): Boolean =
        method in supportedMethods &&
            source is AnimeHttpSource &&
            source.id.toString() == SOURCE_ID

    fun invoke(
        source: AnimeHttpSource,
        data: DataBody,
    ): Any =
        when (data.method) {
            "getPopularAnime" -> getPopularAnime(source, data.page ?: 1)
            "getLatestAnime" -> getLatestAnime(source, data.page ?: 1)
            "getSearchAnime" -> getSearchAnime(source, data.search.orEmpty())
            "getDetailsAnime" -> getDetailsAnime(source, requireAnimeData(data))
            "getAnimeUrl" -> absoluteUrl(source, requireAnimeData(data).url)
            "getEpisodeList" -> getEpisodeList(source, requireAnimeData(data))
            "getEpisodeUrl" -> absoluteUrl(source, requireNotNull(data.episodeData).url)
            "getVideoList" -> getVideoList(source, requireNotNull(data.episodeData).url)
            else -> error("Unsupported UniqueStream method: ${data.method}")
        }

    private fun getPopularAnime(
        source: AnimeHttpSource,
        page: Int,
    ): AnimeResponse {
        if (page != 1) return AnimeResponse(emptyList(), false)
        val document = getDocument(source, "${source.baseUrl}/ratings/")
        return AnimeResponse(parseCards(document, "a.rh-card-link"), false)
    }

    private fun getLatestAnime(
        source: AnimeHttpSource,
        page: Int,
    ): AnimeResponse {
        if (page != 1) return AnimeResponse(emptyList(), false)
        val tvShows = parseCards(getDocument(source, "${source.baseUrl}/tvshows/"), "a.ts-poster-card")
        val movies = parseCards(getDocument(source, "${source.baseUrl}/movies/"), "a.ts-poster-card")
        return AnimeResponse((tvShows + movies).distinctBy(JAnime::url), false)
    }

    private fun getSearchAnime(
        source: AnimeHttpSource,
        query: String,
    ): AnimeResponse {
        if (query.isBlank()) return getPopularAnime(source, 1)
        val url =
            "${source.baseUrl}/wp-json/wp/v2/search"
                .toHttpUrl()
                .newBuilder()
                .addQueryParameter("search", query)
                .addQueryParameter("per_page", "100")
                .build()
        val results =
            objectMapper
                .readTree(getText(source, url.toString()))
                .filter { it["subtype"]?.asText() in setOf("tvshows", "movies") }
                .mapNotNull(::searchResultToAnime)
                .distinctBy(JAnime::url)
        return AnimeResponse(results, false)
    }

    private fun getDetailsAnime(
        source: AnimeHttpSource,
        animeData: AnimeData,
    ): JAnime {
        val document = getDocument(source, absoluteUrl(source, animeData.url))
        return parseDetails(document, animeData)
    }

    private fun getEpisodeList(
        source: AnimeHttpSource,
        animeData: AnimeData,
    ): List<SEpisode> {
        val url = absoluteUrl(source, animeData.url)
        val document = getDocument(source, url)
        val episodes = parseEpisodes(document)
        if (episodes.isNotEmpty()) return episodes.reversed()
        return listOf(
            SEpisode.create().apply {
                this.url = relativeUrl(source, url)
                name = animeData.title ?: document.title().substringBefore(" – ")
                episode_number = 1f
            },
        )
    }

    private fun getVideoList(
        source: AnimeHttpSource,
        episodeUrl: String?,
    ): List<Video> {
        val pageUrl = absoluteUrl(source, episodeUrl)
        val document = getDocument(source, pageUrl)
        val nonce =
            playerNonceRegex
                .find(document.selectFirst("script#uniquestream-player-js-extra")?.data().orEmpty())
                ?.groupValues
                ?.get(1)
                ?: error("UniqueStream player nonce was not found")
        val buttons = document.select("button.server-btn")
        if (buttons.isEmpty()) error("UniqueStream player servers were not found")

        val videos =
            buttons.mapIndexedNotNull { index, button ->
                runCatching {
                    val embedUrl = loadEmbedUrl(source, pageUrl, nonce, button)
                    val masterUrl = extractMasterUrl(getText(source, embedUrl, referer = pageUrl))
                    val videoHeaders = Headers.headersOf("Referer", embedUrl)
                    Video(masterUrl, "Server ${index + 1}", masterUrl, videoHeaders)
                }.getOrNull()
            }
        if (videos.isEmpty()) error("UniqueStream returned no playable streams")
        return videos
    }

    private fun loadEmbedUrl(
        source: AnimeHttpSource,
        pageUrl: String,
        nonce: String,
        button: Element,
    ): String {
        val request =
            Request
                .Builder()
                .url("${source.baseUrl}/wp-admin/admin-ajax.php")
                .headers(
                    source.headers
                        .newBuilder()
                        .set("User-Agent", BROWSER_USER_AGENT)
                        .set("Referer", pageUrl)
                        .set("X-Requested-With", "XMLHttpRequest")
                        .build(),
                ).post(
                    FormBody
                        .Builder()
                        .add("action", PLAYER_ACTION)
                        .add("nonce", nonce)
                        .add("post", button.attr("data-post"))
                        .add("type", button.attr("data-type"))
                        .add("nume", button.attr("data-num"))
                        .build(),
                ).build()
        val response = execute(source, request)
        val embedHtml = objectMapper.readTree(response)["embed_url"]?.asText().orEmpty()
        return Jsoup.parseBodyFragment(embedHtml).selectFirst("iframe[src]")?.attr("src")
            ?: error("UniqueStream player embed URL was not found")
    }

    internal fun parseCards(
        document: Document,
        selector: String,
    ): List<JAnime> =
        document.select(selector).mapNotNull { card ->
            val image = card.selectFirst("img")
            val title =
                image?.attr("alt")?.takeIf(String::isNotBlank)
                    ?: card.selectFirst(".rh-card-title, .poster-title, h2, h3")?.text()
                    ?: return@mapNotNull null
            val href = card.attr("abs:href").ifBlank { card.attr("href") }
            if (href.isBlank()) return@mapNotNull null
            JAnime(
                url = relativeUrl(document.location(), href),
                title = title,
                artist = null,
                author = null,
                description = null,
                genre = null,
                status = SAnime.UNKNOWN,
                thumbnail_url = image?.absoluteImageUrl(),
                initialized = false,
            )
        }

    internal fun parseDetails(
        document: Document,
        fallback: AnimeData = AnimeData(null, null, null, null, null, null, null, null, null),
    ): JAnime {
        val schema =
            document
                .select("script[type=application/ld+json]")
                .asSequence()
                .mapNotNull { runCatching { objectMapper.readTree(it.data()) }.getOrNull() }
                .firstOrNull { it["@type"]?.asText() in setOf("Movie", "TVSeries") }
        val title =
            schema
                ?.get("name")
                ?.asText()
                .orEmpty()
                .ifBlank { fallback.title.orEmpty() }
        val genres =
            schema
                ?.get("genre")
                ?.let { node ->
                    if (node.isArray) node.map(JsonNode::asText) else listOf(node.asText())
                }.orEmpty()
        return JAnime(
            url = relativeUrl(document.location(), document.location()),
            title = title,
            artist = fallback.artist,
            author = fallback.author,
            description = schema?.get("description")?.asText() ?: fallback.description,
            genre = genres.takeIf { it.isNotEmpty() }?.joinToString() ?: fallback.genre,
            status = fallback.status ?: SAnime.UNKNOWN,
            thumbnail_url = schema?.get("image")?.asText() ?: fallback.thumbnail_url,
            initialized = true,
        )
    }

    internal fun parseEpisodes(document: Document): List<SEpisode> =
        document.select("a.ep-card[href]").mapIndexed { index, card ->
            val season =
                card
                    .closest(".season-carousel-panel")
                    ?.attr("data-season-number")
                    ?.toIntOrNull()
                    ?: 1
            val episode =
                episodeNumberRegex
                    .find(card.selectFirst(".ep-card-badge")?.text().orEmpty())
                    ?.groupValues
                    ?.get(1)
                    ?.toFloatOrNull()
                    ?: (index + 1).toFloat()
            val episodeTitle = card.selectFirst(".ep-card-title")?.text().orEmpty()
            val dateText =
                card
                    .select(".ep-card-meta span")
                    .lastOrNull()
                    ?.text()
                    .orEmpty()
            SEpisode.create().apply {
                url = relativeUrl(document.location(), card.attr("abs:href"))
                name = "S${season.toString().padStart(2, '0')}E${episode.cleanNumber()} - $episodeTitle"
                episode_number = episode
                date_upload = parseDate(dateText)
            }
        }

    internal fun extractMasterUrl(html: String): String =
        masterUrlRegex.find(html)?.groupValues?.get(1)
            ?: error("UniqueStream master playlist was not found")

    private fun searchResultToAnime(node: JsonNode): JAnime? {
        val url = node["url"]?.asText()?.takeIf(String::isNotBlank) ?: return null
        val title = node["title"]?.asText()?.takeIf(String::isNotBlank) ?: return null
        return JAnime(
            url = relativeUrl("https://uniquestream.net", url),
            title = Jsoup.parse(title).text(),
            artist = null,
            author = null,
            description = null,
            genre = null,
            status = SAnime.UNKNOWN,
            thumbnail_url = null,
            initialized = false,
        )
    }

    private fun getDocument(
        source: AnimeHttpSource,
        url: String,
    ): Document = Jsoup.parse(getText(source, url), url)

    private fun getText(
        source: AnimeHttpSource,
        url: String,
        referer: String? = null,
    ): String {
        val headers =
            source.headers
                .newBuilder()
                .set("User-Agent", BROWSER_USER_AGENT)
                .apply { if (referer != null) set("Referer", referer) }
                .build()
        return execute(source, GET(url, headers))
    }

    private fun execute(
        source: AnimeHttpSource,
        request: Request,
    ): String =
        source.client.newCall(request).execute().use { response ->
            response.requireSuccess()
            response.body.string()
        }

    private fun Response.requireSuccess() {
        if (!isSuccessful) throw HttpException(code)
    }

    private fun requireAnimeData(data: DataBody): AnimeData = requireNotNull(data.animeData) { "animeData is required for ${data.method}" }

    private fun absoluteUrl(
        source: AnimeHttpSource,
        url: String?,
    ): String =
        source.baseUrl
            .toHttpUrl()
            .resolve(url.orEmpty())
            ?.toString() ?: error("Invalid UniqueStream URL")

    private fun relativeUrl(
        source: AnimeHttpSource,
        url: String,
    ): String = relativeUrl(source.baseUrl, url)

    private fun relativeUrl(
        baseUrl: String,
        url: String,
    ): String {
        val parsed = baseUrl.toHttpUrl().resolve(url) ?: return url
        return parsed.encodedPath + parsed.encodedQuery?.let { "?$it" }.orEmpty()
    }

    private fun Element.absoluteImageUrl(): String? =
        listOf("abs:src", "abs:data-src", "abs:data-lazy-src")
            .asSequence()
            .map(::attr)
            .firstOrNull(String::isNotBlank)

    private fun Float.cleanNumber(): String = if (this % 1f == 0f) toInt().toString() else toString()

    private fun parseDate(value: String): Long =
        runCatching {
            LocalDate
                .parse(value, dateFormat)
                .atStartOfDay()
                .toInstant(ZoneOffset.UTC)
                .toEpochMilli()
        }.getOrDefault(0L)
}
