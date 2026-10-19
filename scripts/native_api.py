"""ctypes bindings used by the headless integration tests and inspection tools."""
import ctypes as C
import json
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[1]
class Frame(C.Structure):
    _fields_=[('width',C.c_uint32),('height',C.c_uint32),('number',C.c_uint64),('fps',C.c_double),('sample_rate',C.c_double),('rgba',C.POINTER(C.c_uint32)),('indices',C.POINTER(C.c_uint8)),('ram',C.POINTER(C.c_uint8))]
class Rule(C.Structure):
    _fields_=[('color_index',C.c_int32),('role',C.c_int32)]+[(x,C.c_float) for x in ['min_x','max_x','min_y','max_y','min_width','max_width','min_height','max_height','height','elevation']]+[('pattern',C.c_uint64)]
class Profile(C.Structure):
    _fields_=[('hud_top',C.c_float),('hud_bottom',C.c_float),('default_height',C.c_float),('background_index',C.c_int32),('side_view',C.c_int32),('max_objects',C.c_uint32),('max_boxes',C.c_uint32),('scene_ram_offset',C.c_int32),('rule_count',C.c_uint32),('rules',C.POINTER(Rule)),('adapter',C.c_uint32)]
class Box(C.Structure):
    _fields_=[(x,C.c_float) for x in ['x','y','z','width','height','depth']]
class Object(C.Structure):
    _fields_=[(x,C.c_uint64) for x in ['id','geometry_hash','pattern']]+[(x,C.c_uint32) for x in ['color_rgba','first_box','box_count']]+[('role',C.c_int32),('color_index',C.c_int32)]+[(x,C.c_float) for x in ['x','y','z','pixel_x','pixel_y','pixel_width','pixel_height']]
class Scene(C.Structure):
    _fields_=[('frame_number',C.c_uint64),('scene_id',C.c_uint64)]+[(x,C.c_uint32) for x in ['object_count','box_count','dropped_objects','dropped_boxes']]+[('analysis_ms',C.c_double),('objects',C.POINTER(Object)),('boxes',C.POINTER(Box))]
class TIAWrite(C.Structure):
    _fields_=[('cycle',C.c_uint32),('address',C.c_uint16),('value',C.c_uint8),('reserved',C.c_uint8)]

def load_library():
    name='AtariDiorama.dll' if sys.platform=='win32' else 'libAtariDiorama.dylib' if sys.platform=='darwin' else 'libAtariDiorama.so'
    lib=C.CDLL(str(ROOT/'build/native-host'/name))
    signatures={
      'initialize':(C.c_bool,[C.c_char_p]),'load_rom':(C.c_bool,[C.POINTER(C.c_uint8),C.c_size_t,C.c_char_p]),
      'shutdown':(None,[]),'last_error':(C.c_char_p,[]),'run_frame':(C.POINTER(Frame),[]),'current_frame':(C.POINTER(Frame),[]),
      'set_input':(None,[C.c_uint32,C.c_uint16,C.c_int16,C.c_int16]),'set_controller':(None,[C.c_uint32,C.c_uint32]),
      'reset':(None,[]),'state_size':(C.c_size_t,[]),'save_state':(C.c_bool,[C.POINTER(C.c_uint8),C.c_size_t]),
      'load_state':(C.c_bool,[C.POINTER(C.c_uint8),C.c_size_t]),'audio_read':(C.c_size_t,[C.POINTER(C.c_float),C.c_size_t]),
      'audio_dropped':(C.c_uint64,[]),'tia_writes':(C.POINTER(TIAWrite),[C.POINTER(C.c_uint32),C.POINTER(C.c_uint32)]),
      'audio_streaming':(None,[C.c_bool]),'audio_stream_read':(C.c_size_t,[C.POINTER(C.c_int16),C.c_size_t]),
      'audio_receive':(None,[C.POINTER(C.c_int16),C.c_size_t]),'audio_clear':(None,[]),
      'reconstruct':(C.POINTER(Scene),[C.POINTER(Frame),C.POINTER(Profile)]),'reset_reconstruction':(None,[])}
    for name,(result,args) in signatures.items():
        fn=getattr(lib,'ad_'+name);fn.restype=result;fn.argtypes=args
    return lib

def load_rom(lib,data=None):
    data=data or (ROOT/'ios/Resources/TabletopTest.a26').read_bytes()
    memory=(C.c_uint8*len(data)).from_buffer_copy(data)
    if not lib.ad_load_rom(memory,len(data),b'TabletopTest.a26'):raise RuntimeError(lib.ad_last_error().decode())

def profile_from_json(filename):
    data=json.loads(Path(filename).read_text());rules=[]
    for r in data['rules']:
        rules.append(Rule(r.get('colorIndex',-1),r.get('role',0),r.get('minX',0),r.get('maxX',1),r.get('minY',0),r.get('maxY',1),r.get('minWidth',0),r.get('maxWidth',1),r.get('minHeight',0),r.get('maxHeight',1),r.get('height',.025),r.get('elevation',0),int(r.get('pattern','0'),16)))
    storage=(Rule*len(rules))(*rules)
    p=Profile(data.get('hudTop',0),data.get('hudBottom',0),data.get('defaultHeight',.025),data.get('backgroundIndex',-1),int(data.get('perspective')=='sideView'),1024,24000,data.get('sceneRAMOffset',-1),len(storage),storage)
    p._rules=storage
    p.adapter=1 if data.get('reconstruction')=='iceHockeyNTSCv1' else 0
    return p

def copy_struct(obj):
    return type(obj).from_buffer_copy(bytes(obj))
