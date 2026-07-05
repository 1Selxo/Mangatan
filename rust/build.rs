use std::{env, path::PathBuf};

fn main() {
    println!("cargo:rerun-if-changed=../third_party/hoshidicts");
    println!("cargo:rerun-if-changed=native/hoshidicts_bridge");

    if env::var("CARGO_CFG_TARGET_ARCH").as_deref() == Ok("wasm32") {
        return;
    }

    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let project_root = manifest_dir
        .parent()
        .expect("rust crate should live below project root");
    let bridge_dir = manifest_dir.join("native").join("hoshidicts_bridge");

    let dst = cmake::Config::new(&bridge_dir)
        .define("MANGAYOMI_PROJECT_ROOT", project_root)
        .define("CMAKE_POSITION_INDEPENDENT_CODE", "ON")
        .build();

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
