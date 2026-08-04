package mextensionserver.util

/*
 * Copyright (C) Contributors to the Suwayomi project
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import android.content.pm.PackageInfo
import android.content.pm.Signature
import android.os.Bundle
import com.googlecode.d2j.dex.Dex2jar
import com.googlecode.d2j.reader.MultiDexFileReader
import com.googlecode.dex2jar.tools.BaksmaliBaseDexExceptionHandler
import io.github.oshai.kotlinlogging.KotlinLogging
import net.dongliu.apk.parser.ApkFile
import net.dongliu.apk.parser.ApkParsers
import xyz.nulldev.androidcompat.pm.toPackageInfo
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.io.File
import java.net.URLClassLoader
import java.nio.file.Files
import java.nio.file.Path
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

object PackageTools {
    private val logger = KotlinLogging.logger {}

    const val EXTENSION_FEATURE = "tachiyomi.extension"
    const val METADATA_SOURCE_CLASS = "tachiyomi.extension.class"
    const val METADATA_SOURCE_FACTORY = "tachiyomi.extension.factory"
    const val METADATA_NSFW = "tachiyomi.extension.nsfw"
    const val LIB_VERSION_MIN = 1.3
    const val LIB_VERSION_MAX = 1.5

    /**
     * Convert dex to jar, a wrapper for the dex2jar library
     */
    fun dex2jar(
        dexFile: File,
        jarFile: File,
    ) {
        // adopted from com.googlecode.dex2jar.tools.Dex2jarCmd.doCommandLine
        // source at: https://github.com/DexPatcher/dex2jar/tree/v2.1-20190905-lanchon/dex-tools/src/main/java/com/googlecode/dex2jar/tools/Dex2jarCmd.java

        val jarFilePath = jarFile.toPath()
        val reader = MultiDexFileReader.open(Files.readAllBytes(dexFile.toPath()))
        val handler = BaksmaliBaseDexExceptionHandler()
        val translated = ByteArrayOutputStream()
        Dex2jar
            .from(reader)
            .withExceptionHandler(handler)
            .reUseReg(false)
            .topoLogicalSort()
            .skipDebug(true)
            .optimizeSynchronized(false)
            .printIR(false)
            .noCode(false)
            .skipExceptions(false)
            .dontSanitizeNames(true)
            .doTranslate(translated)
        writeTranslatedClasses(translated, jarFile)
        if (handler.hasException()) {
            val errorFile: Path =
                jarFilePath.parent.resolve("${dexFile.nameWithoutExtension}-error.txt")
            logger.error(
                """
                Detail Error Information in File $errorFile
                Please report this file to one of following link if possible (any one).
                https://sourceforge.net/p/dex2jar/tickets/
                https://bitbucket.org/pxb1988/dex2jar/issues
                https://github.com/pxb1988/dex2jar/issues
                dex2jar@googlegroups.com
                """.trimIndent(),
            )
            handler.dump(errorFile, emptyArray<String>())
        } else {
            BytecodeEditor.fixAndroidClasses(jarFilePath)
        }
    }

    private fun writeTranslatedClasses(
        translated: ByteArrayOutputStream,
        jarFile: File,
    ) {
        val seenEntries = mutableSetOf<String>()
        DataInputStream(translated.toByteArray().inputStream()).use { input ->
            ZipOutputStream(jarFile.outputStream().buffered()).use { output ->
                while (input.available() > 0) {
                    val nameLength = input.readInt()
                    require(nameLength in 1..1_048_576) {
                        "Invalid translated class name length: $nameLength"
                    }
                    val name = input.readNBytes(nameLength).toString(Charsets.UTF_8)
                    val classLength = input.readInt()
                    require(classLength in 1..translated.size()) {
                        "Invalid translated class size for $name: $classLength"
                    }
                    val classBytes = input.readNBytes(classLength)
                    require(classBytes.size == classLength) {
                        "Incomplete translated class data for $name"
                    }

                    val entryName = "$name.class"
                    if (!seenEntries.add(entryName)) continue
                    output.putNextEntry(ZipEntry(entryName))
                    output.write(classBytes)
                    output.closeEntry()
                }
            }
        }
    }

    /** A modified version of `xyz.nulldev.androidcompat.pm.InstalledPackage.info` */
    fun getPackageInfo(apkFilePath: String): PackageInfo {
        val apk = File(apkFilePath)
        return ApkParsers.getMetaInfo(apk).toPackageInfo(apk).apply {
            ApkFile(apk).use { parsed ->
                logger.trace { parsed.manifestXml }

                applicationInfo.metaData =
                    Bundle().apply {
                        manifestMetadata(parsed.manifestXml).forEach { (name, value) ->
                            putString(name, value)
                        }
                    }

                signatures =
                    (
                        parsed.apkSingers.flatMap { it.certificateMetas }
                        // + parsed.apkV2Singers.flatMap { it.certificateMetas }
                    ) // Blocked by: https://github.com/hsiafan/apk-parser/issues/72
                        .map { Signature(it.data) }
                        .toTypedArray()
            }
        }
    }

    private fun manifestMetadata(manifestXml: String): Map<String, String> {
        val metadata = linkedMapOf<String, String>()
        val attributePattern =
            Regex("""(?:android:)?(name|value)\s*=\s*(["'])(.*?)\2""")

        Regex("""<meta-data\b[^>]*>""")
            .findAll(manifestXml)
            .forEach { tag ->
                val attributes =
                    attributePattern
                        .findAll(tag.value)
                        .associate { match ->
                            match.groupValues[1] to decodeXmlAttribute(match.groupValues[3])
                        }
                val name = attributes["name"] ?: return@forEach
                val value = attributes["value"] ?: return@forEach
                metadata[name] = value
            }
        return metadata
    }

    private fun decodeXmlAttribute(value: String): String =
        value
            .replace("&quot;", "\"")
            .replace("&apos;", "'")
            .replace("&lt;", "<")
            .replace("&gt;", ">")
            .replace("&amp;", "&")

    data class LoadedSource(
        val instance: Any,
        val classLoader: URLClassLoader,
    )

    /**
     * loads the extension main class called [className] from the jar located at [jarPath]
     * It may return an instance of HttpSource or SourceFactory depending on the extension.
     */
    fun loadExtensionSources(
        jarFile: File,
        className: String,
        apkFile: File? = null,
    ): LoadedSource {
        val urls = mutableListOf(jarFile.toURI().toURL())
        apkFile?.let { urls.add(it.toURI().toURL()) } // Add APK for resources
        val classLoader = URLClassLoader(urls.toTypedArray(), PackageTools::class.java.classLoader)
        try {
            val classToLoad = Class.forName(className, false, classLoader)
            return LoadedSource(
                instance = classToLoad.getDeclaredConstructor().newInstance(),
                classLoader = classLoader,
            )
        } catch (error: Throwable) {
            classLoader.close()
            throw error
        }
    }
}
