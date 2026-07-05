cmake_minimum_required(VERSION 3.22.1)

project(mangayomi_hoshidicts_bridge LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(NOT DEFINED MANGAYOMI_PROJECT_ROOT)
    message(FATAL_ERROR "MANGAYOMI_PROJECT_ROOT must point to the Mangayomi workspace root")
endif()

set(HOSHIDICTS_ROOT "${MANGAYOMI_PROJECT_ROOT}/third_party/hoshidicts")
set(HOSHIDICTS_GENERATED_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated")

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
set(HOSHIDICTS_KANJI_MAPPING_HEADER "${HOSHIDICTS_GENERATED_DIR}/hoshidicts_full_list_embedded.hpp")

file(MAKE_DIRECTORY "${HOSHIDICTS_GENERATED_DIR}")
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
    else()
        list(APPEND HOSHIDICTS_PATCHED_SOURCES "${HOSHIDICTS_SOURCE}")
    endif()
endforeach()
set_property(TARGET hoshidicts PROPERTY SOURCES "${HOSHIDICTS_PATCHED_SOURCES}")
target_include_directories(hoshidicts PRIVATE
    "${HOSHIDICTS_GENERATED_DIR}"
    "${HOSHIDICTS_ROOT}/src/text_processor"
)

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
