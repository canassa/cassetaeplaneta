#!/usr/bin/env python3
"""Run every scripted test in tools/play/*.input in parallel.

The commands come from each script's leading comment block: every line
`#   zig-out/bin/noite ...` is one run that must pass.  Optional bracketed
parts (`[--dump DIR]`) are dropped.  A line right after a command may say
how it is expected to end instead of exit 0:

    #   expect-exit: N     the exit code must be N
    #   expect-panic       a nonzero exit with "panic" in the output (a crash
                           the original has too, named in BUGS.md)

Usage: tools/play_all.py [-j N] [--no-build] [--timeout S] [NAME_FILTER...]
Filters are substrings of the script's name (`inv`, `salgin-alone`).
Logs: zig-out/play-logs/<script>.<mode>.log.  Each run gets a private --save
dir (zig-out/play-logs/save/<script>.<mode>) so runs never share files.
Run it from anywhere; it works in the repository the script lives in.
"""
import argparse
import concurrent.futures as cf
import os
import re
import shlex
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PLAY = ROOT / "tools" / "play"
LOGS = ROOT / "zig-out" / "play-logs"
CMD = re.compile(r"^#\s+(zig-out/bin/noite\s.*)$")
EXIT = re.compile(r"^#\s+expect-exit:\s*(-?\d+)\s*$")
PANIC = re.compile(r"^#\s+expect-panic\s*$")


def parse(path):
    """Runs of one script: [(mode, argv, expect)], expect = ('exit', n) | ('panic',)."""
    runs = []
    for line in path.read_text().splitlines():
        if line.strip() and not line.startswith("#"):
            break
        m = CMD.match(line)
        if m:
            text = re.sub(r"\[[^\]]*\]", "", m.group(1))
            argv = shlex.split(text)
            fix = "orig"
            if "--fix" in argv:
                fix = "fix " + argv[argv.index("--fix") + 1]
            runs.append([fix, argv, ("exit", 0)])
        elif runs and EXIT.match(line):
            runs[-1][2] = ("exit", int(EXIT.match(line).group(1)))
        elif runs and PANIC.match(line):
            runs[-1][2] = ("panic",)
    return [tuple(r) for r in runs]


def run_one(job):
    name, mode, argv, expect, timeout = job
    tag = re.sub(r"[^A-Za-z0-9._-]+", "_", f"{name}.{mode}")
    log = LOGS / f"{tag}.log"
    save = LOGS / "save" / tag
    save.mkdir(parents=True, exist_ok=True)
    argv = [str(ROOT / argv[0])] + argv[1:]
    if "--save" not in argv:
        argv += ["--save", str(save)]
    env = dict(os.environ)
    env.setdefault("SDL_VIDEODRIVER", "offscreen")
    env.setdefault("SDL_AUDIODRIVER", "dummy")
    t0 = time.monotonic()
    try:
        p = subprocess.run(argv, cwd=ROOT, env=env, stdin=subprocess.DEVNULL,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           timeout=timeout)
        code, out = p.returncode, p.stdout.decode("utf-8", "replace")
    except subprocess.TimeoutExpired as e:
        code, out = None, (e.stdout or b"").decode("utf-8", "replace") + f"\n[timeout after {timeout}s]\n"
    dt = time.monotonic() - t0
    log.write_text(out)
    if code is None:
        ok = False
    elif expect[0] == "panic":
        ok = code != 0 and "panic" in out
    else:
        ok = code == expect[1]
    shutil.rmtree(save, ignore_errors=True)
    return name, mode, ok, dt, code, out, expect


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("filters", nargs="*", help="substrings of script names")
    ap.add_argument("-j", type=int, default=os.cpu_count() or 1, help="parallel runs (default: CPU count)")
    ap.add_argument("--no-build", action="store_true", help="use the existing zig-out/bin/noite")
    ap.add_argument("--timeout", type=int, default=900, help="seconds per run")
    a = ap.parse_args()

    jobs = []
    for path in sorted(PLAY.glob("*.input")):
        name = path.stem
        if a.filters and not any(f in name for f in a.filters):
            continue
        runs = parse(path)
        if not runs:
            print(f"warning: {path.name} has no runnable header line", file=sys.stderr)
        for mode, argv, expect in runs:
            jobs.append((name, mode, argv, expect, a.timeout))
    if not jobs:
        sys.exit("no scripts match")

    if not a.no_build:
        b = subprocess.run(["zig", "build"], cwd=ROOT)
        if b.returncode:
            sys.exit("zig build failed")
    LOGS.mkdir(parents=True, exist_ok=True)

    # Longest first, so the pool ends together.
    jobs.sort(key=lambda j: -int(re.search(r"--ms (\d+)", " ".join(j[2])).group(1)) if "--ms" in j[2] else 0)
    t0 = time.monotonic()
    failed = []
    with cf.ThreadPoolExecutor(max_workers=a.j) as ex:
        for name, mode, ok, dt, code, out, expect in ex.map(run_one, jobs):
            note = ""
            if expect[0] == "panic":
                note = " (expected panic)"
            elif expect[1]:
                note = f" (expected exit {expect[1]})"
            print(f"{'PASS' if ok else 'FAIL'} {name:34} {mode:34} {dt:6.1f}s{note}", flush=True)
            if not ok:
                failed.append(name)
                print(f"  exit {code}; tail of {LOGS.relative_to(ROOT)}/{name}.{mode.replace(' ', '_')}.log:")
                for l in out.rstrip().splitlines()[-15:]:
                    print("  | " + l)
    print(f"{len(jobs) - len(failed)}/{len(jobs)} passed in {time.monotonic() - t0:.1f}s (-j {a.j})")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
