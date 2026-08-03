package mextensionserver.controller

import fi.iki.elonen.NanoHTTPD
import io.github.oshai.kotlinlogging.KotlinLogging
import mextensionserver.impl.MihonVideoProxy
import java.io.ByteArrayInputStream

class VideoProxyHandler {
    private val logger = KotlinLogging.logger {}

    fun serve(session: NanoHTTPD.IHTTPSession): NanoHTTPD.Response {
        val token = session.uri.removePrefix(ROUTE_PREFIX)
        if (token.isEmpty() || token == session.uri) {
            return notFound()
        }

        return try {
            val video = MihonVideoProxy.fetch(token, session.headers["range"]) ?: return notFound()
            val status =
                NanoHTTPD.Response.Status.lookup(video.statusCode)
                    ?: NanoHTTPD.Response.Status.INTERNAL_ERROR
            NanoHTTPD
                .newFixedLengthResponse(
                    status,
                    video.contentType,
                    ByteArrayInputStream(video.bytes),
                    video.bytes.size.toLong(),
                ).apply {
                    video.responseHeaders.forEach { (name, value) -> addHeader(name, value) }
                    addHeader("Access-Control-Allow-Origin", "*")
                }
        } catch (error: Throwable) {
            logger.error(error) { "Error proxying extension video" }
            NanoHTTPD.newFixedLengthResponse(
                NanoHTTPD.Response.Status.INTERNAL_ERROR,
                NanoHTTPD.MIME_PLAINTEXT,
                error.message ?: error.javaClass.simpleName,
            )
        }
    }

    private fun notFound(): NanoHTTPD.Response =
        NanoHTTPD.newFixedLengthResponse(
            NanoHTTPD.Response.Status.NOT_FOUND,
            NanoHTTPD.MIME_PLAINTEXT,
            "Video not found",
        )

    companion object {
        const val ROUTE_PREFIX = "/video/"
    }
}
