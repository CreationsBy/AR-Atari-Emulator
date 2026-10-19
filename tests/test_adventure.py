"""Original synthetic fixtures in CI; supplied commercial cartridge stays local."""
import ctypes as C
import hashlib
from pathlib import Path
import sys
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from native_api import *

SHA='b0326b45e5cab066b2d03f1e683708d82de3ffe60b2e968bf88c5494237f0a96'
ROM=ROOT/'roms/Adventure (USA).a26'

class AdventureGeometry(unittest.TestCase):
    def setUp(self):
        self.lib=load_library();self.lib.ad_initialize(str(ROOT/'build').encode())
        # Original fixture, not a copy of Adventure's tables or sprite artwork.
        self.rom=bytearray(4096);self.rom[:3]=bytes([0x4c,0,0xf0]);self.rom[-4:]=bytes([0,0xf0,0,0xf0])
        def word(address,value):self.rom[address-0xf000:address-0xf000+2]=value.to_bytes(2,'little')
        self.word=word
        for room in [17,18]:
            word(0xfe1b+room*9,0xf100);self.rom[0xfe1b+room*9+4-0xf000]=1
        for row in range(7):self.rom[0x100+row*3]=0x10 # reflected four-pixel edge walls
        for id,address in [(1,0xc8),(6,0xa4),(9,0xb6),(10,0xbc),(11,0xbf),(14,0xcb)]:
            word(0xff44+id*9,address);word(0xff44+id*9+2,address+4)
        # A ring and a narrow key-shaped fixture. Interior holes must survive.
        self.rom[0x200:0x204]=bytes([0xff,0x81,0xff,0])
        self.rom[0x210:0x214]=bytes([0x80,0xf0,0x80,0])
        self.rom[0x240:0x261]=bytes([255]*32+[0])
        load_rom(self.lib,self.rom)
        self.p=profile_from_json(ROOT/'profiles/adventure-experimental.json')
    def tearDown(self):self.lib.ad_shutdown()
    def fixture(self,frame=10,room=17,player_x=80,sprite_id=6,sprite_x=40,dark=False):
        indices=(C.c_uint8*(160*210))();rgba=(C.c_uint32*(160*210))();ram=(C.c_uint8*128)()
        def pixel(x,y,c):indices[y*160+x]=c;rgba[y*160+x]=0xff000000|c|(c<<8)|(c<<16)
        for y in range(2,195):
            for x in range(160):pixel(x,y,8)
            for x in list(range(4))+list(range(156,160)):pixel(x,y,8 if dark else 26)
        ram[0]=0;ram[1]=0xf1;ram[10]=room;ram[11]=player_x;ram[12]=32
        for y in range(149,157):
            for x in range(player_x-2,player_x+2):pixel(x,y,26)
        ram[21]=sprite_id*9;ram[22]=162;ram[2]=0;ram[3]=0xf2;ram[6]=sprite_x;ram[7]=64
        dynamic={6:0xa4,9:0xb6,10:0xbc,11:0xbf,14:0xcb}.get(sprite_id,0xc8)-128
        ram[dynamic]=room;ram[dynamic+1]=sprite_x;ram[dynamic+2]=64
        for row,bits in enumerate([0xff,0x81,0xff]):
            for bit in range(8):
                if bits&(128>>bit):
                    for dy in range(2):pixel(sprite_x-1+bit,85+row*2+dy,26)
        f=Frame(160,210,frame,59.92,31400,rgba,indices,ram)
        return f,indices,rgba,ram
    def scene(self,fixture):return self.lib.ad_reconstruct(C.byref(fixture[0]),C.byref(self.p)).contents
    def test_same_color_player_and_creature_separate_from_walls(self):
        fixture=self.fixture(player_x=4,sprite_x=4);before=bytes(fixture[3]);s=self.scene(fixture)
        objs=s.objects[:s.object_count]
        self.assertEqual(bytes(fixture[3]),before)
        self.assertTrue({1,2,106,1026}.issubset({o.id for o in objs}))
        self.assertEqual(next(o for o in objs if o.id==106).role,2)
        actor=next(o for o in objs if o.id==106)
        self.assertEqual(actor.box_count,4) # ring hole survives rectangle merging
        self.assertTrue(all(b.width>0 and b.height>0 and b.depth>0 for b in s.boxes[:s.box_count]))
    def test_actor_translation_reuses_identity_and_local_mesh(self):
        s=self.scene(self.fixture());a=copy_struct(next(o for o in s.objects[:s.object_count] if o.id==106))
        s=self.scene(self.fixture(frame=11,sprite_x=41));b=copy_struct(next(o for o in s.objects[:s.object_count] if o.id==106))
        self.assertEqual(a.geometry_hash,b.geometry_hash);self.assertEqual(a.id,b.id)
        self.assertAlmostEqual(b.x-a.x,1/160,places=6)
    def test_dark_room_does_not_reveal_unrendered_playfield(self):
        s=self.scene(self.fixture(dark=True));self.assertFalse(any(o.role==1 for o in s.objects[:s.object_count]))
    def test_dark_surround_reveals_only_its_rendered_window(self):
        fixture=self.fixture(dark=True);f,indices,rgba,ram=fixture
        ram[21]=0;ram[2]=0x40;ram[3]=0xf2;ram[6]=1;ram[7]=64
        for y in range(85,149):
            for x in range(4,32):indices[y*160+x]=40;rgba[y*160+x]=0xff282828
        s=self.scene(fixture);walls=[o for o in s.objects[:s.object_count] if o.role==1]
        self.assertTrue(walls)
        self.assertTrue(all(o.pixel_x==0 and o.pixel_y>=85 and o.pixel_y+o.pixel_height<=149 for o in walls))
        self.assertTrue(any(o.id==3040 and o.role==4 for o in s.objects[:s.object_count]))
        self.assertFalse(any(o.id==100 for o in s.objects[:s.object_count]))
    def test_multiplex_hold_expires_and_room_transition_clears_cache(self):
        s=self.scene(self.fixture());room_id=s.scene_id
        fixture=self.fixture(frame=11);fixture[3][21]=162
        s=self.scene(fixture);self.assertTrue(any(o.id==106 for o in s.objects[:s.object_count]))
        fixture[0].number=14;s=self.scene(fixture)
        self.assertFalse(any(o.id==106 for o in s.objects[:s.object_count]))
        fixture=self.fixture(frame=15,room=18);fixture[3][21]=162
        s=self.scene(fixture);self.assertNotEqual(s.scene_id,room_id)
        self.assertFalse(any(o.id==106 for o in s.objects[:s.object_count]))
    def test_items_and_bridge_have_distinct_roles_and_budget_bounds(self):
        s=self.scene(self.fixture(sprite_id=11));self.assertEqual(next(o for o in s.objects[:s.object_count] if o.id==111).role,5)
        s=self.scene(self.fixture(frame=11,sprite_id=10));self.assertEqual(next(o for o in s.objects[:s.object_count] if o.id==110).role,4)
        self.p.max_objects=2;self.p.max_boxes=6;s=self.scene(self.fixture(frame=12))
        self.assertLessEqual(s.object_count,2);self.assertLessEqual(s.box_count,6);self.assertGreater(s.dropped_objects,0)

