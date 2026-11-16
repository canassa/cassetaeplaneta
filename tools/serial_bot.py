#!/usr/bin/env python3
"""A reaction-time bot for SERIAL: how often the killers get a life off a player who sees them.

    nix develop -c python3 tools/serial_bot.py [--seeds N] [--reaction MS]
        [--warn-steps N,...] [--passive] [--verbose]

It plays tools/serial_plan.py's simulation of the Corrigida's game (`Sim(start,
True)`: K1-K5 fixed, the figures follow from `start`, the game's srand seed) with
the keys a player has (LEFT/RIGHT step the three aims, one tap per 130 ms; SPACE
fires one bullet at a time) and what a player sees:

- a figure is seen `--reaction` ms after it appears; the good ones (kind 1) are
  shot at, the harmless-looking (kind 0, and the babá and Papai Noel, whose
  killer versions look the same until their tell) are not;
- a killer is told by its sprite (babá: the baby rises 2 steps before the
  shot; Noel: he lies down with his rifle 6 steps before) or by the warning
  (`corrigida.warn_steps` steps before, `--warn-steps`, 0 = no warning); the
  earlier of the two. It is shot at `--reaction` ms after it is told;
- it plans a shot as a player does: from where the figures walk (the walks are
  straight, so a player leads them) it takes the first aim and fire time whose
  bullet hits the wanted figure and nothing else.

`--passive` is the baseline: no keys at all. Prints, per warning length, the
lives lost per game, games lost, killers that walked in, killers shot before they
fired (the warning's job), killer shots that landed, and the score.
"""

import argparse
import copy
import os
import statistics
import sys
from concurrent.futures import ProcessPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import serial_plan as sp  # noqa: E402

TAP = 130  # ms per LEFT/RIGHT tap
KILLERS = (2, 9)
# Steps before a killer's shot at which its own sprite gives it away (frame 8 of
# 3sbabt: the baby; frame 8 of 3snoem: Noel prone with the rifle).
TELL = {2: 4, 9: 8}
GOOD = [i for i, k in enumerate(sp.KINDS) if k == 1]


def left(f):
    return f.frames - f.frame


def told(f, warn_steps):
    """Is killer `f` giving itself away (its tell, or the warning)?"""
    if not f.moving:
        return False
    steps = max(TELL[f.index], 2 + warn_steps if warn_steps else 0)
    return 2 < left(f) <= steps


def probe(sim, keys, fire_at, wanted):
    """Plays `keys` and a shot at `fire_at` on a copy; the figures the bullet
    hit and whether the game's state allowed it."""
    c = copy.deepcopy(sim)
    c.run(keys, fire_at - 1)
    if c.bullet.moving or c.result is not None:
        return None
    n = len(c.hits)
    c.run([(fire_at, sp.VK_SPACE, True), (fire_at + 50, sp.VK_SPACE, False)], fire_at + 50)
    c.run([], fire_at + 2500)
    if c.bullet.moving:
        return None
    return [(t, i) for t, i in c.hits[n:]]


