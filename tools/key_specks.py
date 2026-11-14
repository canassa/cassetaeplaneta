"""Find colour-11 pixels inside sprite art that the game draws as holes.

Every object is drawn with palette index 11 as the transparent colour, so an
index-11 pixel inside a picture shows the scene behind it. Most index 11 is the
backdrop around the art; some is deliberate (holes between limbs, checkerboard
see-through). This script classifies every index-11 connected component
(4-connected) of each 8-bit BMP on the disc:

    outside   touches the bitmap's edge: the backdrop (real transparency)
    hole      enclosed, more than --max-cluster pixels: a deliberate gap
    The small enclosed components left are grouped 8-connected (diagonal
    links count):
    fringe    a group touching the backdrop or a hole diagonally: the art's
              edge, left as is
    dither    a group of --dither-min pixels or more: a checkerboard
              see-through area (deliberate)
    single    one pixel, no index 11 among its 8 neighbours: almost surely a
              palette-reduction accident (the suspicious ones)
    cluster   a group of 2..--dither-min-1 pixels: grey zone

Usage (from the repo root, in the dev shell):

    python3 tools/key_specks.py [--assets assets] [--out zig-out/key-specks]
        [--max-cluster 6] [--dither-min 12] [--sheets 40]

Writes <out>/report.tsv (one row per bitmap with suspicious pixels, duplicates
collapsed) and <out>/sheet/<name>.png: the bitmap at 3x, index 11 shown as a
dark checker, singles in magenta, clusters in yellow, for the --sheets
sprites with the most suspicious pixels. Background pictures (640x480 and
larger) are listed last and marked, since they are drawn opaque.
"""

import argparse
import collections
import hashlib
import os
import struct
import zlib

KEY = 11


def load_bmp(path):
    """(width, height, rows top-down, palette) of an 8-bit BI_RGB BMP, or None."""
    with open(path, "rb") as f:
        d = f.read()
    if d[:2] != b"BM" or len(d) < 54:
        return None
    off = struct.unpack_from("<I", d, 10)[0]
    hsize = struct.unpack_from("<I", d, 14)[0]
    w, h = struct.unpack_from("<ii", d, 18)
    bpp = struct.unpack_from("<H", d, 28)[0]
    comp = struct.unpack_from("<I", d, 30)[0]
    if bpp != 8 or comp != 0 or w <= 0 or h == 0:
        return None
    pal_off = 14 + hsize
    pal = [d[pal_off + 4 * i : pal_off + 4 * i + 3][::-1] for i in range(256)]
    stride = (w + 3) & ~3
    ah = abs(h)
    rows = [d[off + y * stride : off + y * stride + w] for y in range(ah)]
    if h > 0:
        rows.reverse()  # bottom-up on disc
    return w, ah, rows, pal


def classify(w, h, rows, max_cluster, dither_min):
    """Index-11 components -> list of (kind, [(x, y), ...]).

    First the 4-connected components: those touching the edge are the
    backdrop, enclosed ones larger than `max_cluster` are holes. The small
    enclosed ones left are then grouped 8-connected (diagonal links count):
    a group of `dither_min` pixels or more is a checkerboard see-through
    area; a group touching the backdrop or a hole diagonally is the art's
    fringe; the rest are the suspicious singles and clusters."""
    comp_id = [-1] * (w * h)
    kinds = []
    comps = []
    for y0 in range(h):
        for x0 in range(w):
            if rows[y0][x0] != KEY or comp_id[y0 * w + x0] >= 0:
                continue
            cid = len(comps)
            comp = []
            stack = [(x0, y0)]
            comp_id[y0 * w + x0] = cid
            edge = False
            while stack:
                x, y = stack.pop()
                comp.append((x, y))
                if x in (0, w - 1) or y in (0, h - 1):
                    edge = True
                for a, b in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= a < w and 0 <= b < h and comp_id[b * w + a] < 0 and rows[b][a] == KEY:
                        comp_id[b * w + a] = cid
                        stack.append((a, b))
            comps.append(comp)
            kinds.append("outside" if edge else "hole" if len(comp) > max_cluster else "small")
    out = [(k, c) for k, c in zip(kinds, comps) if k != "small"]
    done = set()
    for cid, comp in enumerate(comps):
        if kinds[cid] != "small" or cid in done:
            continue
        group = []
        fringe = False
        stack = [cid]
        done.add(cid)
        while stack:
            c = stack.pop()
            group.extend(comps[c])
            for x, y in comps[c]:
                for a, b in ((x + 1, y + 1), (x - 1, y + 1), (x + 1, y - 1), (x - 1, y - 1)):
                    if not (0 <= a < w and 0 <= b < h) or rows[b][a] != KEY:
                        continue
                    n = comp_id[b * w + a]
                    if kinds[n] != "small":
                        fringe = True
                    elif n not in done:
                        done.add(n)
                        stack.append(n)
        if fringe:
            kind = "fringe"
        elif len(group) >= dither_min:
            kind = "dither"
        elif len(group) == 1:
            kind = "single"
        else:
            kind = "cluster"
        out.append((kind, group))
    return out


