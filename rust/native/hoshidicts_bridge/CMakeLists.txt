cmake_minimum_required(VERSION 3.22.1)

project(mangayomi_hoshidicts_bridge LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(NOT DEFINED MANGAYOMI_PROJECT_ROOT)
    message(FATAL_ERROR "MANGAYOMI_PROJECT_ROOT must point to the Mangatan workspace root")
endif()

set(HOSHIDICTS_ROOT "${MANGAYOMI_PROJECT_ROOT}/third_party/hoshidicts")
set(HOSHIDICTS_GENERATED_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated")
set(HOSHIDICTS_RANGES_TO_HEADER "${HOSHIDICTS_GENERATED_DIR}/hoshidicts_ranges_to_compat.hpp")

function(hoshidicts_replace_or_fail VARIABLE NEEDLE REPLACEMENT DESCRIPTION)
    string(FIND "${${VARIABLE}}" "${NEEDLE}" HOSHIDICTS_REPLACE_POSITION)
    if(HOSHIDICTS_REPLACE_POSITION EQUAL -1)
        message(FATAL_ERROR "Could not apply Hoshidicts compatibility patch: ${DESCRIPTION}")
    endif()
    string(REPLACE "${NEEDLE}" "${REPLACEMENT}" HOSHIDICTS_REPLACED_VALUE "${${VARIABLE}}")
    set(${VARIABLE} "${HOSHIDICTS_REPLACED_VALUE}" PARENT_SCOPE)
endfunction()

add_subdirectory(
    "${HOSHIDICTS_ROOT}"
    "${CMAKE_CURRENT_BINARY_DIR}/hoshidicts"
    EXCLUDE_FROM_ALL
)

if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    target_compile_options(hoshidicts PRIVATE "$<$<COMPILE_LANGUAGE:CXX>:-Wno-c23-extensions>")
endif()

if(MSVC)
    target_compile_options(hoshidicts PRIVATE "$<$<COMPILE_LANGUAGE:CXX>:/utf-8>" "$<$<COMPILE_LANGUAGE:CXX>:/EHsc>")
endif()

set(HOSHIDICTS_TEXT_PROCESSOR_SOURCE "${HOSHIDICTS_ROOT}/src/text_processor/text_processor.cpp")
set(HOSHIDICTS_TEXT_PROCESSOR_PATCHED "${HOSHIDICTS_GENERATED_DIR}/text_processor.cpp")
set(HOSHIDICTS_IMPORTER_SOURCE "${HOSHIDICTS_ROOT}/src/importer.cpp")
set(HOSHIDICTS_IMPORTER_PATCHED "${HOSHIDICTS_GENERATED_DIR}/importer.cpp")
set(HOSHIDICTS_MEMORY_SOURCE "${HOSHIDICTS_ROOT}/src/memory/memory.cpp")
set(HOSHIDICTS_MEMORY_PATCHED "${HOSHIDICTS_GENERATED_DIR}/memory.cpp")
set(HOSHIDICTS_QUERY_SOURCE "${HOSHIDICTS_ROOT}/src/query.cpp")
set(HOSHIDICTS_QUERY_PATCHED "${HOSHIDICTS_GENERATED_DIR}/query.cpp")
set(HOSHIDICTS_YOMITAN_PARSER_SOURCE "${HOSHIDICTS_ROOT}/src/json/yomitan_parser.cpp")
set(HOSHIDICTS_YOMITAN_PARSER_PATCHED "${HOSHIDICTS_GENERATED_DIR}/yomitan_parser.cpp")
set(HOSHIDICTS_KANJI_MAPPING_HEADER "${HOSHIDICTS_GENERATED_DIR}/hoshidicts_full_list_embedded.hpp")

file(MAKE_DIRECTORY "${HOSHIDICTS_GENERATED_DIR}")
file(WRITE "${HOSHIDICTS_RANGES_TO_HEADER}"
    "#pragma once\n"
    "#include <ranges>\n"
    "#include <vector>\n"
    "#ifndef __cpp_lib_ranges_to_container\n"
    "namespace std::ranges {\n"
    "template <template <class...> class Container>\n"
    "struct hoshidicts_to_closure {\n"
    "    template <input_range Range>\n"
    "    friend auto operator|(Range&& range, const hoshidicts_to_closure&) {\n"
    "        using value_type = range_value_t<Range>;\n"
    "        return Container<value_type>(begin(range), end(range));\n"
    "    }\n"
    "};\n"
    "template <template <class...> class Container>\n"
    "constexpr auto to() {\n"
    "    return hoshidicts_to_closure<Container>{};\n"
    "}\n"
    "}\n"
    "#endif\n"
)
file(READ "${HOSHIDICTS_TEXT_PROCESSOR_SOURCE}" HOSHIDICTS_TEXT_PROCESSOR_CONTENT)
string(REPLACE
    "#include <utf8.h>"
    "#include <utf8.h>\n#include <utf8/cpp17.h>"
    HOSHIDICTS_TEXT_PROCESSOR_CONTENT
    "${HOSHIDICTS_TEXT_PROCESSOR_CONTENT}"
)
string(REPLACE
    "constexpr auto mapping_list = std::to_array<unsigned char>({\n#embed \"../../external/kanji-processor/src/full_list.json\"\n});"
    "#include \"hoshidicts_full_list_embedded.hpp\""
    HOSHIDICTS_TEXT_PROCESSOR_CONTENT
    "${HOSHIDICTS_TEXT_PROCESSOR_CONTENT}"
)
file(WRITE "${HOSHIDICTS_TEXT_PROCESSOR_PATCHED}" "${HOSHIDICTS_TEXT_PROCESSOR_CONTENT}")

# Hoshidicts passes UTF-8 paths through its public API. On Windows, convert
# those paths explicitly instead of interpreting them with the active ANSI
# code page. The generated overlays keep the vendored submodule untouched.
file(READ "${HOSHIDICTS_MEMORY_SOURCE}" HOSHIDICTS_MEMORY_CONTENT)
hoshidicts_replace_or_fail(
    HOSHIDICTS_MEMORY_CONTENT
    [=[#include <windows.h>]=]
    [=[#include <windows.h>

namespace {
std::wstring hoshidicts_utf8_to_wide(const std::string& value) {
  if (value.empty()) {
    return {};
  }
  const int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                                         static_cast<int>(value.size()), nullptr, 0);
  if (length <= 0) {
    return {};
  }
  std::wstring wide(static_cast<size_t>(length), L'\0');
  if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                          static_cast<int>(value.size()), wide.data(), length) != length) {
    return {};
  }
  return wide;
}
}]=]
    "add the UTF-8 to UTF-16 path converter"
)
hoshidicts_replace_or_fail(
    HOSHIDICTS_MEMORY_CONTENT
    [=[CreateFileA(path.c_str(),]=]
    [=[CreateFileW(hoshidicts_utf8_to_wide(path).c_str(),]=]
    "use wide Windows file APIs"
)
file(WRITE "${HOSHIDICTS_MEMORY_PATCHED}" "${HOSHIDICTS_MEMORY_CONTENT}")

file(READ "${HOSHIDICTS_IMPORTER_SOURCE}" HOSHIDICTS_IMPORTER_CONTENT)
hoshidicts_replace_or_fail(
    HOSHIDICTS_IMPORTER_CONTENT
    [=[size_t write_media(const std::string& path, const Zip& zip, const std::vector<int>& files) {]=]
    [=[size_t write_media(const std::filesystem::path& path, const Zip& zip, const std::vector<int>& files) {]=]
    "make media output use filesystem paths"
)
hoshidicts_replace_or_fail(
    HOSHIDICTS_IMPORTER_CONTENT
    [=[  std::ofstream media(path + "/media.bin", std::ios::binary);
  std::ofstream media_idx(path + "/media.idx", std::ios::binary);]=]
    [=[  std::ofstream media(path / "media.bin", std::ios::binary);
  std::ofstream media_idx(path / "media.idx", std::ios::binary);]=]
    "open media files with native paths"
)
hoshidicts_replace_or_fail(
    HOSHIDICTS_IMPORTER_CONTENT
    [=[    std::filesystem::path dict_path = std::filesystem::path(output_dir) / result.title;
    std::string path = dict_path.string();]=]
    [=[    const std::filesystem::path dict_path =
        std::filesystem::u8path(output_dir) / std::filesystem::u8path(result.title);
    const auto path_u8 = dict_path.generic_u8string();
    const std::string path(path_u8.begin(), path_u8.end());]=]
    "construct dictionary paths from UTF-8"
)
hoshidicts_replace_or_fail(
    HOSHIDICTS_IMPORTER_CONTENT
    [=[    if (glz::write_file_json(index, path + "/index.json", std::string{})) {
      throw std::runtime_error("failed to write index.json");
    }]=]
    [=[    std::string index_json;
    if (glz::write_json(index, index_json)) {
      throw std::runtime_error("failed to serialize index.json");
    }
    std::ofstream index_file(dict_path / "index.json", std::ios::binary);
    setup_stream_exceptions(index_file);
    index_file.write(index_json.data(), static_cast<std::streamsize>(index_json.size()));]=]
    "write index.json through a native filesystem path"
)
hoshidicts_replace_or_fail(
    HOSHIDICTS_IMPORTER_CONTENT
    [=[        std::ofstream styles_file(path + "/styles.css", std::ios::binary);]=]
    [=[        std::ofstream styles_file(dict_path / "styles.css", std::ios::binary);]=]
    "write styles through a native filesystem path"
)
hoshidicts_replace_or_fail(
    HOSHIDICTS_IMPORTER_CONTENT
    [=[    std::future<size_t> media_thread =
        std::async(std::launch::async, [&path, &zip, &files]() { return write_media(path, zip, files.media_files); });]=]
    [=[    std::future<size_t> media_thread = std::async(std::launch::async, [&dict_path, &zip, &files]() {
      return write_media(dict_path, zip, files.media_files);
    });]=]
    "send a native path to the media writer"
)
hoshidicts_replace_or_fail(
    HOSHIDICTS_IMPORTER_CONTENT
    [=[    std::ofstream blobs(path + "/blobs.bin", std::ios::binary);]=]
    [=[    std::ofstream blobs(dict_path / "blobs.bin", std::ios::binary);]=]
    "write blobs through a native filesystem path"
)
hoshidicts_replace_or_fail(
    HOSHIDICTS_IMPORTER_CONTENT
    [=[    std::ofstream sui(path + "/.hoshidicts_3", std::ios::binary);]=]
    [=[    std::ofstream sui(dict_path / ".hoshidicts_3", std::ios::binary);]=]
    "write the version marker through a native filesystem path"
)
hoshidicts_replace_or_fail(
    HOSHIDICTS_IMPORTER_CONTENT
    [=[    std::filesystem::remove_all(std::filesystem::path(output_dir) / result.title);]=]
    [=[    std::filesystem::remove_all(std::filesystem::u8path(output_dir) /
                                std::filesystem::u8path(result.title));]=]
    "clean failed UTF-8 dictionary paths"
)
file(WRITE "${HOSHIDICTS_IMPORTER_PATCHED}" "${HOSHIDICTS_IMPORTER_CONTENT}")

file(READ "${HOSHIDICTS_QUERY_SOURCE}" HOSHIDICTS_QUERY_CONTENT)
hoshidicts_replace_or_fail(
    HOSHIDICTS_QUERY_CONTENT
    [=[void DictionaryQuery::add_dict(const std::string& path, DictionaryType type) {
  int version = 0;
  if (std::filesystem::is_regular_file(path + "/.hoshidicts_3")) {
    version = 3;
  } else if (std::filesystem::is_regular_file(path + "/.hoshidicts_2")) {
    version = 2;
  } else if (std::filesystem::is_regular_file(path + "/.hoshidicts_1")) {
    version = 1;
  } else {
    return;
  }

  Dictionary dict;
  Index index;
  std::string buf{};
  if (glz::read_file_json(index, path + "/index.json", buf)) {
    return;
  }]=]
    [=[void DictionaryQuery::add_dict(const std::string& path, DictionaryType type) {
  const std::filesystem::path dictionary_path = std::filesystem::u8path(path);
  int version = 0;
  if (std::filesystem::is_regular_file(dictionary_path / ".hoshidicts_3")) {
    version = 3;
  } else if (std::filesystem::is_regular_file(dictionary_path / ".hoshidicts_2")) {
    version = 2;
  } else if (std::filesystem::is_regular_file(dictionary_path / ".hoshidicts_1")) {
    version = 1;
  } else {
    return;
  }

  Dictionary dict;
  Index index;
  std::ifstream index_file(dictionary_path / "index.json", std::ios::binary);
  if (!index_file) {
    return;
  }
  std::string buf(std::istreambuf_iterator<char>(index_file), {});
  if (!yomitan_parser::parse_index(buf, index)) {
    return;
  }]=]
    "load dictionary metadata through native filesystem paths"
)
hoshidicts_replace_or_fail(
    HOSHIDICTS_QUERY_CONTENT
    [=[  dict.name = index.title.empty() ? std::filesystem::path(path).stem().string() : index.title;
  if (std::filesystem::exists(path + "/styles.css")) {
    std::ifstream f(path + "/styles.css");]=]
    [=[  const auto fallback_name_u8 = dictionary_path.stem().u8string();
  dict.name = index.title.empty()
                  ? std::string(fallback_name_u8.begin(), fallback_name_u8.end())
                  : std::string(index.title);
  if (std::filesystem::exists(dictionary_path / "styles.css")) {
    std::ifstream f(dictionary_path / "styles.css");]=]
    "load styles and fallback names through native filesystem paths"
)
file(WRITE "${HOSHIDICTS_QUERY_PATCHED}" "${HOSHIDICTS_QUERY_CONTENT}")

file(READ "${HOSHIDICTS_YOMITAN_PARSER_SOURCE}" HOSHIDICTS_YOMITAN_PARSER_CONTENT)
hoshidicts_replace_or_fail(
    HOSHIDICTS_YOMITAN_PARSER_CONTENT
    [=[#include <string_view>
#include <variant>]=]
    [=[#include <charconv>
#include <string_view>
#include <system_error>
#include <variant>]=]
    "include numeric-string parsing support"
)
hoshidicts_replace_or_fail(
    HOSHIDICTS_YOMITAN_PARSER_CONTENT
    [=[  int val;
  error = glz::read_json(val, content);
  if (!error) {
    out.value = val;
    out.display_value = std::to_string(val);
    out.reading = "";
    return true;
  }]=]
    [=[  int val;
  error = glz::read_json(val, content);
  if (!error) {
    out.value = val;
    out.display_value = std::to_string(val);
    out.reading = "";
    return true;
  }

  std::string string_value;
  error = glz::read_json(string_value, content);
  if (!error) {
    const auto [end, parse_error] =
        std::from_chars(string_value.data(), string_value.data() + string_value.size(), val);
    if (parse_error == std::errc{} && end == string_value.data() + string_value.size()) {
      out.value = val;
      out.display_value = string_value;
      out.reading = "";
      return true;
    }
  }]=]
    "accept numeric frequency values encoded as JSON strings"
)
file(WRITE "${HOSHIDICTS_YOMITAN_PARSER_PATCHED}" "${HOSHIDICTS_YOMITAN_PARSER_CONTENT}")

file(READ "${HOSHIDICTS_ROOT}/external/kanji-processor/src/full_list.json" HOSHIDICTS_KANJI_MAPPING_HEX HEX)
string(REGEX REPLACE "([0-9A-Fa-f][0-9A-Fa-f])" "0x\\1," HOSHIDICTS_KANJI_MAPPING_BYTES "${HOSHIDICTS_KANJI_MAPPING_HEX}")
string(REGEX REPLACE "((0x[0-9A-Fa-f][0-9A-Fa-f],){16})" "\\1\n" HOSHIDICTS_KANJI_MAPPING_BYTES "${HOSHIDICTS_KANJI_MAPPING_BYTES}")
file(WRITE "${HOSHIDICTS_KANJI_MAPPING_HEADER}"
    "#pragma once\n"
    "#include <cstddef>\n"
    "constexpr unsigned char mapping_list_data[] = {\n"
    "${HOSHIDICTS_KANJI_MAPPING_BYTES}\n"
    "};\n"
    "struct HoshidictsEmbeddedBytes {\n"
    "    constexpr const unsigned char* data() const { return mapping_list_data; }\n"
    "    constexpr std::size_t size() const { return sizeof(mapping_list_data); }\n"
    "};\n"
    "constexpr HoshidictsEmbeddedBytes mapping_list{};\n"
)

get_target_property(HOSHIDICTS_SOURCES hoshidicts SOURCES)
set(HOSHIDICTS_PATCHED_SOURCES)
foreach(HOSHIDICTS_SOURCE IN LISTS HOSHIDICTS_SOURCES)
    if(HOSHIDICTS_SOURCE STREQUAL "src/text_processor/text_processor.cpp" OR
       HOSHIDICTS_SOURCE STREQUAL "${HOSHIDICTS_TEXT_PROCESSOR_SOURCE}")
        list(APPEND HOSHIDICTS_PATCHED_SOURCES "${HOSHIDICTS_TEXT_PROCESSOR_PATCHED}")
    elseif(HOSHIDICTS_SOURCE STREQUAL "src/importer.cpp" OR
           HOSHIDICTS_SOURCE STREQUAL "${HOSHIDICTS_IMPORTER_SOURCE}")
        list(APPEND HOSHIDICTS_PATCHED_SOURCES "${HOSHIDICTS_IMPORTER_PATCHED}")
    elseif(HOSHIDICTS_SOURCE STREQUAL "src/memory/memory.cpp" OR
           HOSHIDICTS_SOURCE STREQUAL "${HOSHIDICTS_MEMORY_SOURCE}")
        list(APPEND HOSHIDICTS_PATCHED_SOURCES "${HOSHIDICTS_MEMORY_PATCHED}")
    elseif(HOSHIDICTS_SOURCE STREQUAL "src/query.cpp" OR
           HOSHIDICTS_SOURCE STREQUAL "${HOSHIDICTS_QUERY_SOURCE}")
        list(APPEND HOSHIDICTS_PATCHED_SOURCES "${HOSHIDICTS_QUERY_PATCHED}")
    elseif(HOSHIDICTS_SOURCE STREQUAL "src/json/yomitan_parser.cpp" OR
           HOSHIDICTS_SOURCE STREQUAL "${HOSHIDICTS_YOMITAN_PARSER_SOURCE}")
        list(APPEND HOSHIDICTS_PATCHED_SOURCES "${HOSHIDICTS_YOMITAN_PARSER_PATCHED}")
    else()
        list(APPEND HOSHIDICTS_PATCHED_SOURCES "${HOSHIDICTS_SOURCE}")
    endif()
endforeach()
set_property(TARGET hoshidicts PROPERTY SOURCES "${HOSHIDICTS_PATCHED_SOURCES}")
target_include_directories(hoshidicts PRIVATE
    "${HOSHIDICTS_GENERATED_DIR}"
    "${HOSHIDICTS_ROOT}/src"
    "${HOSHIDICTS_ROOT}/src/json"
    "${HOSHIDICTS_ROOT}/src/memory"
    "${HOSHIDICTS_ROOT}/src/text_processor"
)
if(MSVC)
    target_compile_options(hoshidicts PRIVATE "$<$<COMPILE_LANGUAGE:CXX>:/FI${HOSHIDICTS_RANGES_TO_HEADER}>")
else()
    target_compile_options(hoshidicts PRIVATE "$<$<COMPILE_LANGUAGE:CXX>:-include>" "$<$<COMPILE_LANGUAGE:CXX>:${HOSHIDICTS_RANGES_TO_HEADER}>")
endif()

add_library(hoshidicts_bridge STATIC
    hoshidicts_c_api.cpp
)

target_include_directories(hoshidicts_bridge PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${HOSHIDICTS_ROOT}/include"
)

target_link_libraries(hoshidicts_bridge PUBLIC
    hoshidicts
)

if(MSVC)
    target_compile_options(hoshidicts_bridge PRIVATE "$<$<COMPILE_LANGUAGE:CXX>:/utf-8>" "$<$<COMPILE_LANGUAGE:CXX>:/EHsc>")
endif()

install(TARGETS
    hoshidicts_bridge
    hoshidicts
    libzstd_static
    libdeflate_static
    utf8proc
    ARCHIVE DESTINATION lib
    LIBRARY DESTINATION lib
    RUNTIME DESTINATION bin
)
