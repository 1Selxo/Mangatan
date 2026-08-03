package mextensionserver

import java.net.HttpURLConnection
import java.net.URI
import java.nio.file.Files
import kotlin.io.path.deleteRecursively
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class EmbeddedBridgeTest {
    @AfterTest
    fun stopBridge() {
        EmbeddedBridge.stop()
    }

    @Test
    fun `starts on loopback and can be restarted`() {
        val appDir = Files.createTempDirectory("mextension-embedded-test")
        try {
            val port = EmbeddedBridge.start(0, appDir.toString())

            assertTrue(port > 0)
            assertTrue(EmbeddedBridge.isRunning())
            assertEquals(port, EmbeddedBridge.start(0, appDir.toString()))

            val connection =
                URI("http://127.0.0.1:$port/").toURL().openConnection() as HttpURLConnection
            try {
                assertEquals(200, connection.responseCode)
                assertEquals("mextensionserver Server Running", connection.inputStream.bufferedReader().readText())
            } finally {
                connection.disconnect()
            }
            val capabilities =
                URI("http://127.0.0.1:$port/capabilities").toURL().readText()
            assertTrue(capabilities.contains("\"youtubeResolver\":true"))

            EmbeddedBridge.pause()
            assertFalse(EmbeddedBridge.isRunning())
            assertEquals(port, EmbeddedBridge.start(port, appDir.toString()))
            assertTrue(EmbeddedBridge.isRunning())

            EmbeddedBridge.stop()
            assertFalse(EmbeddedBridge.isRunning())
        } finally {
            appDir.deleteRecursively()
        }
    }
}
