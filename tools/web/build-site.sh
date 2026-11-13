#!/usr/bin/env bash
# Builds the static site for the browser version (docs/WEB.md):
#
#     nix develop -c tools/web/build-site.sh [OUT]      # default zig-out/site
#
# OUT gets the page (zig build web: index.html, noite.js, noite.wasm,
# manifest.json), the disc files the manifest lists under assets/ and the
# SoundFont ($NOITE_SOUNDFONT, set by the dev shell) under soundfont/.
# OUT is replaced. Serve it as is (see docs/WEB.md for the headers).
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
out=${1:-$root/zig-out/site}
: "${NOITE_SOUNDFONT:?run inside nix develop (NOITE_SOUNDFONT is not set)}"

cd "$root"
zig build web
rm -rf "$out"
mkdir -p "$out"
cp zig-out/web/index.html zig-out/web/noite.js zig-out/web/noite.wasm zig-out/web/manifest.json "$out/"
python3 - "$out" <<'EOF'
import json, pathlib, shutil, sys, os
from urllib.parse import unquote
out = pathlib.Path(sys.argv[1])
m = json.loads((out / "manifest.json").read_text())
for f in m["files"]:
    url = unquote(f["url"])
    src = pathlib.Path(os.environ["NOITE_SOUNDFONT"]) if url.startswith("soundfont/") else pathlib.Path(url)
    dst = out / url
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dst)
    assert dst.stat().st_size == f["size"], url
print(f"{out}: {len(m['files'])} files, {m['total'] / 1e6:.1f} MB")
EOF
