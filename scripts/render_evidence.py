"""Run with Blender --background --python scripts/render_evidence.py.
Renders only boxes captured from Stella's actual framebuffer reconstruction.
This is offline geometry verification, not an AR or iOS screenshot.
"""
from pathlib import Path
import json
import math
import argparse
import sys
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--input',type=Path,default=ROOT/'build/evidence/reconstructed-scene.json')
parser.add_argument('--output',type=Path,default=ROOT/'build/evidence')
parser.add_argument('--upright',action='store_true')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
data=json.loads(args.input.read_text())
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)

def material(name,color):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    bsdf=m.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Base Color'].default_value=(*color,1);bsdf.inputs['Roughness'].default_value=.72
    return m

for obj in data['objects']:
    vertices=[];faces=[];px,py,pz=obj['position']
    for x,y,z,w,h,d in obj['boxes']:
        start=len(vertices)
        corners=[(x+sx*w/2,y+sy*h/2,z+sz*d/2) for sx,sz,sy in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
        standing=(data.get('reconstruction')=='iceHockeyNTSCv1' and obj['role']==2 or
                  data.get('reconstruction')=='adventureNTSCv1' and obj['role'] in (2,5))
        if args.upright and standing:
            corners=[(cx,cz,-cy) for cx,cy,cz in corners]
        corners=[(cx+px,cy+py,cz+pz) for cx,cy,cz in corners]
        vertices += [(cx,cy,0.375-cz) if args.upright else (cx,cz,cy) for cx,cy,cz in corners]
        faces += [tuple(start+i for i in f) for f in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]]
    mesh=bpy.data.meshes.new(str(obj['id']));mesh.from_pydata(vertices,[],faces);mesh.update()
    entity=bpy.data.objects.new('TIA_'+str(obj['colorIndex'])+'_'+str(obj['id']),mesh);bpy.context.collection.objects.link(entity)
    c=obj['rgba'];entity.data.materials.append(material(str(c),[(c&255)/255,((c>>8)&255)/255,((c>>16)&255)/255]))
bpy.ops.mesh.primitive_cube_add(size=1,location=(0,0,-.012));base=bpy.context.object;base.name='Presentation base';base.dimensions=(1.04,.79,.02)
if args.upright:base.location=(0,-.012,.375);base.dimensions=(1.04,.02,.79)
base.data.materials.append(material('Base',[.022,.032,.044]))
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.026));bpy.context.object.data.materials.append(material('Ground',[.055,.073,.09]))
bpy.ops.object.light_add(type='AREA',location=(-1,1.5 if args.upright else -1,2));bpy.context.object.data.energy=180;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=2
bpy.ops.object.camera_add(location=(1.1,1.4,1.4));camera=bpy.context.object
camera.rotation_euler=(Vector((0,0,.375 if args.upright else .02))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=1.55
scene=bpy.context.scene;scene.camera=camera;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1200;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.world.color=(.20,.20,.20);scene.render.image_settings.file_format='PNG';scene.render.filepath=str(output/'reconstruction-3d.png')
scene.view_settings.view_transform='Standard'
bpy.ops.render.render(write_still=True)
