#!/usr/bin/env python3
"""A player for the Corrigida's arcade INV: how beatable it is, and input scripts of its games.

    nix develop -c python3 tools/inv_bot.py [--games N] [-j N]
    nix develop -c python3 tools/inv_bot.py --emit FILE --seed N [--start MS] [bot options]

The game is `src/inv/arcade/sim.zig` run by the very `driver.Driver` the game uses (`src/inv/arcade/bot.zig`
is the player), so a game it plays is exactly the game's: `--emit` writes its keys as a script for
`noite --minigame inv --headless --fix all` (the first line is the key that takes the controls screen
down, at `--start`; the game's clock starts then). Without `--emit` it plays `--games` games for each of
four players and prints how they fare:

- *attentive*: sees a bomb 400 ms late (and carries it forward to now, as a player judges its fall), aims
  by a picture 100 ms old, looks at the bombs in 9 of 10 of its decisions;
- *casual*: 600 ms, 150 ms, an aim error of up to 25 px, looks at the bombs in 7 of 10;
- *inattentive*: 800 ms, 200 ms, 40 px, 5 of 10;
- *distracted*: 1000 ms, 250 ms, 50 px, 35 of 100.

Options of the bot itself (see `bot.zig`): --reaction MS, --aim MS, --sloppy PX, --lapse PCT, --jitter MS,
--seed N, --no-saucer, --trace (the game's events), --verbose (every game).
"""
import argparse
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BOT = os.path.join(ROOT, "zig-out", "bin", "inv-bot")

PLAYERS = [
    ("attentive", ["--reaction", "400", "--aim", "100", "--sloppy", "10", "--lapse", "10"]),
    ("casual", ["--reaction", "600", "--aim", "150", "--sloppy", "25", "--lapse", "30"]),
    ("inattentive", ["--reaction", "800", "--aim", "200", "--sloppy", "40", "--lapse", "50"]),
    ("distracted", ["--reaction", "1000", "--aim", "250", "--sloppy", "50", "--lapse", "65"]),
]


def build():
    subprocess.run(["zig", "build", "inv-bot"], cwd=ROOT, check=False,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, input=b"")


def run(args):
    return subprocess.run([BOT] + args, cwd=ROOT, capture_output=True, text=True).stdout


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--games", type=int, default=200)
    ap.add_argument("-j", type=int, default=os.cpu_count() or 1)
    ap.add_argument("--emit", metavar="FILE")
    ap.add_argument("--no-build", action="store_true")
    a, rest = ap.parse_known_args()
    if not a.no_build:
        build()
    if a.emit:
        out = run(["--emit", a.emit] + rest)
        sys.stdout.write(out)
        return
    with ThreadPoolExecutor(a.j) as ex:
        outs = list(ex.map(lambda p: run(["--games", str(a.games)] + p[1] + rest), PLAYERS))
    for (name, _), out in zip(PLAYERS, outs):
        print(f"== {name}")
        print(out.rstrip())


if __name__ == "__main__":
    main()
