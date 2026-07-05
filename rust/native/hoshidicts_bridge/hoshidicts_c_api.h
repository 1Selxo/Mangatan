#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct HoshiBytes {
  uint8_t* data;
  size_t len;
} HoshiBytes;

char* hoshidicts_import_dictionary_json(const char* zip_path, const char* output_dir, bool low_ram);
void* hoshidicts_create_lookup_session(void);
void hoshidicts_destroy_lookup_session(void* session);
char* hoshidicts_rebuild_query_json(void* session,
                                    const char* const* term_paths,
                                    size_t term_count,
                                    const char* const* freq_paths,
                                    size_t freq_count,
                                    const char* const* pitch_paths,
                                    size_t pitch_count);
char* hoshidicts_lookup_json(void* session, const char* text, int max_results, size_t scan_length);
char* hoshidicts_styles_json(void* session);
HoshiBytes hoshidicts_get_media_file(void* session, const char* dict_name, const char* media_path);
void hoshidicts_free_string(char* value);
void hoshidicts_free_bytes(HoshiBytes value);

#ifdef __cplusplus
}
#endif
