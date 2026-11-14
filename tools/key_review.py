"""Build and review the list of colour-11 holes NOITE's sprites draw.

NOITE draws every object bitmap with palette index 11 as the transparent
colour (`g_unk001C`), so a stray index-11 pixel inside the art shows the
scene behind it (BUGS.md, `sprite_key_specks`). This script lists the
bitmaps NOITE loads as sprites, finds the suspicious index-11 pixels in them
with `tools/key_specks.py` (its "single" and "cluster" pixels) and keeps the
reviewed decisions in `src/data/key_specks.tsv`:

    file      the path as NOITE opens it, lower case, from the disc root
              (`fase1/1fsala/1omesa.bmp`, `pan/bmp/mao.bmp`)
    x, y      the pixel, top-down
    fill      the palette index the fix writes there
    decision  `fill` (an accident inside the art), `keep` (a hole that may be
              meant) or `?` (not reviewed yet)
    kind      single / cluster (key_specks.py's class)
    reason    why a pixel is kept (or a note on a fill)

The sprites are the bitmaps of the CASSETA.INI lines NOITE builds objects
from: `Local=`, `Animated=`, `Exit=`, `2Exit=`, `Moveable=`, `Static=`,
`C_Actor=` (`<NomeBMP>.bmp`), `Portable=` (`<name>0.bmp` and the icon
`<name>2.bmp`), `ZoomPort=` (`<name>0.bmp`, `<small>2.bmp`, the icon
`<name>2.bmp`), `Player=` (`<name><i>.bmp`, one per `Sprite=` line),
`Control=` and `StatusBar=`; with the B51 fix, `p/1obibli0.bmp`. A name the
disc lacks is looked for as `pan/bmp/<file name>.bmp`, as `load_dib` does.
`Screen=` pictures (the backgrounds) are drawn opaque and left out, and so are
the minigames, separate programs.

Running it again keeps every decision already in the TSV (duplicate bitmaps
share theirs) and adds new candidates as `?`.

Usage (from the repo root, in the dev shell):

    python3 tools/key_review.py [--assets assets] [--tsv src/data/key_specks.tsv]
        [--out zig-out/key-review] [--per-sheet 48] [--summary N]

Writes the TSV, <out>/sheet-NN.png (per candidate a 15x15 neighbourhood at
8x: before, the hole in magenta, and after the fill; other candidates of the
crop in orange, the real transparency as a grey checker; labelled with the
row number, file, x and y) and <out>/index.tsv (row number -> pixel). With
--summary N, <out>/summary.png shows N filled pixels before and after.
"""

import argparse
import collections
import hashlib
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from key_specks import KEY, classify, load_bmp, write_png  # noqa: E402

FIELDS = ("file", "x", "y", "fill", "decision", "kind", "reason")


def resolve(assets, rel):
    """The real path of the disc path `rel` (any case, `/`-separated), or None."""
    cur = assets
    for part in rel.split("/"):
        if not part:
            continue
        try:
            names = os.listdir(cur)
        except OSError:
            return None
        hit = next((n for n in names if n.lower() == part.lower()), None)
        if hit is None:
            return None
        cur = os.path.join(cur, hit)
    return cur if os.path.isfile(cur) else None


def open_path(assets, name):
    """(key, real path) of the bitmap `load_dib` opens for `name` (an INI
    name plus suffix, backslashes, relative to the disc root), or None."""
    rel = name.replace("\\", "/").strip("/").lower()
    real = resolve(assets, rel)
    if real:
        return rel, real
    fname = os.path.splitext(rel.rsplit("/", 1)[-1])[0]
    rel = f"pan/bmp/{fname}.bmp"
    real = resolve(assets, rel)
    return (rel, real) if real else None


