#!/usr/bin/env python3
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
    manifest=json.loads((ROOT/'third_party/stella2014-manifest.json').read_text())
    vendor=ROOT/'third_party/stella2014'
    actual={p.relative_to(vendor).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in vendor.rglob('*') if p.is_file()}
    if actual!=manifest['files']:
        changed=[p for p in set(actual)|set(manifest['files']) if actual.get(p)!=manifest['files'].get(p)]
        raise SystemExit('Vendor integrity check failed: '+', '.join(changed))
    print(f"Stella {manifest['revision']}: {len(actual)} files verified")
if __name__=='__main__':main()
