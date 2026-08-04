package eu.kanade.tachiyomi.network

import eu.kanade.tachiyomi.App
import okhttp3.brotli.BrotliInterceptor
import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class NetworkHelperTest {
    @Test
    fun `default client matches current Mihon extension contract`() {
        val client = NetworkHelper(App()).client
        val interceptors = client.interceptors.map { it.javaClass.simpleName }
        val networkInterceptors = client.networkInterceptors

        assertTrue("UncaughtExceptionInterceptor" in interceptors)
        assertTrue("UserAgentInterceptor" in interceptors)
        assertTrue("CloudflareInterceptor" in interceptors)
        assertFalse("MangaFireProtectionInterceptor" in interceptors)
        assertFalse(
            networkInterceptors.any {
                it.javaClass.simpleName == "IgnoreGzipInterceptor"
            },
        )
        assertFalse(networkInterceptors.any { it is BrotliInterceptor })
    }
}
