import ctypes as C
import hashlib
import json
from pathlib import Path
import sys
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from native_api import *
from assemble_homebrew import assemble

class NativeIntegration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lib=load_library()
        cls.lib.ad_initialize(str(ROOT/'build').encode())
        cls.profile=profile_from_json(ROOT/'profiles/tabletop-test.json')
    @classmethod
    def tearDownClass(cls):cls.lib.ad_shutdown()
    def setUp(self):
        load_rom(self.lib)
        self.audio=(C.c_float*4096)()
        self.lib.ad_audio_read(self.audio,2048) # consume load flush
        for _ in range(90):self.step()
    def step(self):
        f=self.lib.ad_run_frame()
        self.lib.ad_audio_read(self.audio,2048)
        return f
    def scene(self):return self.lib.ad_reconstruct(self.lib.ad_current_frame(),C.byref(self.profile)).contents
    def test_original_rom_reproducible(self):
        data,_=assemble((ROOT/'homebrew/TabletopTest.asm').read_text())
        self.assertEqual(data,(ROOT/'ios/Resources/TabletopTest.a26').read_bytes())
        self.assertIn(hashlib.sha256(data).hexdigest(),json.loads((ROOT/'profiles/tabletop-test.json').read_text())['sha256'])
    def test_multiplayer_audio_tap_is_independent_and_guest_playback_preserves_state(self):
        self.lib.ad_audio_streaming(True)
        try:
            self.lib.ad_set_input(0,1,0,0)
            self.lib.ad_run_frame()
            tap=(C.c_int16*(8192*2))()
            count=self.lib.ad_audio_stream_read(tap,8192)
            normal=self.lib.ad_audio_read(self.audio,2048)
            self.assertGreater(count,0);self.assertEqual(normal,count)
            self.assertTrue(any(tap[i] for i in range(count*2)))
            for i in range(count*2):self.assertAlmostEqual(self.audio[i],tap[i]/32768,places=6)
            self.assertEqual(self.lib.ad_audio_stream_read(tap,8192),0)
            before=bytes(self.lib.ad_current_frame().contents.ram[:128])
            self.lib.ad_audio_clear();self.lib.ad_audio_read(self.audio,2048)
            self.lib.ad_audio_streaming(False)
            self.lib.ad_audio_receive(tap,count)
            self.assertEqual(self.lib.ad_audio_read(self.audio,2048),count)
            self.assertEqual(before,bytes(self.lib.ad_current_frame().contents.ram[:128]))
            for i in range(count*2):self.assertAlmostEqual(self.audio[i],tap[i]/32768,places=6)
        finally:self.lib.ad_audio_streaming(False)
    def test_two_joystick_ports_and_fire_buttons_are_independent(self):
        source=(ROOT/'homebrew/PaddleProbe.asm').read_text()
        source=source.replace('LDA $08\n    STA $80','LDA $0C\n    STA $80').replace('LDA $09\n    STA $81','LDA $0D\n    STA $81')
        probe,_=assemble(source);load_rom(self.lib,probe)
        for port in (0,1):self.lib.ad_set_controller(port,0)
        self.lib.ad_set_input(0,(1<<7)|1,0,0)
        self.lib.ad_set_input(1,(1<<6)|1,0,0)
        for _ in range(4):self.step()
        ram=self.lib.ad_current_frame().contents.ram
        self.assertEqual(ram[2],0x7B) # P1 right and P2 left, active low SWCHA
        self.assertEqual((ram[0]&128,ram[1]&128),(0,0))
        self.lib.ad_set_input(1,0,0,0)
        for _ in range(4):self.step()
        ram=self.lib.ad_current_frame().contents.ram
        self.assertEqual(ram[2],0x7F);self.assertEqual((ram[0]&128,ram[1]&128),(0,128))
    def test_demo_second_player_takes_over_red_actor(self):
        before=self.lib.ad_current_frame().contents.ram[2]
        self.lib.ad_set_input(0,1<<7,0,0)
        self.lib.ad_set_input(1,(1<<6)|1,0,0)
        for _ in range(8):self.step()
        ram=self.lib.ad_current_frame().contents.ram
        self.assertEqual(ram[0],76);self.assertEqual(ram[2],before-8)
        self.assertEqual(ram[10],1);self.assertEqual(ram[12],128)
        self.lib.ad_set_input(1,0,0,0)
        for _ in range(5):self.step()
        ram=self.lib.ad_current_frame().contents.ram
        self.assertEqual(ram[2],before-8);self.assertEqual(ram[12],0)
    def test_real_core_frame_ram_and_tia(self):
        f=self.lib.ad_current_frame().contents
        self.assertEqual(f.width,160);self.assertGreaterEqual(f.height,192)
        self.assertTrue(49<f.fps<65);self.assertEqual(f.sample_rate,31400)
        self.assertEqual(f.ram[0],68);self.assertEqual(f.ram[1],48)
        colors=set(f.indices[:f.width*f.height])
        self.assertTrue({0,132,70,200}.issubset(colors),colors)
        count=C.c_uint32();dropped=C.c_uint32();trace=self.lib.ad_tia_writes(C.byref(count),C.byref(dropped))
        self.assertGreater(count.value,300);self.assertEqual(dropped.value,0)
        self.assertIn(0x1B,{v.address for v in trace[:count.value]})
    def test_joystick_simultaneous_fire_audio_and_geometry(self):
        before=self.lib.ad_current_frame().contents.ram[0]
        self.lib.ad_set_input(0,(1<<7)|(1<<0),0,0) # Right + Fire
        nonzero=False
        for _ in range(12):
            self.lib.ad_run_frame();n=self.lib.ad_audio_read(self.audio,2048)
            nonzero |= any(abs(self.audio[i])>0.001 for i in range(n*2))
        f=self.lib.ad_current_frame().contents
        self.assertEqual(f.ram[0],before+12);self.assertEqual(f.ram[4],128);self.assertTrue(nonzero)
        scene=self.scene();objects=scene.objects[:scene.object_count]
        self.assertGreater(scene.object_count,2)
        self.assertTrue(any(o.role==1 for o in objects));self.assertTrue(any(o.color_index==132 for o in objects))
        self.assertTrue(all(b.height>0 and b.width>0 and b.depth>0 for b in scene.boxes[:scene.box_count]))
    def test_save_restore_deterministic_replay(self):
        n=self.lib.ad_state_size();self.assertGreater(n,128)
        state=(C.c_uint8*n)();self.assertTrue(self.lib.ad_save_state(state,n))
        def replay():
            self.lib.ad_set_input(0,1<<7,0,0)
            for _ in range(8):f=self.step()
            return bytes(f.contents.ram[:128]),C.string_at(f.contents.rgba,f.contents.width*f.contents.height*4)
        ram1,pixels1=replay()
        self.assertTrue(self.lib.ad_load_state(state,n))
        ram2,pixels2=replay();self.assertEqual(ram1,ram2);self.assertEqual(pixels1,pixels2)
        self.assertFalse(self.lib.ad_load_state(state,n-1))
    def test_room_transition_and_mesh_tracking(self):
        s=self.scene();old=s.scene_id
        self.lib.ad_set_input(0,1<<2,0,0)
        for _ in range(3):self.step()
        s=self.scene();self.assertNotEqual(s.scene_id,old)
        self.assertIn(40,[o.color_index for o in s.objects[:s.object_count]])
        self.lib.ad_set_input(0,0,0,0)
        a=[copy_struct(o) for o in s.objects[:s.object_count] if o.color_index==132]
        self.step();s=self.scene();b=[copy_struct(o) for o in s.objects[:s.object_count] if o.color_index==132]
        self.assertTrue(a and b);self.assertEqual(a[0].id,b[0].id);self.assertEqual(a[0].geometry_hash,b[0].geometry_hash)
    def test_repeated_rom_load_and_paddle_device(self):
        for _ in range(3):
            load_rom(self.lib);self.lib.ad_set_controller(0,1);self.lib.ad_set_input(0,1<<8,32767,-32767)
            for _ in range(4):self.step()
            self.assertEqual(self.lib.ad_current_frame().contents.width,160)
    def test_reconstruction_does_not_change_game_state(self):
        n=self.lib.ad_state_size();state=(C.c_uint8*n)();self.assertTrue(self.lib.ad_save_state(state,n))
        def replay(reconstruct):
            self.lib.ad_set_input(0,(1<<6)|(1<<4),0,0)
            for _ in range(12):
                f=self.step()
                if reconstruct:self.scene()
            return bytes(f.contents.ram[:128]),C.string_at(f.contents.rgba,f.contents.width*f.contents.height*4)
        a=replay(True);self.assertTrue(self.lib.ad_load_state(state,n));b=replay(False)
        self.assertEqual(a,b)
    def test_hardware_playfield_collision_is_visible_in_ram(self):
        self.lib.ad_set_input(0,1<<4,0,0)
        for _ in range(10):self.step()
        self.lib.ad_set_input(0,1<<6,0,0)
        for _ in range(40):self.step()
        self.lib.ad_set_input(0,0,0,0)
        for _ in range(3):self.step()
        self.assertTrue(self.lib.ad_current_frame().contents.ram[6]&128)
    def test_paddle_capacitor_inputs_and_both_fire_buttons(self):
        probe,_=assemble((ROOT/'homebrew/PaddleProbe.asm').read_text())
        load_rom(self.lib,probe);self.lib.ad_set_controller(0,1)
        self.lib.ad_set_input(0,0,0,0)
        for _ in range(4):self.step()
        self.lib.ad_set_input(0,0,-32767,32767)
        for _ in range(8):self.step()
        ram=self.lib.ad_current_frame().contents.ram
        self.assertEqual((ram[0]&128,ram[1]&128),(0,128))
        self.lib.ad_set_input(0,1<<8,32767,-32767)
        for _ in range(8):self.step()
        ram=self.lib.ad_current_frame().contents.ram
        self.assertEqual((ram[0]&128,ram[1]&128),(128,0));self.assertEqual(ram[2],127)
        self.lib.ad_set_input(0,1,32767,-32767)
        for _ in range(3):self.step()
        self.assertEqual(self.lib.ad_current_frame().contents.ram[2],191)

