// Read-only interpretation of the exact supplied Adventure NTSC cartridge.
// Room/sprite graphics stay in the user's ROM. No commercial masks are bundled.
#include "AtariDiorama.h"
#include <algorithm>
#include <array>
#include <chrono>
#include <map>
#include <vector>
extern "C" const uint8_t *ad_loaded_cartridge(size_t*);

namespace {
constexpr int W=160,H=210;
using Mask=std::array<uint8_t,W*H>;
std::vector<ADObject> objects;
std::vector<ADBox> boxes;
ADScene result{};
uint64_t sceneID=0,lastFrame=0;
int lastRoom=-1;
uint32_t objectLimit,boxLimit;
struct Sprite { Mask mask{}; int x=0,y=0,state=0,color=0; uint32_t rgba=0; uint64_t frame=0; bool valid=false; };
std::array<Sprite,18> cached;
struct Rect {int x,y,w,h;};
std::vector<Rect> rectangles(const Mask &mask) {
    std::vector<Rect> rects;std::map<std::pair<int,int>,int> active;
    for(int y=2;y<195;++y) {
        std::map<std::pair<int,int>,int> next;
        for(int x=0;x<W;) {
            if(!mask[y*W+x]){++x;continue;}
            int first=x;while(x<W && mask[y*W+x])++x;
            auto key=std::make_pair(first,x-first);auto it=active.find(key);int index;
            if(it==active.end()){index=int(rects.size());rects.push_back({first,y,x-first,1});}
            else {index=it->second;++rects[index].h;}
            next[key]=index;
        }
        active=std::move(next);
    }
    return rects;
}
float worldX(float x){return x/W-.5f;}
float worldZ(float y){return .75f*(y/H-.5f);}
bool emit(uint64_t id,int role,int color,uint32_t rgba,const Mask &mask,float height,float elevation,bool standing) {
    auto rects=rectangles(mask);if(rects.empty())return false;
    if(objects.size()>=objectLimit || boxes.size()+rects.size()>boxLimit){++result.dropped_objects;result.dropped_boxes+=uint32_t(rects.size());return false;}
    int x0=W,y0=H,x1=0,y1=0;
    for(auto r:rects){x0=std::min(x0,r.x);y0=std::min(y0,r.y);x1=std::max(x1,r.x+r.w);y1=std::max(y1,r.y+r.h);}
    ADObject o{};o.id=id;o.role=role;o.color_index=color;o.color_rgba=rgba;o.first_box=uint32_t(boxes.size());
    o.pixel_x=float(x0);o.pixel_y=float(y0);o.pixel_width=float(x1-x0);o.pixel_height=float(y1-y0);
    o.x=worldX(float(x0));o.y=elevation;o.z=worldZ(float(standing?y1:y0));
    uint64_t hash=14695981039346656037ULL;
    for(auto r:rects) {
        float x=(r.x-x0+r.w*.5f)/W,z=.75f*(r.y-y0+r.h*.5f)/H;
        ADBox b=standing?ADBox{x,.75f*(y1-r.y-r.h*.5f)/H,0,float(r.w)/W,.75f*r.h/H,height}:
            ADBox{x,height*.5f,z,float(r.w)/W,height,.75f*r.h/H};
        boxes.push_back(b);
        for(float v:{b.x,b.y,b.z,b.width,b.height,b.depth}) {
            auto bytes=reinterpret_cast<const uint8_t*>(&v);for(size_t i=0;i<sizeof(v);++i)hash=(hash^bytes[i])*1099511628211ULL;
        }
    }
    o.geometry_hash=o.pattern=hash;o.box_count=uint32_t(rects.size());objects.push_back(o);return true;
}
}
extern "C" void ad_reset_adventure(){objects.clear();boxes.clear();cached={};lastRoom=-1;lastFrame=0;++sceneID;}
extern "C" const ADScene *ad_reconstruct_adventure(const ADFrame *f,const ADProfile *p) {
    size_t size=0;const auto rom=ad_loaded_cartridge(&size);
    if(!rom || size!=4096 || !f->ram || !f->indices || f->width!=W || f->height!=H || f->ram[10]>30)return nullptr;
    auto read=[&](int a)->int {return a>=0xf000 && a<0x10000?rom[a-0xf000]:a>=0x80 && a<0x100?f->ram[a-0x80]:0;};
    auto word=[&](int a)->int {return read(a)|(read(a+1)<<8);};
    int room=f->ram[10],roomPointer=word(0xfe1b+room*9),graphics=f->ram[0]|(f->ram[1]<<8);
    // A frame-boundary room change may precede the next display setup. Let the
    // generic path show that transitional raster rather than label old walls.
    if(roomPointer!=graphics || roomPointer<0xf000 || roomPointer+20>=0x10000 || graphics+20>=0x10000)return nullptr;
    auto start=std::chrono::steady_clock::now();
    if(room!=lastRoom || f->number<lastFrame){ad_reset_adventure();lastRoom=room;}
    lastFrame=f->number;objects.clear();boxes.clear();result={};
    objectLimit=std::min(p->max_objects?p->max_objects:uint32_t(AD_MAX_OBJECTS),uint32_t(AD_MAX_OBJECTS));
    boxLimit=std::min(p->max_boxes?p->max_boxes:uint32_t(AD_MAX_BOXES),uint32_t(AD_MAX_BOXES));
    float depth=std::clamp(p->default_height,.004f,.15f);
    Mask playfield{},floor{},claimed{},revealed{};
    int control=read(0xfe1b+room*9+4);
    std::array<int,256> backgroundCounts{};std::array<uint32_t,256> palette{};
    for(int y=2;y<195;++y)for(int x=0;x<W;++x) {
        int row=y<19?0:1+(y-19)/32,bit=x/4;
        if(bit>=20)bit=(control&1)?39-bit:bit-20;
        int address=graphics+row*3+(bit<4?0:bit<12?1:2);
        int shift=bit<4?bit+4:bit<12?11-bit:bit-12;
        bool wall=(read(address)&(1<<shift))!=0 || ((control&128) && x==12) || ((control&64) && x==149);
        playfield[y*W+x]=wall;floor[y*W+x]=1;
        int color=f->indices[y*W+x]&254;palette[color]=f->rgba[y*W+x];
        if(!wall)++backgroundCounts[color];
    }
    int bg=int(std::max_element(backgroundCounts.begin(),backgroundCounts.end())-backgroundCounts.begin());
    emit(1,AD_PLATFORM,bg,palette[bg],floor,.003f,0,false);
    // Authored doorway recess beneath each castle portcullis. The original
    // kernel draws gate slats over solid PF pixels, but extruding that backing
    // would bury the standing gate inside a castle block in Vertical mode.
    // Keep the measured eight-pixel-wide portal footprint open as it retracts.
    if(room>=15 && room<=17)for(int id=1;id<=3;++id) {
        int dynamic=word(0xff44+id*9);
        if(read(dynamic)!=room)continue;
        int x0=read(dynamic+1)-1,y0=213-2*read(dynamic+2);
        for(int y=std::max(2,y0);y<std::min(195,y0+32);++y)
            for(int x=std::max(0,x0);x<std::min(W,x0+8);++x)playfield[y*W+x]=0;
    }
    // Explicit ball geometry stays separate even when touching a same-color wall.
    Mask player{};int px=int(f->ram[11])-2,py=213-2*int(f->ram[12]);
    for(int y=py;y<py+8;++y)for(int x=px;x<px+4;++x)
        if(x>=0 && x<W && y>=2 && y<195 && (f->indices[y*W+x]&254)!=bg)player[y*W+x]=claimed[y*W+x]=1;
    int playerColor=-1;for(int i=0;i<W*H;++i)if(player[i]){playerColor=f->indices[i]&254;break;}
    if(room!=0 && playerColor>=0)emit(2,AD_GENERIC,playerColor,palette[playerColor],player,depth*1.1f,.003f,false);
    // Capture only the two sprites actually selected by the ROM's display cache.
    // Decode their masks from the user's ROM, then intersect with visible pixels.
    // The surround (object 0) is a visibility effect, never a solid obstacle.
    std::array<bool,18> active{};
    for(int slot=0;slot<2;++slot) {
        int offset=f->ram[21+slot];if(offset%9 || offset>=162)continue;
        int id=offset/9;active[id]=true;
        int ptr=f->ram[2+slot*2]|(f->ram[3+slot*2]<<8),x0=int(f->ram[6+slot*2])-1,y0=213-2*int(f->ram[7+slot*2]);
        if(ptr<0xf000 || ptr>=0x10000)continue;
        int scale=(read(0xff44+offset+8)&7)==7?4:1;
        if(id==0) {
            // The surround reveals a local patch of an invisible maze. It is
            // not scenery. Preserve its visible floor color and reveal only
            // playfield pixels inside the currently displayed window.
            std::array<int,256> colors{};
            for(int y=std::max(2,y0);y<std::min(195,y0+64);++y)for(int x=std::max(0,x0);x<std::min(W,x0+32);++x) {
                int i=y*W+x,c=f->indices[i]&254;
                if(!playfield[i] && !player[i] && c!=bg)++colors[c];
            }
            int surroundColor=int(std::max_element(colors.begin(),colors.end())-colors.begin());
            bool visible=colors[surroundColor]>=32;Mask patch{};
            if(visible)for(int y=std::max(2,y0);y<std::min(195,y0+64);++y)for(int x=std::max(0,x0);x<std::min(W,x0+32);++x)revealed[y*W+x]=1;
            if(visible)for(int i=0;i<W*H;++i)if(revealed[i] && !playfield[i] && !player[i] && (f->indices[i]&254)==surroundColor)patch[i]=1;
            emit(3000+surroundColor,AD_PLATFORM,surroundColor,palette[surroundColor],patch,.003f,0,false);
            continue;
        }
        Sprite sprite{};sprite.x=x0;sprite.y=y0;sprite.frame=f->number;
        sprite.state=read(word(0xff44+offset+2));
        std::array<int,256> colors{};
        for(int row=0;row<96 && ptr+row<0x10000;++row) {
            int bits=read(ptr+row);if(!bits)break;
            for(int bit=0;bit<8;++bit)if(bits&(128>>bit))for(int dx=0;dx<scale;++dx)for(int dy=0;dy<2;++dy) {
                int x=(x0+bit*scale+dx)%W,y=y0+row*2+dy;
                if(x<0)x+=W;
                if(y<2 || y>=195)continue;
                int i=y*W+x,c=f->indices[i]&254;
                if(c!=bg && !player[i]){sprite.mask[i]=1;++colors[c];}
            }
        }
        sprite.color=int(std::max_element(colors.begin(),colors.end())-colors.begin());
        // Do not turn differently colored overlapping objects into this sprite.
        for(int i=0;i<W*H;++i)if(sprite.mask[i]) {
            if((f->indices[i]&254)!=sprite.color)sprite.mask[i]=0;
            else claimed[i]=1;
        }
        sprite.rgba=palette[sprite.color];sprite.valid=colors[sprite.color]>0;cached[id]=sprite;
    }
    for(int id=1;id<18;++id) {
        auto &s=cached[id];if(!s.valid)continue;
        int offset=id*9,dynamic=word(0xff44+offset);
        if(read(dynamic)!=room){s.valid=false;continue;}
        if(!active[id]) {
            // Hold a recently observed *unchanged* mask for multiplexed frames.
            // No guessed motion, old-room silhouettes or unseen object creation.
            if(f->number-s.frame>3 || read(dynamic+1)-1!=s.x || 213-2*read(dynamic+2)!=s.y || read(word(0xff44+offset+2))!=s.state){s.valid=false;continue;}
        }
        bool creature=id>=6 && id<=8 || id==14,bridge=id==10;
        emit(100+id,bridge?AD_PLATFORM:creature?AD_ACTOR:AD_SCENERY,s.color,s.rgba,s.mask,
             bridge?depth*1.7f:depth,bridge?.018f:.004f,!bridge);
    }
    // Only visible playfield pixels become walls: dark-room walls that the ROM
    // has not revealed stay hidden. Moving same-color sprites cannot add walls.
    std::map<int,Mask> walls,towers;
    for(int y=2;y<195;++y)for(int x=0;x<W;++x) {
        int i=y*W+x,c=f->indices[i]&254;
        if(!playfield[i] || (c==bg && !revealed[i]))continue;
        // Dynamic sprites with another color occlude rather than recolor walls.
        if(claimed[i] && !player[i])continue;
        bool castle=room>=15 && room<=17 && x>=40 && x<120 && y<147;
        (castle?towers:walls)[c][i]=1;
    }
    for(auto &entry:walls)emit(1000+entry.first,AD_WALL,entry.first,palette[entry.first],entry.second,depth*2.2f,.003f,false);
    for(auto &entry:towers)emit(2000+entry.first,AD_WALL,entry.first,palette[entry.first],entry.second,depth*4.5f,.003f,false);
    result.frame_number=f->number;result.scene_id=sceneID;result.object_count=uint32_t(objects.size());result.box_count=uint32_t(boxes.size());
    result.objects=objects.data();result.boxes=boxes.data();
    result.analysis_ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count();return &result;
}
