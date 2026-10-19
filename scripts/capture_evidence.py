#!/usr/bin/env python3
"""Capture real core output and reconstructed geometry; never fabricates game frames."""
import csv
import ctypes as C
import json
from pathlib import Path
import statistics
import struct
import time
import wave
from native_api import *
from generate_resources import png

def main():
    output=ROOT/'build/evidence';output.mkdir(parents=True,exist_ok=True)
    lib=load_library();lib.ad_initialize(str(output).encode());load_rom(lib)
    p=profile_from_json(ROOT/'profiles/tabletop-test.json')
    scratch=(C.c_float*4096)();lib.ad_audio_read(scratch,2048)
    timings=[];audio=[];first=None;last=None
    start=time.perf_counter()
    for frame in range(240):
        lib.ad_set_input(0,((1<<7) if 60<=frame<80 else 0) | ((1<<0) if frame>=120 else 0),0,0)
        f=lib.ad_run_frame()
        s=lib.ad_reconstruct(f,C.byref(p)).contents;timings.append(s.analysis_ms)
        count=lib.ad_audio_read(scratch,2048)
        audio.extend(max(-32768,min(32767,int(scratch[i]*32767))) for i in range(count*2))
        if frame==59:first=int(f.contents.ram[0])
        if frame==80:last=int(f.contents.ram[0])
    elapsed=time.perf_counter()-start
    f=f.contents
    pixels=C.string_at(f.rgba,f.width*f.height*4)
    png(output/'original-frame.png',f.width,f.height,pixels)
    # Capture is a literal list of generated boxes, also used by offline visual QA.
    objects=[]
    for obj in s.objects[:s.object_count]:
        objects.append({'id':obj.id,'role':obj.role,'colorIndex':obj.color_index,'rgba':obj.color_rgba,
            'position':[obj.x,obj.y,obj.z],'pattern':f'{obj.pattern:016x}',
            'boxes':[[b.x,b.y,b.z,b.width,b.height,b.depth] for b in s.boxes[obj.first_box:obj.first_box+obj.box_count]]})
    (output/'reconstructed-scene.json').write_text(json.dumps({'frame':int(f.number),'objects':objects},indent=2))
    with wave.open(str(output/'original-tia-audio.wav'),'wb') as wav:
        wav.setnchannels(2);wav.setsampwidth(2);wav.setframerate(31400)
        wav.writeframes(struct.pack('<'+'h'*len(audio),*audio))
    count=C.c_uint32();dropped=C.c_uint32();writes=lib.ad_tia_writes(C.byref(count),C.byref(dropped))
    with (output/'tia-writes.csv').open('w',newline='') as stream:
        writer=csv.writer(stream);writer.writerow(['cpu_cycle','tia_register_hex','value_hex'])
        writer.writerows((v.cycle,f'{v.address:02x}',f'{v.value:02x}') for v in writes[:count.value])
    report={'core':json.loads((ROOT/'build/native-host/build-info.json').read_text()),'romSHA256':json.loads((ROOT/'homebrew/manifest.json').read_text())['sha256'],
        'framesExecuted':240,'frameSize':[f.width,f.height],'requestedFPS':f.fps,'audioSampleRate':f.sample_rate,
        'headlessWallSeconds':elapsed,'headlessThroughputFPS':240/elapsed,'reconstructionMedianMS':statistics.median(timings),
        'reconstructionP95MS':sorted(timings)[int(len(timings)*.95)],'objects':s.object_count,'boxes':s.box_count,
        'droppedObjects':s.dropped_objects,'tiaWritesLastFrame':count.value,'tiaTraceDropped':dropped.value,
        'joystickBefore':first,'joystickAfter20Frames':last,'audioFramesCaptured':len(audio)//2,
        'audioNonzeroSamples':sum(v!=0 for v in audio),'iOSCompiled':False,'iPhoneTested':False,'ARTested':False,
        'note':'Host-only evidence. Throughput includes Python capture overhead; not an iPhone FPS measurement.'}
    (output/'validation-report.json').write_text(json.dumps(report,indent=2)+'\n')
    lib.ad_shutdown();print(json.dumps(report,indent=2))
if __name__=='__main__':main()
