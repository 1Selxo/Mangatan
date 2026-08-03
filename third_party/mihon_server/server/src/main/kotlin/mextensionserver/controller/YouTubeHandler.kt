package mextensionserver.controller

import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import fi.iki.elonen.NanoHTTPD
import io.github.oshai.kotlinlogging.KotlinLogging
import mextensionserver.impl.NewPipeYouTubeResolver
import mextensionserver.impl.YouTubeVideoResolver

class YouTubeHandler(
    private val resolver: YouTubeVideoResolver = NewPipeYouTubeResolver,
) {
    private val logger = KotlinLogging.logger {}
    private val objectMapper = jacksonObjectMapper()

    fun serve(session: NanoHTTPD.IHTTPSession): NanoHTTPD.Response = serveUrl(session.parameters["url"]?.firstOrNull())

    internal fun serveUrl(requestUrl: String?): NanoHTTPD.Response {
        val url = requestUrl?.trim()
        if (url.isNullOrEmpty()) {
            return jsonError(NanoHTTPD.Response.Status.BAD_REQUEST, "Missing YouTube URL")
        }

        return try {
            NanoHTTPD.newFixedLengthResponse(
                NanoHTTPD.Response.Status.OK,
                "application/json",
                objectMapper.writeValueAsString(resolver.resolve(url)),
            )
        } catch (error: Throwable) {
            logger.error(error) { "Error resolving YouTube video" }
            jsonError(
                NanoHTTPD.Response.Status.INTERNAL_ERROR,
                error.message ?: error.javaClass.simpleName,
            )
        }
    }

    private fun jsonError(
        status: NanoHTTPD.Response.Status,
        message: String,
    ): NanoHTTPD.Response =
        NanoHTTPD.newFixedLengthResponse(
            status,
            "application/json",
            objectMapper.writeValueAsString(mapOf("error" to message)),
        )
}
