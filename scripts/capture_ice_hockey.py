#!/usr/bin/env python3
"""Inspect the user-supplied exact ROM locally. Never copies cartridge bytes."""
import argparse
import collections
import ctypes as C
import hashlib
import json
import statistics
from native_api import *
from generate_resources import png

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--rom',type=Path,default=ROOT/'roms/Ice Hockey (USA).a26');args=parser.parse_args()
    data=args.rom.read_bytes();sha=hashlib.sha256(data).hexdigest()
    if sha!='fc8b861d9cf9c9d5f7f7677f22b39d512d249697b69c1e7dcf238c5dc8f44b60':raise SystemExit('This capture recipe is only validated for the supplied NTSC revision')
    output=ROOT/'build/ice-hockey';output.mkdir(parents=True,exist_ok=True)
    lib=load_library();lib.ad_initialize(str(output).encode());load_rom(lib,data)
    profile=profile_from_json(ROOT/'profiles/ice-hockey-ntsc.json');audio=(C.c_float*4096)();lib.ad_audio_read(audio,2048)
    checkpoints={30,125,240,399,499,700,900,1199,1799,2399,2999,3599};captures=[];times=[];drops=0;head_counts=collections.Counter();puck_frames=0
    try:
        for i in range(3600):
            directions=[0,1<<7,1<<4,1<<6,1<<5]
            first=(1<<14)|((1<<2) if 60<=i<63 else 0)|((1<<3) if 120<=i<123 else 0)
            if i>=300:first|=directions[(i//120)%5]|(1 if i%90<20 else 0)
            second=(directions[((i//150)+2)%5]|(1 if i%100<25 else 0)) if i>=600 else 0
            lib.ad_set_input(0,first,0,0);lib.ad_set_input(1,second,0,0)
            f=lib.ad_run_frame();lib.ad_audio_read(audio,2048);s=lib.ad_reconstruct(f,C.byref(profile)).contents
            objs=s.objects[:s.object_count];times.append(s.analysis_ms);drops+=s.dropped_objects
            head_counts[sum(o.role==2 and o.color_index==70 for o in objs)]+=1
            puck_frames+=any(o.role==3 for o in objs)
            if i in checkpoints:
                frame=f.contents;png(output/f'profile-frame-{i}.png',frame.width,frame.height,C.string_at(frame.rgba,frame.width*frame.height*4))
                objects=[{'id':o.id,'role':o.role,'colorIndex':o.color_index,'rgba':o.color_rgba,
                    'position':[o.x,o.y,o.z],'pattern':f'{o.pattern:016x}',
                    'boxes':[[b.x,b.y,b.z,b.width,b.height,b.depth] for b in s.boxes[o.first_box:o.first_box+o.box_count]]} for o in objs]
                scene={'frame':i,'reconstruction':'iceHockeyNTSCv1','objects':objects}
                (output/f'scene-{i}.json').write_text(json.dumps(scene))
                if i==240:(output/'reconstructed-scene.json').write_text(json.dumps(scene))
                captures.append({'frame':i,'objects':s.object_count,'boxes':s.box_count,'heads':sum(o.role==2 and o.color_index==70 for o in objs),'puckComponents':sum(o.role==3 for o in objs)})
        report={'romSHA256':sha,'romMD5':hashlib.md5(data).hexdigest(),'profileID':'ice-hockey-ntsc-v1','framesExecuted':3600,
            'scenario':'Game 2 selected, Reset, scripted movement and Fire on both ports; no game-state writes',
            'headComponentHistogram':dict(head_counts),'framesWithVisiblePuckCandidate':puck_frames,'geometryDrops':drops,
            'analysisMedianMS':statistics.median(times),'analysisP95MS':sorted(times)[int(len(times)*.95)],
            'captures':captures,'iPhoneProfileTested':False,'note':'Host evidence, not full profile certification; overlaps/falls can make color attribution ambiguous.'}
        (output/'validation-report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
    finally:lib.ad_shutdown()

if __name__=='__main__':main()
