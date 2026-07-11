use encoding_rs::Encoding;
use epub::doc::EpubDoc;
use std::fs;
use std::io::{Cursor, Read, Seek};
use std::path::Path;
use zip::ZipArchive;

#[derive(Debug, Clone)]
pub struct EpubChapter {
    /// Logical section name inherited from the nearest preceding EPUB TOC
    /// entry. Raw spine fragments remain separate for reliable rendering.
    pub name: String,
    pub content: String,
    pub path: String,
    /// Canonical path inside the EPUB archive. This is intentionally kept
    /// alongside [path] so existing records remain readable while the reader
    /// can resolve images, footnotes, and cross-chapter links correctly.
    pub href: String,
    /// Stable position in the original OPF spine.
    pub spine_index: u32,
    /// Whether this spine item should appear in the user-facing chapter list.
    /// Non-navigation fragments are still kept for seamless reader paging.
    pub is_navigation_entry: bool,
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

#[derive(Debug, Clone)]
struct NavigationEntry {
    label: String,
    href: String,
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
        let navigation = collect_navigation_entries(doc);
        let mut current_section_name: Option<String> = None;
        let mut has_renderable_spine_item = false;
        let chapters: Vec<EpubChapter> = spine
            .iter()
            .enumerate()
            .filter_map(|(source_spine_index, item)| {
                let resource_path = doc.resources.get(&item.idref)?.path.clone();
                let content = doc
                    .get_resource(&item.idref)
                    .map(|(bytes, _)| decode_text_resource(&bytes))
                    .unwrap_or_default();

                // `linear="no"` is only a reading-order hint. Real-world
                // Japanese EPUBs use it for valid cover/title pages which
                // must remain addressable by the reader. Drop only resources
                // that cannot render any text or image content.
                if !epub_content_is_renderable(&content) {
                    return None;
                }

                let href = normalize_epub_path(&resource_path.to_string_lossy());
                let toc_name = find_chapter_name_from_navigation(&navigation, &href);
                let is_first_spine_item = !has_renderable_spine_item;
                let is_navigation_entry = toc_name.is_some() || is_first_spine_item;

                if let Some(toc_name) = toc_name {
                    current_section_name = Some(toc_name);
                } else if is_first_spine_item {
                    // A surprising number of EPUB2 files have a stale NCX
                    // cover target which is not in the OPF spine. Keep a
                    // deterministic beginning row so the book remains
                    // enterable without inventing a row for every fragment.
                    current_section_name = Some("Beginning".to_owned());
                }
                let chapter_name = current_section_name.clone().unwrap_or_else(|| name.clone());
                has_renderable_spine_item = true;

                Some(EpubChapter {
                    name: chapter_name,
                    content,
                    path: item.idref.clone(),
                    href,
                    spine_index: source_spine_index as u32,
                    is_navigation_entry,
                })
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

/// Extract reader assets and images with their binary content from EPUB (file path version).
///
/// `stylesheets` also carries local font files. Keeping them in the existing
/// resource bucket avoids an FFI schema migration while allowing CSS
/// `@font-face` URLs to resolve after the EPUB package is materialized.
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

        let lower_name = name.to_ascii_lowercase();
        if lower_name.ends_with(".css") || is_epub_reader_auxiliary_asset(&lower_name) {
            let mut content = Vec::new();
            file.read_to_end(&mut content)
                .map_err(|e| format!("Cannot read EPUB reader asset: {}", e))?;

            stylesheets.push(EpubResource { name, content });
        } else if lower_name.ends_with(".jpg")
            || lower_name.ends_with(".jpeg")
            || lower_name.ends_with(".png")
            || lower_name.ends_with(".gif")
            || lower_name.ends_with(".svg")
            || lower_name.ends_with(".webp")
        {
            let mut content = Vec::new();
            file.read_to_end(&mut content)
                .map_err(|e| format!("Cannot read image file: {}", e))?;

            images.push(EpubResource { name, content });
        }
    }

    Ok((stylesheets, images))
}

fn is_epub_reader_auxiliary_asset(lower_name: &str) -> bool {
    let lower_name = lower_name.to_ascii_lowercase();
    lower_name.ends_with(".woff")
        || lower_name.ends_with(".woff2")
        || lower_name.ends_with(".ttf")
        || lower_name.ends_with(".otf")
        || lower_name.ends_with(".eot")
}

/// Collect logical navigation independently from the raw OPF spine.
///
/// The `epub` crate reads valid EPUB2 NCX files, but it intentionally ignores
/// malformed NCX and does not populate `toc` from EPUB3 navigation XHTML.
/// Many converted Japanese books contain a malformed title while their
/// `navMap` is still perfectly usable, so both fallbacks are parsed here.
fn collect_navigation_entries<R: Read + Seek>(doc: &mut EpubDoc<R>) -> Vec<NavigationEntry> {
    let mut entries = Vec::new();
    flatten_nav_points(&doc.toc, &mut entries);
    if !entries.is_empty() {
        return entries;
    }

    if let Some(nav_id) = doc.get_nav_id() {
        let nav_path = doc
            .resources
            .get(&nav_id)
            .map(|resource| resource.path.to_string_lossy().into_owned());
        if let (Some(nav_path), Some((bytes, _))) = (nav_path, doc.get_resource(&nav_id)) {
            entries = parse_epub3_navigation(&decode_text_resource(&bytes), &nav_path);
        }
    }
    if !entries.is_empty() {
        return entries;
    }

    let ncx = doc.resources.iter().find_map(|(id, resource)| {
        let path = resource.path.to_string_lossy();
        (resource
            .mime
            .eq_ignore_ascii_case("application/x-dtbncx+xml")
            || path.to_ascii_lowercase().ends_with(".ncx"))
        .then(|| (id.clone(), path.into_owned()))
    });
    if let Some((ncx_id, ncx_path)) = ncx {
        if let Some((bytes, _)) = doc.get_resource(&ncx_id) {
            entries = parse_ncx_navigation(&decode_text_resource(&bytes), &ncx_path);
        }
    }
    entries
}

fn flatten_nav_points(points: &[epub::doc::NavPoint], output: &mut Vec<NavigationEntry>) {
    for point in points {
        output.push(NavigationEntry {
            label: point.label.clone(),
            href: normalize_epub_path(&point.content.to_string_lossy()),
        });
        flatten_nav_points(&point.children, output);
    }
}

fn parse_ncx_navigation(markup: &str, ncx_path: &str) -> Vec<NavigationEntry> {
    let Some(nav_map) = element_content(markup, "navMap") else {
        return Vec::new();
    };
    let lower = nav_map.to_ascii_lowercase();
    let mut entries = Vec::new();
    let mut cursor = 0;
    while let Some(relative_start) = lower[cursor..].find("<navpoint") {
        let start = cursor + relative_start;
        let Some(relative_end) = lower[start..].find("</navpoint>") else {
            break;
        };
        let end = start + relative_end + "</navpoint>".len();
        let block = &nav_map[start..end];
        let label = element_content(block, "navLabel")
            .and_then(|value| element_content(value, "text").or(Some(value)))
            .map(strip_markup)
            .unwrap_or_default();
        let href = opening_tag(block, "content")
            .and_then(|tag| attribute_value(tag, "src"))
            .unwrap_or_default();
        if !label.is_empty() && !href.is_empty() {
            entries.push(NavigationEntry {
                label,
                href: resolve_epub_reference(ncx_path, &href),
            });
        }
        // Advance past only this opening token so nested navPoints are also
        // flattened in their authored order.
        cursor = start + "<navpoint".len();
    }
    entries
}

fn parse_epub3_navigation(markup: &str, nav_path: &str) -> Vec<NavigationEntry> {
    let lower = markup.to_ascii_lowercase();
    let mut nav_cursor = 0;
    while let Some(relative_start) = lower[nav_cursor..].find("<nav") {
        let start = nav_cursor + relative_start;
        let Some(open_end_relative) = lower[start..].find('>') else {
            break;
        };
        let open_end = start + open_end_relative + 1;
        let tag = &markup[start..open_end];
        let is_toc = attribute_value(tag, "epub:type")
            .or_else(|| attribute_value(tag, "type"))
            .is_some_and(|value| value.split_whitespace().any(|part| part == "toc"))
            || attribute_value(tag, "role").is_some_and(|value| value == "doc-toc");
        if !is_toc {
            nav_cursor = open_end;
            continue;
        }
        let close = lower[open_end..]
            .find("</nav>")
            .map(|relative| open_end + relative)
            .unwrap_or(markup.len());
        return parse_navigation_links(&markup[open_end..close], nav_path);
    }
    Vec::new()
}

fn parse_navigation_links(markup: &str, base_path: &str) -> Vec<NavigationEntry> {
    let lower = markup.to_ascii_lowercase();
    let mut entries = Vec::new();
    let mut cursor = 0;
    while let Some(relative_start) = lower[cursor..].find("<a") {
        let start = cursor + relative_start;
        let Some(open_end_relative) = lower[start..].find('>') else {
            break;
        };
        let open_end = start + open_end_relative + 1;
        let Some(close_relative) = lower[open_end..].find("</a>") else {
            break;
        };
        let close = open_end + close_relative;
        let href = attribute_value(&markup[start..open_end], "href").unwrap_or_default();
        let label = strip_markup(&markup[open_end..close]);
        if !label.is_empty() && !href.is_empty() {
            entries.push(NavigationEntry {
                label,
                href: resolve_epub_reference(base_path, &href),
            });
        }
        cursor = close + "</a>".len();
    }
    entries
}

fn find_chapter_name_from_navigation(
    navigation: &[NavigationEntry],
    resource_path: &str,
) -> Option<String> {
    navigation
        .iter()
        .find(|entry| epub_paths_match(&entry.href, resource_path))
        .map(|entry| entry.label.clone())
}

fn resolve_epub_reference(base_path: &str, reference: &str) -> String {
    if reference.starts_with('/') {
        return normalize_epub_path(reference);
    }
    let normalized_base = normalize_epub_path(base_path);
    let directory = normalized_base
        .rsplit_once('/')
        .map(|(directory, _)| directory)
        .unwrap_or_default();
    normalize_epub_path(&format!("{directory}/{reference}"))
}

fn opening_tag<'a>(markup: &'a str, tag_name: &str) -> Option<&'a str> {
    let lower = markup.to_ascii_lowercase();
    let start = lower.find(&format!("<{}", tag_name.to_ascii_lowercase()))?;
    let end = lower[start..].find('>')? + start + 1;
    Some(&markup[start..end])
}

