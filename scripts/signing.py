#!/usr/bin/env python3
"""Hosted Mac signing setup. Never prints private-key material or passwords."""
import base64
from datetime import datetime,timezone
import fnmatch
import hashlib
import json
import os
from pathlib import Path
import plistlib
import secrets
import subprocess
import sys
ROOT=Path(__file__).resolve().parents[1]
STATE=ROOT/'build/signing-state.json'

def run(*args):
    process=subprocess.run(args,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    if process.returncode:raise RuntimeError(f'{args[0]} failed during signing setup: '+process.stderr.decode(errors='replace'))
    return process.stdout

def prepare():
    build=ROOT/'build';build.mkdir(exist_ok=True)
    mode=os.environ['SIGNING_MODE'];bundle=os.environ['BUNDLE_ID']
    if mode not in ['development','ad-hoc']:raise RuntimeError('Unknown signing mode')
    temp=Path(os.environ.get('RUNNER_TEMP',build/'signing')).resolve();temp.mkdir(parents=True,exist_ok=True)
    certificate=temp/'atari-signing.p12';profilePath=temp/'atari-profile.mobileprovision';keychain=temp/'atari-signing.keychain-db'
    certificate.write_bytes(base64.b64decode(os.environ['BUILD_CERTIFICATE_BASE64'],validate=True))
    profilePath.write_bytes(base64.b64decode(os.environ['BUILD_PROVISION_PROFILE_BASE64'],validate=True))
    certificate.chmod(0o600);profilePath.chmod(0o600)
    profile=plistlib.loads(run('security','cms','-D','-i',str(profilePath)))
    team=profile['TeamIdentifier'][0];name=profile['Name'];uuid=profile['UUID']
    if any('\n' in value or '\r' in value for value in [bundle,team,name,uuid]):raise RuntimeError('Invalid signing metadata')
    if not fnmatch.fnmatchcase(bundle,profile['Entitlements']['application-identifier'].split('.',1)[1]):raise RuntimeError('Provisioning profile does not match bundle identifier')
    if profile['ExpirationDate'].replace(tzinfo=timezone.utc)<=datetime.now(timezone.utc):raise RuntimeError('Provisioning profile has expired')
    if not profile.get('ProvisionedDevices'):raise RuntimeError('Use a profile containing the test iPhone UDID')
    debug=profile['Entitlements'].get('get-task-allow',False)
    if (mode=='development')!=debug:raise RuntimeError('Profile type does not match selected signing mode')
    previous=run('security','list-keychains','-d','user').decode()
    import shlex
    original=shlex.split(previous)
    state={'keychain':str(keychain),'certificate':str(certificate),'profile':str(profilePath),'installed':[],'searchList':original}
    STATE.write_text(json.dumps(state))
    password=secrets.token_urlsafe(36)
    run('security','create-keychain','-p',password,str(keychain))
    run('security','set-keychain-settings','-lut','21600',str(keychain))
    run('security','unlock-keychain','-p',password,str(keychain))
    run('security','import',str(certificate),'-P',os.environ['P12_PASSWORD'],'-A','-t','cert','-f','pkcs12','-k',str(keychain))
    run('security','set-key-partition-list','-S','apple-tool:,apple:,codesign:','-s','-k',password,str(keychain))
    run('security','list-keychains','-d','user','-s',str(keychain),*original)
    identities=run('security','find-identity','-v','-p','codesigning',str(keychain)).decode()
    fingerprints=[hashlib.sha1(der).hexdigest().upper() for der in profile['DeveloperCertificates']]
    identity=next((s for s in fingerprints if s in identities),None)
    if not identity:raise RuntimeError('The imported private key does not match this profile')
    import shutil
    for directory in [Path.home()/'Library/MobileDevice/Provisioning Profiles',Path.home()/'Library/Developer/Xcode/UserData/Provisioning Profiles']:
        directory.mkdir(parents=True,exist_ok=True);dest=directory/(uuid+'.mobileprovision')
        if dest.exists():raise RuntimeError('Refusing to overwrite an existing provisioning profile on this Mac')
        shutil.copyfile(profilePath,dest);state['installed'].append(str(dest));STATE.write_text(json.dumps(state))
    values={'APPLE_TEAM_ID':team,'PROFILE_NAME':name,'SIGNING_IDENTITY_SHA':identity,'SIGNING_KEYCHAIN':str(keychain)}
    with open(os.environ['GITHUB_ENV'],'a') as stream:
        for k,v in values.items():stream.write(k+'='+v+'\n')
    export={'method':'debugging' if mode=='development' else 'release-testing','teamID':team,'signingStyle':'manual',
            'signingCertificate':identity,'provisioningProfiles':{bundle:name},'stripSwiftSymbols':True,
            'manageAppVersionAndBuildNumber':False,'destination':'export'}
    (build/'ExportOptions.plist').write_bytes(plistlib.dumps(export))
    print('Validated signing identity and matching device provisioning profile')

def cleanup():
    if not STATE.exists():return
    state=json.loads(STATE.read_text())
    if state.get('searchList'):run('security','list-keychains','-d','user','-s',*state['searchList'])
    keychain=Path(state['keychain'])
    if keychain.exists():run('security','delete-keychain',str(keychain))
    for filename in [state['certificate'],state['profile'],*state['installed']]:
        Path(filename).unlink(missing_ok=True)
    STATE.unlink()
    print('Temporary signing material removed')

if __name__=='__main__':
    try:
        if sys.argv[1]=='prepare':prepare()
        elif sys.argv[1]=='cleanup':cleanup()
        else:raise RuntimeError('Expected prepare or cleanup')
    except Exception as error:
        print(str(error),file=sys.stderr);sys.exit(1)
