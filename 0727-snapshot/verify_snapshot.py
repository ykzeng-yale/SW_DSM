#!/usr/bin/env python3
"""Read-only verification of the complete restored source-folder snapshot."""
import hashlib,json,os,sys
from pathlib import Path
base=Path(sys.argv[1])
manifest=json.loads(Path(__file__).with_name("SOURCE_MANIFEST.json").read_text())
errors=[]
for e in manifest["entries"]:
    p=base/e["path"]
    if e["type"]=="symlink":
        if not p.is_symlink() or os.readlink(p)!=e["target"]: errors.append(e["path"])
    elif e["type"]=="directory":
        if not p.is_dir() or p.is_symlink(): errors.append(e["path"])
    else:
        if not p.is_file() or p.is_symlink(): errors.append(e["path"]);continue
        h=hashlib.sha256()
        with p.open("rb") as f:
            for b in iter(lambda:f.read(8*1024*1024),b""): h.update(b)
        if p.stat().st_size!=e["size"] or h.hexdigest()!=e["sha256"]: errors.append(e["path"])
expected={e["path"] for e in manifest["entries"]}
actual={str(p.relative_to(base)) for p in base.rglob("*")}
errors.extend("unexpected: "+p for p in sorted(actual-expected))
if errors:
    print("FAILED",len(errors));print("\n".join(errors));sys.exit(1)
print("PASS: all",len(expected),"entries match the source manifest")
