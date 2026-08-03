package eu.kanade.tachiyomi.network.interceptor

import kotlin.test.Test
import kotlin.test.assertTrue

class RateLimitInterceptorTest {
    @Test
    fun `exposes duration default ABI used by current extensions`() {
        val methods = Class.forName("eu.kanade.tachiyomi.network.interceptor.RateLimitInterceptorKt").declaredMethods

        assertTrue {
            methods.any {
                it.name == "rateLimit-SxA4cEA\$default" &&
                    it.parameterCount == 5
            }
        }
    }
}
