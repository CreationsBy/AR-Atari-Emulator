#!/usr/bin/env python3
"""Windows-friendly live prototype: real native Stella -> native boxes -> WebGL.
Localhost only. This inspection tool is separate from the native iOS application.
"""
import argparse
import base64
import ctypes as C
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
import json
from pathlib import Path
import threading
import time
from native_api import *

class Runtime:
    def __init__(self):
        self.lock=threading.Lock();self.stop=threading.Event();self.lib=load_library()
        self.lib.ad_initialize(str(ROOT/'build').encode())
        self.paused=False;self.depth=1.;self.snapshot={};self.pending_audio=bytearray();self.saved=None
        self.load((ROOT/'ios/Resources/TabletopTest.a26').read_bytes(),'TabletopTest.a26')
    def load(self,data,name):
        import hashlib
        sha=hashlib.sha256(data).hexdigest();md5=hashlib.md5(data).hexdigest()
        p=None
        for file in (ROOT/'profiles').glob('*.json'):
            candidate=json.loads(file.read_text())
            if sha in candidate['sha256'] or md5 in candidate['md5']:p=file;self.metadata=candidate;break
        self.profile=profile_from_json(p) if p else Profile(0,0,.035,-1,0,1024,24000,-1,0,None)
        if not p:self.metadata={'title':name,'compatibility':'generic','notes':'Experimental generic color segmentation. No dedicated profile.'}
        memory=(C.c_uint8*len(data)).from_buffer_copy(data)
        if not self.lib.ad_load_rom(memory,len(data),name.encode()):raise RuntimeError(self.lib.ad_last_error().decode())
        paddle=int(self.metadata.get('controller')=='paddles')
        for port in range(2):self.lib.ad_set_controller(port,paddle)
        self.sha=sha;self.saved=None;self.pending_audio.clear()
    def run(self):
        scratch=(C.c_float*4096)();deadline=time.perf_counter()
        self.lib.ad_audio_read(scratch,2048)
        while not self.stop.is_set():
            with self.lock:
                if not self.paused:
                    f=self.lib.ad_run_frame()
                    s=self.lib.ad_reconstruct(f,C.byref(self.profile)).contents
                    frame=f.contents
                    objects=[]
                    for obj in s.objects[:s.object_count]:
                        objects.append({'id':obj.id,'hash':str(obj.geometry_hash),'color':obj.color_rgba,'role':obj.role,
                            'position':[obj.x,obj.y,obj.z], 'boxes':[[b.x,b.y,b.z,b.width,b.height,b.depth] for b in s.boxes[obj.first_box:obj.first_box+obj.box_count]]})
                    count=self.lib.ad_audio_read(scratch,2048)
                    samples=(C.c_int16*(count*2))(*(max(-32768,min(32767,int(scratch[i]*32767))) for i in range(count*2)))
                    self.pending_audio.extend(bytes(samples))
                    if len(self.pending_audio)>31400*4:self.pending_audio=self.pending_audio[-31400*4:]
                    self.snapshot={'frame':frame.number,'width':frame.width,'height':frame.height,'fps':frame.fps,'analysisMS':s.analysis_ms,
                        'objects':objects,'boxes':s.box_count,'pixels':base64.b64encode(C.string_at(frame.rgba,frame.width*frame.height*4)).decode(),
                        'ram':list(frame.ram[:128]),'metadata':self.metadata,'sha256':self.sha,'paused':self.paused}
                    interval=1/max(frame.fps,1)
                else:interval=1/60
            deadline+=interval
            delay=deadline-time.perf_counter()
            if delay<-.1:deadline=time.perf_counter()
            self.stop.wait(max(0,delay))
    def command(self,data):
        if 'buttons' in data:
            mask=int(data['buttons'])&65535
            if self.metadata.get('controller')=='paddles' and mask&1:mask=(mask&~1)|(1<<8)
            self.lib.ad_set_input(0,mask,max(-32767,min(32767,int(data.get('paddle',0)*32767))),0)
        if 'paused' in data:self.paused=bool(data['paused'])
        if data.get('reset'):self.lib.ad_reset()
        if data.get('save'):
            n=self.lib.ad_state_size();memory=(C.c_uint8*n)()
            if not n or not self.lib.ad_save_state(memory,n):raise RuntimeError('Core save failed')
            self.saved=bytes(memory)
        if data.get('restore'):
            if not self.saved:raise RuntimeError('Save a state first')
            memory=(C.c_uint8*len(self.saved)).from_buffer_copy(self.saved)
            if not self.lib.ad_load_state(memory,len(memory)):raise RuntimeError('Core restore failed')

def main():
    p=argparse.ArgumentParser();p.add_argument('--port',type=int,default=8260);args=p.parse_args()
    runtime=Runtime()
    class Handler(BaseHTTPRequestHandler):
        def log_message(self,*args):pass
        def reply(self,status,content,kind='application/json'):
            self.send_response(status);self.send_header('Content-Type',kind);self.send_header('Content-Length',str(len(content)))
            self.send_header('Cache-Control','no-store');self.send_header('X-Content-Type-Options','nosniff');self.end_headers();self.wfile.write(content)
        def do_GET(self):
            if self.path=='/':self.reply(200,(ROOT/'tools/preview.html').read_bytes(),'text/html; charset=utf-8')
            elif self.path=='/api/frame':
                with runtime.lock:
                    payload=dict(runtime.snapshot);payload['audio']=base64.b64encode(runtime.pending_audio).decode();runtime.pending_audio.clear();payload['paused']=runtime.paused
                self.reply(200,json.dumps(payload).encode())
            else:self.reply(404,b'{}')
        def do_POST(self):
            # Local same-origin requests only, with a bounded body. No filesystem paths.
            origin=self.headers.get('Origin')
            if origin and origin!=f'http://127.0.0.1:{args.port}':self.reply(403,b'{}');return
            length=int(self.headers.get('Content-Length','0'))
            if not 0<length<=1048576:self.reply(413,b'{}');return
            data=self.rfile.read(length)
            try:
                with runtime.lock:
                    if self.path=='/api/input':runtime.command(json.loads(data))
                    elif self.path=='/api/rom':runtime.load(data,'Imported cartridge.a26')
                    else:self.reply(404,b'{}');return
                self.reply(200,b'{"ok":true}')
            except Exception as error:self.reply(400,json.dumps({'error':str(error)}).encode())
    thread=threading.Thread(target=runtime.run,daemon=True);thread.start()
    server=ThreadingHTTPServer(('127.0.0.1',args.port),Handler)
    print(f'Live Stella 3D prototype: http://127.0.0.1:{args.port}',flush=True)
    try:server.serve_forever()
    except KeyboardInterrupt:pass
    finally:runtime.stop.set();thread.join();server.server_close();runtime.lib.ad_shutdown()
if __name__=='__main__':main()
