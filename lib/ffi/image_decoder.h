#ifndef IMAGE_DECODER_H_
#define IMAGE_DECODER_H_

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>

#ifdef _WIN32
#define DECODER_EXPORT __declspec(dllexport)
#else
#define DECODER_EXPORT __attribute__((visibility("default")))
#endif

typedef struct ImageDecoderContext ImageDecoderContext;

DECODER_EXPORT ImageDecoderContext* init_decoder(const char* file_path, bool crop_borders, int* out_width, int* out_height);

DECODER_EXPORT bool decode_region(ImageDecoderContext* ctx, int left, int top, int right, int bottom, int sample_size, unsigned char* out_rgba_buffer);

DECODER_EXPORT void free_decoder(ImageDecoderContext* ctx);

// Where the region init_decoder reported lies in the whole image: its offset
// when borders were cropped, and the whole image's size.
DECODER_EXPORT void get_decoder_crop(ImageDecoderContext* ctx, int* out_left, int* out_top, int* out_full_width, int* out_full_height);

#ifdef __cplusplus
}
#endif

#endif // IMAGE_DECODER_H_