fn element_content<'a>(markup: &'a str, tag_name: &str) -> Option<&'a str> {
    let lower = markup.to_ascii_lowercase();
    let start = lower.find(&format!("<{}", tag_name.to_ascii_lowercase()))?;
    let content_start = lower[start..].find('>')? + start + 1;
    let content_end = lower[content_start..]
        .find(&format!("</{}>", tag_name.to_ascii_lowercase()))?
        + content_start;
    Some(&markup[content_start..content_end])
}

fn attribute_value(tag: &str, attribute: &str) -> Option<String> {
    let lower = tag.to_ascii_lowercase();
    let attribute = attribute.to_ascii_lowercase();
    let mut cursor = 0;
    while let Some(relative) = lower[cursor..].find(&attribute) {
        let start = cursor + relative;
        let before_is_boundary = start == 0
            || lower.as_bytes()[start - 1].is_ascii_whitespace()
            || lower.as_bytes()[start - 1] == b'<';
        let mut equals = start + attribute.len();
        while equals < lower.len() && lower.as_bytes()[equals].is_ascii_whitespace() {
            equals += 1;
        }
        if before_is_boundary && lower.as_bytes().get(equals) == Some(&b'=') {
            let mut value_start = equals + 1;
            while value_start < tag.len() && tag.as_bytes()[value_start].is_ascii_whitespace() {
                value_start += 1;
            }
            let quote = *tag.as_bytes().get(value_start)?;
            if quote == b'\'' || quote == b'"' {
                let value_end = tag[value_start + 1..].find(quote as char)? + value_start + 1;
                return Some(decode_markup_entities(&tag[value_start + 1..value_end]));
            }
        }
        cursor = start + attribute.len();
    }
    None
}

