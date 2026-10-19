#!/usr/bin/env python3
"""Build pinned Stella + the same portable bridge/reconstruction used by iOS.
No shell interpolation. On Windows pass --zig .tools/zig-.../zig.exe.
"""
import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
VENDOR = ROOT / 'third_party/stella2014'

def prepare(output):
    # Instrument a build copy; the vendored upstream tree stays byte-for-byte intact.
    target = output / 'stella2014'
    target.mkdir(parents=True, exist_ok=True)
    for source in VENDOR.rglob('*'):
        if not source.is_file():
            continue
        dest = target / source.relative_to(VENDOR)
        dest.parent.mkdir(parents=True, exist_ok=True)
        content = source.read_bytes()
        if source.name == 'TIA.cxx':
            text = content.decode()
            anchor = '  int32_t clock = mySystem->cycles() * 3;'
            # Only instrument poke (other methods also compute clock).
            start = text.index('bool TIA::poke(uint16_t addr, uint8_t value)')
            pos = text.index(anchor, start) + len(anchor)
            text = text[:pos] + '\n  ad_capture_tia_write(uint32_t((clock - myClockWhenFrameStarted) / 3), addr, value);' + text[pos:]
            content = ('#include <stdint.h>\nextern "C" void ad_capture_tia_write(uint32_t, uint16_t, uint8_t);\n' + text).encode()
        elif source.name == 'Console.hxx':
            text = content.decode()
            anchor = '    void setProperties(const Properties& props);'
            if text.count(anchor) != 1: raise RuntimeError('Controller configuration anchor changed')
            content = text.replace(anchor, anchor + '\n    void dioramaSetControllers(const Properties& props);').encode()
        elif source.name == 'Console.cxx':
            content += b'\n// Atari Diorama: change physical controller configuration without replacing the ROM.\nvoid Console::dioramaSetControllers(const Properties& props) {\n  myProperties = props;\n  setControllers(myProperties.get(Cartridge_MD5));\n}\n'
        elif source.name == 'libretro.cxx':
            text = content.decode()
            # sched.h is unused by this core and absent in MinGW's headers.
            text = text.replace('#ifndef _MSC_VER\n#include <sched.h>', '#if !defined(_MSC_VER) && !defined(_WIN32)\n#include <sched.h>')
            anchor = '   //Copy the frame from stella to libretro'
            if text.count(anchor) != 1:
                raise RuntimeError('Pinned video instrumentation anchor changed')
            text = text.replace(anchor, '   ad_capture_indices(tia.currentFrameBuffer(), videoWidth, videoHeight);\n' + anchor)
            text += '''
// Atari Diorama: explicit controller selection configures Stella's real devices.
extern "C" void ad_core_set_controller(unsigned port, unsigned type) {
   if (!console || port > 1) return;
   // Absolute paddle events must not leak into a subsequently selected joystick.
   osystem.eventHandler().event().clear();
   Properties props = console->properties();
   props.set(port == 0 ? Controller_Left : Controller_Right, type == 1 ? "PADDLES" : "JOYSTICK");
   console->dioramaSetControllers(props);
   init_paddles();
}
'''
            content = ('#include <stdint.h>\nextern "C" void ad_capture_indices(const uint8_t*, unsigned, unsigned);\n' + text).encode()
        if not dest.exists() or dest.read_bytes() != content:
            dest.write_bytes(content)
    return target

