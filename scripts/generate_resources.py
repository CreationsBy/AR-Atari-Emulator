#!/usr/bin/env python3
"""Create an original pixel-art application icon and copy bundled license texts."""
from pathlib import Path
import json
import shutil
import struct
import zlib
ROOT=Path(__file__).resolve().parents[1]

def png(path,width,height,rgba):
    def chunk(name,data):return struct.pack('>I',len(data))+name+data+struct.pack('>I',zlib.crc32(name+data)&0xffffffff)
    raw=b''.join(b'\0'+rgba[y*width*4:(y+1)*width*4] for y in range(height))
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b''))

def main():
    output=ROOT/'ios/Resources/Assets.xcassets/AppIcon.appiconset';output.mkdir(parents=True,exist_ok=True)
    n=1024;data=bytearray(n*n*4)
    # Code-native 32x32 pixel symbol, supersampled into the icon's square canvas.
    for y in range(n):
        for x in range(n):
            gx,gy=x//32,y//32
            color=(10,17,24,255)
            if 5<=gx<27 and 7<=gy<25:color=(19,43,49,255)
            if (5<=gx<27 and gy in [7,8,23,24]) or (gx in [5,6,25,26] and 7<=gy<25):color=(115,238,195,255)
            if (13<=gx<16 and 13<=gy<19) or (11<=gx<18 and 15<=gy<17):color=(255,150,76,255)
            if 20<=gx<23 and 11<=gy<14:color=(80,166,240,255)
            data[(y*n+x)*4:(y*n+x+1)*4]=bytes(color)
    png(output/'AppIcon.png',n,n,data)
    (output/'Contents.json').write_text(json.dumps({'images':[{'filename':'AppIcon.png','idiom':'universal','platform':'ios','size':'1024x1024'}],'info':{'author':'xcode','version':1}},indent=2))
    (output.parent/'Contents.json').write_text('{"info":{"author":"xcode","version":1}}\n')
    shutil.copyfile(ROOT/'LICENSE',ROOT/'ios/Resources/LICENSE.txt')
    shutil.copyfile(ROOT/'THIRD_PARTY_NOTICES.md',ROOT/'ios/Resources/THIRD_PARTY_NOTICES.txt')
    print('Application icon and license resources generated')
if __name__=='__main__':main()