fn strip_markup(markup: &str) -> String {
    let mut text = String::new();
    let mut in_tag = false;
    for character in markup.chars() {
        match character {
            '<' => in_tag = true,
            '>' => in_tag = false,
            _ if !in_tag => text.push(character),
            _ => {}
        }
    }
    decode_markup_entities(&text)
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
}

fn decode_markup_entities(value: &str) -> String {
    let named = value
        .replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", "\"")
        .replace("&apos;", "'")
        .replace("&#39;", "'")
        .replace("&nbsp;", " ");
    let mut decoded = String::with_capacity(named.len());
    let mut remaining = named.as_str();
    while let Some(start) = remaining.find("&#") {
        decoded.push_str(&remaining[..start]);
        let entity_start = start + 2;
        let Some(relative_end) = remaining[entity_start..].find(';') else {
            decoded.push_str(&remaining[start..]);
            return decoded;
        };
        let end = entity_start + relative_end;
        let entity = &remaining[entity_start..end];
        let value = entity
            .strip_prefix('x')
            .or_else(|| entity.strip_prefix('X'))
            .and_then(|hex| u32::from_str_radix(hex, 16).ok())
            .or_else(|| entity.parse::<u32>().ok());
        if let Some(character) = value.and_then(char::from_u32) {
            decoded.push(character);
        } else {
            decoded.push_str(&remaining[start..=end]);
        }
        remaining = &remaining[end + 1..];
    }
    decoded.push_str(remaining);
    decoded
}