def source_list(vendor):
    make = (vendor / 'Makefile.common').read_text().replace('\\\n', ' ')
    variables = {'CORE_DIR': str(vendor / 'stella'), 'LIBRETRO_DIR': str(vendor), 'LIBRETRO_COMM_DIR': str(vendor / 'libretro-common')}
    result = []
    for kind in ['SOURCES_CXX', 'SOURCES_C']:
        value = re.search(r'^' + kind + r'\s*:=([^\n]+)', make, re.M).group(1)
        for key, replacement in variables.items():
            value = value.replace('$(' + key + ')', replacement.replace(' ', '__SPACE__'))
        result += [Path(item.replace('__SPACE__', ' ')) for item in value.split()]
    return result + list((ROOT / 'native/src').glob('*.cpp'))

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--platform', choices=['host', 'ios', 'simulator'], default='host')
    parser.add_argument('--arch', default='arm64')
    parser.add_argument('--zig')
    parser.add_argument('--jobs', type=int, default=4)
    args = parser.parse_args()
    output = ROOT / 'build' / ('native-' + args.platform)
    output.mkdir(parents=True, exist_ok=True)
    if args.zig:
        # Keep compiler caches in the authorized workspace (including child processes).
        os.environ['ZIG_GLOBAL_CACHE_DIR'] = str(ROOT / '.tools/zig-global-cache')
        os.environ['ZIG_LOCAL_CACHE_DIR'] = str(output / 'zig-cache')
    vendor = prepare(output)
    includes = [ROOT / 'native/include', vendor, vendor / 'libretro-common/include', vendor / 'stella', vendor / 'stella/src', vendor / 'stella/stubs']
    includes += [vendor / 'stella/src' / p for p in ['emucore', 'common', 'gui']]
    common = ['-O2', '-DNDEBUG', '-D__LIBRETRO__', '-DTHUMB_SUPPORT', '-fno-strict-overflow', '-Wno-narrowing', '-Wno-deprecated-declarations']
    common += [f'-I{p}' for p in includes]
    apple = args.platform != 'host'
    if apple:
        sdk = 'iphoneos' if args.platform == 'ios' else 'iphonesimulator'
        sdkpath = subprocess.check_output(['xcrun', '--sdk', sdk, '--show-sdk-path'], text=True).strip()
        triple = f'{args.arch}-apple-ios16.0' + ('-simulator' if args.platform == 'simulator' else '')
        common += ['-target', triple, '-isysroot', sdkpath, '-fPIC']
    elif sys.platform != 'win32':
        common += ['-fPIC']
    # GCC requires the numeric threshold in -Werror= as well; Clang expects
    # the warning group without that value. Check the actual host compiler.
    clang_stack_flags = bool(args.zig) or apple
    if not clang_stack_flags:
        version = subprocess.check_output([os.environ.get('CXX', 'c++'), '--version'], text=True)
        clang_stack_flags = 'clang' in version.lower()
    def compile_one(source):
        cpp = source.suffix in ['.cxx', '.cpp']
        command = [str(Path(args.zig).resolve()), 'c++' if cpp else 'cc'] if args.zig else [('clang++' if cpp else 'clang') if apple else os.environ.get('CXX' if cpp else 'CC', 'c++' if cpp else 'cc')]
        obj = output / (hashlib.sha256(str(source).encode()).hexdigest()[:18] + '.o')
        flags = common + (['-std=c++17'] if cpp else ['-std=gnu99'])
        if source.parent == ROOT / 'native/src':
            # App-authored bridge/adapters run on an iOS background queue.
            # Catch large frame/aggregate temporaries on the actual target ABI.
            flags += ['-Wframe-larger-than=65536', '-Werror=frame-larger-than' if clang_stack_flags else '-Werror=frame-larger-than=65536']
        stamp = obj.with_suffix('.command')
        digest = hashlib.sha256((' '.join(command + flags)).encode()).hexdigest()
        headers = list((ROOT / 'native/include').glob('*.h'))
        newest = max([source.stat().st_mtime] + [h.stat().st_mtime for h in headers])
        if not obj.exists() or obj.stat().st_mtime < newest or not stamp.exists() or stamp.read_text() != digest:
            run = subprocess.run(command + flags + ['-c', str(source), '-o', str(obj)], capture_output=True, text=True)
            if run.returncode:
                raise RuntimeError(f'{source.name}\n{run.stderr}')
            stamp.write_text(digest)
        return obj
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        objects = list(pool.map(compile_one, source_list(vendor)))
    if apple:
        library = output / 'libAtariDiorama.a'
        subprocess.run(['xcrun', 'libtool', '-static', '-o', str(library)] + [str(p) for p in objects], check=True)
    else:
        library = output / ('AtariDiorama.dll' if sys.platform == 'win32' else 'libAtariDiorama.dylib' if sys.platform == 'darwin' else 'libAtariDiorama.so')
        command = [str(Path(args.zig).resolve()), 'c++'] if args.zig else [os.environ.get('CXX', 'c++')]
        command += ['-shared', '-o', str(library)] + [str(p) for p in objects]
        if sys.platform == 'win32': command += ['-lwinmm']
        link = subprocess.run(command, capture_output=True, text=True)
        if link.returncode:
            raise SystemExit('Native link failed. Stop the live preview before rebuilding on Windows.\n' + link.stderr)
    (output / 'build-info.json').write_text(json.dumps({'core_revision':'7d1361e407e63f29e52892655069e5fb4096e691', 'platform':args.platform, 'sources':len(objects)}, indent=2))
    print(library)

if __name__ == '__main__':
    main()
