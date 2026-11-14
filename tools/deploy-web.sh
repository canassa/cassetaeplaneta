#!/usr/bin/env bash
# Build the web site and publish it at https://cassetaeplaneta.canassa.com.
# Run from the repo root inside the dev shell: nix develop -c tools/deploy-web.sh
#
# azathoth's nginx serves /var/www/cassetaeplaneta/current (canassa/infra,
# hosts/azathoth/web.nix). Each run uploads a new release next to the old
# ones, hard-linking unchanged files against the current release, then
# switches `current` atomically. Rollback: point `current` at an older
# releases/<id> with `ln -s releases/<id> next && mv -Tf next current`.
set -euo pipefail
target=canassa@ns3232567.ip-162-19-235.eu
base=/var/www/cassetaeplaneta
url=https://cassetaeplaneta.canassa.com
site=zig-out/site

# Ship only committed code: refuse uncommitted changes to tracked files
# (submodules aside).
if [ -n "$(git status --porcelain --untracked-files=no --ignore-submodules)" ]; then
  echo "deploy-web: uncommitted changes; commit them or deploy from a clean worktree" >&2
  git status --short --untracked-files=no --ignore-submodules >&2
  exit 1
fi

# The release id names the server's releases/<id> directory; the page
# reports it (Relatório, snapshots), so it is stamped in before the upload.
release=$(date -u +%Y%m%dT%H%M%SZ)
NOITE_RELEASE=$release tools/web/build-site.sh "$site"

ssh "$target" "mkdir -p $base/releases/$release"
# --link-dest is resolved on the server, relative to the destination.
rsync -a --delete --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r \
  --link-dest="$base/current/" \
  "$site/" "$target:$base/releases/$release/"
ssh "$target" "ln -s releases/$release $base/next-$release && mv -Tf $base/next-$release $base/current"

# The page, then the hashed URLs it loads (from the built index.html and
# manifest): each should answer 200 with the Cache-Control of docs/WEB.md.
mapfile -t paths < <(python3 - "$site" <<'EOF'
import json, pathlib, re, sys
site = pathlib.Path(sys.argv[1])
html = (site / "index.html").read_text()
print("/")
for attr in ("src", "data-wasm", "data-manifest"):
    print("/" + re.search(rf'<script [^>]*\b{attr}="([^"]+)"', html).group(1))
m = json.loads((site / "manifest.json").read_text())
ini = next(f for f in m["files"] if f["url"] == "assets/CASSETA.INI")
print(f"/{ini['url']}?h={ini['hash']}")
EOF
)
for path in "${paths[@]}"; do
  curl --fail --silent --show-error -o /dev/null -w "%{http_code} %header{cache-control} $path\n" "$url$path"
done
echo "deployed release $release"