fn normalize_epub_path(path: &str) -> String {
    let without_suffix = path
        .split('#')
        .next()
        .unwrap_or(path)
        .split('?')
        .next()
        .unwrap_or(path)
        .replace('\\', "/");
    let decoded = percent_decode_path(&without_suffix);
    let mut segments = Vec::new();
    for segment in decoded.split('/') {
        match segment {
            "" | "." => {}
            ".." => {
                segments.pop();
            }
            value => segments.push(value),
        }
    }
    segments.join("/")
}

fn epub_paths_match(left: &str, right: &str) -> bool {
    left == right
        || left
            .strip_suffix(right)
            .is_some_and(|prefix| prefix.ends_with('/'))
        || right
            .strip_suffix(left)
            .is_some_and(|prefix| prefix.ends_with('/'))
}

fn percent_decode_path(value: &str) -> String {
    let bytes = value.as_bytes();
    let mut decoded = Vec::with_capacity(bytes.len());
    let mut index = 0;
    while index < bytes.len() {
        if bytes[index] == b'%' && index + 2 < bytes.len() {
            let high = (bytes[index + 1] as char).to_digit(16);
            let low = (bytes[index + 2] as char).to_digit(16);
            if let (Some(high), Some(low)) = (high, low) {
                decoded.push((high * 16 + low) as u8);
                index += 3;
                continue;
            }
        }
        decoded.push(bytes[index]);
        index += 1;
    }
    String::from_utf8_lossy(&decoded).into_owned()
}

