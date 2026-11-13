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

tools/web/build-site.sh "$site"

release=$(date -u +%Y%m%dT%H%M%SZ)
ssh "$target" "mkdir -p $base/releases/$release"
# --link-dest is resolved on the server, relative to the destination.
rsync -a --delete --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r \
  --link-dest="$base/current/" \
  "$site/" "$target:$base/releases/$release/"
ssh "$target" "ln -s releases/$release $base/next-$release && mv -Tf $base/next-$release $base/current"

for path in / /noite.wasm /manifest.json /assets/CASSETA.INI; do
  curl --fail --silent --show-error -o /dev/null -w "%{http_code} $path\n" "$url$path"
done
echo "deployed release $release"
