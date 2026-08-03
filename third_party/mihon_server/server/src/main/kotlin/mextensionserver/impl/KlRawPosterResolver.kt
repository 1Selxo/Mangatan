package mextensionserver.impl

import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import okhttp3.Headers
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request

/** Resolves KL Raw's currently broken poster CDN URLs to public cover art. */
internal object KlRawPosterResolver {
    const val DEFAULT_POSTER_URL = "https://www.klraw.info/theme/mangareader/images/default.jpg"
    private const val API_URL = "https://api.mangadex.org/manga"
    private const val COVER_ORIGIN = "https://uploads.mangadex.org"
    private val objectMapper = jacksonObjectMapper()
    private val headers =
        Headers.headersOf(
            "Accept",
            "application/json",
            "User-Agent",
            "Mangatan-MExtensionServer/1.0",
        )

    fun resolve(
        client: OkHttpClient,
        title: String,
    ): String =
        runCatching {
            val url =
                API_URL
                    .toHttpUrl()
                    .newBuilder()
                    .addQueryParameter("title", title)
                    .addQueryParameter("limit", "1")
                    .addQueryParameter("includes[]", "cover_art")
                    .build()
            val request =
                Request
                    .Builder()
                    .url(url)
                    .headers(headers)
                    .build()
            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) return@use null
                parseCoverUrl(response.body.string())
            }
        }.getOrNull() ?: DEFAULT_POSTER_URL

    internal fun parseCoverUrl(json: String): String? {
        val manga = objectMapper.readTree(json)["data"]?.firstOrNull() ?: return null
        val mangaId = manga["id"]?.asText()?.takeIf(String::isNotBlank) ?: return null
        val fileName =
            manga["relationships"]
                ?.firstOrNull { it["type"]?.asText() == "cover_art" }
                ?.get("attributes")
                ?.get("fileName")
                ?.asText()
                ?.takeIf(String::isNotBlank)
                ?: return null
        return COVER_ORIGIN
            .toHttpUrl()
            .newBuilder()
            .addPathSegment("covers")
            .addPathSegment(mangaId)
            .addPathSegment("$fileName.256.jpg")
            .build()
            .toString()
    }
}