fn epub_content_is_renderable(markup: &str) -> bool {
    let lower = markup.to_ascii_lowercase();
    if lower.contains("<img") || lower.contains("<svg") || lower.contains("<image") {
        return true;
    }

    let mut in_tag = false;
    let mut in_entity = false;
    for character in markup.chars() {
        match character {
            '<' => in_tag = true,
            '>' => in_tag = false,
            '&' if !in_tag => in_entity = true,
            ';' if in_entity => in_entity = false,
            _ if !in_tag && !in_entity && !character.is_whitespace() => return true,
            _ => {}
        }
    }
    false
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
    use super::{
        declared_encoding, decode_text_resource, epub_content_is_renderable, epub_paths_match,
        is_epub_reader_auxiliary_asset, normalize_epub_path, parse_epub3_navigation,
        parse_epub_from_bytes, parse_ncx_navigation,
    };
    use std::io::{Cursor, Write};
    use zip::{write::SimpleFileOptions, CompressionMethod, ZipWriter};

    #[test]
    fn canonicalizes_epub_paths_without_matching_partial_names() {
        assert_eq!(
            normalize_epub_path("./OEBPS/text/chapter-10.xhtml#note"),
            "OEBPS/text/chapter-10.xhtml"
        );
        assert_ne!(
            normalize_epub_path("OEBPS/text/chapter-1.xhtml"),
            normalize_epub_path("OEBPS/text/chapter-10.xhtml")
        );
        assert_eq!(
            normalize_epub_path("./OPS/../OEBPS/%E7%9B%AE%E6%AC%A1.xhtml?x=1#top"),
            "OEBPS/目次.xhtml"
        );
        assert!(epub_paths_match(
            "OEBPS/text/chapter-1.xhtml",
            "text/chapter-1.xhtml"
        ));
        assert!(!epub_paths_match(
            "OEBPS/text/chapter-1.xhtml",
            "OEBPS/text/chapter-10.xhtml"
        ));
    }

    #[test]
    fn recovers_navigation_from_ncx_with_malformed_title_markup() {
        let ncx = r#"<ncx><docTitle><text>業物語 <物語></text></docTitle>
<navMap>
  <navPoint><navLabel><text>目次</text></navLabel><content src="Text/part0003.xhtml"/></navPoint>
  <navPoint><navLabel><text>第一話</text></navLabel><content src="Text/part0004.xhtml#start"/></navPoint>
</navMap></ncx>"#;
        let entries = parse_ncx_navigation(ncx, "OEBPS/toc.ncx");

        assert_eq!(entries.len(), 2);
        assert_eq!(entries[0].label, "目次");
        assert_eq!(entries[0].href, "OEBPS/Text/part0003.xhtml");
        assert_eq!(entries[1].label, "第一話");
        assert_eq!(entries[1].href, "OEBPS/Text/part0004.xhtml");
    }

    #[test]
    fn reads_epub3_navigation_xhtml_in_authored_order() {
        let nav = r#"<html xmlns:epub="http://www.idpf.org/2007/ops"><body>
<nav epub:type="toc"><ol>
  <li><a href="Text/chapter-1.xhtml">第一章</a></li>
  <li><a href="Text/chapter-2.xhtml#part">第二章</a></li>
</ol></nav></body></html>"#;
        let entries = parse_epub3_navigation(nav, "EPUB/nav.xhtml");

        assert_eq!(entries.len(), 2);
        assert_eq!(entries[0].label, "第一章");
        assert_eq!(entries[0].href, "EPUB/Text/chapter-1.xhtml");
        assert_eq!(entries[1].label, "第二章");
        assert_eq!(entries[1].href, "EPUB/Text/chapter-2.xhtml");
    }

    #[test]
    fn ignores_empty_navigation_markup_but_keeps_image_pages() {
        assert!(!epub_content_is_renderable(
            "<html><body> \n </body></html>"
        ));
        assert!(epub_content_is_renderable(
            "<html><body><img src=\"cover.JPG\"></body></html>"
        ));
        assert!(epub_content_is_renderable("<p>Japanese text</p>"));
    }

    #[test]
    fn keeps_local_fonts_with_stylesheets_for_file_backed_reader_sessions() {
        assert!(is_epub_reader_auxiliary_asset("oebps/fonts/book.woff2"));
        assert!(is_epub_reader_auxiliary_asset("OEBPS/Fonts/BOOK.OTF"));
        assert!(!is_epub_reader_auxiliary_asset("OEBPS/images/cover.webp"));
    }

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
        assert_eq!(book.chapters[0].spine_index, 0);
        assert!(book.chapters[0].is_navigation_entry);
        assert_eq!(book.chapters[0].name, "Beginning");
        assert!(book.chapters[0].content.contains("本文を辞書検索"));
    }
}
