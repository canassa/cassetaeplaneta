#!/usr/bin/env python3
"""List the disc files the game can open: tools/web/files.txt.

    nix develop -c python3 tools/web/files.py [--trace STRACE...] [--check]

The browser build downloads only these (tools/web/manifest.py). Two
sources, merged:

- **Static**: every name in CASSETA.INI (and in string literals of the
  port's source, for the handlers' own paths), expanded the way the
  engine builds paths from it (`ini_asset_path`, src/ini.zig): `.bmp`,
  `.wav`, `.rle`, `.avi`, numbered frames `N.bmp`, each with the engine's
  fallback chain — `load_dib` tries `pan\\bmp\\<name>.bmp`, `wave_open`
  `pan\\wav\\<name>.wav`, `animation_open_avi` tries `hd\\<name>.avi`, then
  the name, then `pan\\avi\\<name>.avi`. Only the first file of a chain that
  exists is listed: the game never opens the others.
- **Traced** (optional): `strace -f -e trace=openat` logs of native runs
  (`tools/smoke.py`, the playthrough); every disc file a `noite` process
  opened. `--check` fails if a traced file is missing from the static
  list (the static rules missed a path the game builds).

Plus the files the engine opens by fixed name (CASSETA.INI, CASSETUP.INI,
JOGO0-5.INI and the save slots HD\\JOGO0-5.INI, MSSVGA\\VGASYS.FON).
A ported minigame's names (src/encaixe/, src/tiro/) are looked for at the
disc root, then in its EXE's directory (ENCAIXE\\, TIRO\\), as the host does.
"""

import argparse
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
ASSETS = ROOT / "assets"
OUT = ROOT / "tools" / "web" / "files.txt"
FIXED = ["CASSETA.INI", "CASSETUP.INI", "MSSVGA/VGASYS.FON"] + [f"{d}JOGO{i}.INI" for d in ("", "HD/") for i in range(6)]
# The ported minigames: src/<name>/, their EXE in <NAME>/ on the disc.
MINIGAMES = {"encaixe", "tiro"}
# Sprite and icon frames: `<name><N>.bmp`.
MAX_FRAME = 200


def disc_index():
    """lower-case relative path -> real relative path, for every disc file."""
    idx = {}
    for p in ASSETS.rglob("*"):
        if p.is_file():
            rel = p.relative_to(ASSETS).as_posix()
            idx[rel.lower()] = rel
    return idx


def norm(name):
    parts = [x for x in name.replace("\\", "/").split("/") if x and x != "."]
    if parts and len(parts[0]) == 2 and parts[0][1] == ":":
        parts = parts[1:]
    return "/".join(parts).lower()


def fname(path):
    base = path.rsplit("/", 1)[-1]
    return base.rsplit(".", 1)[0] if "." in base else base


def chains(token):
    """The engine's open attempts for a name, as lists tried in order."""
    t = norm(token)
    if not t:
        return []
    f = fname(t)
    ext = t.rsplit(".", 1)[1] if "." in t.rsplit("/", 1)[-1] else None
    out = []
    if ext is None:
        out.append([t + ".bmp", f"pan/bmp/{f}.bmp"])
        out.append([t + ".wav", f"pan/wav/{f}.wav"])
        out.append([t + ".rle"])
        out.append([t + ".mid"])
        out.append([f"hd/{f}.avi", t + ".avi", f"pan/avi/{f}.avi"])
        for n in range(MAX_FRAME):
            out.append([f"{t}{n}.bmp", f"pan/bmp/{f}{n}.bmp"])
    elif ext == "bmp":
        out.append([t, f"pan/bmp/{f}.bmp"])
    elif ext == "wav":
        out.append([t, f"pan/wav/{f}.wav"])
    elif ext == "avi":
        out.append([f"hd/{f}.avi", t, f"pan/avi/{f}.avi"])
    elif ext not in ("exe", "dll"):  # WinExec: a stub, or a ported minigame's code
        out.append([t])
    return out


def ini_tokens():
    text = (ASSETS / "CASSETA.INI").read_text(encoding="latin-1")
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        for tok in line.split("=", 1)[1].split(","):
            tok = tok.strip()
            if re.search(r"[A-Za-z]", tok):
                yield tok
            elif re.fullmatch(r"\d+", tok):
                # A number where a wave name goes (`WAVE=…,0`): `0.wav`.
                yield tok + ".wav"


def source_tokens():
    """(name, program directory) for each path literal of the port. A
    ported minigame's names (src/<name>/) are relative to its EXE's
    directory, which the host searches after the disc root."""
    lit = re.compile(r'"((?:[^"\\]|\\.)*)"')
    for p in (ROOT / "src").rglob("*.zig"):
        rel = p.relative_to(ROOT / "src").parts
        prog = rel[0] if rel[0] in MINIGAMES else None
        for m in lit.finditer(p.read_text(encoding="utf-8")):
            s = m.group(1).replace("\\\\", "\\")
            # An MCI command's file (`open doom2.mid type sequencer …`).
            mci = re.match(r"open (\S+\.[A-Za-z0-9]{3}) ", s)
            if mci:
                yield mci.group(1), prog
            # A path the engine opens: has a directory or a file extension.
            elif re.fullmatch(r"[A-Za-z0-9_\\.: ]+", s) and ("\\" in s or re.search(r"\.[A-Za-z0-9]{3}$", s)):
                yield s, prog


def traced(paths):
    """Disc files opened by `noite` processes in strace -f logs."""
    seen = set()
    for path in paths:
        noite_pids = set()
        lines = pathlib.Path(path).read_text(errors="replace").splitlines()
        for line in lines:
            if "execve(" in line and "zig-out/bin/noite" in line:
                noite_pids.add(line.split()[0])
        for line in lines:
            if "openat(" not in line or "O_DIRECTORY" in line or "= -1" in line:
                continue
            pid = line.split()[0]
            if noite_pids and pid not in noite_pids:
                continue
            m = re.search(r'"(?:[^"]*/)?assets/([^"]+)"', line)
            if m:
                seen.add(m.group(1).lower())
    return seen


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--trace", nargs="*", default=[])
    ap.add_argument("--check", action="store_true", help="fail if a traced file is not found statically")
    args = ap.parse_args()
    idx = disc_index()
    static = set()
    for tok, prog in [(t, None) for t in ini_tokens()] + list(source_tokens()):
        # A minigame opens its names as given: the disc root, then its
        # EXE's directory (`Sim.open`), without NOITE's `pan\` fallbacks.
        for chain in [[norm(tok), f"{prog}/{norm(tok)}"]] if prog else chains(tok):
            for cand in chain:
                if cand in idx:
                    static.add(cand)
                    break
    static |= {f.lower() for f in FIXED}
    tr = {t for t in traced(args.trace) if t in idx}
    missing = sorted(tr - static)
    for m in missing:
        print(f"traced but not found statically: {idx[m]}", file=sys.stderr)
    files = sorted(idx[k] for k in static | tr)
    OUT.write_text("".join(f + "\n" for f in files))
    size = sum((ASSETS / f).stat().st_size for f in files)
    print(f"{len(files)} files, {size / 1e6:.1f} MB ({len(tr)} traced, {len(missing)} only traced)")
    if args.check and missing:
        sys.exit(1)


if __name__ == "__main__":
    main()
