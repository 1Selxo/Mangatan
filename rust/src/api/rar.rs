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

#[cfg(not(target_arch = "wasm32"))]
mod implementation {
    use super::{RarEntry, RarEntryData};
    use std::{
        collections::HashSet,
        ffi::{CStr, CString},
        os::raw::{c_char, c_int, c_void},
        ptr,
    };

    const ARCHIVE_EOF: c_int = 1;
    const ARCHIVE_WARN: c_int = -20;
    const READ_BLOCK_SIZE: usize = 64 * 1024;

    enum ArchiveHandle {}
    enum ArchiveEntryHandle {}

    unsafe extern "C" {
        fn archive_read_new() -> *mut ArchiveHandle;
        fn archive_read_support_filter_none(archive: *mut ArchiveHandle) -> c_int;
        fn archive_read_support_format_rar(archive: *mut ArchiveHandle) -> c_int;
        fn archive_read_support_format_rar5(archive: *mut ArchiveHandle) -> c_int;
        fn archive_read_open_filename(
            archive: *mut ArchiveHandle,
            filename: *const c_char,
            block_size: usize,
        ) -> c_int;
        #[cfg(target_os = "windows")]
        fn archive_read_open_filename_w(
            archive: *mut ArchiveHandle,
            filename: *const u16,
            block_size: usize,
        ) -> c_int;
        fn archive_read_next_header(
            archive: *mut ArchiveHandle,
            entry: *mut *mut ArchiveEntryHandle,
        ) -> c_int;
        fn archive_read_data(
            archive: *mut ArchiveHandle,
            buffer: *mut c_void,
            size: usize,
        ) -> isize;
        fn archive_read_data_skip(archive: *mut ArchiveHandle) -> c_int;
        fn archive_read_free(archive: *mut ArchiveHandle) -> c_int;
        fn archive_error_string(archive: *mut ArchiveHandle) -> *const c_char;
        fn archive_entry_pathname(entry: *mut ArchiveEntryHandle) -> *const c_char;
        fn archive_entry_pathname_utf8(entry: *mut ArchiveEntryHandle) -> *const c_char;
        fn mangatan_libarchive_entry_is_regular(entry: *mut ArchiveEntryHandle) -> c_int;
    }

    struct ArchiveReader(*mut ArchiveHandle);

    impl ArchiveReader {
        fn open(path: &str) -> Result<Self, String> {
            validate_path(path, "archive path")?;

            // SAFETY: libarchive returns an owned handle that is released by Drop.
            let handle = unsafe { archive_read_new() };
            if handle.is_null() {
                return Err("Failed to allocate a libarchive reader".to_owned());
            }
            let reader = Self(handle);

            // RAR data is self-contained, so no external compression filters or
            // helper programs need to be enabled.
            reader.check(
                unsafe { archive_read_support_filter_none(handle) },
                "Failed to enable the unfiltered archive reader",
            )?;
            reader.check(
                unsafe { archive_read_support_format_rar(handle) },
                "Failed to enable RAR support",
            )?;
            reader.check(
                unsafe { archive_read_support_format_rar5(handle) },
                "Failed to enable RAR5 support",
            )?;
            reader.open_path(path)?;

            Ok(reader)
        }

        #[cfg(target_os = "windows")]
        fn open_path(&self, path: &str) -> Result<(), String> {
            let mut path = path.encode_utf16().collect::<Vec<_>>();
            path.push(0);
            // SAFETY: the UTF-16 path is null-terminated and remains alive for
            // the duration of the call. The handle is valid while self exists.
            self.check(
                unsafe { archive_read_open_filename_w(self.0, path.as_ptr(), READ_BLOCK_SIZE) },
                "Failed to open RAR archive",
            )
        }

        #[cfg(not(target_os = "windows"))]
        fn open_path(&self, path: &str) -> Result<(), String> {
            let path = CString::new(path)
                .map_err(|_| "Invalid archive path: contains a null character".to_owned())?;
            // SAFETY: the path is null-terminated and remains alive for the
            // duration of the call. The handle is valid while self exists.
            self.check(
                unsafe { archive_read_open_filename(self.0, path.as_ptr(), READ_BLOCK_SIZE) },
                "Failed to open RAR archive",
            )
        }

        fn next_header(&self) -> Result<Option<*mut ArchiveEntryHandle>, String> {
            let mut entry = ptr::null_mut();
            // SAFETY: libarchive owns the returned entry and keeps it valid until
            // the next header is read from this live reader.
            let status = unsafe { archive_read_next_header(self.0, &mut entry) };
            if status == ARCHIVE_EOF {
                return Ok(None);
            }
            self.check(status, "Failed to read RAR archive header")?;
            if entry.is_null() {
                return Err("libarchive returned an empty RAR archive header".to_owned());
            }
            Ok(Some(entry))
        }

        fn skip_data(&self, name: &str) -> Result<(), String> {
            // SAFETY: self owns a valid reader positioned at the current entry.
            self.check(
                unsafe { archive_read_data_skip(self.0) },
                &format!("Failed to skip RAR entry {name}"),
            )
        }

