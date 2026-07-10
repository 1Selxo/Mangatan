use encoding_rs::Encoding;
use epub::doc::EpubDoc;
use std::fs;
use std::io::{Cursor, Read, Seek};
use std::path::Path;
use zip::ZipArchive;

#[derive(Debug, Clone)]
pub struct EpubChapter {
    pub name: String,
    pub content: String,
    pub path: String,
}

#[derive(Debug, Clone)]
pub struct EpubResource {
    pub name: String,
    pub content: Vec<u8>,
}

#[derive(Debug, Clone)]
pub struct EpubNovel {
    pub name: String,
    pub cover: Option<Vec<u8>>,
    pub summary: Option<String>,
    pub author: Option<String>,
    pub artist: Option<String>,
    pub chapters: Vec<EpubChapter>,
    pub images: Vec<EpubResource>,
    pub stylesheets: Vec<EpubResource>,
}

pub fn parse_epub_from_path(epub_path: String, full_data: bool) -> Result<EpubNovel, String> {
    let path = Path::new(&epub_path);

    if !path.exists() {
        return Err(format!("EPUB file not found: {}", epub_path));
    }

    // Open EPUB file
    let mut doc = EpubDoc::new(&epub_path).map_err(|e| format!("Failed to open EPUB: {}", e))?;

    // Parse using common logic
    parse_epub_with_doc(&mut doc, Some(&epub_path), None, full_data)
}

pub fn parse_epub_from_bytes(epub_bytes: Vec<u8>, full_data: bool) -> Result<EpubNovel, String> {
    let cursor = Cursor::new(epub_bytes.clone());

    // Try to parse as ZIP archive first to extract metadata
    let mut doc =
        EpubDoc::from_reader(cursor).map_err(|e| format!("Failed to parse EPUB: {}", e))?;

    // Parse using common logic (no file path available for resource extraction)
    parse_epub_with_doc(&mut doc, None, Some(epub_bytes), full_data)
}

/// Internal function to parse EPUB from EpubDoc
/// Handles both file path and bytes sources
fn parse_epub_with_doc<R: Read + Seek>(
    doc: &mut EpubDoc<R>,
    epub_path: Option<&str>,
    epub_bytes: Option<Vec<u8>>,
    full_data: bool,
) -> Result<EpubNovel, String> {
    // Extract metadata
    let name = doc
        .mdata("title")
        .map(|m| m.value.clone())
        .unwrap_or_else(|| "Untitled".to_string());

    let author = doc.mdata("creator").map(|m| m.value.clone());
    let artist = doc.mdata("contributor").map(|m| m.value.clone());
    let summary = doc.mdata("description").map(|m| m.value.clone());
    // Extract cover
    let cover = doc.get_cover().map(|(data, _mime)| data);
    // Only extract chapters, cover, and resources if full_data is true
    let (chapters, images, stylesheets) = if full_data {
        // Extract chapters from spine with real names from TOC
        let spine = doc.spine.clone();
        let toc = doc.toc.clone();
        let chapters: Vec<EpubChapter> = spine
            .iter()
            .enumerate()
            .map(|(idx, item)| {
                let content = doc
                    .get_resource(&item.idref)
                    .map(|(bytes, _)| decode_text_resource(&bytes))
                    .unwrap_or_default();

                // Try to find chapter name from TOC
                let chapter_name = find_chapter_name_from_toc(&toc, &item.idref)
                    .unwrap_or_else(|| format!("Chapter {}", idx + 1));

                EpubChapter {
                    name: chapter_name,
                    content,
                    path: item.idref.clone(),
                }
            })
            .collect();

        // Extract resources with content only if we have a file path
        let (stylesheets, images) = if let Some(path) = epub_path {
            extract_resources_with_content(path).unwrap_or_else(|_| (vec![], vec![]))
        } else {
            extract_resources_with_content_from_bytes(epub_bytes.unwrap_or_default())
                .unwrap_or_else(|_| (vec![], vec![]))
        };

        (chapters, images, stylesheets)
    } else {
        // Only metadata, no full data
        (vec![], vec![], vec![])
    };

    Ok(EpubNovel {
        name,
        cover,
        summary,
        author,
        artist,
        chapters,
        images,
        stylesheets,
    })
}