def sprite_names(assets):
    """{INI name with suffix: [where it comes from]} for every sprite bitmap."""
    names = collections.defaultdict(list)
    section = "?"
    player = None
    sprite_lines = 0
    with open(os.path.join(assets, "CASSETA.INI"), "rb") as f:
        lines = f.read().decode("latin-1").splitlines()
    for line in lines:
        line = line.strip()
        if line.startswith("["):
            section = line.strip("[]")
            continue
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, val = line.split("=", 1)
        v = [s.strip() for s in val.split(",")]
        where = f"{section}:{key}={v[0]}"
        if key in ("Local", "Animated", "Exit", "2Exit", "Moveable", "Static", "C_Actor"):
            names[v[3] + ".bmp"].append(where)
        elif key == "Portable":
            names[v[4] + "0.bmp"].append(where)
            names[v[4] + "2.bmp"].append(where + " icon")
        elif key == "ZoomPort":
            names[v[4] + "0.bmp"].append(where)
            names[v[8] + "2.bmp"].append(where + " small")
            names[v[4] + "2.bmp"].append(where + " icon")
        elif key == "Player":
            player = (v[4], int(v[3]))
        elif key == "Sprite":
            sprite_lines += 1
        elif key == "Control":
            names[v[2] + ".bmp"].append(where)
        elif key == "StatusBar":
            names[v[3] + ".bmp"].append(where)
    if player:
        for i in range(min(player[1], sprite_lines)):
            names[f"{player[0]}{i}.bmp"].append(f"Player strip {i}")
    names["p\\1obibli0.bmp"].append("B51 fix: the bible's scene picture")
    return names


def sprites(assets):
    """[(key, real path, [sources])] of the bitmaps NOITE draws keyed, sorted."""
    out = {}
    for name, where in sprite_names(assets).items():
        hit = open_path(assets, name)
        if not hit:
            continue
        key, real = hit
        out.setdefault(key, (real, []))[1].extend(where)
    return sorted((k, r, w) for k, (r, w) in out.items())


def propose_fills(w, h, rows, pixels):
    """{(x, y): index}: each pixel gets the most common non-key colour of its
    8 neighbours (ties: the one nearest their mean in palette order is not
    meaningful, so the first in reading order); a cluster is filled in
    passes, so an inner pixel sees its filled neighbours."""
    todo = set(pixels)
    fill = {}
    while todo:
        done = {}
        for x, y in sorted(todo, key=lambda p: (p[1], p[0])):
            c = collections.Counter()
            order = []
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    a, b = x + dx, y + dy
                    if (dx or dy) and 0 <= a < w and 0 <= b < h:
                        v = fill.get((a, b), rows[b][a])
                        if v != KEY and (a, b) not in todo:
                            c[v] += 1
                            order.append(v)
            if c:
                best = max(c.values())
                done[(x, y)] = next(v for v in order if c[v] == best)
        if not done:
            break
        fill.update(done)
        todo -= set(done)
    return fill


def read_tsv(path):
    rows = {}
    if not os.path.exists(path):
        return rows
    with open(path) as f:
        for line in f:
            line = line.rstrip("\n")
            if not line or line.startswith("#") or line.startswith("file\t"):
                continue
            r = dict(zip(FIELDS, line.split("\t")))
            rows[(r["file"], int(r["x"]), int(r["y"]))] = r
    return rows


# A 3x5 font (enough for paths and numbers), one string of 15 bits per glyph.
FONT = {
    "0": "111101101101111", "1": "010110010010111", "2": "111001111100111",
    "3": "111001111001111", "4": "101101111001001", "5": "111100111001111",
    "6": "111100111101111", "7": "111001001010010", "8": "111101111101111",
    "9": "111101111001111", "A": "010101111101101", "B": "110101110101110",
    "C": "011100100100011", "D": "110101101101110", "E": "111100110100111",
    "F": "111100110100100", "G": "011100101101011", "H": "101101111101101",
    "I": "111010010010111", "J": "001001001101010", "K": "101101110101101",
    "L": "100100100100111", "M": "101111111101101", "N": "110101101101101",
    "O": "010101101101010", "P": "110101110100100", "Q": "010101101110011",
    "R": "110101110101101", "S": "011100010001110", "T": "111010010010010",
    "U": "101101101101111", "V": "101101101101010", "W": "101101111111101",
    "X": "101101010101101", "Y": "101101010010010", "Z": "111001010100111",
    "/": "001001010100100", ",": "000000000010100", ".": "000000000000010",
    "_": "000000000000111", "#": "101111101111101", ":": "000010000010000",
    " ": "000000000000000", "-": "000000111000000", "=": "000111000111000",
}


