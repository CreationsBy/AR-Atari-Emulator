// Complete original-frame voxel relief for the exact-hash Ice Hockey profile.
// Every box footprint comes from visible pixels, including score/time/logo.
// No authored rink, posts, nets, sprite poses, hidden puck or RAM reconstruction.
#include "AtariDiorama.h"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <map>
#include <vector>

namespace {
struct Component {
    int x0,y0,x1,y1,color,band,role=AD_GENERIC;
    uint32_t rgba;
    std::vector<int> pixels;
};
std::vector<ADObject> objects,previous;
std::vector<ADBox> boxes;
ADScene result{};
uint64_t sceneID=1,nextID=1;
int lastWidth=0,lastHeight=0;
std::vector<uint8_t> seen;
uint64_t byteHash(uint64_t hash,uint8_t byte){return (hash^byte)*1099511628211ULL;}
int band(int y){return y<28?0:y>=188?2:1;}
}
extern "C" void ad_reset_ice_hockey(){
    objects.clear();previous.clear();boxes.clear();lastWidth=lastHeight=0;nextID=1;++sceneID;
}
extern "C" const ADScene *ad_reconstruct_ice_hockey(const ADFrame *f,const ADProfile *p) {
    if(!f->indices || f->width!=160 || f->height!=210)return nullptr;
    const int w=int(f->width),h=int(f->height),n=w*h;
    auto start=std::chrono::steady_clock::now();
    if(w!=lastWidth || h!=lastHeight){ad_reset_ice_hockey();lastWidth=w;lastHeight=h;}
    result={};previous=objects;objects.clear();boxes.clear();seen.assign(n,0);
    std::vector<Component> components;
    for(int y=0;y<h;++y)for(int x=0;x<w;++x) {
        int seed=y*w+x;if(seen[seed])continue;
        Component c{x,y,x,y,f->indices[seed]&254,band(y),AD_GENERIC,f->rgba[seed],{seed}};
        seen[seed]=1;
        for(size_t q=0;q<c.pixels.size();++q) {
            int i=c.pixels[q],px=i%w,py=i/w;
            c.x0=std::min(c.x0,px);c.y0=std::min(c.y0,py);c.x1=std::max(c.x1,px);c.y1=std::max(c.y1,py);
            for(int j:{px>0?i-1:-1,px+1<w?i+1:-1,py>0?i-w:-1,py+1<h?i+w:-1})
                if(j>=0 && !seen[j] && band(j/w)==c.band && (f->indices[j]&254)==c.color && f->rgba[j]==c.rgba){seen[j]=1;c.pixels.push_back(j);}
        }
        if(c.color==0)c.role=c.band==1 && c.pixels.size()<=16 && c.x0>=32 && c.x1<128 && c.y0>=42 && c.y1<187?AD_PROJECTILE:AD_PLATFORM;
        else if(c.band!=1)c.role=AD_SCENERY;
        else c.role=c.color==10?AD_PLATFORM:AD_ACTOR;
        components.push_back(std::move(c));
    }
    uint32_t objectLimit=std::min(p->max_objects?p->max_objects:uint32_t(AD_MAX_OBJECTS),uint32_t(AD_MAX_OBJECTS));
    uint32_t boxLimit=std::min(p->max_boxes?p->max_boxes:uint32_t(AD_MAX_BOXES),uint32_t(AD_MAX_BOXES));
    float thickness=std::clamp(p->default_height,.001f,.12f);
    std::vector<bool> used(previous.size());
    for(auto &c:components) {
        int cw=c.x1-c.x0+1,ch=c.y1-c.y0+1;
        std::vector<uint8_t> mask(cw*ch);
        for(int i:c.pixels)mask[(i/w-c.y0)*cw+i%w-c.x0]=1;
        uint64_t pattern=14695981039346656037ULL;
        for(int value:{cw,ch})for(int shift=0;shift<32;shift+=8)pattern=byteHash(pattern,uint8_t(value>>shift));
        for(auto value:mask)pattern=byteHash(pattern,value);
        struct Rect{int x,y,w,h;};std::vector<Rect> rectangles;
        std::map<std::pair<int,int>,int> active;
        for(int y=0;y<ch;++y) {
            std::map<std::pair<int,int>,int> next;
            for(int x=0;x<cw;) {
                if(!mask[y*cw+x]){++x;continue;}
                int first=x;while(x<cw && mask[y*cw+x])++x;
                auto key=std::make_pair(first,x-first);auto old=active.find(key);int index;
                if(old==active.end()){index=int(rectangles.size());rectangles.push_back({first,y,x-first,1});}
                else{index=old->second;++rectangles[index].h;}
                next[key]=index;
            }
            active=std::move(next);
        }
        if(objects.size()>=objectLimit || boxes.size()+rectangles.size()>boxLimit){++result.dropped_objects;result.dropped_boxes+=uint32_t(rectangles.size());continue;}
        ADObject o{};o.pattern=pattern;o.color_index=c.color;o.color_rgba=c.rgba;o.role=c.role;
        o.pixel_x=float(c.x0);o.pixel_y=float(c.y0);o.pixel_width=float(cw);o.pixel_height=float(ch);
        o.x=float(c.x0)/w-.5f;o.z=.75f*(float(c.y0)/h-.5f);
        int best=-1;float distance=40;
        for(size_t j=0;j<previous.size();++j)if(!used[j] && previous[j].role==o.role && previous[j].color_index==o.color_index && band(int(previous[j].pixel_y))==c.band) {
            auto &old=previous[j];float d=std::abs(old.pixel_x-o.pixel_x)+std::abs(old.pixel_y-o.pixel_y)+.5f*(std::abs(old.pixel_width-o.pixel_width)+std::abs(old.pixel_height-o.pixel_height));
            if(d<distance){distance=d;best=int(j);}
        }
        if(best>=0){o.id=previous[best].id;used[best]=true;}else o.id=nextID++;
        float height=c.color==0 && c.role!=AD_PROJECTILE?.001f:c.role==AD_PLATFORM?.003f:thickness;
        o.first_box=uint32_t(boxes.size());
        for(auto r:rectangles)boxes.push_back({(r.x+r.w*.5f)/w,height*.5f,.75f*(r.y+r.h*.5f)/h,float(r.w)/w,height,.75f*r.h/h});
        o.box_count=uint32_t(rectangles.size());uint64_t geometry=pattern;
        for(float value:{height,float(w),float(h)}) {
            auto bytes=reinterpret_cast<const uint8_t*>(&value);for(size_t i=0;i<sizeof(value);++i)geometry=byteHash(geometry,bytes[i]);
        }
        o.geometry_hash=geometry;objects.push_back(o);
    }
    result.frame_number=f->number;result.scene_id=sceneID;result.object_count=uint32_t(objects.size());result.box_count=uint32_t(boxes.size());
    result.objects=objects.data();result.boxes=boxes.data();result.analysis_ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count();return &result;
}
