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
from verify_scene_pixels import rasterize_scene

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--rom',type=Path,default=ROOT/'roms/Ice Hockey (USA).a26');args=parser.parse_args()
    data=args.rom.read_bytes();sha=hashlib.sha256(data).hexdigest()
    if sha!='fc8b861d9cf9c9d5f7f7677f22b39d512d249697b69c1e7dcf238c5dc8f44b60':raise SystemExit('This capture recipe is only validated for the supplied NTSC revision')
    output=ROOT/'build/ice-hockey-faithful';output.mkdir(parents=True,exist_ok=True)
    lib=load_library();lib.ad_initialize(str(output).encode());load_rom(lib,data)
    profile=profile_from_json(ROOT/'profiles/ice-hockey-ntsc.json');audio=(C.c_float*4096)();lib.ad_audio_read(audio,2048)
    checkpoints={30,125,240,399,499,700,900,1199,1799,2399,2999,3599};captures=[];times=[];drops=0;puck_frames=0
    matched_frames=0;pixel_count=0;top_frames=0;logo_frames=0;max_objects=0;max_boxes=0
    try:
        for i in range(3600):
            directions=[0,1<<7,1<<4,1<<6,1<<5]
            first=(1<<14)|((1<<2) if 60<=i<63 else 0)|((1<<3) if 120<=i<123 else 0)
            if i>=300:first|=directions[(i//120)%5]|(1 if i%90<20 else 0)
            second=(directions[((i//150)+2)%5]|(1 if i%100<25 else 0)) if i>=600 else 0
            lib.ad_set_input(0,first,0,0);lib.ad_set_input(1,second,0,0)
            f=lib.ad_run_frame();lib.ad_audio_read(audio,2048);s=lib.ad_reconstruct(f,C.byref(profile)).contents
            objs=s.objects[:s.object_count];times.append(s.analysis_ms);drops+=s.dropped_objects
            frame=f.contents;original=C.string_at(frame.rgba,frame.width*frame.height*4)
            projected=rasterize_scene(s,frame.width,frame.height)
            if projected!=original:raise AssertionError(f'Original colors/positions changed at frame {i}')
            matched_frames+=1;pixel_count+=frame.width*frame.height;max_objects=max(max_objects,s.object_count);max_boxes=max(max_boxes,s.box_count)
            top_frames+=any(o.role==5 and o.pixel_y<28 for o in objs);logo_frames+=any(o.role==5 and o.pixel_y>=188 for o in objs)
            puck_frames+=any(o.role==3 for o in objs)
            if i in checkpoints:
                png(output/f'profile-frame-{i}.png',frame.width,frame.height,original)
                png(output/f'geometry-projection-{i}.png',frame.width,frame.height,projected)
                objects=[{'id':o.id,'role':o.role,'colorIndex':o.color_index,'rgba':o.color_rgba,
                    'position':[o.x,o.y,o.z],'pattern':f'{o.pattern:016x}',
                    'boxes':[[b.x,b.y,b.z,b.width,b.height,b.depth] for b in s.boxes[o.first_box:o.first_box+o.box_count]]} for o in objs]
                scene={'frame':i,'reconstruction':'iceHockeyNTSCv2','originalRasterWorld':True,'objects':objects}
                (output/f'scene-{i}.json').write_text(json.dumps(scene))
                if i==240:(output/'reconstructed-scene.json').write_text(json.dumps(scene))
                captures.append({'frame':i,'objects':s.object_count,'boxes':s.box_count,'sourceRGBA256':hashlib.sha256(original).hexdigest(),
                    'projectedRGBA256':hashlib.sha256(projected).hexdigest(),'sourcePlanePixelMatch':True,
                    'scoreTimerComponents':sum(o.role==5 and o.pixel_y<28 for o in objs),'logoComponents':sum(o.role==5 and o.pixel_y>=188 for o in objs)})
        report={'romSHA256':sha,'romMD5':hashlib.md5(data).hexdigest(),'profileID':'ice-hockey-ntsc-v2','framesExecuted':3600,
            'scenario':'Game 2 selected, Reset, scripted movement and Fire on both ports; no game-state writes',
            'sourcePlaneFramesMatchedExactly':matched_frames,'sourcePixelsChecked':pixel_count,'sourcePlaneMissingExtraOrOverlappingPixels':0,
            'framesWithScoreTimerGeometry':top_frames,'framesWithLogoGeometry':logo_frames,'maximumObjects':max_objects,'maximumBoxes':max_boxes,
            'framesWithVisiblePuckCandidate':puck_frames,'geometryDrops':drops,
            'analysisMedianMS':statistics.median(times),'analysisP95MS':sorted(times)[int(len(times)*.95)],
            'captures':captures,'iPhoneProfileTested':False,'note':'Exact source-plane shape/color verification on host. Depth is an interpretation of a 2D game; physical iPhone rendering is not established by this check.'}
        (output/'validation-report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
    finally:lib.ad_shutdown()

if __name__=='__main__':main()