class Segmentation(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.lib=load_library()
    def synthetic(self):
        w=h=16
        indices=(C.c_uint8*(w*h))();rgba=(C.c_uint32*(w*h))()
        for y in range(3,11):
            for x in range(3,11):
                if x in [3,10] or y in [3,10]:indices[y*w+x]=132;rgba[y*w+x]=0xFFAA2200
        p=Profile(0,0,.05,0,0,1024,24000,-1,0,None)
        f=Frame(w,h,1,60,31400,rgba,indices,None)
        return f,p,indices,rgba
    def test_holes_and_immediate_deletion(self):
        f,p,indices,rgba=self.synthetic();s=self.lib.ad_reconstruct(C.byref(f),C.byref(p)).contents
        self.assertEqual(s.object_count,1);self.assertEqual(s.box_count,4)
        area=sum(b.width*b.depth for b in s.boxes[:s.box_count])
        self.assertAlmostEqual(area,28/(16*16)*.75,places=5)
        for i in range(256):indices[i]=0
        s=self.lib.ad_reconstruct(C.byref(f),C.byref(p)).contents;self.assertEqual(s.object_count,0)
    def test_budget_and_hud(self):
        f,p,indices,rgba=self.synthetic();p.max_boxes=1
        s=self.lib.ad_reconstruct(C.byref(f),C.byref(p)).contents
        self.assertEqual(s.object_count,0);self.assertEqual(s.dropped_objects,1);self.assertEqual(s.dropped_boxes,4)
        p.max_boxes=24000;p.hud_top=.75
        self.assertEqual(self.lib.ad_reconstruct(C.byref(f),C.byref(p)).contents.object_count,0)
    def test_side_view_volumetric_mesh(self):
        f,p,indices,rgba=self.synthetic();p.side_view=1
        s=self.lib.ad_reconstruct(C.byref(f),C.byref(p)).contents
        # The generic converter classifies this large connected ring as a wall,
        # giving it twice the default height, now expressed as upright depth.
        self.assertTrue(all(abs(b.depth-.10)<1e-6 for b in s.boxes[:s.box_count]))

if __name__=='__main__':unittest.main(verbosity=2)