        fn read_data(&self, name: &str) -> Result<Vec<u8>, String> {
            let mut content = Vec::new();
            let mut buffer = [0_u8; READ_BLOCK_SIZE];
            loop {
                // SAFETY: buffer is writable for its full length and self owns a
                // valid reader positioned at the current entry.
                let read = unsafe {
                    archive_read_data(self.0, buffer.as_mut_ptr().cast::<c_void>(), buffer.len())
                };
                if read == 0 {
                    return Ok(content);
                }
                if read < 0 {
                    return Err(self.error(&format!("Failed to extract RAR entry {name}")));
                }
                content.extend_from_slice(&buffer[..read as usize]);
            }
        }

        fn check(&self, status: c_int, context: &str) -> Result<(), String> {
            if status < ARCHIVE_WARN {
                Err(self.error(context))
            } else {
                Ok(())
            }
        }

        fn error(&self, context: &str) -> String {
            // SAFETY: the returned message belongs to this live reader and is
            // either null or a null-terminated string.
            let detail = unsafe {
                let message = archive_error_string(self.0);
                (!message.is_null()).then(|| CStr::from_ptr(message).to_string_lossy())
            };
            match detail {
                Some(detail) if !detail.is_empty() => format!("{context}: {detail}"),
                _ => context.to_owned(),
            }
        }
    }

    impl Drop for ArchiveReader {
        fn drop(&mut self) {
            // SAFETY: this is the unique owned reader handle and it is released
            // exactly once here.
            unsafe {
                archive_read_free(self.0);
            }
        }
    }

    pub(super) fn list_rar_entries(archive_path: String) -> Result<Vec<RarEntry>, String> {
        let reader = ArchiveReader::open(&archive_path)?;
        let mut entries = Vec::new();

        while let Some(entry) = reader.next_header()? {
            let name = entry_name(entry)?;
            entries.push(RarEntry {
                name: name.clone(),
                is_file: is_regular_file(entry),
            });
            reader.skip_data(&name)?;
        }

        Ok(entries)
    }

    pub(super) fn extract_rar_entries(
        archive_path: String,
        entry_names: Vec<String>,
    ) -> Result<Vec<RarEntryData>, String> {
        for entry_name in &entry_names {
            validate_path(entry_name, "RAR entry name")?;
        }

        let mut remaining = entry_names.into_iter().collect::<HashSet<_>>();
        if remaining.is_empty() {
            return Ok(Vec::new());
        }

        let reader = ArchiveReader::open(&archive_path)?;
        let mut extracted = Vec::new();
        while let Some(entry) = reader.next_header()? {
            let name = entry_name(entry)?;
            if is_regular_file(entry) && remaining.remove(&name) {
                extracted.push(RarEntryData {
                    content: reader.read_data(&name)?,
                    name,
                });
            } else {
                reader.skip_data(&name)?;
            }
        }

        if !remaining.is_empty() {
            let mut missing = remaining.into_iter().collect::<Vec<_>>();
            missing.sort_unstable();
            return Err(format!(
                "RAR archive did not contain the requested entries: {}",
                missing.join(", ")
            ));
        }

        Ok(extracted)
    }

    fn entry_name(entry: *mut ArchiveEntryHandle) -> Result<String, String> {
        // SAFETY: entry belongs to the active reader and both accessors return
        // strings owned by that reader. The fallback preserves legacy names
        // when UTF-8 conversion is unavailable.
        let name = unsafe {
            let utf8 = archive_entry_pathname_utf8(entry);
            let raw = if utf8.is_null() {
                archive_entry_pathname(entry)
            } else {
                utf8
            };
            if raw.is_null() {
                return Err("RAR archive entry has no pathname".to_owned());
            }
            CStr::from_ptr(raw).to_string_lossy().into_owned()
        };
        Ok(name)
    }

    fn is_regular_file(entry: *mut ArchiveEntryHandle) -> bool {
        // SAFETY: entry belongs to the active reader. The small C bridge
        // normalizes platform-specific mode_t widths to an int result.
        unsafe { mangatan_libarchive_entry_is_regular(entry) != 0 }
    }

    fn validate_path(value: &str, label: &str) -> Result<(), String> {
        if value.contains('\0') {
            Err(format!("Invalid {label}: contains a null character"))
        } else {
            Ok(())
        }
    }
}

#[cfg(target_arch = "wasm32")]
mod implementation {
    use super::{RarEntry, RarEntryData};

    const UNSUPPORTED_MESSAGE: &str = "RAR archives are not supported in web builds";

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

#[cfg(all(test, not(target_arch = "wasm32")))]
mod tests {
    use super::{extract_rar_entries, list_rar_entries};
    use base64::Engine;
    use std::fs;

    #[test]
    fn lists_and_extracts_rar5_comic_images() {
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
            path_string.clone(),
            vec!["cover.png".to_owned(), "2.png".to_owned()],
        )
        .expect("selected images should extract");
        assert_eq!(extracted.len(), 2);
        assert!(extracted
            .iter()
            .all(|entry| entry.content.starts_with(b"\x89PNG\r\n\x1a\n")));

        let error = extract_rar_entries(path_string, vec!["missing.png".to_owned()])
            .expect_err("missing entries should be reported");
        assert!(error.contains("missing.png"));

        fs::remove_file(path).expect("fixture should be removable");
    }
}
