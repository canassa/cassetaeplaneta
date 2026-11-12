#!/usr/bin/env bash
# Serve the GhidraMCP bridge (toolchain/ghidra-mcp) over streamable-HTTP on
# :8000 — the `ghidra` server in .mcp.json. It relays to the GhidraMCP plugin's
# HTTP server (:8089) inside a running Ghidra GUI, so open ghidra/noite.gpr and
# start the plugin first.
set -euo pipefail
cd "$(dirname "$0")/toolchain/ghidra-mcp"
exec nix shell nixpkgs#uv -c uv run bridge-mcp-ghidra \
  --transport streamable-http --mcp-host 127.0.0.1 --mcp-port "${1:-8000}" --no-lazy
