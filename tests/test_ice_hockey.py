"""Synthetic semantic fixtures run in CI; commercial-ROM checks run only locally."""
import ctypes as C
import hashlib
from pathlib import Path
import sys
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from native_api import *

ROM=ROOT/'roms/Ice Hockey (USA).a26'
SHA='fc8b861d9cf9c9d5f7f7677f22b39d512d249697b69c1e7dcf238c5dc8f44b60'

class IceHockeyGeometry(unittest.TestCase):
    def setUp(self):
        self.lib=load_library();self.lib.ad_reset_reconstruction()
        self.profile=profile_from_json(ROOT/'profiles/ice-hockey-ntsc.json')
    def fixture(self, shift=0):
        indices=(C.c_uint8*(160*210))();rgba=(C.c_uint32*(160*210))();ram=(C.c_uint8*128)()
        def pixel(x,y,c):indices[y*160+x]=c;rgba[y*160+x]=0xff000000|c|(c<<8)|(c<<16)
        for y in range(42,187):
            for x in range(32,128):pixel(x,y,10)
        for y0,y1 in [(42,46),(184,187)]:
            for y in range(y0,y1):
                for x in range(64,96):pixel(x,y,0)
        for slot,(x,vertical) in enumerate([(80+shift,133),(96,100),(62,70),(80,13)]):
            ram[0x39+slot]=x;ram[0x35+slot]=vertical;bx=x-9;hy=169-vertical
            for y in range(hy,hy+3):
                for xx in range(bx+2,bx+4):pixel(xx,y,70)
            for y in range(hy+4,hy+10):
                for xx in range(bx,bx+8):pixel(xx,y,132 if slot%2==0 else 252)
            for y in range(hy+10,hy+18):
                for xx in range(bx+1,bx+5):pixel(xx,y,68 if slot%2==0 else 212)
        for y in range(115,117):
            for x in range(42,44):pixel(x,y,0)
        for x in range(60,70):pixel(x,12,136) # score must not become geometry
        f=Frame(160,210,100,59.92,31400,rgba,indices,ram)
        return f,indices,rgba,ram
    def scene(self,fixture):return self.lib.ad_reconstruct(C.byref(fixture[0]),C.byref(self.profile)).contents
    def test_rink_nets_upright_multicolor_skaters_puck_and_hud(self):
        fixture=self.fixture();before=bytes(fixture[3]);s=self.scene(fixture);objs=s.objects[:s.object_count]
        self.assertEqual(bytes(fixture[3]),before)
        self.assertEqual(sum(o.role==4 for o in objs),1)
        self.assertEqual(sum(o.id in (1003,1004) for o in objs),2)
        self.assertEqual(sum(o.role==2 and o.color_index==70 for o in objs),4)
        self.assertTrue(any(o.role==3 and o.pixel_x==42 for o in objs))
        self.assertTrue(all(o.pixel_y>=28 for o in objs))
        self.assertEqual(s.dropped_objects,0)
        self.assertTrue(all(b.width>0 and b.height>0 and b.depth>0 for b in s.boxes[:s.box_count]))
        heads=[o for o in objs if o.role==2 and o.color_index==70]
        self.assertTrue(all(s.boxes[o.first_box].y>0.05 for o in heads))
        floor=next(o for o in objs if o.role==4)
        # Surface has five rectangles, leaving the measured goal openings clear.
        self.assertEqual(floor.box_count,5)
    def test_translation_retains_actor_identity_and_geometry(self):
        s=self.scene(self.fixture());a=copy_struct(next(o for o in s.objects[:s.object_count] if o.color_index==70 and o.pixel_y==36))
        s=self.scene(self.fixture(1));b=copy_struct(next(o for o in s.objects[:s.object_count] if o.color_index==70 and o.pixel_y==36))
        self.assertEqual(a.id,b.id);self.assertEqual(a.geometry_hash,b.geometry_hash)
        self.assertAlmostEqual(b.x-a.x,1/160,places=6)
    def test_semantic_adapter_respects_geometry_budgets(self):
        self.profile.max_objects=3;self.profile.max_boxes=30
        s=self.scene(self.fixture())
        self.assertLessEqual(s.object_count,3);self.assertLessEqual(s.box_count,30)
        self.assertGreater(s.dropped_objects,0)

@unittest.skipUnless(ROM.exists(),'User-supplied Ice Hockey ROM is not distributed to CI')
class IceHockeySuppliedROM(unittest.TestCase):
    def test_real_rom_scene_and_read_only_interpretation(self):
        data=ROM.read_bytes();self.assertEqual(hashlib.sha256(data).hexdigest(),SHA)
        lib=load_library();lib.ad_initialize(str(ROOT/'build').encode());load_rom(lib,data)
        try:
            scratch=(C.c_float*4096)();lib.ad_audio_read(scratch,2048)
            for i in range(240):
                lib.ad_set_input(0,(1<<14)|((1<<3) if 120<=i<123 else 0),0,0)
                lib.ad_run_frame();lib.ad_audio_read(scratch,2048)
            n=lib.ad_state_size();a=(C.c_uint8*n)();b=(C.c_uint8*n)();self.assertTrue(lib.ad_save_state(a,n))
            p=profile_from_json(ROOT/'profiles/ice-hockey-ntsc.json');s=lib.ad_reconstruct(lib.ad_current_frame(),C.byref(p)).contents
            self.assertTrue(lib.ad_save_state(b,n));self.assertEqual(bytes(a),bytes(b))
            objects=s.objects[:s.object_count]
            self.assertEqual(sum(o.role==2 and o.color_index==70 for o in objects),4)
            self.assertTrue(any(o.id==1001 for o in objects));self.assertEqual(s.dropped_objects,0)
        finally:lib.ad_shutdown()
