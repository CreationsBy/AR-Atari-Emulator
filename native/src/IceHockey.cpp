// Read-only interpretation of exact-hash Activision Ice Hockey NTSC captures.
// Four sorted raster slots: X at RIOT offsets $39..$3c; inverted head Y at
// $35..$38. These are renderer inputs, never replacement game physics.
#include "AtariDiorama.h"
#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <map>
#include <vector>

namespace {
std::vector<ADObject> objects;
std::vector<ADBox> boxes;
ADScene result{};
uint64_t sceneID=1, nextPlayerID=1;
struct Player { int x,y,team; uint64_t id; };
std::vector<Player> previous;
uint64_t hash(const std::vector<ADBox>& geometry) {
    uint64_t value=14695981039346656037ULL;
    for(const auto &box:geometry)for(float f:{box.x,box.y,box.z,box.width,box.height,box.depth}) {
        auto bytes=reinterpret_cast<const uint8_t*>(&f);
        for(size_t i=0;i<sizeof(f);++i)value=(value^bytes[i])*1099511628211ULL;
    }
    return value;
}
uint32_t objectLimit,boxLimit;
bool emit(uint64_t id,int role,int color,uint32_t rgba,float x,float y,float z,
          float px,float py,float pw,float ph,const std::vector<ADBox>& geometry) {
    if(geometry.empty())return false;
    if(objects.size()>=objectLimit || boxes.size()+geometry.size()>boxLimit) {
        ++result.dropped_objects;result.dropped_boxes+=uint32_t(geometry.size());return false;
    }
    ADObject o{};o.id=id;o.role=role;o.color_index=color;o.color_rgba=rgba;
    o.x=x;o.y=y;o.z=z;o.pixel_x=px;o.pixel_y=py;o.pixel_width=pw;o.pixel_height=ph;
    o.first_box=uint32_t(boxes.size());o.box_count=uint32_t(geometry.size());
    o.geometry_hash=o.pattern=hash(geometry);
    boxes.insert(boxes.end(),geometry.begin(),geometry.end());objects.push_back(o);return true;
}
float worldX(float x){return x/160.0f-0.5f;}
float worldZ(float y){return 0.75f*(y/210.0f-0.5f);}
ADBox rectangle(float x,float y,float width,float rows,float elevation,float height) {
    return {worldX(x+width/2),elevation+height/2,worldZ(y+rows/2),width/160,height,0.75f*rows/210};
}
bool skaterColor(int c){return c==70 || c==132 || c==68 || c==250 || c==252 || c==212;}
}

