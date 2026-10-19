#!/usr/bin/env python3
from pathlib import Path
import os
import zipfile
ROOT=Path(__file__).resolve().parents[1]
def main():
    out=ROOT/'build/deliverables/AtariDiorama-source.zip';out.parent.mkdir(parents=True,exist_ok=True)
    excluded={'.git','.tools','build','__pycache__','roms'}
    count=0
    with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
        for directory,dirs,files in os.walk(ROOT):
            dirs[:]=[d for d in dirs if d not in excluded and not d.endswith('.xcodeproj')]
            for name in files:
                p=Path(directory)/name;relative=p.relative_to(ROOT)
                if p.suffix in ['.zip','.ipa','.p12','.mobileprovision','.key','.pem','.csr','.cer','.xcuserstate'] or name.startswith('.env'):continue
                z.write(p,'AtariDiorama/'+relative.as_posix());count+=1
        # The ROMs directory's explanatory readme is safe to distribute.
        z.write(ROOT/'roms/README.md','AtariDiorama/roms/README.md')
    print(f'{out}: {count+1} source files')
if __name__=='__main__':main()
