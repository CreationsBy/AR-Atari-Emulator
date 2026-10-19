"""Original synthetic artwork in CI; the supplied cartridge always stays local."""
import ctypes as C
import hashlib
from pathlib import Path
import sys
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from native_api import *
from verify_scene_pixels import rasterize_scene

ROM=ROOT/'roms/Ice Hockey (USA).a26'
SHA='fc8b861d9cf9c9d5f7f7677f22b39d512d249697b69c1e7dcf238c5dc8f44b60'

class IceHockeyGeometry(unittest.TestCase):
    def setUp(self):
        self.lib=load_library();self.lib.ad_reset_reconstruction()
        self.profile=profile_from_json(ROOT/'profiles/ice-hockey-ntsc.json')
    def fixture(self,shift=0):
        indices=(C.c_uint8*(160*210))();rgba=(C.c_uint32*(160*210))(*([0xff000000]*(160*210)));ram=(C.c_uint8*128)()
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
        # Original synthetic glyph shapes, not commercial logo/ROM data.
        for y in range(6,13):
            for x in range(64,70):
                if x in (64,69) or y in (6,12):pixel(x,y,136)
        for x in range(46,50):pixel(x,18,132)
        for x in range(110,114):pixel(x,18,252)
        for y in range(192,197):
            for x in range(64,95):
                if (x+y)%3:pixel(x,y,136)
        return Frame(160,210,100,59.92,31400,rgba,indices,ram),indices,rgba,ram
    def scene(self,fixture):return self.lib.ad_reconstruct(C.byref(fixture[0]),C.byref(self.profile)).contents
    def assert_source_pixels(self,fixture,scene):
        self.assertEqual(rasterize_scene(scene,160,210),C.string_at(fixture[2],160*210*4))
    def test_entire_frame_includes_score_timer_logo_without_authored_scenery(self):
        fixture=self.fixture();before=bytes(fixture[3]);s=self.scene(fixture)
        self.assertEqual(bytes(fixture[3]),before);self.assert_source_pixels(fixture,s)
        objects=s.objects[:s.object_count]
        self.assertTrue(any(o.role==5 and o.pixel_y<28 for o in objects))
        self.assertTrue(any(o.role==5 and o.pixel_y>=188 for o in objects))
        self.assertFalse(any(o.role==1 for o in objects)) # no invented boards or posts
        self.assertTrue(any(o.role==3 and o.pixel_x==42 for o in objects));self.assertEqual(s.dropped_objects,0)
        # Goal voids, thin pixel lines and glyph holes were checked by the exact
        # independent projection above, not inferred from rectangle counts.
    def test_translation_retains_actor_identity_and_geometry(self):
        s=self.scene(self.fixture());a=copy_struct(next(o for o in s.objects[:s.object_count] if o.color_index==70 and o.pixel_y==36))
        s=self.scene(self.fixture(1));b=copy_struct(next(o for o in s.objects[:s.object_count] if o.color_index==70 and o.pixel_y==36))
        self.assertEqual(a.id,b.id);self.assertEqual(a.geometry_hash,b.geometry_hash);self.assertAlmostEqual(b.x-a.x,1/160,places=6)
    def test_adapter_respects_geometry_budgets(self):
        self.profile.max_objects=3;self.profile.max_boxes=30;s=self.scene(self.fixture())
        self.assertLessEqual(s.object_count,3);self.assertLessEqual(s.box_count,30);self.assertGreater(s.dropped_objects,0)
    def test_score_timer_logo_changes_remove_old_pixels_immediately(self):
        fixture=self.fixture();self.assert_source_pixels(fixture,self.scene(fixture))
        for y0,y1 in [(0,28),(188,210)]:
            for y in range(y0,y1):
                for x in range(160):fixture[1][y*160+x]=0;fixture[2][y*160+x]=0xff000000
        fixture[1][9*160+80]=252;fixture[2][9*160+80]=0xff0033cc
        fixture[0].number+=1;s=self.scene(fixture);self.assert_source_pixels(fixture,s)
        self.assertFalse(any(o.color_index!=0 and o.pixel_y>=188 for o in s.objects[:s.object_count]))
    def test_palette_changes_and_no_ram_keep_exact_visible_artwork(self):
        fixture=self.fixture();fixture[0].ram=None
        for i in range(160*210):
            color=fixture[1][i];fixture[1][i]=color%16
            fixture[2][i]=0xff000000|((color*5939)&0xffffff)
        self.assert_source_pixels(fixture,self.scene(fixture))
    def test_low_quality_budget_keeps_complete_fixture(self):
        self.profile.max_objects=256;self.profile.max_boxes=6000;fixture=self.fixture();s=self.scene(fixture)
        self.assertEqual(s.dropped_objects,0);self.assert_source_pixels(fixture,s)
    def test_blank_startup_does_not_invent_rink_or_text(self):
        fixture=self.fixture()
        for i in range(160*210):fixture[1][i]=0;fixture[2][i]=0xff000000
        s=self.scene(fixture);self.assert_source_pixels(fixture,s)
        self.assertTrue(all(o.color_index==0 and o.role==4 for o in s.objects[:s.object_count]))

@unittest.skipUnless(ROM.exists(),'User-supplied Ice Hockey ROM is not distributed to CI')
class IceHockeySuppliedROM(unittest.TestCase):
    def test_real_rom_full_artwork_and_read_only_interpretation(self):
        data=ROM.read_bytes();self.assertEqual(hashlib.sha256(data).hexdigest(),SHA)
        lib=load_library();lib.ad_initialize(str(ROOT/'build').encode());load_rom(lib,data)
        try:
            scratch=(C.c_float*4096)();lib.ad_audio_read(scratch,2048)
            for i in range(240):
                lib.ad_set_input(0,(1<<14)|((1<<3) if 120<=i<123 else 0),0,0)
                lib.ad_run_frame();lib.ad_audio_read(scratch,2048)
            n=lib.ad_state_size();a=(C.c_uint8*n)();b=(C.c_uint8*n)();self.assertTrue(lib.ad_save_state(a,n))
            p=profile_from_json(ROOT/'profiles/ice-hockey-ntsc.json');f=lib.ad_current_frame();s=lib.ad_reconstruct(f,C.byref(p)).contents
            self.assertTrue(lib.ad_save_state(b,n));self.assertEqual(bytes(a),bytes(b))
            self.assertEqual(rasterize_scene(s,160,210),C.string_at(f.contents.rgba,160*210*4));self.assertEqual(s.dropped_objects,0)
            objects=s.objects[:s.object_count]
            self.assertTrue(any(o.role==5 and o.pixel_y<28 for o in objects));self.assertTrue(any(o.role==5 and o.pixel_y>=188 for o in objects))
        finally:lib.ad_shutdown()