class Canvas:
    def __init__(self, w, h, bg=(24, 24, 24)):
        self.w, self.h = w, h
        self.px = [bytearray(bg * w) for _ in range(h)]

    def rect(self, x, y, w, h, c):
        for yy in range(max(0, y), min(self.h, y + h)):
            row = self.px[yy]
            for xx in range(max(0, x), min(self.w, x + w)):
                row[3 * xx : 3 * xx + 3] = bytes(c)

    def text(self, x, y, s, c=(230, 230, 230), scale=2):
        for ch in s.upper():
            g = FONT.get(ch, FONT[" "])
            for i, bit in enumerate(g):
                if bit == "1":
                    self.rect(x + (i % 3) * scale, y + (i // 3) * scale, scale, scale, c)
            x += 4 * scale

    def save(self, path):
        write_png(path, self.w, self.h, self.px)


HOLE = (255, 0, 255)
OTHER = (255, 140, 0)
R = 7  # crop radius: 15x15
Z = 8  # zoom


def draw_crop(cv, ox, oy, bmp, x, y, fills, others, after):
    w, h, rows, pal = bmp
    for dy in range(-R, R + 1):
        for dx in range(-R, R + 1):
            a, b = x + dx, y + dy
            if not (0 <= a < w and 0 <= b < h):
                c = (0, 0, 0)
            elif (a, b) == (x, y):
                c = tuple(pal[fills[(x, y)]]) if after and (x, y) in fills else HOLE
            elif (a, b) in others:
                c = OTHER
            elif rows[b][a] == KEY:
                c = (60, 60, 60) if (a + b) & 1 else (100, 100, 100)
            else:
                c = tuple(pal[rows[b][a]])
            cv.rect(ox + (dx + R) * Z, oy + (dy + R) * Z, Z, Z, c)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--assets", default="assets")
    ap.add_argument("--tsv", default="src/data/key_specks.tsv")
    ap.add_argument("--out", default="zig-out/key-review")
    ap.add_argument("--max-cluster", type=int, default=6)
    ap.add_argument("--dither-min", type=int, default=12)
    ap.add_argument("--per-sheet", type=int, default=48)
    ap.add_argument("--summary", type=int, default=0)
    ap.add_argument("--list", action="store_true", help="print the sprite list")
    a = ap.parse_args()

    old = read_tsv(a.tsv)
    spr = sprites(a.assets)
    if a.list:
        for key, real, where in spr:
            print(f"{key}\t{real}\t{'; '.join(where)}")
    groups = collections.OrderedDict()  # content hash -> [keys]
    bmps = {}
    for key, real, _ in spr:
        data = open(real, "rb").read()
        groups.setdefault(hashlib.sha1(data).hexdigest(), []).append(key)
        bmps[key] = load_bmp(real)

    out_rows = []
    review = []  # (row number, key, x, y, kind, fill) for the first path of a group
    n_bitmaps = 0
    for keys in groups.values():
        first = keys[0]
        bmp = bmps[first]
        if not bmp:
            continue
        w, h, rows, _ = bmp
        cand = {}
        for kind, comp in classify(w, h, rows, a.max_cluster, a.dither_min):
            if kind in ("single", "cluster"):
                for p in comp:
                    cand[p] = kind
        if not cand:
            continue
        n_bitmaps += 1
        fills = propose_fills(w, h, rows, cand)
        for (x, y) in sorted(cand, key=lambda p: (p[1], p[0])):
            prev = next((old[(k, x, y)] for k in keys if (k, x, y) in old), None)
            fill = int(prev["fill"]) if prev else fills.get((x, y), KEY)
            decision = prev["decision"] if prev else "?"
            reason = prev.get("reason", "") if prev else ""
            review.append((len(review) + 1, first, x, y, cand[(x, y)], fill, decision, cand))
            for k in keys:
                out_rows.append((k, x, y, fill, decision, cand[(x, y)], reason))

    os.makedirs(os.path.dirname(a.tsv), exist_ok=True)
    out_rows.sort(key=lambda r: (r[0], r[2], r[1]))
    with open(a.tsv, "w") as f:
        f.write("# Colour-11 pixels inside NOITE's sprites (BUGS.md, fix sprite_key_specks).\n")
        f.write("# Generated by tools/key_review.py, decisions reviewed by hand: the fix\n")
        f.write("# writes `fill` into the `fill` rows when the bitmap is loaded.\n")
        f.write("\t".join(FIELDS) + "\n")
        for r in out_rows:
            f.write("\t".join(str(v) for v in r) + "\n")

    os.makedirs(a.out, exist_ok=True)
    for old_png in os.listdir(a.out):
        if old_png.startswith("sheet-") and old_png.endswith(".png"):
            os.remove(os.path.join(a.out, old_png))
    with open(os.path.join(a.out, "index.tsv"), "w") as f:
        f.write("n\tfile\tx\ty\tkind\tfill\tdecision\n")
        for n, key, x, y, kind, fill, decision, _ in review:
            f.write(f"{n}\t{key}\t{x}\t{y}\t{kind}\t{fill}\t{decision}\n")
    cw, chh = 2 * (2 * R + 1) * Z + 8, (2 * R + 1) * Z + 30
    cols = 6
    for s in range(0, len(review), a.per_sheet):
        batch = review[s : s + a.per_sheet]
        nrows = (len(batch) + cols - 1) // cols
        cv = Canvas(cols * (cw + 12), nrows * (chh + 8))
        for i, (n, key, x, y, kind, fill, decision, cand) in enumerate(batch):
            ox, oy = (i % cols) * (cw + 12) + 4, (i // cols) * (chh + 8) + 4
            fills = propose_fills(*bmps[key][:3], cand)
            fills[(x, y)] = fill
            others = set(cand) - {(x, y)}
            draw_crop(cv, ox, oy + 26, bmps[key], x, y, fills, others, False)
            draw_crop(cv, ox + (2 * R + 1) * Z + 8, oy + 26, bmps[key], x, y, fills, others, True)
            short = key.removesuffix(".bmp")
            cv.text(ox, oy, f"#{n} {'C' if kind == 'cluster' else 'S'}", (255, 255, 120), 2)
            cv.text(ox + 70, oy + 2, f"{short} {x},{y}", (220, 220, 220), 1)
            cv.text(ox + 70, oy + 12, f"FILL {fill} {decision}", (160, 200, 255), 1)
        cv.save(os.path.join(a.out, f"sheet-{s // a.per_sheet + 1:02d}.png"))

    if a.summary:
        firsts = {}  # one filled pixel per bitmap, the middle one
        for r in review:
            if r[6] == "fill":
                firsts.setdefault(r[1], []).append(r)
        picks = [rs[len(rs) // 2] for rs in firsts.values()][: a.summary]
        cols = 4
        nrows = (len(picks) + cols - 1) // cols
        cv = Canvas(cols * (cw + 12), nrows * (chh + 8) + 24)
        cv.text(4, 4, "BEFORE: HOLE IN MAGENTA / AFTER: FILLED", (255, 255, 255), 2)
        for i, (n, key, x, y, kind, fill, decision, cand) in enumerate(picks):
            ox, oy = (i % cols) * (cw + 12) + 4, (i // cols) * (chh + 8) + 28
            fills = propose_fills(*bmps[key][:3], cand)
            fills[(x, y)] = fill
            others = set(cand) - {(x, y)}
            draw_crop(cv, ox, oy + 26, bmps[key], x, y, fills, others, False)
            draw_crop(cv, ox + (2 * R + 1) * Z + 8, oy + 26, bmps[key], x, y, fills, others, True)
            cv.text(ox, oy + 4, f"{key.removesuffix('.bmp')} {x},{y}", (220, 220, 220), 2)
        cv.save(os.path.join(a.out, "summary.png"))

    dec = collections.Counter(r[6] for r in review)
    print(f"{len(spr)} sprite bitmaps ({len(groups)} distinct), {n_bitmaps} with candidates, "
          f"{len(review)} candidate pixels: {dec['fill']} fill, {dec['keep']} keep, "
          f"{dec['?']} unreviewed; {a.tsv}, sheets in {a.out}/")


if __name__ == "__main__":
    main()
