#include "AtariDiorama.h"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <map>
#include <tuple>
#include <vector>
extern "C" const ADScene *ad_reconstruct_ice_hockey(const ADFrame*, const ADProfile*);
extern "C" void ad_reset_ice_hockey();

namespace {
struct Component {
    int x0,y0,x1,y1,color;
    uint32_t rgba;
    std::vector<int> pixels;
    uint64_t pattern=0;
    int role=AD_GENERIC;
    float height=0.025f, elevation=0;
};
std::vector<ADObject> objects, previous;
std::vector<ADBox> boxes;
ADScene result{};
uint64_t nextID=1, sceneID=0;
int previousRoom=-1, previousWidth=0, previousHeight=0;
uint64_t hashByte(uint64_t h, uint8_t b) { return (h^b)*1099511628211ULL; }
uint64_t hashMask(const Component &c, int width) {
    const int w=c.x1-c.x0+1, h=c.y1-c.y0+1;
    std::vector<uint8_t> mask(w*h);
    for(int p:c.pixels) mask[(p/width-c.y0)*w+(p%width-c.x0)]=1;
    uint64_t hash=14695981039346656037ULL;
    for(int v:{w,h}) for(int s=0;s<32;s+=8) hash=hashByte(hash,uint8_t(v>>s));
    for(auto b:mask) hash=hashByte(hash,b);
    return hash;
}
bool matches(const Component &c, const ADRule &r, int w,int h) {
    float x=(c.x0+c.x1+1)*0.5f/w, y=(c.y0+c.y1+1)*0.5f/h;
    float cw=float(c.x1-c.x0+1)/w,ch=float(c.y1-c.y0+1)/h;
    return (r.color_index<0 || (c.color&254)==(r.color_index&254)) &&
        x>=r.min_x && x<=r.max_x && y>=r.min_y && y<=r.max_y &&
        cw>=r.min_width && cw<=r.max_width && ch>=r.min_height && ch<=r.max_height &&
        (!r.pattern || r.pattern==c.pattern);
}
}
extern "C" void ad_reset_reconstruction() {
    ad_reset_ice_hockey();
    objects.clear(); previous.clear(); boxes.clear(); previousRoom=-1;
    previousWidth=previousHeight=0; ++sceneID;
}
extern "C" const ADScene *ad_reconstruct(const ADFrame *f,const ADProfile *p) {
    auto start=std::chrono::steady_clock::now();
    result={};
    if(!f || !p || !f->rgba || !f->width || !f->height || f->width>512 || f->height>512)
        return &result;
    if(p->adapter==1) if(auto scene=ad_reconstruct_ice_hockey(f,p))return scene;
    int w=int(f->width),h=int(f->height),n=w*h;
    int top=std::clamp(int(p->hud_top*h),0,h), bottom=std::clamp(h-int(p->hud_bottom*h),top,h);
    int room=p->scene_ram_offset>=0 && p->scene_ram_offset<128 && f->ram ? f->ram[p->scene_ram_offset] : -1;
    if(room!=previousRoom || w!=previousWidth || h!=previousHeight) {
        ad_reset_reconstruction(); previousRoom=room; previousWidth=w; previousHeight=h;
    }
    previous=objects; objects.clear(); boxes.clear();
    auto colorAt=[&](int i)->int { return f->indices ? f->indices[i]&254 : int(f->rgba[i]&0x00ffffff); };
    int background=p->background_index;
    if(background<0 || !f->indices) {
        std::map<int,int> border;
        for(int y=top;y<bottom;++y) { ++border[colorAt(y*w)]; ++border[colorAt(y*w+w-1)]; }
        for(int x=0;x<w && top<bottom;++x) { ++border[colorAt(top*w+x)]; ++border[colorAt((bottom-1)*w+x)]; }
        int best=-1; for(auto &v:border) if(v.second>best) {best=v.second; background=v.first;}
    } else background &=254;
    std::vector<uint8_t> seen(n);
    std::vector<Component> components;
    for(int y=top;y<bottom;++y) for(int x=0;x<w;++x) {
        int seed=y*w+x,color=colorAt(seed);
        if(seen[seed] || color==background) continue;
        Component c{x,y,x,y,color,f->rgba[seed],{seed}};
        seen[seed]=1;
        for(size_t q=0;q<c.pixels.size();++q) {
            int i=c.pixels[q],px=i%w,py=i/w;
            c.x0=std::min(c.x0,px);c.x1=std::max(c.x1,px);c.y0=std::min(c.y0,py);c.y1=std::max(c.y1,py);
            const int neighbors[4]={px>0?i-1:-1,px+1<w?i+1:-1,py>top?i-w:-1,py+1<bottom?i+w:-1};
            for(int j:neighbors) if(j>=0 && !seen[j] && colorAt(j)==color) {seen[j]=1;c.pixels.push_back(j);}
        }
        c.pattern=hashMask(c,w); c.height=std::clamp(p->default_height,0.001f,0.5f);
        // Generic roles are explicitly heuristic. They never feed back into emulation.
        if(c.pixels.size()>size_t(w*h/30)) { c.role=AD_WALL;c.height*=2; }
        else if(c.pixels.size()<16) { c.role=AD_PROJECTILE;c.height*=0.7f; }
        else c.role=AD_ACTOR;
        for(uint32_t r=0;p->rules && r<std::min(p->rule_count,128u);++r) if(matches(c,p->rules[r],w,h)) {
            c.role=p->rules[r].role;c.height=std::clamp(p->rules[r].height,0.001f,0.5f);
            c.elevation=std::clamp(p->rules[r].elevation,-0.5f,1.0f);break;
        }
        components.push_back(std::move(c));
    }
    const uint32_t objectLimit=std::min(p->max_objects?p->max_objects:uint32_t(AD_MAX_OBJECTS),uint32_t(AD_MAX_OBJECTS));
    const uint32_t boxLimit=std::min(p->max_boxes?p->max_boxes:uint32_t(AD_MAX_BOXES),uint32_t(AD_MAX_BOXES));
    std::vector<bool> used(previous.size());
    for(const auto &c:components) {
        if(objects.size()>=objectLimit) {++result.dropped_objects;continue;}
        ADObject obj{};
        obj.pattern=c.pattern; obj.color_index=c.color; obj.color_rgba=c.rgba;obj.role=c.role;
        obj.pixel_x=float(c.x0);obj.pixel_y=float(c.y0);obj.pixel_width=float(c.x1-c.x0+1);obj.pixel_height=float(c.y1-c.y0+1);
        // Pixel aspect ratio ~2:1 in NTSC. Total depth is 0.75 of width, independent of crop.
        obj.x=float(c.x0)/w-0.5f;
        obj.y=p->side_view ? 0.75f*(1.0f-float(c.y0)/h) : c.elevation;
        obj.z=p->side_view ? c.elevation : 0.75f*(float(c.y0)/h-0.5f);
        float distance=40.0f; int best=-1;
        for(size_t k=0;k<previous.size();++k) if(!used[k] && previous[k].role==obj.role && previous[k].color_index==obj.color_index) {
            auto &old=previous[k];
            float d=std::abs(old.pixel_x-obj.pixel_x)+std::abs(old.pixel_y-obj.pixel_y)+
                0.5f*(std::abs(old.pixel_width-obj.pixel_width)+std::abs(old.pixel_height-obj.pixel_height));
            if(d<distance) {distance=d;best=int(k);}
        }
        if(best>=0) {obj.id=previous[best].id;used[best]=true;} else obj.id=nextID++;
        obj.first_box=uint32_t(boxes.size());
        // Horizontal runs merge vertically only when their exact extents agree.
        // Holes, sprite silhouettes, detached bricks and independent heights survive.
        int cw=c.x1-c.x0+1,ch=c.y1-c.y0+1;
        std::vector<uint8_t> mask(cw*ch);
        for(int i:c.pixels) mask[(i/w-c.y0)*cw+(i%w-c.x0)]=1;
        struct Rect{int x,y,w,h;};std::vector<Rect> rects;
        std::map<std::pair<int,int>,int> active;
        for(int y=0;y<ch;++y) {
            std::map<std::pair<int,int>,int> next;
            for(int x=0;x<cw;) {
                if(!mask[y*cw+x]) {++x;continue;}
                int first=x;while(x<cw && mask[y*cw+x])++x;
                auto key=std::make_pair(first,x-first);auto it=active.find(key);
                int index;
                if(it!=active.end()) {index=it->second;++rects[index].h;}
                else {index=int(rects.size());rects.push_back({first,y,x-first,1});}
                next[key]=index;
            }
            active=std::move(next);
        }
        if(boxes.size()+rects.size()>boxLimit) {
            ++result.dropped_objects;result.dropped_boxes+=uint32_t(rects.size());continue;
        }
        for(auto &r:rects) {
            float rx=(r.x+r.w*0.5f)/w, ry=0.75f*(r.y+r.h*0.5f)/h;
            float rw=float(r.w)/w,rh=0.75f*r.h/h;
            if(p->side_view) boxes.push_back({rx,-ry,c.height*0.5f,rw,rh,c.height});
            else boxes.push_back({rx,c.height*0.5f,ry,rw,c.height,rh});
        }
        obj.box_count=uint32_t(boxes.size())-obj.first_box;
        uint64_t gh=c.pattern;
        for(float v:{c.height,c.elevation,float(p->side_view),float(w),float(h)}) {
            auto b=reinterpret_cast<const uint8_t*>(&v);for(size_t j=0;j<sizeof(v);++j)gh=hashByte(gh,b[j]);
        }
        obj.geometry_hash=gh; objects.push_back(obj);
    }
    result.frame_number=f->number;result.scene_id=sceneID;
    result.object_count=uint32_t(objects.size());result.box_count=uint32_t(boxes.size());
    result.objects=objects.data();result.boxes=boxes.data();
    result.analysis_ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count();
    return &result;
}
