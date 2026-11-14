#!/usr/bin/env python3
"""Plan an ENCAIXE (Encaixe Perfeito) game and write it as an input script.

    nix develop -c python3 tools/encaixe_plan.py [--start MS] [--epoch S]
        [--lines N] [--relative-to MS] [--lose] [-o FILE]

The pieces come from `rand() % 6` after `srand(time(NULL))` at WM_CREATE
(te_game_create_player); in the headless harness time() is
`epoch + ticks / 1000` (src/platform/headless.zig), so the sequence is
known from the moment ENCAIXE starts (`--start`: 0 alone, WinExec + 1500
ms from NOITE). The planner simulates the board as docs/encaixe/GAME.md
describes it (shapes, rotation about the top-left, line clear, the
timings below) and places each piece with a greedy evaluation plus a
look-ahead on the next piece, then writes the key presses at absolute
times. It plays through the game's real input only; the script is then
checked by running it (`result won 1500`).

Timing (the piece's timer 12, `P` = 200 ms, 150 after the 5th line; the
rotation animation's period is always 200): a landing tick at T spawns
the next piece and restarts the timer (first fall T + P). Every move
happens at row 0 before that fall:
  - `key up` at t rotates; the tick at t + 200 shows the frame and
    restarts the fall (next fall t + 200 + P); the next key at t + 250;
  - `key left|right` at t moves one column at once; its key-up at t + 50
    restarts the fall (next fall t + 50 + P); the next key at t + 100.
After the last move the piece falls one row per P and lands on the tick
after its last possible step.

Avoided so that the Original and the Corrigida (`--fix all`) play the
same game: moving the O left (BUGS E1), rotating near the floor (E2),
a clear that jumps over the 5th line (E7), the down key (E5).
"""

import argparse
import sys

COLS, ROWS = 11, 14

# (dc, dr) cells of each kind and rotation, top-left anchored (GAME.md).
SHAPES = {
    0: [
        [(0, 0), (1, 0), (2, 0), (1, 1), (1, 2), (1, 3)],
        [(3, 0), (0, 1), (1, 1), (2, 1), (3, 1), (3, 2)],
        [(1, 0), (1, 1), (1, 2), (0, 3), (1, 3), (2, 3)],
        [(0, 0), (0, 1), (1, 1), (2, 1), (3, 1), (0, 2)],
    ],
    1: [
        [(0, 0), (1, 0), (2, 0), (1, 1)],
        [(1, 0), (0, 1), (1, 1), (1, 2)],
        [(1, 0), (0, 1), (1, 1), (2, 1)],
        [(0, 0), (0, 1), (1, 1), (0, 2)],
    ],
    2: [
        [(0, 0), (1, 0), (1, 1), (1, 2)],
        [(2, 0), (0, 1), (1, 1), (2, 1)],
        [(0, 0), (0, 1), (0, 2), (1, 2)],
        [(0, 0), (1, 0), (2, 0), (0, 1)],
    ],
    3: [
        [(0, 0), (1, 0), (0, 1), (0, 2)],
        [(0, 0), (1, 0), (2, 0), (2, 1)],
        [(1, 0), (1, 1), (0, 2), (1, 2)],
        [(0, 0), (0, 1), (1, 1), (2, 1)],
    ],
    4: [
        [(0, 0), (0, 1), (0, 2), (0, 3)],
        [(0, 0), (1, 0), (2, 0), (3, 0)],
        [(0, 0), (0, 1), (0, 2), (0, 3)],
        [(0, 0), (1, 0), (2, 0), (3, 0)],
    ],
    5: [[(0, 0), (1, 0), (0, 1), (1, 1)]] * 4,
}
SPAWN_COL = 4
ANIM_MS = 200


class Rand:
    """The MSVC CRT LCG (src/core/crt.zig)."""

    def __init__(self, seed):
        self.s = seed & 0xFFFF

    def rand(self):
        self.s = (self.s * 0x343FD + 0x269EC3) & 0xFFFFFFFF
        return (self.s >> 16) & 0x7FFF


def width(kind, rot):
    return max(dc for dc, _ in SHAPES[kind][rot]) + 1


def height(kind, rot):
    return max(dr for _, dr in SHAPES[kind][rot]) + 1


def fits(board, kind, rot, col, row):
    for dc, dr in SHAPES[kind][rot]:
        c, r = col + dc, row + dr
        if c < 0 or c >= COLS or r < 0 or r >= ROWS or board[r][c]:
            return False
    return True


def place(board, kind, rot, col):
    """Drop from row 0; the new board, the landing row and the rows cleared
    (None when the piece cannot drop from row 0)."""
    if not fits(board, kind, rot, col, 0):
        return None
    row = 0
    while fits(board, kind, rot, col, row + 1):
        row += 1
    b = [r[:] for r in board]
    for dc, dr in SHAPES[kind][rot]:
        b[row + dr][col + dc] = 1
    full = [r for r in range(row, row + height(kind, rot)) if all(b[r])]
    # te_piece_clear_row, bottom up: rows above move down; row 0 keeps its
    # cells (BUGS E10).
    for i, r in enumerate(sorted(full, reverse=True)):
        r += i
        for rr in range(r, 0, -1):
            b[rr] = b[rr - 1][:]
    return b, row, len(full)


def path_ok(board, kind, rot, col):
    """The rotations at the spawn column, then the shifts, all at row 0."""
    for r in range(rot + 1):
        if not fits(board, kind, r, SPAWN_COL, 0):
            return False
    step = 1 if col > SPAWN_COL else -1
    for c in range(SPAWN_COL, col + step, step) if col != SPAWN_COL else []:
        if not fits(board, kind, rot, c, 0):
            return False
    return True


