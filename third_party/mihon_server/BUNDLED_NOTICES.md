# Third-party components in the shaded server JAR

The server JAR Mangatan ships (`MExtensionServer-<version>-<revision>.jar`) is a
shaded ("fat") JAR: the components below are compiled into it. It is built from
the vendored source in this directory by
`scripts/build_vendored_mihon_server.{sh,ps1}`, which copies this file next to
the JAR in every desktop release bundle as `THIRD_PARTY_NOTICES.md`.

This table is an index, derived from `gradle/libs.versions.toml` and the module
`build.gradle.kts` files in this tree. Where a component's own `LICENSE`,
`NOTICE` or POM — shaded into the JAR alongside its classes — states different
terms, that statement governs. To list what is present in a built JAR:

```sh
unzip -l MExtensionServer-*.jar | grep -Ei 'licen|notice'
```

Two components need their terms stated here rather than only referenced, because
their published artifacts carry no license text of their own: logback and
NanoHTTPD's transitive pieces.

| Component | License | Source |
| --- | --- | --- |
| M-Extension-Server | MPL-2.0 | `M-Extension-Server-LICENSE.txt`; source vendored at `third_party/mihon_server` |
| NewPipe Extractor | GPL-3.0-or-later | `NewPipe-Extractor-LICENSE.txt`; corresponding source vendored at `third_party/newpipe_extractor` |
| logback-classic / logback-core | EPL-1.0 **or** LGPL-2.1 (dual) | <https://github.com/qos-ch/logback> |
| SLF4J (`slf4j-api`, `slf4j-simple`) | MIT | <https://github.com/qos-ch/slf4j> |
| Kotlin stdlib / reflect | Apache-2.0 | <https://github.com/JetBrains/kotlin> |
| kotlinx.coroutines, kotlinx.serialization | Apache-2.0 | <https://github.com/Kotlin> |
| kotlin-logging | Apache-2.0 | <https://github.com/oshai/kotlin-logging> |
| OkHttp (+ logging, dnsoverhttps, brotli, zstd) and Okio | Apache-2.0 | <https://github.com/square/okhttp> |
| jsoup | MIT | <https://github.com/jhy/jsoup> |
| NanoHTTPD | BSD-3-Clause | <https://github.com/NanoHttpd/nanohttpd> |
| RxJava 1.x / RxKotlin | Apache-2.0 | <https://github.com/ReactiveX/RxJava> |
| Jackson (`databind`, `annotations`, `module-kotlin`) | Apache-2.0 | <https://github.com/FasterXML> |
| Typesafe Config, config4k | Apache-2.0 | <https://github.com/lightbend/config> |
| dex2jar (`dex-translator`, `dex-tools`) | Apache-2.0 | <https://github.com/pxb1988/dex2jar> |
| apk-parser (`net.dongliu:apk-parser`) | BSD-2-Clause | <https://github.com/hsiafan/apk-parser> |
| ASM (`asm`, `-tree`, `-commons`, `-util`) | BSD-3-Clause | <https://asm.ow2.io/> |
| Kodein-DI | MIT | <https://github.com/kosi-libs/Kodein> |
| Injekt (`null2264` fork) | Apache-2.0 | <https://github.com/kohesive/injekt> |
| quickjs4j (`io.roastedroot:quickjs4j`) | Apache-2.0 | <https://github.com/roastedroot/quickjs4j> |
| ICU4J, ICU4J charset | Unicode-3.0 | <https://github.com/unicode-org/icu> |
| TwelveMonkeys ImageIO / common | BSD-3-Clause | <https://github.com/haraldk/TwelveMonkeys> |
| webp-imageio | Apache-2.0 | <https://github.com/usefulness/webp-imageio> |
| multiplatform-settings | Apache-2.0 | <https://github.com/russhwolf/multiplatform-settings> |
| kotlin-multiplatform-appdirs | Apache-2.0 | <https://github.com/Syer10/kotlin-multiplatform-appdirs> |
| protobuf-javalite | BSD-3-Clause | <https://github.com/protocolbuffers/protobuf> |
| Android stub library (`Suwayomi:android-jar`) | Apache-2.0 | <https://github.com/Suwayomi/Suwayomi-Server> |
| KCEF (desktop bundles only) | Apache-2.0 | <https://github.com/DATL4G/KCEF> |

`apksig`, `xmlpull` and the AndroidX annotations are `compileOnly` and are not
shaded into the JAR.

The iOS variant is built with `-PiosRuntime=true`, which excludes logback (SLF4J
Simple is substituted) and KCEF along with its JOGL/JNA native payloads. Its
`ios/EmbeddedMihon/THIRD_PARTY_NOTICES.md` covers that build.

logback ships no license text of its own in its artifact. Its dual
EPL-1.0 / LGPL-2.1 terms are stated above and its complete source is at the URL
given; the canonical license texts are published at
<https://www.eclipse.org/legal/epl-v10.html> and
<https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html>.

The bundled Java runtime is a `jlink` image of the JDK used to build the release
(GPL-2.0-with-Classpath-exception); see `jre/legal` inside the bundle for its
notices.
