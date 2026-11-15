#!/usr/bin/env python3
"""Win rates of the fights' player bots (core/fight_bot.zig) over many seeds.

    nix develop -c python3 tools/fight_bots.py [--seeds N] [--game xilindro,salgin]
        [--bots idle,masher,novice,decent] [--fixes NAME=ARG ...] [--exe PATH]
        [--tsv FILE] [--stats]

Each run is `noite --minigame GAME --headless --fix ARG --fight-bot BOT,SEED
--epoch E`: the bot (what a player sees, a human's reaction time) plays one
round and the port prints the result (`xilindro: won, score N`) and the
bot's end line (`fightbot: end ...`). The harness is deterministic by
virtual time, so a run varies with the bot's seed and the epoch (the
games' srand). `--fixes` is a list of NAME=ARG pairs, ARG being the
`--fix` argument (`orig` for none; `mk3=all,fight_mk3` for the MK3 prototype,
which needs its private sprite pack, docs/fights/MK3.md): by default `orig`, `fair`
(`all,-fight_easy_ai`, when that fix exists) and `easy` (`all`).

Use a ReleaseFast build for speed:
    nix develop -c zig build -Doptimize=ReleaseFast --prefix zig-out/fast
and `--exe zig-out/fast/bin/noite`.
"""

import argparse
import concurrent.futures
import os
import pathlib
import re
import statistics
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
RESULT = re.compile(r"^\[(\d+)\] (?:xilindro|salgin): (won|lost), score (-?\d+)$", re.M)
END = re.compile(r"^\[(\d+)\] fightbot: end (.*)$", re.M)
BOTS = ("idle", "masher", "novice", "decent")


def run_one(exe, game, fix, bot, seed, tune=None):
    args = [exe, "--minigame", game, "--headless", "--ms", "130000", "--quiet",
            "--fight-bot", f"{bot},{seed}", "--epoch", str(800_000_000 + seed * 7919)]
    if fix != "orig":
        args += ["--fix", fix]
    if tune:
        args += ["--fight-tune", tune]
    out = subprocess.run(args, cwd=ROOT, capture_output=True, text=True)
    text = out.stdout + out.stderr
    res = RESULT.search(text)
    end = END.search(text)
    d = {"won": None, "score": 0, "t": 0}
    if res:
        d["won"] = res.group(2) == "won"
        d["score"] = int(res.group(3))
    if end:
        d["t"] = int(end.group(1))
        for kv in end.group(2).split():
            k, _, v = kv.partition("=")
            if v.lstrip("-").isdigit():
                d[k] = int(v)
    elif res is None:
        d["err"] = text[-300:]
    return d


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--seeds", type=int, default=100)
    ap.add_argument("--game", default="xilindro,salgin")
    ap.add_argument("--bots", default=",".join(BOTS))
    ap.add_argument("--fixes", nargs="*", default=None)
    ap.add_argument("--exe", default=str(ROOT / "zig-out" / "bin" / "noite"))
    ap.add_argument("--tsv", type=pathlib.Path)
    ap.add_argument("--stats", action="store_true", help="also the opponent's behaviour counts")
    ap.add_argument("--tune", help="the easy opponent's dials, key=value,... (core/fight_easy.zig Style)")
    ap.add_argument("-j", type=int, default=os.cpu_count())
    a = ap.parse_args()
    fixes = {}
    for f in a.fixes or ["orig=orig", "fair=all,-fight_easy_ai", "easy=all"]:
        k, _, v = f.partition("=")
        fixes[k] = v
    games, bots = a.game.split(","), a.bots.split(",")
    jobs = [(g, fk, b, s) for g in games for fk in fixes for b in bots for s in range(1, a.seeds + 1)]
    results = {}
    with concurrent.futures.ThreadPoolExecutor(a.j) as ex:
        futs = {ex.submit(run_one, a.exe, g, fixes[fk], b, s, a.tune): (g, fk, b, s) for g, fk, b, s in jobs}
        for f in concurrent.futures.as_completed(futs):
            results.setdefault(futs[f][:3], []).append(f.result())
    rows = []
    print(f"{'game':9} {'fixes':6} {'bot':7} {'win%':>5} {'KO%':>4} {'end s':>6} {'fighter':>7} {'opp':>5} "
          f"{'landed':>6} {'taken':>5} {'blows':>5}" + ("  opponent beats%" if a.stats else ""))
    for g in games:
        for fk in fixes:
            for b in bots:
                rs = results[(g, fk, b)]
                bad = [r for r in rs if r["won"] is None]
                if bad:
                    print(f"{g} {fk} {b}: {len(bad)} runs without a result: {bad[0].get('err')}", file=sys.stderr)
                rs = [r for r in rs if r["won"] is not None]
                n = len(rs)
                win = 100 * sum(r["won"] for r in rs) / n
                ko = 100 * sum(1 for r in rs if r.get("clock", 0) > 0) / n
                m = lambda k: statistics.mean(r.get(k, 0) for r in rs)
                line = (f"{g:9} {fk:6} {b:7} {win:5.0f} {ko:4.0f} {m('t') / 1000:6.1f} {m('fighter'):7.1f} {m('opponent'):5.1f} "
                        f"{m('landed'):6.1f} {m('taken'):5.1f} {m('blows'):5.1f}")
                if a.stats:
                    ph = {k[3:]: m(k) for k in rs[0] if k.startswith("ph_")}
                    tot = sum(ph.values()) or 1
                    line += "  " + " ".join(f"{k}{100 * v / tot:.0f}" for k, v in ph.items() if v)
                print(line)
                rows.append((g, fk, b, n, win, ko, m("t") / 1000, m("fighter"), m("opponent")))
    if a.tsv:
        a.tsv.parent.mkdir(parents=True, exist_ok=True)
        a.tsv.write_text("game\tfixes\tbot\truns\twin_pct\tko_pct\tend_s\tfighter\topponent\n" +
                         "\n".join("\t".join(f"{x:.1f}" if isinstance(x, float) else str(x) for x in r) for r in rows) + "\n")


if __name__ == "__main__":
    main()
