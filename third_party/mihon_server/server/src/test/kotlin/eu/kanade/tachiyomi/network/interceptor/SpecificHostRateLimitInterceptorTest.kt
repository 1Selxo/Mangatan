package eu.kanade.tachiyomi.network.interceptor

import kotlin.test.Test
import kotlin.test.assertTrue

class SpecificHostRateLimitInterceptorTest {
    @Test
    fun `exports the duration ABI used by current extensions`() {
        val methods = Class.forName("eu.kanade.tachiyomi.network.interceptor.SpecificHostRateLimitInterceptorKt").declaredMethods

        assertTrue(methods.any { it.name == "rateLimitHost-Wn2Vu4Y" && it.parameterCount == 4 })
    }
}