extern "C" void ad_reset_ice_hockey(){previous.clear();objects.clear();boxes.clear();nextPlayerID=1;++sceneID;}
extern "C" const ADScene *ad_reconstruct_ice_hockey(const ADFrame *f,const ADProfile *p) {
    if(!f->ram || !f->indices || f->width!=160 || f->height!=210)return nullptr;
    int ice=0;uint32_t iceRGBA=0;
    for(int i=30*160;i<187*160;++i)if((f->indices[i]&254)==10){++ice;iceRGBA=f->rgba[i];}
    // Loading screens/unsupported palettes use the profile's generic fallback.
    if(ice<4000)return nullptr;
    auto start=std::chrono::steady_clock::now();result={};objects.clear();boxes.clear();
    objectLimit=std::min(p->max_objects?p->max_objects:uint32_t(AD_MAX_OBJECTS),uint32_t(AD_MAX_OBJECTS));
    boxLimit=std::min(p->max_boxes?p->max_boxes:uint32_t(AD_MAX_BOXES),uint32_t(AD_MAX_BOXES));
    const float thickness=std::clamp(p->default_height,0.004f,0.12f);
    // The visible ice is x32..127, y42..186. End openings x64..95 are
    // black in the actual raster; the surface preserves those goal mouths.
    emit(1001,AD_PLATFORM,10,iceRGBA,0,0,0,32,42,96,145,{
        rectangle(32,46,96,138,0,0.003f),rectangle(32,42,32,4,0,0.003f),
        rectangle(96,42,32,4,0,0.003f),rectangle(32,184,32,3,0,0.003f),rectangle(96,184,32,3,0,0.003f)});
    float boardHeight=thickness*1.1f;
    emit(1002,AD_WALL,10,iceRGBA,0,0,0,32,42,96,145,{
        rectangle(31,42,1,145,0,boardHeight),rectangle(128,42,1,145,0,boardHeight),
        rectangle(32,41,32,1,0,boardHeight),rectangle(96,41,32,1,0,boardHeight),
        rectangle(32,187,32,1,0,boardHeight),rectangle(96,187,32,1,0,boardHeight)});
    // Authored depth interpretation around the measured raster goal openings.
    for(int end=0;end<2;++end) {
        float front=end?184.0f:46.0f, back=end?187.0f:42.0f;
        float a=worldZ(front),b=worldZ(back),height=thickness*2.2f,bar=0.004f;
        float left=worldX(64),right=worldX(96),center=(left+right)/2;
        std::vector<ADBox> net={
            {left,height/2,a,bar,height,bar},{right,height/2,a,bar,height,bar},
            {center,height,a,right-left,bar,bar},{center,height,b,right-left,bar,bar},
            {left,height,(a+b)/2,bar,bar,std::abs(a-b)+bar},{right,height,(a+b)/2,bar,bar,std::abs(a-b)+bar}};
        for(int strand=0;strand<=8;++strand)net.push_back({left+(right-left)*strand/8,height/2,b,0.0015f,height,0.0015f});
        net.push_back({center,height/2,b,right-left,0.0015f,0.0015f});
        emit(1003+end,AD_SCENERY,10,iceRGBA,0,0,0,64,end?184:42,32,end?3:4,net);
    }
    std::array<Player,4> players;
    std::array<std::map<int,std::vector<int>>,4> parts;
    for(int slot=0;slot<4;++slot)players[slot]={int(f->ram[0x39+slot])-9,169-int(f->ram[0x35+slot]),0,0};
    for(int y=28;y<187;++y)for(int x=16;x<144;++x) {
        int i=y*160+x,c=f->indices[i]&254;
        if(!skaterColor(c))continue;
        float best=1e9f;int selected=-1;
        for(int slot=0;slot<4;++slot) {
            auto &a=players[slot];
            if(a.x<16 || a.x>140 || a.y<25 || a.y>177 || x<a.x-3 || x>a.x+22 || y<a.y-2 || y>a.y+21)continue;
            float dx=x-(a.x+4),dy=y-(a.y+9),distance=dx*dx+dy*dy*0.4f;
            if(distance<best){best=distance;selected=slot;}
        }
        if(selected>=0)parts[selected][c].push_back(i);
    }
    std::vector<bool> used(previous.size());
    for(int slot=0;slot<4;++slot) {
        auto &a=players[slot];int blue=0,yellow=0;
        for(auto &part:parts[slot]) {
            if(part.first==132 || part.first==68)blue+=int(part.second.size());
            if(part.first==250 || part.first==252 || part.first==212)yellow+=int(part.second.size());
        }
        a.team=blue>yellow?1:2;
        int best=-1,distance=60;
        for(size_t old=0;old<previous.size();++old)if(!used[old] && previous[old].team==a.team) {
            int d=std::abs(previous[old].x-a.x)+std::abs(previous[old].y-a.y);
            if(d<distance){distance=d;best=int(old);}
        }
        if(best>=0){a.id=previous[best].id;used[best]=true;}else a.id=nextPlayerID++;
        for(const auto &part:parts[slot]) {
            // Merge same-color horizontal pixel runs, but keep the complete
            // multicolor skater at one RAM-derived foot anchor. Raster y becomes
            // physical height, rather than a trail of flat slabs on the ice.
            std::map<int,std::vector<int>> rows;
            int x0=160,y0=210,x1=0,y1=0;
            for(int i:part.second){int x=i%160,y=i/160;rows[y].push_back(x);x0=std::min(x0,x);y0=std::min(y0,y);x1=std::max(x1,x);y1=std::max(y1,y);}
            std::vector<ADBox> geometry;
            for(auto &row:rows) {
                auto &xs=row.second;std::sort(xs.begin(),xs.end());
                for(size_t j=0;j<xs.size();) {
                    int first=xs[j],last=first;++j;
                    while(j<xs.size() && xs[j]==last+1)last=xs[j++];
                    geometry.push_back({((first+last+1)*0.5f-a.x)/160,
                        0.75f*(a.y+19-row.first-0.5f)/210,0,
                        (last-first+1)/160.0f,0.75f/210,thickness});
                }
            }
            emit(10000+a.id*256+part.first,AD_ACTOR,part.first,f->rgba[part.second[0]],
                worldX(float(a.x)),0.004f,worldZ(float(a.y+19)),float(x0),float(y0),float(x1-x0+1),float(y1-y0+1),geometry);
        }
    }
    previous.assign(players.begin(),players.end());
    // Puck pixels are small black components in the ice, excluding the two goal
    // openings. A carried/occluded puck is not invented from a guessed velocity.
    std::array<uint8_t,160*210> seen{};uint64_t puck=2000;
    for(int y=46;y<184;++y)for(int x=32;x<128;++x) {
        int seed=y*160+x;if(seen[seed] || (f->indices[seed]&254)!=0)continue;
        std::vector<int> queue={seed};seen[seed]=1;int x0=x,y0=y,x1=x,y1=y;
        for(size_t q=0;q<queue.size();++q) {
            int i=queue[q],px=i%160,py=i/160;x0=std::min(x0,px);x1=std::max(x1,px);y0=std::min(y0,py);y1=std::max(y1,py);
            for(int j:{px>32?i-1:-1,px<127?i+1:-1,py>46?i-160:-1,py<183?i+160:-1})
                if(j>=0 && !seen[j] && (f->indices[j]&254)==0){seen[j]=1;queue.push_back(j);}
        }
        if(queue.size()<=16 && x1-x0<=5 && y1-y0<=3)
            emit(puck++,AD_PROJECTILE,0,f->rgba[seed],0,0,0,float(x0),float(y0),float(x1-x0+1),float(y1-y0+1),
                 {rectangle(float(x0),float(y0),float(x1-x0+1),float(y1-y0+1),0.003f,thickness*0.25f)});
    }
    result.frame_number=f->number;result.scene_id=sceneID;
    result.object_count=uint32_t(objects.size());result.box_count=uint32_t(boxes.size());result.objects=objects.data();result.boxes=boxes.data();
    result.analysis_ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count();return &result;
}
