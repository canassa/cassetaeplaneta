#!/usr/bin/env bash
# Builds the static site for the browser version (docs/WEB.md):
#
#     nix develop -c tools/web/build-site.sh [OUT]      # default zig-out/site
#
# OUT gets the page (zig build web: index.html, noite.js, noite.wasm,
# manifest.json), the disc files the manifest lists under assets/ and the
# SoundFont ($NOITE_SOUNDFONT, set by the dev shell) under soundfont/;
# then tools/web/stamp.py gives every file but index.html a content hash
# (requested as `url?h=<hash>`) and stamps the release id ($NOITE_RELEASE,
# "local" without it) and the commit into index.html. Then the asset
# explorer goes to OUT/explorer/ (tools/explorer/build.py, in the
# `explorer` dev shell: Pillow and ffmpeg; its media are cached in
# zig-out/explorer/cache); the game's manifest does not list it.
# OUT is replaced. Serve it as is (see docs/WEB.md for the headers).
#
# Two opt-in variables, for a private build with the MK3 fight prototype
# (docs/fights/MK3.md; never the public deploy):
#   NOITE_SPRITES=DIR       adds the files under DIR (zig-out/sprites: the
#                           Ryu pack, not in git) as sprites/<path>, keyed
#                           `<path>` (ryu/pack.bin) in the manifest;
#   NOITE_SKIP_EXPLORER=1   leaves out the asset explorer (slow to build).
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
extra = os.environ.get("NOITE_SPRITES")
if extra:
    import hashlib
    from urllib.parse import quote
    base = pathlib.Path(extra)
    for src in sorted(p for p in base.rglob("*") if p.is_file()):
        rel = src.relative_to(base).as_posix()
        dst = out / "sprites" / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dst)
        m["keys"][rel.lower()] = len(m["files"])
        m["files"].append({"url": "sprites/" + quote(rel), "size": src.stat().st_size})
    m["total"] = sum(f["size"] for f in m["files"])
    m["version"] = hashlib.sha256("".join(f"{f['url']} {f['size']}\n" for f in m["files"]).encode()).hexdigest()[:16]
    (out / "manifest.json").write_text(json.dumps(m, separators=(",", ":")))
print(f"{out}: {len(m['files'])} files, {m['total'] / 1e6:.1f} MB")
EOF
# The commit the page reports (tools/web/stamp.py); -dirty when the tree
# has uncommitted changes.
NOITE_COMMIT=$(git describe --always --dirty --abbrev=12 2>/dev/null || true) python3 tools/web/stamp.py "$out"
# The asset explorer (docs/WEB.md, "Asset explorer").
[ -n "${NOITE_SKIP_EXPLORER:-}" ] || nix develop "$root#explorer" --command python3 tools/explorer/build.py "$out/explorer" --cache "$root/zig-out/explorer/cache"
