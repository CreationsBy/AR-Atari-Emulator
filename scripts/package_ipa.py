#!/usr/bin/env python3
"""Package an *unsigned* device archive for a separate signing tool."""
import argparse
from pathlib import Path
import plistlib
import shutil
import subprocess

def main():
    p=argparse.ArgumentParser();p.add_argument('archive');p.add_argument('output');args=p.parse_args()
    archive=Path(args.archive).resolve();out=Path(args.output).resolve()
    apps=list((archive/'Products/Applications').glob('*.app'))
    if len(apps)!=1:raise SystemExit('Expected exactly one application in the device archive')
    info=plistlib.loads((apps[0]/'Info.plist').read_bytes())
    if info.get('CFBundleSupportedPlatforms')!=['iPhoneOS']:raise SystemExit('Only device builds can be packaged as an IPA')
    stage=out.parent/'unsigned-package';payload=stage/'Payload';payload.mkdir(parents=True,exist_ok=True)
    shutil.copytree(apps[0],payload/apps[0].name,dirs_exist_ok=True,symlinks=True)
    # macOS zip preserves executable bits and the normal Payload/*.app layout.
    out.parent.mkdir(parents=True,exist_ok=True)
    if out.exists():out.unlink()
    subprocess.run(['zip','-qry',str(out),'Payload'],cwd=stage,check=True)
    print(str(out)+' — UNSIGNED; requires signing before installation')
if __name__=='__main__':main()