def evaluate(board, land_row, kind, rot, cleared):
    heights = []
    holes = 0
    for c in range(COLS):
        h = 0
        seen = False
        for r in range(ROWS):
            if board[r][c]:
                if not seen:
                    h = ROWS - r
                    seen = True
            elif seen:
                holes += 1
        heights.append(h)
    bump = sum(abs(heights[i] - heights[i + 1]) for i in range(COLS - 1))
    row_tr = 0
    for r in range(ROWS):
        prev = 1
        for c in range(COLS):
            if board[r][c] != prev:
                row_tr += 1
            prev = board[r][c]
        if prev != 1:
            row_tr += 1
    col_tr = 0
    for c in range(COLS):
        prev = 0
        for r in range(ROWS):
            if board[r][c] != prev:
                col_tr += 1
            prev = board[r][c]
        if prev != 1:
            col_tr += 1
    wells = 0
    for c in range(COLS):
        left = heights[c - 1] if c > 0 else ROWS
        right = heights[c + 1] if c < COLS - 1 else ROWS
        d = min(left, right) - heights[c]
        if d > 0:
            wells += d * (d + 1) // 2
    landing = ROWS - land_row - height(kind, rot) / 2
    return (-4.5 * landing + 3.4 * cleared - 3.2 * row_tr - 9.3 * col_tr
            - 7.9 * holes - 3.4 * wells - 0.5 * bump - 2.0 * max(heights))


def moves(board, kind, lines):
    """Every legal placement: (rot, col, board, row, cleared)."""
    out = []
    rots = [0] if kind == 5 else ([0, 1] if kind == 4 else [0, 1, 2, 3])
    for rot in rots:
        for col in range(COLS - width(kind, rot) + 1):
            if kind == 5 and col < SPAWN_COL:
                continue  # BUGS E1
            if not path_ok(board, kind, rot, col):
                continue
            res = place(board, kind, rot, col)
            if res is None:
                continue
            b, row, n = res
            if row < 3:
                continue  # a loss
            if lines < 5 < lines + n:
                continue  # BUGS E7
            out.append((rot, col, b, row, n))
    return out


def plan(seq, target):
    """Greedy with a one-piece look-ahead. The list of placements."""
    board = [[0] * COLS for _ in range(ROWS)]
    lines = 0
    out = []
    for i, kind in enumerate(seq):
        if lines >= target:
            break
        best = None
        for rot, col, b, row, n in moves(board, kind, lines):
            if lines + n >= target:
                score = 1e9
            else:
                score = evaluate(b, row, kind, rot, n)
                if i + 1 < len(seq):
                    nxt = [evaluate(b2, r2, seq[i + 1], ro2, n2)
                           for ro2, _, b2, r2, n2 in moves(b, seq[i + 1], lines + n)]
                    score = score + (max(nxt) if nxt else -1e6)
            if best is None or score > best[0]:
                best = (score, rot, col, b, row, n)
        if best is None:
            raise SystemExit(f"piece {i} (kind {kind}): no legal placement")
        _, rot, col, board, row, n = best
        lines += n
        out.append((kind, rot, col, row, n, lines))
    if lines < target:
        raise SystemExit(f"only {lines} lines with {len(seq)} pieces")
    return out


def script(start, epoch, target, lose):
    rng = Rand(epoch + start // 1000)
    seq = [rng.rand() % 6 for _ in range(200)]
    lines = []
    t_spawn = start
    period = 200
    if lose:
        return seq, [], None
    placements = plan(seq, target)
    for kind, rot, col, row, n, total in placements:
        t = t_spawn + 100
        restart = t_spawn
        lines.append(f"# piece kind {kind}: rotation {rot}, column {col}, lands at row {row}"
                     + (f", {n} line(s), {total} in all" if n else ""))
        for _ in range(rot):
            lines.append(f"{t} key up")
            restart = t + ANIM_MS
            t += ANIM_MS + 50
        shifts = col - SPAWN_COL
        for _ in range(abs(shifts)):
            lines.append(f"{t} key {'right' if shifts > 0 else 'left'}")
            restart = t + 50
            t += 100
        t_spawn = restart + (row + 1) * period
        if total >= 5:
            period = 150
    return seq, lines, t_spawn


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--start", type=int, default=0, help="ms when ENCAIXE's WM_CREATE runs")
    ap.add_argument("--epoch", type=int, default=800_000_000, help="the headless time() at 0")
    ap.add_argument("--lines", type=int, default=10)
    ap.add_argument("--relative-to", type=int, metavar="MS",
                    help="write `+N` times, the first from MS (a `wait` line's scene entry)")
    ap.add_argument("--lose", action="store_true", help="print the sequence only")
    ap.add_argument("-o", "--output")
    a = ap.parse_args()
    seq, lines, end = script(a.start, a.epoch, a.lines, a.lose)
    if a.lose:
        print(" ".join(map(str, seq[:20])))
        return
    if a.relative_to is not None:
        prev = a.relative_to
        rel = []
        for line in lines:
            if line.startswith("#"):
                rel.append(line)
                continue
            t, rest = line.split(" ", 1)
            rel.append(f"+{int(t) - prev} {rest}")
            prev = int(t)
        lines = rel
    text = "\n".join(lines) + "\n"
    if a.output:
        open(a.output, "w").write(text)
    else:
        sys.stdout.write(text)
    print(f"# {sum(1 for l in lines if l.startswith('#'))} pieces, the last lands at {end} ms",
          file=sys.stderr)


if __name__ == "__main__":
    main()