def play(seed, reaction, warn_steps, passive=False, horizon=125_000, arm=None, emit=None):
    """One game from `seed` (`srand` gets 800000000 + seed); returns the stats.
    `arm`: when the game starts (the intro screen is taken down), default 0;
    `emit`: a file to write the bot's keys to as an input script."""
    arm = arm or 0
    start = arm
    sim = sp.Sim(seed * 1000, True, arm=arm)
    pressed = []
    seen = {}  # figure -> time first seen walking
    told_at = {}  # killer -> time its tell started (this walk)
    keys = []  # queued key events, absolute
    last_plan = -10_000
    t = start
    encounters = 0  # killers that walked in
    cancelled = 0  # ... and were hit before they fired
    fired = set()  # killers that fired in this walk
    moving = set()
    n_shots = n_hits = 0
    while sim.result is None and t < start + horizon:
        t += 50
        due = [e for e in keys if e[0] <= t]
        keys = [e for e in keys if e[0] > t]
        sim.run(due, t)
        for _, i in sim.shot_at[n_shots:]:
            fired.add(i)
        n_shots = len(sim.shot_at)
        for _, i in sim.hits[n_hits:]:
            if i in KILLERS and i not in fired:
                cancelled += 1
        n_hits = len(sim.hits)
        for i in KILLERS:
            m = sim.figs[i].moving
            if m and i not in moving:
                encounters += 1
                fired.discard(i)
            if m:
                moving.add(i)
            else:
                moving.discard(i)
        if sim.result is not None:
            break
        for f in sim.figs:
            if f.moving and f.index not in seen:
                seen[f.index] = t
            if not f.moving:
                seen.pop(f.index, None)
                told_at.pop(f.index, None)
            elif f.index in KILLERS and told(f, warn_steps) and f.index not in told_at:
                told_at[f.index] = t
        if passive or keys or sim.bullet.moving or t < last_plan + 200:
            continue
        # The wanted figures: told killers first, then the good ones.
        wants = []
        for i in KILLERS:
            f = sim.figs[i]
            if f.moving and i in told_at and t >= told_at[i] + reaction:
                wants.append(i)
        for i in GOOD:
            f = sim.figs[i]
            if f.moving and i in seen and t >= seen[i] + reaction:
                wants.append(i)
        if not wants:
            continue
        best = None
        for want in wants:
            for aim in (sim.aim, 1, 0, 2):
                k = sp.aim_keys(sim.aim, aim)
                at = t
                pre = []
                for j, name in enumerate(k):
                    pre += [(at + TAP * j, name, True), (at + TAP * j + 50, name, False)]
                ready = t + TAP * len(k) + 20
                for fire_at in range(ready, ready + 2400, 100):
                    got = probe(sim, pre, fire_at, wants)
                    if got is None:
                        continue
                    if got and all(i == want for _, i in got):
                        cand = (fire_at, len(k), pre, fire_at)
                        if best is None or fire_at < best[0]:
                            best = cand
                        break
            if best is not None and want in KILLERS:
                break
        if best is not None:
            fire_at, _, pre, _ = best
            pressed += [(e[0], e[1]) for e in pre if e[2]] + [(fire_at, sp.VK_SPACE)]
            keys += pre + [(fire_at, sp.VK_SPACE, True), (fire_at + 50, sp.VK_SPACE, False)]
            keys.sort()
            last_plan = t
    sim.run([], start + horizon)
    if emit:
        with open(emit, "w") as f:
            f.write(f"# the bot's keys (tools/serial_bot.py, seed {seed}, reaction {reaction} ms, warning {warn_steps} steps)\n")
            for at, name in sorted(pressed):
                f.write(f"{at} key {name}\n")
    lives_lost = sp.LIVES - (sim.result[1] if sim.result else sim.lives)
    kills = [i for _, i in sim.hits if i in KILLERS]
    return {
        "lost_lives": lives_lost,
        "game_lost": (sim.result[1] if sim.result else sim.lives) <= 0,
        "killer_shots": len(sim.shot_at),
        "killers_hit": len(kills),
        "encounters": encounters,
        "cancelled": cancelled,
        "shots": len(sim.shots),
        "score": sim.score,
        "good_hits": sum(1 for _, i in sim.hits if sp.KINDS[i] == 1),
        "bad_hits": sum(1 for _, i in sim.hits if sp.KINDS[i] == 0),
    }


def job(a):
    return play(*a)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--seeds", type=int, default=12)
    ap.add_argument("--reaction", type=int, default=400)
    ap.add_argument("--warn-steps", default="0,3,5,7", help="warning lengths to try (steps of 200 ms)")
    ap.add_argument("--passive", action="store_true", help="no keys at all (the baseline)")
    ap.add_argument("--emit", metavar="FILE", help="play one game (--seed, the first --warn-steps) and write its keys as an input script")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--arm", type=int, default=0, help="ms the game starts at (the intro screen taken down)")
    ap.add_argument("-j", type=int, default=os.cpu_count() or 1)
    a = ap.parse_args()
    if a.emit:
        w = int(a.warn_steps.split(",")[0])
        r = play(a.seed, a.reaction, w, a.passive, arm=a.arm, emit=a.emit)
        print(r)
        return
    seeds = range(1, a.seeds + 1)
    print(f"reaction {a.reaction} ms, {a.seeds} games each; per game:")
    print(f"{'warn':>6} {'lives lost':>10} {'games lost':>10} {'killers':>7} {'cancelled':>9} {'shots landed':>12} {'good hits':>9} {'bad hits':>8} {'score':>7}")
    for w in [int(x) for x in a.warn_steps.split(",")]:
        with ProcessPoolExecutor(a.j) as ex:
            rs = list(ex.map(job, [(s, a.reaction, w, a.passive, 125_000, a.arm) for s in seeds]))
        n = len(rs)

        def avg(k):
            return sum(r[k] for r in rs) / n

        lost = sum(r["game_lost"] for r in rs)
        label = "none" if w == 0 else f"{w * 200} ms"
        print(f"{label:>6} {avg('lost_lives'):10.2f} {lost:>7}/{n:<2} {avg('encounters'):7.2f} {avg('cancelled'):9.2f} {avg('killer_shots'):12.2f} "
              f"{avg('good_hits'):9.2f} {avg('bad_hits'):8.2f} {statistics.mean(r['score'] for r in rs):7.0f}")


if __name__ == "__main__":
    main()
