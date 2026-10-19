#include "AtariDiorama.h"
#include "libretro.h"
#include <algorithm>
#include <array>
#include <atomic>
#include <cstdarg>
#include <cstdio>
#include <cstring>
#include <map>
#include <string>
#include <vector>
extern "C" void ad_core_set_controller(unsigned, unsigned);

namespace {
bool initialized=false, loaded=false;
std::string error, directory, romName;
std::vector<uint8_t> rom;
std::map<std::string,std::string> options;
retro_pixel_format pixelFormat=RETRO_PIXEL_FORMAT_0RGB1555;
ADFrame frame{};
std::array<uint32_t,160*320> pixels{};
std::array<uint8_t,160*320> indices{};
std::array<uint8_t,128> ram{};
std::array<ADTIAWrite,AD_MAX_TRACE> trace{};
uint32_t traceCount=0,traceDropped=0;
std::atomic<uint16_t> buttons[2];
std::atomic<int16_t> paddles[2][2];
int controllerTypes[2]={-1,-1};
constexpr uint64_t audioCapacity=32768;
std::array<float,audioCapacity*2> audio{};
std::atomic<uint64_t> audioHead{0},audioTail{0},audioDropped{0};
std::atomic<bool> flushAudio{false};
bool streamAudio=false;
std::vector<int16_t> streamSamples;
void logMessage(retro_log_level level,const char *fmt,...) {
    if(level<RETRO_LOG_WARN)return;
    char buffer[2048];va_list args;va_start(args,fmt);vsnprintf(buffer,sizeof(buffer),fmt,args);va_end(args);
    // Keep useful core diagnostics without printing ROM data.
    if(level>=RETRO_LOG_ERROR) error=buffer;
}
bool environment(unsigned command,void *data) {
    switch(command) {
    case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT:
        pixelFormat=*static_cast<retro_pixel_format*>(data);
        return pixelFormat==RETRO_PIXEL_FORMAT_XRGB8888 || pixelFormat==RETRO_PIXEL_FORMAT_RGB565 || pixelFormat==RETRO_PIXEL_FORMAT_0RGB1555;
    case RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION: *static_cast<unsigned*>(data)=0;return true;
    case RETRO_ENVIRONMENT_SET_VARIABLES: {
        auto v=static_cast<retro_variable*>(data);
        for(;v && v->key;++v) {
            std::string text=v->value?v->value:"";auto pos=text.find("; ");
            if(pos!=std::string::npos) {auto value=text.substr(pos+2);options[v->key]=value.substr(0,value.find('|'));}
        }
        return true;
    }
    case RETRO_ENVIRONMENT_GET_VARIABLE: {
        auto v=static_cast<retro_variable*>(data);auto it=options.find(v->key);
        v->value=it==options.end()?nullptr:it->second.c_str();return it!=options.end();
    }
    case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE: *static_cast<bool*>(data)=false;return true;
    case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
    case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:
        *static_cast<const char**>(data)=directory.c_str();return true;
    case RETRO_ENVIRONMENT_GET_LOG_INTERFACE: static_cast<retro_log_callback*>(data)->log=logMessage;return true;
    case RETRO_ENVIRONMENT_GET_CAN_DUPE: *static_cast<bool*>(data)=true;return true;
    case RETRO_ENVIRONMENT_GET_INPUT_BITMASKS: return true;
    case RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME:
    case RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS:
    case RETRO_ENVIRONMENT_SET_CONTROLLER_INFO:
    case RETRO_ENVIRONMENT_SET_PERFORMANCE_LEVEL: return true;
    case RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO: {
        auto av=static_cast<retro_system_av_info*>(data);frame.fps=av->timing.fps;frame.sample_rate=av->timing.sample_rate;return true;
    }
    default: return false;
    }
}
void video(const void *data,unsigned w,unsigned h,size_t pitch) {
    if(!data)return;
    if(w>160 || h>320 || !w || !h) {error="Core returned invalid framebuffer dimensions";return;}
    frame.width=w;frame.height=h;
    for(unsigned y=0;y<h;++y) for(unsigned x=0;x<w;++x) {
        auto row=static_cast<const uint8_t*>(data)+y*pitch;uint32_t r,g,b;
        if(pixelFormat==RETRO_PIXEL_FORMAT_XRGB8888) {
            uint32_t c;std::memcpy(&c,row+x*4,4);r=(c>>16)&255;g=(c>>8)&255;b=c&255;
        } else {
            uint16_t c;std::memcpy(&c,row+x*2,2);
            r=(c>>(pixelFormat==RETRO_PIXEL_FORMAT_RGB565?11:10))&31;
            g=(c>>5)&(pixelFormat==RETRO_PIXEL_FORMAT_RGB565?63:31);b=c&31;
            r=(r*255+15)/31;b=(b*255+15)/31;
            g=pixelFormat==RETRO_PIXEL_FORMAT_RGB565?(g*255+31)/63:(g*255+15)/31;
        }
        pixels[y*w+x]=r|(g<<8)|(b<<16)|0xff000000u;
    }
}
size_t audioBatch(const int16_t *data,size_t frames) {
    if(streamAudio) {
        constexpr size_t limit=8192*2;
        size_t samples=std::min(frames*2,limit);
        if(streamSamples.size()+samples>limit)streamSamples.clear();
        streamSamples.insert(streamSamples.end(),data,data+samples);
    }
    uint64_t head=audioHead.load(std::memory_order_relaxed),tail=audioTail.load(std::memory_order_acquire);
    size_t writable=std::min(frames,size_t(audioCapacity-(head-tail)));
    for(size_t i=0;i<writable;++i) {
        auto j=((head+i)%audioCapacity)*2;
        audio[j]=data[i*2]/32768.0f;audio[j+1]=data[i*2+1]/32768.0f;
    }
    audioHead.store(head+writable,std::memory_order_release);
    audioDropped.fetch_add(frames-writable,std::memory_order_relaxed);return frames;
}
void audioSample(int16_t l,int16_t r) {const int16_t v[2]={l,r};audioBatch(v,1);}
void poll() {}
int16_t input(unsigned port,unsigned device,unsigned index,unsigned id) {
    if(port>=2)return 0;
    if(device==RETRO_DEVICE_JOYPAD) {
        uint16_t mask=buttons[port].load(std::memory_order_relaxed);
        return id==RETRO_DEVICE_ID_JOYPAD_MASK?int16_t(mask):(id<16 && (mask&(1u<<id))?1:0);
    }
    if(device==RETRO_DEVICE_ANALOG && index==RETRO_DEVICE_INDEX_ANALOG_LEFT && id<2)
        return paddles[port][id].load(std::memory_order_relaxed);
    return 0;
}
}
extern "C" void ad_capture_tia_write(uint32_t cycle,uint16_t address,uint8_t value) {
    if(traceCount<trace.size())trace[traceCount++]={cycle,uint16_t(address&63),value,0};else ++traceDropped;
}
extern "C" void ad_capture_indices(const uint8_t *data,unsigned w,unsigned h) {
    if(data && w<=160 && h<=320)std::memcpy(indices.data(),data,w*h);
}
extern "C" bool ad_initialize(const char *storage) {
    if(initialized)return true;
    directory=storage?storage:".";error.clear();
    retro_set_environment(environment);retro_set_video_refresh(video);
    retro_set_audio_sample(audioSample);retro_set_audio_sample_batch(audioBatch);
    retro_set_input_poll(poll);retro_set_input_state(input);retro_init();
    options["stella2014_color_depth"]="24bit";
    initialized=true;frame.rgba=pixels.data();frame.indices=indices.data();frame.ram=ram.data();return true;
}
extern "C" bool ad_load_rom(const uint8_t *bytes,size_t size,const char *filename) {
    error.clear();
    if(!initialized || !bytes || size<2048 || size>1024*1024) {error="Expected a 2 KB–1 MB raw Atari 2600 ROM";return false;}
    if(loaded) {retro_unload_game();loaded=false;}
    rom.assign(bytes,bytes+size);romName=filename?filename:"cartridge.a26";
    retro_game_info game{romName.c_str(),rom.data(),rom.size(),nullptr};
    if(!retro_load_game(&game)) {error="Stella rejected this cartridge";return false;}
    loaded=true;frame.number=0;frame.width=frame.height=0;
    retro_system_av_info av{};retro_get_system_av_info(&av);
    frame.fps=av.timing.fps;frame.sample_rate=av.timing.sample_rate;
    for(unsigned port=0;port<2;++port){controllerTypes[port]=-1;ad_set_input(port,0,0,0);ad_set_controller(port,AD_JOYSTICK);}
    flushAudio.store(true,std::memory_order_release);ad_reset_reconstruction();return true;
}
extern "C" void ad_shutdown() {
    if(loaded)retro_unload_game();if(initialized)retro_deinit();initialized=loaded=false;
    rom.clear();flushAudio.store(true,std::memory_order_release);ad_reset_reconstruction();
}
extern "C" const char *ad_last_error() {return error.c_str();}
// Private renderer access on the emulator queue. Never exposed to network peers.
// Game-specific adapters read graphics from the user's loaded cartridge rather
// than distributing commercial sprite/room data in the application.
extern "C" const uint8_t *ad_loaded_cartridge(size_t *size) {
    *size=loaded?rom.size():0;return loaded?rom.data():nullptr;
}
extern "C" const ADFrame *ad_run_frame() {
    if(!loaded)return nullptr;
    traceCount=traceDropped=0;retro_run();++frame.number;
    auto memory=retro_get_memory_data(RETRO_MEMORY_SYSTEM_RAM);
    if(memory)std::memcpy(ram.data(),memory,std::min(ram.size(),retro_get_memory_size(RETRO_MEMORY_SYSTEM_RAM)));
    retro_system_av_info av{};retro_get_system_av_info(&av);frame.fps=av.timing.fps;frame.sample_rate=av.timing.sample_rate;
    return &frame;
}
extern "C" const ADFrame *ad_current_frame() {return loaded?&frame:nullptr;}
extern "C" void ad_set_input(uint32_t port,uint16_t mask,int16_t a,int16_t b) {
    if(port<2){buttons[port].store(mask,std::memory_order_relaxed);paddles[port][0].store(a);paddles[port][1].store(b);}
}
extern "C" void ad_set_controller(uint32_t port,uint32_t type) {
    if(initialized && port<2 && controllerTypes[port]!=int(type)) {
        retro_set_controller_port_device(port,type==AD_PADDLES?RETRO_DEVICE_SUBCLASS(RETRO_DEVICE_ANALOG,1):RETRO_DEVICE_JOYPAD);
        if(loaded)ad_core_set_controller(port,type);
        controllerTypes[port]=int(type);
    }
}
extern "C" void ad_reset() {if(loaded){retro_reset();ad_reset_reconstruction();flushAudio.store(true);}}
extern "C" size_t ad_state_size(){return loaded?retro_serialize_size():0;}
extern "C" bool ad_save_state(uint8_t *data,size_t size) {return loaded && data && size==ad_state_size() && retro_serialize(data,size);}
extern "C" bool ad_load_state(const uint8_t *data,size_t size) {
    if(!loaded || !data || size!=ad_state_size() || !retro_unserialize(data,size)) {error="Invalid state or incompatible core version";return false;}
    ad_reset_reconstruction();flushAudio.store(true);return true;
}
extern "C" size_t ad_audio_read(float *output,size_t frames) {
    if(!output)return 0;
    uint64_t tail=audioTail.load(std::memory_order_relaxed),head=audioHead.load(std::memory_order_acquire);
    if(flushAudio.exchange(false,std::memory_order_acq_rel))tail=head;
    size_t count=std::min(frames,size_t(head-tail));
    for(size_t i=0;i<count;++i){auto j=((tail+i)%audioCapacity)*2;output[i*2]=audio[j];output[i*2+1]=audio[j+1];}
    std::fill(output+count*2,output+frames*2,0.0f);audioTail.store(tail+count,std::memory_order_release);return count;
}
extern "C" uint64_t ad_audio_dropped(){return audioDropped.load();}
extern "C" void ad_audio_streaming(bool enabled){streamAudio=enabled;streamSamples.clear();streamSamples.reserve(8192*2);}
extern "C" size_t ad_audio_stream_read(int16_t *output,size_t frames){
    if(!output)return 0;
    size_t n=std::min(frames,streamSamples.size()/2);
    std::copy_n(streamSamples.begin(),n*2,output);
    streamSamples.erase(streamSamples.begin(),streamSamples.begin()+n*2);return n;
}
extern "C" void ad_audio_receive(const int16_t *data,size_t frames){if(data && frames<=8192)audioBatch(data,frames);}
extern "C" void ad_audio_clear(){flushAudio.store(true,std::memory_order_release);}
extern "C" const ADTIAWrite *ad_tia_writes(uint32_t *count,uint32_t *dropped) {
    if(count)*count=traceCount;if(dropped)*dropped=traceDropped;return trace.data();
}
