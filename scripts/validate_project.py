#!/usr/bin/env python3
"""Offline structural checks. These do not substitute for an Xcode build."""
import hashlib
import json
import math
from pathlib import Path
import plistlib
ROOT=Path(__file__).resolve().parents[1]
def main():
    hashes=set();ids=set();profiles=list((ROOT/'profiles').glob('*.json'))
    assert len(profiles)==6,'Expected six explicit conversion profiles'
    properties={'minX','maxX','minY','maxY','minWidth','maxWidth','minHeight','maxHeight'}
    coreDB=(ROOT/'third_party/stella2014/stella/src/emucore/DefProps.hxx').read_text()
    for file in profiles:
        p=json.loads(file.read_text());assert p['schemaVersion']==1
        assert p['id'] not in ids;ids.add(p['id'])
        assert p['compatibility'] in ['development','experimental','generic','full']
        assert p['controller'] in ['joystick','paddles'];assert p['perspective'] in ['topDown','sideView']
        if 'reconstruction' in p:
            adapters={
                'iceHockeyNTSCv2':('fc8b861d9cf9c9d5f7f7677f22b39d512d249697b69c1e7dcf238c5dc8f44b60','a4c08c4994eb9d24fb78be1793e82e26'),
                'adventureNTSCv1':('b0326b45e5cab066b2d03f1e683708d82de3ffe60b2e968bf88c5494237f0a96','157bddb7192754a45372be196797f284')}
            assert p['reconstruction'] in adapters
            sha,md5=adapters[p['reconstruction']]
            assert p['sha256']==[sha] and p['md5']==[md5]
            if p['reconstruction']=='iceHockeyNTSCv2':assert p['hudTop']==0 and p['hudBottom']==0
        assert -1<=p['backgroundIndex']<256;assert -1<=p['sceneRAMOffset']<128
        assert 0<=p['hudTop']<1 and 0<=p['hudBottom']<1 and p['hudTop']+p['hudBottom']<1
        assert 0<p['defaultHeight']<=.5 and len(p['rules'])<=128
        for kind,length in [('sha256',64),('md5',32)]:
            for h in p[kind]:
                assert len(h)==length and all(c in '0123456789abcdef' for c in h)
                assert h not in hashes;hashes.add(h)
                if kind=='md5':assert h in coreDB,'Unknown ROM identifier'
        for r in p['rules']:
            assert 0<=r['role']<=5 and 0<r['height']<=.5
            for key in properties & r.keys():assert math.isfinite(r[key]) and 0<=r[key]<=1
            for lo,hi in [('minX','maxX'),('minY','maxY'),('minWidth','maxWidth'),('minHeight','maxHeight')]:assert r.get(lo,0)<=r.get(hi,1)
        assert len(p.get('program',[]))<=128
        for instruction in p.get('program',[]):
            assert 0<=instruction['ramOffset']<128 and 0<=instruction['ruleIndex']<len(p['rules'])
            assert 0<=instruction['mask']<=255 and 0<=instruction['equals']<=255
            assert instruction['equals'] & instruction['mask']==instruction['equals']
    rom=(ROOT/'ios/Resources/TabletopTest.a26').read_bytes();assert len(rom)==4096
    assert hashlib.sha256(rom).hexdigest() in hashes
    info=plistlib.loads((ROOT/'ios/Info.plist').read_bytes());assert info['NSCameraUsageDescription'];assert 'UIInterfaceOrientationLandscapeLeft' in info['UISupportedInterfaceOrientations']
    required=['README.md','docs/BUILD_WINDOWS.md','docs/PROFILES.md','docs/COMPATIBILITY.md','THIRD_PARTY_NOTICES.md','LICENSE']
    for file in required:assert (ROOT/file).is_file(),file
    print('Profiles, ROM identities, original cartridge and iOS configuration validated (Xcode compilation still required)')
if __name__=='__main__':main()
