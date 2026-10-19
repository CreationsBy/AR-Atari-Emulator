#!/usr/bin/env python3
import argparse
import hashlib
import json
import struct
import subprocess
import sys
import tempfile
from pathlib import Path
import plistlib
import zipfile

def main():
    p=argparse.ArgumentParser();p.add_argument('directory');p.add_argument('--signing',required=True);args=p.parse_args()
    records=[]
    for file in Path(args.directory).glob('*.ipa'):
        with zipfile.ZipFile(file) as z:
            infos=[n for n in z.namelist() if n.startswith('Payload/') and n.endswith('.app/Info.plist') and n.count('/')==2]
            if len(infos)!=1:raise SystemExit('Invalid IPA Payload layout')
            info=plistlib.loads(z.read(infos[0]));root=infos[0][:-len('Info.plist')]
            if root+info['CFBundleExecutable'] not in z.namelist():raise SystemExit('Missing application executable')
            executable=z.read(root+info['CFBundleExecutable'])
            if len(executable)<8 or struct.unpack('<II',executable[:8])!=(0xFEEDFACF,0x0100000C):
                raise SystemExit('Expected an arm64 Mach-O executable from the device archive')
            if info.get('CFBundleSupportedPlatforms')!=['iPhoneOS']:raise SystemExit('Not an iPhone device build')
            signed=root+'embedded.mobileprovision' in z.namelist() and root+'_CodeSignature/CodeResources' in z.namelist()
            if args.signing!='unsigned' and not signed:raise SystemExit('Signed IPA missing provisioning or signature resources')
            if root+'TabletopTest.a26' not in z.namelist():raise SystemExit('Missing homebrew test ROM')
            profiles=[n for n in z.namelist() if n.startswith(root+'profiles/') and n.endswith('.json')]
            if len(profiles)!=6 or root+'profiles/ice-hockey-ntsc.json' not in profiles:raise SystemExit('Missing conversion profiles')
            if json.loads(z.read(root+'profiles/ice-hockey-ntsc.json'))!=json.loads(Path('profiles/ice-hockey-ntsc.json').read_text()):raise SystemExit('Ice Hockey profile differs from source')
            verified=False
            if args.signing!='unsigned' and sys.platform=='darwin':
                with tempfile.TemporaryDirectory(prefix='atari-ipa-verify-') as temporary:
                    z.extractall(temporary)
                    app=Path(temporary)/root
                    subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
                    verified=True
            records.append({'file':file.name,'sha256':hashlib.sha256(file.read_bytes()).hexdigest(),'bundleID':info['CFBundleIdentifier'],
                'signingMode':args.signing,'signatureResourcesPresent':signed,'requiresResigning':args.signing=='unsigned',
                'signatureVerifiedOnMac':verified,'deviceTested':False,'profileCount':len(profiles)})
    if not records:raise SystemExit('No IPA was produced')
    (Path(args.directory)/'artifact-manifest.json').write_text(json.dumps(records,indent=2))
    print(json.dumps(records,indent=2))
if __name__=='__main__':main()
