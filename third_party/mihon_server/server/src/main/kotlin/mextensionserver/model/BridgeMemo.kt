package mextensionserver.model

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import java.util.Base64

/**
 * Keeps TachiyomiX 1.6 source metadata attached to the opaque URL that the
 * existing Mangayomi bridge already persists and sends back on later calls.
 */
object BridgeMemo {
    private const val MARKER = "|mangatan-memo|"

    fun encode(
        url: String,
        memo: JsonObject,
    ): String {
        if (memo.isEmpty()) return url
        val payload =
            Base64
                .getUrlEncoder()
                .withoutPadding()
                .encodeToString(memo.toString().toByteArray(Charsets.UTF_8))
        return "$url$MARKER$payload"
    }

    fun decode(value: String): DecodedUrl {
        val markerIndex = value.lastIndexOf(MARKER)
        if (markerIndex < 0) return DecodedUrl(value, JsonObject(emptyMap()))

        val decoded =
            runCatching {
                val payload = value.substring(markerIndex + MARKER.length)
                val json = Base64.getUrlDecoder().decode(payload).toString(Charsets.UTF_8)
                Json.parseToJsonElement(json) as JsonObject
            }.getOrNull()
                ?: return DecodedUrl(value, JsonObject(emptyMap()))

        return DecodedUrl(value.substring(0, markerIndex), decoded)
    }

    data class DecodedUrl(
        val url: String,
        val memo: JsonObject,
    )
}
