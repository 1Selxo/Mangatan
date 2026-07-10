use serde::Deserialize;

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HoshiImportResult {
    pub success: bool,
    pub title: String,
    pub term_count: u64,
    pub meta_count: u64,
    pub freq_count: u64,
    pub pitch_count: u64,
    pub media_count: u64,
    pub errors: Vec<String>,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HoshiDictionaryStyle {
    pub dict_name: String,
    pub styles: String,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HoshiFrequency {
    pub value: i32,
    pub display_value: String,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HoshiGlossaryEntry {
    pub dict_name: String,
    pub glossary: String,
    pub definition_tags: String,
    pub term_tags: String,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HoshiFrequencyEntry {
    pub dict_name: String,
    pub frequencies: Vec<HoshiFrequency>,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HoshiPitchEntry {
    pub dict_name: String,
    pub pitch_positions: Vec<i32>,
    pub transcriptions: Vec<String>,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HoshiTermResult {
    pub expression: String,
    pub reading: String,
    pub rules: String,
    pub score: i32,
    pub glossaries: Vec<HoshiGlossaryEntry>,
    pub frequencies: Vec<HoshiFrequencyEntry>,
    pub pitches: Vec<HoshiPitchEntry>,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HoshiTransformGroup {
    pub name: String,
    pub description: String,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HoshiLookupResult {
    pub matched: String,
    pub deinflected: String,
    pub trace: Vec<HoshiTransformGroup>,
    pub preprocessor_steps: i32,
    pub term: HoshiTermResult,
}

#[cfg(not(target_arch = "wasm32"))]
pub(crate) mod native {
    use super::*;
    use flutter_rust_bridge::frb;
    use serde::Deserialize;
    use std::ffi::{c_char, c_uchar, c_void, CStr, CString};
    use std::ptr;
    use std::sync::Mutex;

    #[repr(C)]
    struct HoshiBytes {
        data: *mut c_uchar,
        len: usize,
    }

    #[derive(Debug, Deserialize)]
    #[serde(rename_all = "camelCase")]
    struct OperationResult {
        success: bool,
        error: Option<String>,
    }

    #[derive(Debug, Deserialize)]
    struct LookupResponse {
        results: Vec<HoshiLookupResult>,
    }

    #[derive(Debug, Deserialize)]
    struct StylesResponse {
        styles: Vec<HoshiDictionaryStyle>,
    }

    unsafe extern "C" {
        fn hoshidicts_import_dictionary_json(
            zip_path: *const c_char,
            output_dir: *const c_char,
            low_ram: bool,
        ) -> *mut c_char;
        fn hoshidicts_create_lookup_session() -> *mut c_void;
        fn hoshidicts_destroy_lookup_session(session: *mut c_void);
        fn hoshidicts_rebuild_query_json(
            session: *mut c_void,
            term_paths: *const *const c_char,
            term_count: usize,
            freq_paths: *const *const c_char,
            freq_count: usize,
            pitch_paths: *const *const c_char,
            pitch_count: usize,
        ) -> *mut c_char;
        fn hoshidicts_lookup_json(
            session: *mut c_void,
            text: *const c_char,
            max_results: i32,
            scan_length: usize,
        ) -> *mut c_char;
        fn hoshidicts_styles_json(session: *mut c_void) -> *mut c_char;
        fn hoshidicts_get_media_file(
            session: *mut c_void,
            dict_name: *const c_char,
            media_path: *const c_char,
        ) -> HoshiBytes;
        fn hoshidicts_free_string(value: *mut c_char);
        fn hoshidicts_free_bytes(value: HoshiBytes);
    }

    #[frb(opaque)]
    pub struct HoshiLookupSession {
        handle: *mut c_void,
        lock: Mutex<()>,
    }

    unsafe impl Send for HoshiLookupSession {}
    unsafe impl Sync for HoshiLookupSession {}

    impl Drop for HoshiLookupSession {
        fn drop(&mut self) {
            if !self.handle.is_null() {
                unsafe { hoshidicts_destroy_lookup_session(self.handle) };
                self.handle = ptr::null_mut();
            }
        }
    }

    pub fn import_dictionary(
        zip_path: String,
        output_dir: String,
        low_ram: bool,
    ) -> Result<HoshiImportResult, String> {
        let zip_path = cstring(zip_path)?;
        let output_dir = cstring(output_dir)?;
        let json = unsafe {
            take_string(hoshidicts_import_dictionary_json(
                zip_path.as_ptr(),
                output_dir.as_ptr(),
                low_ram,
            ))?
        };
        serde_json::from_str(&json).map_err(|error| error.to_string())
    }

    pub fn create_lookup_session() -> Result<HoshiLookupSession, String> {
        let handle = unsafe { hoshidicts_create_lookup_session() };
        if handle.is_null() {
            return Err("Failed to create Hoshidicts lookup session".to_string());
        }

        Ok(HoshiLookupSession {
            handle,
            lock: Mutex::new(()),
        })
    }

    pub fn rebuild_query(
        session: &HoshiLookupSession,
        term_paths: Vec<String>,
        freq_paths: Vec<String>,
        pitch_paths: Vec<String>,
    ) -> Result<(), String> {
        let _guard = session.lock.lock().map_err(|error| error.to_string())?;
        let term_paths = CStringList::new(term_paths)?;
        let freq_paths = CStringList::new(freq_paths)?;
        let pitch_paths = CStringList::new(pitch_paths)?;

        let json = unsafe {
            take_string(hoshidicts_rebuild_query_json(
                session.handle,
                term_paths.as_ptr(),
                term_paths.len(),
                freq_paths.as_ptr(),
                freq_paths.len(),
                pitch_paths.as_ptr(),
                pitch_paths.len(),
            ))?
        };
        let result: OperationResult =
            serde_json::from_str(&json).map_err(|error| error.to_string())?;
        if result.success {
            Ok(())
        } else {
            Err(result
                .error
                .unwrap_or_else(|| "Failed to rebuild query".to_string()))
        }
    }

    pub fn lookup(
        session: &HoshiLookupSession,
        text: String,
        max_results: i32,
        scan_length: u64,
    ) -> Result<Vec<HoshiLookupResult>, String> {
        let _guard = session.lock.lock().map_err(|error| error.to_string())?;
        let text = cstring(text)?;
        let json = unsafe {
            take_string(hoshidicts_lookup_json(
                session.handle,
                text.as_ptr(),
                max_results,
                scan_length as usize,
            ))?
        };
        let response: LookupResponse = parse_response(&json)?;
        Ok(response.results)
    }

    pub fn get_styles(session: &HoshiLookupSession) -> Result<Vec<HoshiDictionaryStyle>, String> {
        let _guard = session.lock.lock().map_err(|error| error.to_string())?;
        let json = unsafe { take_string(hoshidicts_styles_json(session.handle))? };
        let response: StylesResponse = parse_response(&json)?;
        Ok(response.styles)
    }

    pub fn get_media_file(
        session: &HoshiLookupSession,
        dict_name: String,
        media_path: String,
    ) -> Result<Option<Vec<u8>>, String> {
        let _guard = session.lock.lock().map_err(|error| error.to_string())?;
        let dict_name = cstring(dict_name)?;
        let media_path = cstring(media_path)?;
        let bytes = unsafe {
            hoshidicts_get_media_file(session.handle, dict_name.as_ptr(), media_path.as_ptr())
        };
        if bytes.data.is_null() || bytes.len == 0 {
            return Ok(None);
        }

        let data = unsafe { std::slice::from_raw_parts(bytes.data, bytes.len).to_vec() };
        unsafe { hoshidicts_free_bytes(bytes) };
        Ok(Some(data))
    }

    fn cstring(value: String) -> Result<CString, String> {
        CString::new(value).map_err(|error| error.to_string())
    }

    fn parse_response<T>(json: &str) -> Result<T, String>
    where
        T: for<'de> Deserialize<'de>,
    {
        serde_json::from_str(json).or_else(|parse_error| {
            match serde_json::from_str::<OperationResult>(json) {
                Ok(result) if !result.success => Err(result
                    .error
                    .unwrap_or_else(|| "Hoshidicts call failed".to_string())),
                _ => Err(parse_error.to_string()),
            }
        })
    }

    unsafe fn take_string(ptr: *mut c_char) -> Result<String, String> {
        if ptr.is_null() {
            return Err("Hoshidicts returned a null response".to_string());
        }
        let value = CStr::from_ptr(ptr).to_string_lossy().into_owned();
        hoshidicts_free_string(ptr);
        Ok(value)
    }

    struct CStringList {
        _items: Vec<CString>,
        ptrs: Vec<*const c_char>,
    }

    impl CStringList {
        fn new(items: Vec<String>) -> Result<Self, String> {
            let items = items
                .into_iter()
                .map(cstring)
                .collect::<Result<Vec<_>, _>>()?;
            let ptrs = items.iter().map(|item| item.as_ptr()).collect();
            Ok(Self {
                _items: items,
                ptrs,
            })
        }

        fn as_ptr(&self) -> *const *const c_char {
            if self.ptrs.is_empty() {
                ptr::null()
            } else {
                self.ptrs.as_ptr()
            }
        }

        fn len(&self) -> usize {
            self.ptrs.len()
        }
    }
}

#[cfg(not(target_arch = "wasm32"))]
pub use native::{
    create_lookup_session as hoshidicts_create_lookup_session,
    get_media_file as hoshidicts_get_media_file, get_styles as hoshidicts_get_styles,
    import_dictionary as hoshidicts_import_dictionary, lookup as hoshidicts_lookup,
    rebuild_query as hoshidicts_rebuild_query, HoshiLookupSession,
};

#[cfg(all(test, not(target_arch = "wasm32")))]
mod tests {
    use super::{
        hoshidicts_create_lookup_session, hoshidicts_import_dictionary, hoshidicts_lookup,
        hoshidicts_rebuild_query,
    };
    use std::{env, fs, path::PathBuf, process};

    /// Imports large, locally supplied dictionaries without checking them into
    /// the repository. Separate paths with `|` in HOSHIDICTS_TEST_ZIPS.
    #[test]
    #[ignore = "requires dictionaries supplied through HOSHIDICTS_TEST_ZIPS"]
    fn imports_external_yomitan_dictionaries() {
        let zip_paths = env::var("HOSHIDICTS_TEST_ZIPS")
            .expect("HOSHIDICTS_TEST_ZIPS must contain one or more ZIP paths");
        let output_dir: PathBuf =
            env::temp_dir().join(format!("mangatan-hoshidicts-test-{}", process::id()));
        fs::create_dir_all(&output_dir).expect("failed to create test output directory");
        let mut term_paths = Vec::new();
        let mut frequency_paths = Vec::new();
        let mut pitch_paths = Vec::new();

        for zip_path in zip_paths.split('|').filter(|path| !path.is_empty()) {
            let result = hoshidicts_import_dictionary(
                zip_path.to_owned(),
                output_dir.to_string_lossy().into_owned(),
                true,
            )
            .unwrap_or_else(|error| panic!("failed to call importer for {zip_path}: {error}"));

            assert!(
                result.success,
                "failed to import {zip_path}: {}",
                result.errors.join("; ")
            );
            assert!(
                result.term_count + result.meta_count > 0,
                "imported {zip_path} without any dictionary entries"
            );
            println!(
                "imported {zip_path} as {} (terms: {}, metadata: {}, frequencies: {}, pitches: {}, media: {})",
                result.title,
                result.term_count,
                result.meta_count,
                result.freq_count,
                result.pitch_count,
                result.media_count
            );

            let dictionary_path = output_dir
                .join(&result.title)
                .to_string_lossy()
                .into_owned();
            if result.term_count > 0 {
                term_paths.push(dictionary_path.clone());
            }
            if result.freq_count > 0 {
                frequency_paths.push(dictionary_path.clone());
            }
            if result.pitch_count > 0 {
                pitch_paths.push(dictionary_path);
            }
        }

        let session = hoshidicts_create_lookup_session().expect("failed to create lookup session");
        hoshidicts_rebuild_query(&session, term_paths, frequency_paths, pitch_paths)
            .expect("failed to load imported dictionaries");
        let results = hoshidicts_lookup(&session, "日本".to_owned(), 16, 16)
            .expect("lookup failed after importing dictionaries");
        assert!(!results.is_empty(), "term dictionary was not loaded");
        let frequency_results = hoshidicts_lookup(&session, "の".to_owned(), 16, 16)
            .expect("frequency lookup failed after importing dictionaries");
        assert!(
            frequency_results
                .iter()
                .any(|result| !result.term.frequencies.is_empty()),
            "frequency dictionary was not loaded"
        );
        let pitch_results = hoshidicts_lookup(&session, "ああ".to_owned(), 16, 16)
            .expect("pitch lookup failed after importing dictionaries");
        assert!(
            pitch_results
                .iter()
                .any(|result| !result.term.pitches.is_empty()),
            "pitch dictionary was not loaded"
        );

        fs::remove_dir_all(output_dir).expect("failed to remove test output directory");
    }
}

#[cfg(target_arch = "wasm32")]
pub(crate) mod native {
    use super::*;
    use flutter_rust_bridge::frb;

    #[frb(opaque)]
    pub struct HoshiLookupSession;

    pub fn import_dictionary(
        _zip_path: String,
        _output_dir: String,
        _low_ram: bool,
    ) -> Result<HoshiImportResult, String> {
        Err(unsupported())
    }

    pub fn create_lookup_session() -> Result<HoshiLookupSession, String> {
        Err(unsupported())
    }

    pub fn rebuild_query(
        _session: &HoshiLookupSession,
        _term_paths: Vec<String>,
        _freq_paths: Vec<String>,
        _pitch_paths: Vec<String>,
    ) -> Result<(), String> {
        Err(unsupported())
    }

    pub fn lookup(
        _session: &HoshiLookupSession,
        _text: String,
        _max_results: i32,
        _scan_length: u64,
    ) -> Result<Vec<HoshiLookupResult>, String> {
        Err(unsupported())
    }

    pub fn get_styles(_session: &HoshiLookupSession) -> Result<Vec<HoshiDictionaryStyle>, String> {
        Err(unsupported())
    }

    pub fn get_media_file(
        _session: &HoshiLookupSession,
        _dict_name: String,
        _media_path: String,
    ) -> Result<Option<Vec<u8>>, String> {
        Err(unsupported())
    }

    fn unsupported() -> String {
        "Hoshidicts lookup backend is not available on web builds".to_string()
    }
}

#[cfg(target_arch = "wasm32")]
pub use native::{
    create_lookup_session as hoshidicts_create_lookup_session,
    get_media_file as hoshidicts_get_media_file, get_styles as hoshidicts_get_styles,
    import_dictionary as hoshidicts_import_dictionary, lookup as hoshidicts_lookup,
    rebuild_query as hoshidicts_rebuild_query, HoshiLookupSession,
};