/// Extract CSS and image files with their binary content from EPUB (file path version)
fn extract_resources_with_content(
    epub_path: &str,
) -> Result<(Vec<EpubResource>, Vec<EpubResource>), String> {
    let file = fs::File::open(epub_path).map_err(|e| format!("Cannot open EPUB file: {}", e))?;
    let archive = ZipArchive::new(file).map_err(|e| format!("Invalid ZIP archive: {}", e))?;
    extract_resources_from_archive(archive)
}

/// Extract CSS and image files with their binary content from EPUB (bytes version)
fn extract_resources_with_content_from_bytes(
    epub_bytes: Vec<u8>,
) -> Result<(Vec<EpubResource>, Vec<EpubResource>), String> {
    let cursor = Cursor::new(epub_bytes);
    let archive = ZipArchive::new(cursor).map_err(|e| format!("Invalid ZIP archive: {}", e))?;
    extract_resources_from_archive(archive)
}

/// Internal function to extract resources from a ZipArchive
fn extract_resources_from_archive<R: Read + Seek>(
    mut archive: ZipArchive<R>,
) -> Result<(Vec<EpubResource>, Vec<EpubResource>), String> {
    let mut stylesheets = Vec::new();
    let mut images = Vec::new();

    for i in 0..archive.len() {
        let mut file = archive
            .by_index(i)
            .map_err(|e| format!("Cannot read archive entry: {}", e))?;

        let name = file.name().to_string();

        if name.ends_with(".css") {
            let mut content = Vec::new();
            file.read_to_end(&mut content)
                .map_err(|e| format!("Cannot read CSS file: {}", e))?;

            stylesheets.push(EpubResource { name, content });
        } else if name.ends_with(".jpg")
            || name.ends_with(".jpeg")
            || name.ends_with(".png")
            || name.ends_with(".gif")
            || name.ends_with(".svg")
            || name.ends_with(".webp")
        {
            let mut content = Vec::new();
            file.read_to_end(&mut content)
                .map_err(|e| format!("Cannot read image file: {}", e))?;

            images.push(EpubResource { name, content });
        }
    }

    Ok((stylesheets, images))
}

/// Helper function to find chapter name from TOC by resource ID
/// Recursively searches through navigation points to match the chapter ID
fn find_chapter_name_from_toc(toc: &[epub::doc::NavPoint], resource_id: &str) -> Option<String> {
    for nav_point in toc {
        let path_str = nav_point.content.to_string_lossy();

        // Check if this TOC entry matches the resource ID
        if path_str.contains(resource_id) || path_str.ends_with(&format!("{}.xhtml", resource_id)) {
            return Some(nav_point.label.clone());
        }

        // Recursively search in children
        if let Some(found_name) = find_chapter_name_from_toc(&nav_point.children, resource_id) {
            return Some(found_name);
        }
    }
    None
}

/// Get chapter content from EPUB by path
pub fn get_chapter_content(epub_path: String, chapter_path: String) -> Result<String, String> {
    let mut doc = EpubDoc::new(&epub_path).map_err(|e| format!("Failed to open EPUB: {}", e))?;

    // Find and get the chapter content
    let (content, _mime) = doc
        .get_resource(&chapter_path)
        .ok_or_else(|| format!("Failed to read chapter: {}", chapter_path))?;

    Ok(decode_text_resource(&content))
}

/// EPUB XHTML is normally UTF-8, but real-world books also contain UTF-16 or
/// legacy Japanese encodings. The upstream `get_resource_str` helper rejects
/// those bytes and returns `None`, which used to turn the whole chapter into a
/// blank page. Decode the BOM/XML declaration when present and fall back to a
/// lossless-enough UTF-8 replacement decode so readable content is never
/// silently discarded.
fn decode_text_resource(bytes: &[u8]) -> String {
    if bytes.starts_with(&[0xEF, 0xBB, 0xBF]) {
        return String::from_utf8_lossy(&bytes[3..]).into_owned();
    }
    if bytes.starts_with(&[0xFF, 0xFE]) {
        return decode_utf16(&bytes[2..], true);
    }
    if bytes.starts_with(&[0xFE, 0xFF]) {
        return decode_utf16(&bytes[2..], false);
    }

    let declaration = String::from_utf8_lossy(&bytes[..bytes.len().min(512)]);
    if let Some(label) = declared_encoding(&declaration) {
        let normalized = label.trim().to_ascii_lowercase();
        if normalized == "utf-16" || normalized == "utf-16le" {
            return decode_utf16(bytes, true);
        }
        if normalized == "utf-16be" {
            return decode_utf16(bytes, false);
        }
        if let Some(encoding) = Encoding::for_label(normalized.as_bytes()) {
            let (decoded, _, _) = encoding.decode(bytes);
            return decoded.into_owned();
        }
    }

    String::from_utf8(bytes.to_vec())
        .unwrap_or_else(|_| String::from_utf8_lossy(bytes).into_owned())
}

