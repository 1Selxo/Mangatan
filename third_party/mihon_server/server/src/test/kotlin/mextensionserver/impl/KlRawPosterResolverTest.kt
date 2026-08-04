package mextensionserver.impl

import kotlin.test.Test
import kotlin.test.assertEquals

class KlRawPosterResolverTest {
    @Test
    fun `builds a MangaDex cover URL from search results`() {
        val json =
            """
            {
              "data": [{
                "id": "manga-id",
                "relationships": [{
                  "type": "cover_art",
                  "attributes": {"fileName": "cover-file.jpg"}
                }]
              }]
            }
            """.trimIndent()

        assertEquals(
            "https://uploads.mangadex.org/covers/manga-id/cover-file.jpg.256.jpg",
            KlRawPosterResolver.parseCoverUrl(json),
        )
    }
}
