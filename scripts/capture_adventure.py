#!/usr/bin/env python3
"""Read-only exact-ROM inspection with ordinary joystick/console inputs only."""
import argparse
import collections
import ctypes as C
import hashlib
import json
import statistics
from native_api import *
from generate_resources import png

SHA='b0326b45e5cab066b2d03f1e683708d82de3ffe60b2e968bf88c5494237f0a96'

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--rom',type=Path,default=ROOT/'roms/Adventure (USA).a26');args=parser.parse_args()
    data=args.rom.read_bytes()
    if hashlib.sha256(data).hexdigest()!=SHA:raise SystemExit('Capture recipe requires the measured NTSC revision')
    output=ROOT/'build/adventure';output.mkdir(parents=True,exist_ok=True)
    lib=load_library();lib.ad_initialize(str(output).encode());load_rom(lib,data)
    profile=profile_from_json(ROOT/'profiles/adventure-experimental.json');audio=(C.c_float*4096)();lib.ad_audio_read(audio,2048)
    times=[];rooms=collections.Counter();ids=collections.Counter();carried=collections.Counter();games=collections.Counter();captures=[];drops=0;frame=0;last_capture_room=-1;fallbacks=0
    def capture(label,f,s):
        objects=[{'id':o.id,'role':o.role,'colorIndex':o.color_index,'rgba':o.color_rgba,'position':[o.x,o.y,o.z],
            'pattern':f'{o.pattern:016x}','boxes':[[b.x,b.y,b.z,b.width,b.height,b.depth] for b in s.boxes[o.first_box:o.first_box+o.box_count]]} for o in s.objects[:s.object_count]]
        scene={'frame':frame,'reconstruction':'adventureNTSCv1','objects':objects}
        (output/f'{label}-scene.json').write_text(json.dumps(scene))
        png(output/f'{label}-frame.png',f.width,f.height,C.string_at(f.rgba,f.width*f.height*4))
        captures.append({'label':label,'frame':frame,'room':f.ram[10],'player':list(f.ram[11:13]),'carriedOffset':f.ram[29],
            'game':f.ram[93]//2+1,
            'objects':s.object_count,'boxes':s.box_count,'ids':[o.id for o in s.objects[:s.object_count]]})
    def step(buttons=0,label=None):
        nonlocal frame,drops,last_capture_room,fallbacks
        lib.ad_set_input(0,(1<<14)|buttons,0,0);fp=lib.ad_run_frame();lib.ad_audio_read(audio,2048);frame+=1
        f=fp.contents;s=lib.ad_reconstruct(fp,C.byref(profile)).contents;times.append(s.analysis_ms);drops+=s.dropped_objects
        rooms[f.ram[10]]+=1;carried[f.ram[29]]+=1;games[f.ram[93]//2+1]+=1
        semantic=s.object_count>0 and s.objects[0].id==1 and s.objects[0].role==4 and s.objects[0].pixel_width==160
        if semantic:
            for o in s.objects[:s.object_count]:ids[o.id]+=1
        else:fallbacks+=1
        if label:capture(label,f,s)
        elif f.ram[10]!=last_capture_room and frame>10:capture(f'room-{f.ram[10]}-at-{frame}',f,s)
        last_capture_room=f.ram[10]
        return f
    def wait(count,buttons=0,label=None):
        for _ in range(count):f=step(buttons)
        if label:
            s=lib.ad_reconstruct(lib.ad_current_frame(),C.byref(profile)).contents;capture(label,f,s)
    def goto(x,y,label):
        # Read positions to decide ordinary input, never write the game's RAM.
        for coordinate,target,positive,negative in [(11,x,7,6),(12,y,4,5)]:
            stalled=0;old=-1
            for _ in range(240):
                value=lib.ad_current_frame().contents.ram[coordinate]
                if abs(value-target)<=2:break
                stalled=stalled+1 if value==old else 0;old=value
                if stalled>24:break
                step(1<<(positive if value<target else negative))
        wait(6,label=label)
    try:
        wait(60,label='title');wait(3,1<<3);wait(90,label='yellow-castle')
        goto(32,32,'approach-key');goto(32,64,'pickup-key');goto(32,28,'return-with-key');goto(80,28,'approach-gate');goto(80,65,'open-gate')
        wait(80,1<<4,label='castle-interior');goto(32,32,'sword');wait(3,1,label='drop');goto(80,20,'exit-position');wait(110,1<<5,label='below-castle')
        # Additional room transitions and creatures under normal game rules.
        for cycle in range(3):
            for direction in [6,4,7,5]:wait(120,1<<direction,label=f'explore-{cycle}-{direction}')
            if cycle==1:wait(3,1<<3);wait(45)
        # Game 2, then game 3: different placements and the bat can be observed.
        for game in [2,3]:
            wait(3,1<<2);wait(8)
            for _ in range(3):
                if lib.ad_current_frame().contents.ram[93]==(game-1)*2:break
                wait(3,1<<2);wait(8)
            wait(8);wait(3,1<<3);wait(60,label=f'game-{game}-start')
            for cycle in range(2):
                for direction in [5,6,4,7]:wait(120,1<<direction,label=f'game-{game}-{cycle}-{direction}')
        n=lib.ad_state_size();a=(C.c_uint8*n)();b=(C.c_uint8*n)();assert lib.ad_save_state(a,n)
        lib.ad_reconstruct(lib.ad_current_frame(),C.byref(profile));assert lib.ad_save_state(b,n);assert bytes(a)==bytes(b)
        report={'romSHA256':SHA,'romMD5':hashlib.md5(data).hexdigest(),'profileID':'adventure-ntsc-v2','framesExecuted':frame,
            'scenario':'Console Reset/Select and joystick-only route: yellow key pickup, castle gate approach/interior, room exploration and game variations; no state writes',
            'roomFrames':dict(rooms),'semanticObjectFrames':dict(ids),'genericFallbackFrames':fallbacks,'gameFrames':dict(games),'carriedOffsetFrames':dict(carried),'geometryDrops':drops,
            'analysisMedianMS':statistics.median(times),'analysisP95MS':sorted(times)[int(len(times)*.95)],'reconstructionSaveBytesUnchanged':True,
            'captures':captures,'iPhoneProfileTested':False,'note':'Host captures and interpretation counts, not complete gameplay certification or iPhone FPS.'}
        (output/'validation-report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k!='captures'},indent=2))
    finally:lib.ad_shutdown()

if __name__=='__main__':main()
