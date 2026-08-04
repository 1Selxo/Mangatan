plugins {
    id(
        libs.plugins.kotlin.jvm
            .get()
            .pluginId,
    )
    id(
        libs.plugins.kotlin.serialization
            .get()
            .pluginId,
    )
    id(
        libs.plugins.kotlinter
            .get()
            .pluginId,
    )
}

val iosRuntime = providers.gradleProperty("iosRuntime").map(String::toBoolean).getOrElse(false)

dependencies {
    // Shared
    implementation(libs.bundles.shared)
    testImplementation(libs.bundles.sharedTest)

    // Android stub library
    implementation(libs.android.stubs)

    // XML
    compileOnly(libs.xmlpull)

    // Config API
    implementation(projects.androidCompat.config)

    // APK sig verifier
    compileOnly(libs.apksig)

    // AndroidX annotations
    compileOnly(libs.android.annotations)

    annotationProcessor(libs.quickjs4j.processor)

    // Kotlin wrapper around Java Preferences, makes certain things easier
    implementation(libs.bundles.settings)

    // Android version of SimpleDateFormat
    implementation(libs.icu4j)

    // OpenJDK lacks native JPEG encoder and native WEBP decoder
    implementation(libs.bundles.twelvemonkeys)
    implementation(libs.imageio.webp)

    // iOS has no Chromium runtime. Keep only KCEF's compile-time API so the
    // embedded server never resolves JCEF/JOGL from the desktop-only host.
    if (iosRuntime) {
        compileOnly(libs.kcef) {
            exclude(group = "org.jogamp.jogl")
            exclude(group = "org.jogamp.gluegen")
        }
    } else {
        implementation(libs.kcef)
    }
}

tasks.test {
    useJUnitPlatform()
}