def write_png(path, w, h, rgb_rows):
    raw = b"".join(b"\x00" + bytes(r) for r in rgb_rows)
    def chunk(t, data):
        c = struct.pack(">I", len(data)) + t + data
        return c + struct.pack(">I", zlib.crc32(t + data) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def sheet(path, w, h, rows, pal, marks, scale=3):
    """The bitmap at `scale`, index 11 as a dark checker, marks coloured."""
    colours = {"single": (255, 0, 255), "cluster": (255, 255, 0)}
    out = []
    for y in range(h):
        line = []
        for x in range(w):
            k = marks.get((x, y))
            if k:
                c = colours[k]
            elif rows[y][x] == KEY:
                c = (40, 40, 40) if (x + y) & 1 else (70, 70, 70)
            else:
                c = tuple(pal[rows[y][x]])
            line.extend(c * scale)
        for _ in range(scale):
            out.append(line)
    write_png(path, w * scale, h * scale, out)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--assets", default="assets")
    ap.add_argument("--out", default="zig-out/key-specks")
    ap.add_argument("--max-cluster", type=int, default=6)
    ap.add_argument("--dither-min", type=int, default=12)
    ap.add_argument("--sheets", type=int, default=40)
    a = ap.parse_args()

    seen_hash = {}
    rows_out = []
    for root, _, files in os.walk(a.assets):
        for fn in sorted(files):
            if not fn.upper().endswith(".BMP"):
                continue
            path = os.path.join(root, fn)
            data = open(path, "rb").read()
            hsh = hashlib.sha1(data).hexdigest()
            if hsh in seen_hash:
                seen_hash[hsh][1].append(path)
                continue
            bmp = load_bmp(path)
            if not bmp:
                continue
            w, h, rows, pal = bmp
            comps = classify(w, h, rows, a.max_cluster, a.dither_min)
            count = collections.Counter()
            marks = {}
            for kind, comp in comps:
                count[kind] += len(comp)
                if kind in ("single", "cluster"):
                    for p in comp:
                        marks[p] = kind
            entry = [path, w, h, count, marks, bmp]
            seen_hash[hsh] = (entry, [])
            if count["single"] or count["cluster"]:
                rows_out.append(entry)

    os.makedirs(os.path.join(a.out, "sheet"), exist_ok=True)
    def is_bg(e):
        return e[1] >= 640 and e[2] >= 480
    # Sprites first (backgrounds are drawn opaque), most suspicious first.
    rows_out.sort(key=lambda e: (is_bg(e), -(e[3]["single"] + e[3]["cluster"])))
    with open(os.path.join(a.out, "report.tsv"), "w") as f:
        f.write("path\tw\th\tbackground\tsingle\tcluster\tdither\tfringe\thole\toutside\tduplicates\n")
        for path, w, h, c, _, _ in rows_out:
            hsh = hashlib.sha1(open(path, "rb").read()).hexdigest()
            dups = " ".join(seen_hash[hsh][1])
            bg = "yes" if w >= 640 and h >= 480 else ""
            f.write(f"{path}\t{w}\t{h}\t{bg}\t{c['single']}\t{c['cluster']}\t"
                    f"{c['dither']}\t{c['fringe']}\t{c['hole']}\t{c['outside']}\t{dups}\n")
    for path, w, h, c, marks, bmp in [e for e in rows_out if not is_bg(e)][: a.sheets]:
        name = path.replace(os.sep, "_").replace("assets_", "")
        sheet(os.path.join(a.out, "sheet", name + ".png"), w, h, bmp[2], bmp[3], marks)
    total_s = sum(e[3]["single"] for e in rows_out)
    total_c = sum(e[3]["cluster"] for e in rows_out)
    print(f"{len(rows_out)} bitmaps with suspicious pixels: {total_s} singles, "
          f"{total_c} cluster pixels; report {a.out}/report.tsv, "
          f"{min(a.sheets, len(rows_out))} sheets in {a.out}/sheet/")


if __name__ == "__main__":
    main()
