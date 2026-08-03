package mextensionserver.controller

import fi.iki.elonen.NanoHTTPD
import io.github.oshai.kotlinlogging.KotlinLogging
import mextensionserver.impl.MExtensionServerLoader
import mextensionserver.impl.MihonImageProxy
import mextensionserver.impl.MihonVideoProxy
import java.io.IOException

class MExtensionServerController(
    private val bindHost: String? = null,
) {
    private val logger = KotlinLogging.logger {}
    private var server: WebServer? = null

    fun start(port: Int) {
        try {
            server = WebServer(port)
            server?.start(NanoHTTPD.SOCKET_READ_TIMEOUT, false)
            val actualPort = server?.listeningPort ?: 0
            MihonImageProxy.configure(actualPort)
            MihonVideoProxy.configure(actualPort)
            logger.info { "mextensionserver server started on port $actualPort" }
        } catch (e: IOException) {
            logger.error(e) { "Failed to start mextensionserver server" }
            throw e
        }
    }

    fun stop() {
        pause()
        MExtensionServerLoader.cleanupTempFiles()
    }

    /**
     * Stops only the loopback listener while retaining loaded extension
     * instances. The embedded iOS bridge uses this during app suspension so a
     * resume does not repeat APK conversion and source initialization.
     */
    fun pause() {
        server?.stop()
        server = null
        logger.info { "mextensionserver server stopped" }
    }

    fun isRunning(): Boolean = server?.isAlive == true

    fun getPort(): Int = server?.listeningPort ?: 0

    private inner class WebServer(
        port: Int,
    ) : NanoHTTPD(bindHost, port) {
        override fun serve(session: IHTTPSession): Response =
            when (session.uri) {
                "/dalvik" -> DalvikHandler().serve(session)
                "/youtube/resolve" -> YouTubeHandler().serve(session)
                "/" -> newFixedLengthResponse("mextensionserver Server Running")
                "/capabilities" ->
                    newFixedLengthResponse(
                        Response.Status.OK,
                        "application/json",
                        """{"mangatanMihonBridge":1,"sourceFactory":true,"preferenceCallbacks":true,"imageProxy":true,"videoProxy":true,"youtubeResolver":true,"sourceUrls":true,"extensionHandles":true}""",
                    )
                "/stop" -> {
                    newFixedLengthResponse("Server stopping").also {
                        Thread {
                            Thread.sleep(100)
                            stop()
                        }.start()
                    }
                }
                else ->
                    if (session.uri.startsWith(ImageProxyHandler.ROUTE_PREFIX)) {
                        ImageProxyHandler().serve(session)
                    } else if (session.uri.startsWith(VideoProxyHandler.ROUTE_PREFIX)) {
                        VideoProxyHandler().serve(session)
                    } else {
                        newFixedLengthResponse(Response.Status.NOT_FOUND, MIME_PLAINTEXT, "Not Found")
                    }
            }
    }
}
