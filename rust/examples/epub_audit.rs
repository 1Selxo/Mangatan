#[path = "../src/api/epub.rs"]
mod epub;

use std::collections::HashSet;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

fn main() {
    let root = env::args().nth(1).unwrap_or_else(|| ".".to_owned());
    let mut files = Vec::new();
    collect_epubs(Path::new(&root), &mut files);
    files.sort();

    println!("Auditing {} EPUB files under {}", files.len(), root);
    let mut failures = 0usize;
    let mut warnings = 0usize;

    for path in files {
        match epub::parse_epub_from_path(path.to_string_lossy().into_owned(), true) {
            Ok(book) => {
                let mut issues = Vec::new();
                if book.chapters.is_empty() {
                    issues.push("no renderable spine chapters".to_owned());
                }
                let mut paths = HashSet::new();
                let mut hrefs = HashSet::new();
                let mut text_chars = 0usize;
                let mut replacement_chars = 0usize;
                let mut navigation_labels = Vec::new();
                for chapter in &book.chapters {
                    if chapter.path.trim().is_empty() {
                        issues.push(format!("chapter {:?} has no manifest id", chapter.name));
                    }
                    if chapter.href.trim().is_empty() {
                        issues.push(format!("chapter {:?} has no canonical href", chapter.name));
                    }
                    if !paths.insert(chapter.path.to_owned()) {
                        issues.push(format!("duplicate manifest id {:?}", chapter.path));
                    }
                    if !hrefs.insert(chapter.href.to_lowercase()) {
                        issues.push(format!("duplicate canonical href {:?}", chapter.href));
                    }
                    text_chars += chapter.content.chars().count();
                    replacement_chars += chapter.content.matches('\u{fffd}').count();
                    if chapter.is_navigation_entry {
                        navigation_labels.push(chapter.name.clone());
                    }
                }
                if replacement_chars > 0 {
                    issues.push(format!(
                        "{replacement_chars} replacement characters after decoding"
                    ));
                }

                if issues.is_empty() {
                    println!(
                        "OK\t{}\tspine={} navigation={} images={} css_fonts={} chars={} labels={:?}",
                        path.display(),
                        book.chapters.len(),
                        navigation_labels.len(),
                        book.images.len(),
                        book.stylesheets.len(),
                        text_chars,
                        navigation_labels,
                    );
                } else {
                    warnings += 1;
                    println!("WARN\t{}\t{}", path.display(), issues.join("; "));
                }
            }
            Err(error) => {
                failures += 1;
                println!("FAIL\t{}\t{}", path.display(), error);
            }
        }
    }

    println!("SUMMARY failures={failures} warnings={warnings}");
    if failures > 0 {
        std::process::exit(1);
    }
}

fn collect_epubs(path: &Path, output: &mut Vec<PathBuf>) {
    if path.is_file() {
        if path
            .extension()
            .and_then(|extension| extension.to_str())
            .is_some_and(|extension| extension.eq_ignore_ascii_case("epub"))
        {
            output.push(path.to_path_buf());
        }
        return;
    }

    let Ok(entries) = fs::read_dir(path) else {
        return;
    };
    for entry in entries.flatten() {
        collect_epubs(&entry.path(), output);
    }
}
