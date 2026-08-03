package mextensionserver

import mextensionserver.controller.MExtensionServerController

/**
 * JNI-friendly entry point for applications which embed the bridge in their
 * own process. The embedded server is restricted to loopback and may be
 * stopped and restarted without recreating the JVM.
 */
object EmbeddedBridge {
    private val lock = Any()
    private var controller: MExtensionServerController? = null

    @JvmStatic
    fun start(
        port: Int,
        appDir: String?,
    ): Int =
        synchronized(lock) {
            controller
                ?.takeIf(MExtensionServerController::isRunning)
                ?.getPort()
                ?.let { return@synchronized it }

            initApplication(appDir)
            MExtensionServerController("127.0.0.1")
                .also {
                    it.start(port)
                    controller = it
                }.getPort()
        }

    @JvmStatic
    fun pause() {
        synchronized(lock) {
            // The host process keeps the JVM alive. Preserve loaded extension
            // instances across iOS background/resume cycles; the JVM shutdown
            // hook still performs full cleanup when the process exits.
            controller?.pause()
            controller = null
        }
    }

    @JvmStatic
    fun stop() {
        synchronized(lock) {
            controller?.stop()
            controller = null
        }
    }

    @JvmStatic
    fun isRunning(): Boolean = synchronized(lock) { controller?.isRunning() == true }
}
