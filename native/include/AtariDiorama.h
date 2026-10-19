#ifndef ATARI_DIORAMA_H
#define ATARI_DIORAMA_H
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#ifdef _WIN32
#define AD_API __declspec(dllexport)
#else
#define AD_API __attribute__((visibility("default")))
#endif
#ifdef __cplusplus
extern "C" {
#endif
// One core instance. All calls except input and audio_read belong on one serial queue.
// Returned frame/scene/trace pointers remain valid until the next mutating call.
enum { AD_MAX_OBJECTS=1024, AD_MAX_BOXES=24000, AD_MAX_TRACE=8192 };
enum { AD_JOYSTICK=0, AD_PADDLES=1 };
enum { AD_GENERIC=0, AD_WALL=1, AD_ACTOR=2, AD_PROJECTILE=3, AD_PLATFORM=4, AD_SCENERY=5 };
typedef struct {
    uint32_t width, height;
    uint64_t number;
    double fps, sample_rate;
    const uint32_t *rgba; // byte order R G B A, tightly packed
    const uint8_t *indices; // raw TIA palette indices, same crop as rgba
    const uint8_t *ram; // 128 RIOT bytes, snapshot at frame boundary
} ADFrame;
typedef struct {
    uint32_t cycle; // CPU cycles within core frame (3 TIA clocks / CPU cycle)
    uint16_t address;
    uint8_t value, reserved;
} ADTIAWrite;
typedef struct {
    int32_t color_index; // -1 means any; TIA palette index ignores low bit
    int32_t role;
    float min_x, max_x, min_y, max_y; // normalized component centroid
    float min_width, max_width, min_height, max_height; // normalized dimensions
    float height, elevation; // world units: full game width = 1
    uint64_t pattern; // optional translation-invariant exact binary mask hash
} ADRule;
typedef struct {
    float hud_top, hud_bottom; // normalized excluded bands; HUD remains available in frame
    float default_height;
    int32_t background_index; // -1 = dominant border color
    int32_t side_view; // x/y upright, thickness in z; otherwise x/z tabletop
    uint32_t max_objects, max_boxes;
    int32_t scene_ram_offset; // -1 disabled; room transition resets tracking IDs
    uint32_t rule_count;
    const ADRule *rules;
} ADProfile;
typedef struct {
    float x,y,z, width,height,depth; // component-local box center and dimensions
} ADBox;
typedef struct {
    uint64_t id, geometry_hash, pattern;
    uint32_t color_rgba, first_box, box_count;
    int32_t role, color_index;
    float x,y,z; // object origin; static local mesh is reused as this changes
    float pixel_x,pixel_y,pixel_width,pixel_height;
} ADObject;
typedef struct {
    uint64_t frame_number, scene_id;
    uint32_t object_count, box_count, dropped_objects, dropped_boxes;
    double analysis_ms;
    const ADObject *objects;
    const ADBox *boxes;
} ADScene;
AD_API bool ad_initialize(const char *storage_directory);
AD_API bool ad_load_rom(const uint8_t *bytes, size_t size, const char *filename);
AD_API void ad_shutdown(void);
AD_API const char *ad_last_error(void);
AD_API const ADFrame *ad_run_frame(void);
AD_API const ADFrame *ad_current_frame(void);
AD_API void ad_set_input(uint32_t port, uint16_t buttons, int16_t paddle_a, int16_t paddle_b);
AD_API void ad_set_controller(uint32_t port, uint32_t type);
AD_API void ad_reset(void);
AD_API size_t ad_state_size(void);
AD_API bool ad_save_state(uint8_t *data, size_t size);
AD_API bool ad_load_state(const uint8_t *data, size_t size);
AD_API size_t ad_audio_read(float *stereo, size_t frames);
// Network tap: emulator queue only, independent of the realtime output consumer.
AD_API void ad_audio_streaming(bool enabled);
AD_API size_t ad_audio_stream_read(int16_t *stereo, size_t frames);
// Guest playback uses the normal bounded audio ring without loading a cartridge.
AD_API void ad_audio_receive(const int16_t *stereo, size_t frames);
AD_API void ad_audio_clear(void);
AD_API uint64_t ad_audio_dropped(void);
AD_API const ADTIAWrite *ad_tia_writes(uint32_t *count, uint32_t *dropped);
AD_API const ADScene *ad_reconstruct(const ADFrame *frame, const ADProfile *profile);
AD_API void ad_reset_reconstruction(void);
#ifdef __cplusplus
}
#endif
#endif