fn decode_utf16(bytes: &[u8], little_endian: bool) -> String {
    let units = bytes.chunks_exact(2).map(|pair| {
        if little_endian {
            u16::from_le_bytes([pair[0], pair[1]])
        } else {
            u16::from_be_bytes([pair[0], pair[1]])
        }
    });
    char::decode_utf16(units)
        .map(|value| value.unwrap_or(char::REPLACEMENT_CHARACTER))
        .collect()
}

fn declared_encoding(declaration: &str) -> Option<&str> {
    let lower = declaration.to_ascii_lowercase();
    for marker in ["encoding=\"", "encoding='", "charset=\"", "charset='"] {
        let Some(marker_start) = lower.find(marker) else {
            continue;
        };
        let start = marker_start + marker.len();
        let quote = marker.as_bytes().last().copied().unwrap_or(b'\"') as char;
        let rest = &declaration[start..];
        if let Some(end) = rest.find(quote) {
            return Some(&rest[..end]);
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::{declared_encoding, decode_text_resource, parse_epub_from_bytes};
    use std::io::{Cursor, Write};
    use zip::{write::SimpleFileOptions, CompressionMethod, ZipWriter};

    fn epub_with_chapter(chapter: &[u8]) -> Vec<u8> {
        let cursor = Cursor::new(Vec::new());
        let mut writer = ZipWriter::new(cursor);
        let stored = SimpleFileOptions::default().compression_method(CompressionMethod::Stored);

        writer.start_file("mimetype", stored).unwrap();
        writer.write_all(b"application/epub+zip").unwrap();
        writer
            .start_file("META-INF/container.xml", SimpleFileOptions::default())
            .unwrap();
        writer
            .write_all(
                br#"<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>"#,
            )
            .unwrap();
        writer
            .start_file("OEBPS/content.opf", SimpleFileOptions::default())
            .unwrap();
        writer
            .write_all(
                br#"<?xml version="1.0" encoding="UTF-8"?>
<package version="2.0" unique-identifier="book-id" xmlns="http://www.idpf.org/2007/opf">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="book-id">fixture</dc:identifier><dc:title>Japanese fixture</dc:title>
  </metadata>
  <manifest><item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/></manifest>
  <spine><itemref idref="chapter"/></spine>
</package>"#,
            )
            .unwrap();
        writer
            .start_file("OEBPS/chapter.xhtml", SimpleFileOptions::default())
            .unwrap();
        writer.write_all(chapter).unwrap();

        writer.finish().unwrap().into_inner()
    }

    #[test]
    fn decodes_utf16le_japanese_xhtml() {
        let source = "<?xml version=\"1.0\" encoding=\"UTF-16\"?><p>探偵はもう、死んでいる。</p>";
        let mut bytes = vec![0xFF, 0xFE];
        bytes.extend(source.encode_utf16().flat_map(u16::to_le_bytes));

        assert_eq!(decode_text_resource(&bytes), source);
    }

    #[test]
    fn decodes_shift_jis_from_xml_declaration() {
        let source = "<?xml version=\"1.0\" encoding=\"Shift_JIS\"?><p>辞書検索</p>";
        let (bytes, _, _) = encoding_rs::SHIFT_JIS.encode(source);

        assert_eq!(decode_text_resource(&bytes), source);
    }

    #[test]
    fn reads_encoding_declaration_case_insensitively() {
        assert_eq!(
            declared_encoding("<?xml version='1.0' ENCODING='Shift_JIS'?>"),
            Some("Shift_JIS")
        );
    }

    #[test]
    fn parses_non_utf8_japanese_chapter_through_epub_spine() {
        let source = "<?xml version=\"1.0\" encoding=\"Shift_JIS\"?><html><body><p>本文を辞書検索</p></body></html>";
        let (chapter, _, _) = encoding_rs::SHIFT_JIS.encode(source);

        let book = parse_epub_from_bytes(epub_with_chapter(&chapter), true).unwrap();

        assert_eq!(book.chapters.len(), 1);
        assert!(book.chapters[0].content.contains("本文を辞書検索"));
    }
}
