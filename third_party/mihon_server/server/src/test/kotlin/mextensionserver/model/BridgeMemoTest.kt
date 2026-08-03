package mextensionserver.model

import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class BridgeMemoTest {
    @Test
    fun `round trips memo through opaque URL`() {
        val memo =
            buildJsonObject {
                put("slug", "solo-leveling")
                put("mangaId", "abc123")
            }

        val encoded = BridgeMemo.encode("/manga/abc123", memo)
        val decoded = BridgeMemo.decode(encoded)

        assertEquals("/manga/abc123", decoded.url)
        assertEquals(memo, decoded.memo)
    }

    @Test
    fun `leaves ordinary and malformed URLs unchanged`() {
        val ordinary = "https://example.com/manga/1"
        val malformed = "/manga/1|mangatan-memo|not-base64"

        assertEquals(ordinary, BridgeMemo.decode(ordinary).url)
        assertTrue(BridgeMemo.decode(ordinary).memo.isEmpty())
        assertEquals(malformed, BridgeMemo.decode(malformed).url)
        assertTrue(BridgeMemo.decode(malformed).memo.isEmpty())
    }
}
