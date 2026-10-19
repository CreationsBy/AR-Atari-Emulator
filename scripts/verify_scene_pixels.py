"""Independently project native X/Z box footprints back to original raster pixels."""
def rasterize_scene(scene,width,height):
    image=bytearray(width*height*4);coverage=bytearray(width*height)
    for obj in scene.objects[:scene.object_count]:
        color=int(obj.color_rgba).to_bytes(4,'little')
        for box in scene.boxes[obj.first_box:obj.first_box+obj.box_count]:
            if min(box.width,box.height,box.depth)<=0:raise AssertionError('Non-volumetric geometry')
            left=(obj.x+box.x-box.width/2+.5)*width
            right=(obj.x+box.x+box.width/2+.5)*width
            top=((obj.z+box.z-box.depth/2)/.75+.5)*height
            bottom=((obj.z+box.z+box.depth/2)/.75+.5)*height
            values=[left,right,top,bottom];rounded=[round(v) for v in values]
            if any(abs(v-r)>.002 for v,r in zip(values,rounded)):raise AssertionError('Geometry not aligned to source pixels')
            x0,x1,y0,y1=rounded
            if not (0<=x0<x1<=width and 0<=y0<y1<=height):raise AssertionError('Added geometry outside the original raster')
            row=color*(x1-x0);marks=b'\1'*(x1-x0)
            for y in range(y0,y1):
                start=y*width+x0;end=y*width+x1
                if any(coverage[start:end]):raise AssertionError('Overlapping source-plane geometry')
                coverage[start:end]=marks;image[start*4:end*4]=row
    if 0 in coverage:raise AssertionError('Missing original pixels')
    return bytes(image)