@unittest.skipUnless(ROM.exists(),'User-supplied Adventure ROM is not distributed to CI')
class AdventureSuppliedROM(unittest.TestCase):
    def test_exact_rom_castle_key_and_read_only_reconstruction(self):
        data=ROM.read_bytes();self.assertEqual(hashlib.sha256(data).hexdigest(),SHA)
        lib=load_library();lib.ad_initialize(str(ROOT/'build').encode());load_rom(lib,data)
        try:
            audio=(C.c_float*4096)();lib.ad_audio_read(audio,2048)
            for i in range(150):
                lib.ad_set_input(0,(1<<14)|((1<<3) if 60<=i<63 else 0),0,0)
                lib.ad_run_frame();lib.ad_audio_read(audio,2048)
            n=lib.ad_state_size();a=(C.c_uint8*n)();b=(C.c_uint8*n)();self.assertTrue(lib.ad_save_state(a,n))
            p=profile_from_json(ROOT/'profiles/adventure-experimental.json');s=lib.ad_reconstruct(lib.ad_current_frame(),C.byref(p)).contents
            self.assertTrue(lib.ad_save_state(b,n));self.assertEqual(bytes(a),bytes(b))
            self.assertTrue({1,2,101,111}.issubset({o.id for o in s.objects[:s.object_count]}))
            self.assertTrue(any(o.id==2026 for o in s.objects[:s.object_count]));self.assertEqual(s.dropped_objects,0)
            x=79/160-.5;z=.75*(130/210-.5)
            for o in s.objects[:s.object_count]:
                if o.role!=1:continue
                for box in s.boxes[o.first_box:o.first_box+o.box_count]:
                    self.assertFalse(abs(o.x+box.x-x)<box.width/2 and abs(o.z+box.z-z)<box.depth/2,'Castle volume buries the gate recess')
        finally:lib.ad_shutdown()
