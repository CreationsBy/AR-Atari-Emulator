#!/usr/bin/env python3
"""Small, two-pass assembler for this project's original cartridge.
Only the documented subset below is accepted. No external assembler needed.
"""
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
OPS = {
 'SEI':0x78,'CLD':0xD8,'TXS':0x9A,'DEX':0xCA,'TXA':0x8A,'TYA':0x98,'TAX':0xAA,
 'INY':0xC8,'RTS':0x60,'SEC':0x38,'CLC':0x18,'ASL A':0x0A,
 'LDA #':0xA9,'LDX #':0xA2,'LDY #':0xA0,'CMP #':0xC9,'CPY #':0xC0,'STX z':0x86,
 'AND #':0x29,'EOR #':0x49,'SBC #':0xE9,'ADC #':0x69,
 'LDA z':0xA5,'LDA a':0xAD,'LDA a,X':0xBD,'LDA a,Y':0xB9,'STA z':0x85,'STA a':0x8D,
 'STA z,X':0x95,'STA a,X':0x9D,'INC z':0xE6,'DEC z':0xC6,'SBC z':0xE5,
 'JMP a':0x4C,'JSR a':0x20,'BNE r':0xD0,'BEQ r':0xF0,'BCC r':0x90,'BCS r':0xB0,
}

def assemble(source):
    symbols={}
    lines=[line.split(';')[0].strip() for line in source.splitlines()]
    def value(s, first=False):
        s=s.strip()
        if s.startswith('$'): return int(s[1:],16)
        if s.isdecimal(): return int(s)
        if s in symbols: return symbols[s]
        if first: return 0xFFFF
        raise ValueError('Unknown symbol '+s)
    image=bytearray([0xEA]*4096)
    for first in [True, False]:
        pc=0xF000
        for line in lines:
            if not line:continue
            if '=' in line:
                k,v=line.split('=',1);symbols[k.strip()]=value(v);continue
            if line.endswith(':'):symbols[line[:-1]]=pc;continue
            if line.startswith('.org '):pc=value(line[5:]);continue
            if line.startswith(('.byte ','.word ')):
                width=1 if line.startswith('.byte') else 2
                data=[]
                for v in line[6:].split(','):
                    n=value(v,first);data += [n&255] if width==1 else [n&255,(n>>8)&255]
            else:
                parts=line.split(None,1);op=parts[0];operand=parts[1] if len(parts)>1 else ''
                if not operand or operand=='A':key=line;data=[OPS[key]]
                elif operand.startswith('#'):key=op+' #';data=[OPS[key],value(operand[1:],first)&255]
                elif op in ['BNE','BEQ','BCC','BCS']:
                    offset=value(operand,first)-(pc+2)
                    if not first and not -128<=offset<=127:raise ValueError('Branch too far: '+line)
                    data=[OPS[op+' r'],offset&255]
                else:
                    indexed=operand.endswith((',X',',Y'));arg=operand[:-2] if indexed else operand
                    n=value(arg,first);mode='z' if n<256 else 'a';key=op+' '+mode+(operand[-2:] if indexed else '')
                    data=[OPS[key],n&255]+([] if mode=='z' else [(n>>8)&255])
            if not first:
                if pc<0xF000 or pc+len(data)>0x10000:raise ValueError('Cartridge overflow')
                image[pc-0xF000:pc-0xF000+len(data)]=bytes(data)
            pc+=len(data)
    return bytes(image),symbols

def main():
    image,symbols=assemble((ROOT/'homebrew/TabletopTest.asm').read_text())
    output=ROOT/'ios/Resources';output.mkdir(parents=True,exist_ok=True)
    (output/'TabletopTest.a26').write_bytes(image)
    sha=hashlib.sha256(image).hexdigest()
    (ROOT/'homebrew/manifest.json').write_text(json.dumps({'title':'Tabletop Test','sha256':sha,'size':len(image),'ram':{k:v-128 for k,v in symbols.items() if 128<=v<256}},indent=2)+'\n')
    profile=ROOT/'profiles/tabletop-test.json'
    if profile.exists():
        data=json.loads(profile.read_text());data['sha256']=[sha];profile.write_text(json.dumps(data,indent=2)+'\n')
    print('TabletopTest.a26 SHA-256 '+sha)

if __name__=='__main__':main()
