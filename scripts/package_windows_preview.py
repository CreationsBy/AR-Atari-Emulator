#!/usr/bin/env python3
"""Bundle the tested Windows DLL with its local viewer and complete matching source."""
from pathlib import Path
import zipfile
from package_source import ROOT,main as package_source

def main():
    package_source()
    out=ROOT/'build/deliverables/AtariDiorama-Windows-preview.zip'
    files=['build/native-host/AtariDiorama.dll','build/native-host/build-info.json',
        'scripts/preview_server.py','scripts/native_api.py','scripts/Start-Preview.ps1','scripts/Windows-Helpers.ps1',
        'tools/preview.html','ios/Resources/TabletopTest.a26','LICENSE','THIRD_PARTY_NOTICES.md']
    files += [str(p.relative_to(ROOT)).replace('\\','/') for p in (ROOT/'profiles').glob('*.json')]
    with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
        for name in files:z.write(ROOT/name,'AtariDioramaPreview/'+name)
        z.write(ROOT/'build/deliverables/AtariDiorama-source.zip','AtariDioramaPreview/source/AtariDiorama-source.zip')
        z.writestr('AtariDioramaPreview/README.txt',
            'ATARI DIORAMA - WINDOWS NATIVE PROTOTYPE\n\n'
            'Install Python 3.12+ from python.org if needed. Extract this complete folder.\n'
            'Open a terminal here and run: python scripts/preview_server.py\n'
            'Then open http://127.0.0.1:8260 in a browser.\n'
            'WASD/arrows move; Space fires; Enter selects; R resets.\n'
            'Click Enable sound for real TIA audio. Drag to orbit; scroll to zoom.\n'
            'Ctrl+C in the terminal stops the server. No internet service is used.\n\n'
            'This executes the genuine Stella core and renders reconstructed 3D geometry.\n'
            'It is a Windows inspection tool, not an iOS app or AR test.\n'
            'The native iOS source and hosted IPA workflow are in the included matching\n'
            'source/AtariDiorama-source.zip. Apple compilation and phone testing are pending.\n'
            'Commercial game profiles are experimental. No commercial ROMs are included.\n'
            'GPLv2 binary; full corresponding source, build scripts and notices are included.\n')
    print(out)
if __name__=='__main__':main()
