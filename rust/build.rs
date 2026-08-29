use std::{env, path::PathBuf};

fn main() {
    println!("cargo:rerun-if-changed=../third_party/hoshidicts");
    println!("cargo:rerun-if-changed=../third_party/libarchive");
    println!("cargo:rerun-if-changed=native/hoshidicts_bridge");
    println!("cargo:rerun-if-changed=native/libarchive_bridge.c");

    if env::var("CARGO_CFG_TARGET_ARCH").as_deref() == Ok("wasm32") {
        return;
    }

    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let project_root = manifest_dir
        .parent()
        .expect("rust crate should live below project root");

    build_libarchive(project_root);

    let bridge_dir = manifest_dir.join("native").join("hoshidicts_bridge");

    let mut config = cmake::Config::new(&bridge_dir);
    config
        .define("MANGAYOMI_PROJECT_ROOT", project_root)
        .define("CMAKE_POSITION_INDEPENDENT_CODE", "ON");

    if env::var("CARGO_CFG_TARGET_ENV").as_deref() == Ok("msvc") {
        config.define("CMAKE_MSVC_RUNTIME_LIBRARY", "MultiThreadedDLL");
    }

    let dst = config.build();

    println!(
        "cargo:rustc-link-search=native={}",
        dst.join("lib").display()
    );
    println!("cargo:rustc-link-lib=static=hoshidicts_bridge");
    println!("cargo:rustc-link-lib=static=hoshidicts");

    match env::var("CARGO_CFG_TARGET_OS").as_deref() {
        Ok("windows") => {
            println!("cargo:rustc-link-lib=static=zstd_static");
            println!("cargo:rustc-link-lib=static=deflatestatic");
            println!("cargo:rustc-link-lib=static=utf8proc_static");
        }
        Ok("macos") | Ok("ios") => {
            println!("cargo:rustc-link-lib=static=zstd");
            println!("cargo:rustc-link-lib=static=deflate");
            println!("cargo:rustc-link-lib=static=utf8proc");
            println!("cargo:rustc-link-lib=c++");
        }
        _ => {
            println!("cargo:rustc-link-lib=static=zstd");
            println!("cargo:rustc-link-lib=static=deflate");
            println!("cargo:rustc-link-lib=static=utf8proc");
            println!("cargo:rustc-link-lib=stdc++");
        }
    }
}

fn build_libarchive(project_root: &std::path::Path) {
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap()).join("libarchive");
    let source_dir = project_root.join("third_party").join("libarchive");
    let mut config = cmake::Config::new(&source_dir);
    config
        .out_dir(&out_dir)
        .build_target("archive_static")
        .define("BUILD_SHARED_LIBS", "OFF")
        .define("CMAKE_POSITION_INDEPENDENT_CODE", "ON")
        .define("ENABLE_INSTALL", "OFF")
        .define("ENABLE_TEST", "OFF")
        .define("ENABLE_TAR", "OFF")
        .define("ENABLE_CPIO", "OFF")
        .define("ENABLE_CAT", "OFF")
        .define("ENABLE_UNZIP", "OFF")
        .define("ENABLE_WERROR", "OFF")
        .define("ENABLE_ACL", "OFF")
        .define("ENABLE_XATTR", "OFF")
        .define("ENABLE_ICONV", "OFF")
        .define("ENABLE_LIBXML2", "OFF")
        .define("ENABLE_EXPAT", "OFF")
        .define("ENABLE_WIN32_XMLLITE", "OFF")
        .define("ENABLE_MBEDTLS", "OFF")
        .define("ENABLE_NETTLE", "OFF")
        .define("ENABLE_OPENSSL", "OFF")
        .define("ENABLE_LIBB2", "OFF")
        .define("ENABLE_LZ4", "OFF")
        .define("ENABLE_LZO", "OFF")
        .define("ENABLE_LZMA", "OFF")
        .define("ENABLE_ZSTD", "OFF")
        .define("ENABLE_ZLIB", "OFF")
        .define("ENABLE_BZip2", "OFF")
        .define("ENABLE_PCREPOSIX", "OFF")
        .define("ENABLE_PCRE2POSIX", "OFF")
        .define("ENABLE_LIBGCC", "OFF")
        .define("ENABLE_CNG", "OFF");

    if env::var("CARGO_CFG_TARGET_ENV").as_deref() == Ok("msvc") {
        config
            .define("CMAKE_MSVC_RUNTIME_LIBRARY", "MultiThreadedDLL")
            // Windows has no libc POSIX regex implementation. Selecting LIBC
            // explicitly prevents libarchive from falling through to its
            // disabled libgcc/PCRE fallback; RAR support does not use regex.
            .define("POSIX_REGEX_LIB", "LIBC");
    }

    config.build();

    cc::Build::new()
        .file(project_root.join("rust/native/libarchive_bridge.c"))
        .include(source_dir.join("libarchive"))
        .define("LIBARCHIVE_STATIC", None)
        .compile("mangatan_libarchive_bridge");

    let build_dir = out_dir.join("build").join("libarchive");
    println!("cargo:rustc-link-search=native={}", build_dir.display());
    if env::var("CARGO_CFG_TARGET_ENV").as_deref() == Ok("msvc") {
        println!(
            "cargo:rustc-link-search=native={}",
            build_dir.join("Release").display()
        );
        println!(
            "cargo:rustc-link-search=native={}",
            build_dir.join("Debug").display()
        );
    }
    println!("cargo:rustc-link-lib=static=archive");
}
