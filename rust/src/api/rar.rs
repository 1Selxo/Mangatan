#[derive(Debug, Clone)]
pub struct RarEntry {
    pub name: String,
    pub is_file: bool,
}

#[derive(Debug, Clone)]
pub struct RarEntryData {
    pub name: String,
    pub content: Vec<u8>,
}

pub fn list_rar_entries(archive_path: String) -> Result<Vec<RarEntry>, String> {
    implementation::list_rar_entries(archive_path)
}

pub fn extract_rar_entries(
    archive_path: String,
    entry_names: Vec<String>,
) -> Result<Vec<RarEntryData>, String> {
    implementation::extract_rar_entries(archive_path, entry_names)
}

#[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
mod implementation {
    use super::{RarEntry, RarEntryData};
    use std::collections::HashSet;
    use unrar::Archive;

    pub(super) fn list_rar_entries(archive_path: String) -> Result<Vec<RarEntry>, String> {
        validate_path(&archive_path, "archive path")?;
        let archive = Archive::new(&archive_path)
            .open_for_listing()
            .map_err(|error| format!("Failed to open RAR archive: {error}"))?;

        archive
            .map(|entry| {
                let entry =
                    entry.map_err(|error| format!("Failed to read RAR archive header: {error}"))?;
                Ok(RarEntry {
                    name: entry.filename.to_string_lossy().into_owned(),
                    is_file: entry.is_file(),
                })
            })
            .collect()
    }

    pub(super) fn extract_rar_entries(
        archive_path: String,
        entry_names: Vec<String>,
    ) -> Result<Vec<RarEntryData>, String> {
        validate_path(&archive_path, "archive path")?;
        for entry_name in &entry_names {
            validate_path(entry_name, "RAR entry name")?;
        }

        let requested = entry_names
            .iter()
            .map(String::as_str)
            .collect::<HashSet<_>>();
        if requested.is_empty() {
            return Ok(Vec::new());
        }

        let mut archive = Archive::new(&archive_path)
            .open_for_processing()
            .map_err(|error| format!("Failed to open RAR archive: {error}"))?;
        let mut extracted = Vec::new();
        let mut found = HashSet::new();

        while let Some(header) = archive
            .read_header()
            .map_err(|error| format!("Failed to read RAR archive header: {error}"))?
        {
            let name = header.entry().filename.to_string_lossy().into_owned();
            let should_read = header.entry().is_file() && requested.contains(name.as_str());
            if should_read {
                let (content, remaining_archive) = header
                    .read()
                    .map_err(|error| format!("Failed to extract RAR entry {name}: {error}"))?;
                found.insert(name.clone());
                extracted.push(RarEntryData { name, content });
                archive = remaining_archive;
            } else {
                archive = header
                    .skip()
                    .map_err(|error| format!("Failed to skip RAR entry {name}: {error}"))?;
            }
        }

        let mut missing = requested
            .into_iter()
            .filter(|name| !found.contains(*name))
            .collect::<Vec<_>>();
        if !missing.is_empty() {
            missing.sort_unstable();
            return Err(format!(
                "RAR archive did not contain the requested entries: {}",
                missing.join(", ")
            ));
        }

        Ok(extracted)
    }

    fn validate_path(value: &str, label: &str) -> Result<(), String> {
        if value.contains('\0') {
            Err(format!("Invalid {label}: contains a null character"))
        } else {
            Ok(())
        }
    }
}

#[cfg(not(any(target_os = "linux", target_os = "macos", target_os = "windows")))]
mod implementation {
    use super::{RarEntry, RarEntryData};

    const UNSUPPORTED_MESSAGE: &str = "RAR archives are supported on desktop platforms only";

    pub(super) fn list_rar_entries(_archive_path: String) -> Result<Vec<RarEntry>, String> {
        Err(UNSUPPORTED_MESSAGE.to_owned())
    }

    pub(super) fn extract_rar_entries(
        _archive_path: String,
        _entry_names: Vec<String>,
    ) -> Result<Vec<RarEntryData>, String> {
        Err(UNSUPPORTED_MESSAGE.to_owned())
    }
}

#[cfg(all(
    test,
    any(target_os = "linux", target_os = "macos", target_os = "windows")
))]
mod tests {
    use super::{extract_rar_entries, list_rar_entries};
    use base64::Engine;
    use std::fs;

    #[test]
    fn lists_and_extracts_comic_images() {
        let path =
            std::env::temp_dir().join(format!("mangatan-rar-test-{}.cbr", std::process::id()));
        let bytes = base64::engine::general_purpose::STANDARD
            .decode(include_str!("../../test_data/manga.cbr.base64").trim())
            .expect("fixture base64 should decode");
        fs::write(&path, bytes).expect("fixture should be writable");

        let path_string = path.to_string_lossy().into_owned();
        let entries = list_rar_entries(path_string.clone()).expect("fixture should list");
        assert_eq!(
            entries
                .iter()
                .filter(|entry| entry.is_file)
                .map(|entry| entry.name.as_str())
                .collect::<Vec<_>>(),
            ["2.png", "10.png", "cover.png"]
        );

        let extracted = extract_rar_entries(
            path_string,
            vec!["cover.png".to_owned(), "2.png".to_owned()],
        )
        .expect("selected images should extract");
        assert_eq!(extracted.len(), 2);
        assert!(extracted
            .iter()
            .all(|entry| entry.content.starts_with(b"\x89PNG\r\n\x1a\n")));

        fs::remove_file(path).expect("fixture should be removable");
    }
}
