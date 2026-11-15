#!/usr/bin/env python3
"""Builds the fight engine's character pack for the SF3 3rd Strike Ryu rip.

The rip (Zweifuss' per-move GIFs, Capcom's copyright, private use only) is
NOT in git and neither is the pack this writes: `zig-out/sprites/ryu/pack.bin`
(gitignored). The engine (`src/core/fight_mk3/`) loads it at run time and the
fight is unavailable when it is missing (docs/fights/MK3.md "Sprites").

    nix develop .#explorer -c python3 tools/ryu_pack.py [--gifs DIR] [--out DIR]

`--gifs` is the folder of `ryu-<move>.gif` files (default: the sprite search
folder of the main checkout, `zig-out/sprite-search/hd/raw/sf3-ryu/col`).

Pack layout (little endian): `MK3P`, u32 json length, the JSON, then the pixel
blob. The JSON is the character: a palette (entry 0 = transparent), a frame
table (trimmed size, offset of the picture's top-left from the feet anchor,
offset into the blob, hurt and hit box) and the clips (move name -> frames,
ms per frame, loop, active frames). Frames are 8-bit palette indices, `w*h`
bytes, facing right. All coordinates are source pixels relative to the
anchor: x from the body's centre line, y from the ground (negative up).

How the data is derived (the rip has no box or anchor data):
- Anchor x. Every clip's GIF frames are registered to one crop, so a move's
  frames share an origin. A "static" clip uses the feet's x of its first
  frame (the stance's feet centre) for all frames; a "dynamic" clip (walk,
  dashes, jumps, reactions, the throw: the body travels inside the GIF) uses
  each frame's silhouette centroid, shifted so frame 0 agrees with the
  static rule, then smoothed over three frames, so the body stays under the
  fighter's position and the game's motion is the only motion.
- Anchor y. Ground clips: the picture's bottom edge is the ground. Air
  clips (jumps): each frame's silhouette bottom is the feet, the height is
  the engine's.
- Hurt box: the silhouette's pixels within 26 px of the anchor, bounding box
  (the trunk and legs; an outstretched arm or leg is not hittable). None for
  a fighter on the floor.
- Hit box: for the active frames of an attack, the bounding box of the
  silhouette beyond 20 px in front of the anchor (the limb). A frame is
  active when its reach is at least 80% of the clip's longest and at
  least 12 px past the trunk; the active range is the first to the last such
  frame.
"""

from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path

from PIL import Image

MAIN = Path("/home/canassa/src/github.com/canassa/cassetaeplaneta")
DEFAULT_GIFS = MAIN / "zig-out/sprite-search/hd/raw/sf3-ryu/col"

TRUNK = 26  # px each side of the anchor that count as body
LIMB_FROM = 20  # px in front of the anchor where a limb's hit box starts

# name -> (gif, frame slice, mode, loop, extra)
#   mode: static | dynamic (x anchor), "air" adds the y anchor per frame
#   extra: flags: "attack", "nohurt", "air", "ms=N" (force N ms/frame)
CLIPS: dict[str, tuple[str, slice, str, bool, tuple[str, ...]]] = {
    "stance": ("stance", slice(None), "static", True, ()),
    "crouch": ("crouch", slice(None), "static", True, ()),
    "walk_f": ("walkf", slice(None), "dynamic", True, ()),
    "walk_b": ("walkb", slice(None), "dynamic", True, ()),
    "jump_u": ("jump", slice(None), "dynamic", False, ("air",)),
    "jump_f": ("jumpf", slice(None), "dynamic", False, ("air",)),
    "jump_b": ("jumpb", slice(None), "dynamic", False, ("air",)),
    # MK3's four buttons: low punch, high punch, low kick, high kick
    "lp": ("wp", slice(None), "static", False, ("attack",)),
    "hp": ("hp", slice(None), "static", False, ("attack",)),
    "lk": ("wk", slice(None), "static", False, ("attack",)),
    "hk": ("mk", slice(None), "static", False, ("attack",)),
    # Back + HK: Ryu's tall roundhouse
    "roundhouse": ("hk", slice(None), "static", False, ("attack",)),
    # crouching: punch, uppercut, kick, sweep
    "c_lp": ("crouch-wp", slice(None), "static", False, ("attack",)),
    "uppercut": ("crouch-hp", slice(None), "static", False, ("attack",)),
    "c_lk": ("crouch-wk", slice(None), "static", False, ("attack",)),
    "sweep": ("crouch-hk", slice(None), "static", False, ("attack",)),
    # jumping attacks
    "j_lp": ("jump-lp", slice(None), "static", False, ("attack", "air")),
    "j_hp": ("jump-hp", slice(None), "static", False, ("attack", "air")),
    "j_lk": ("jump-lk", slice(None), "static", False, ("attack", "air")),
    "j_hk": ("jump-hk", slice(None), "static", False, ("attack", "air")),
    "throw": ("throw-forward", slice(None), "dynamic", False, ("attack",)),
    "block_hi": ("block-high", slice(None), "static", True, ()),
    "block_lo": ("block-low", slice(None), "static", True, ()),
    "hit_hi": ("stand-hit", slice(0, 8), "dynamic", False, ()),
    "hit_lo": ("crouch-hit", slice(0, 7), "dynamic", False, ()),
    # the fall: the slam's flip, then lying (the last frames, held)
    "fall": ("slam", slice(0, 14), "dynamic", False, ("nohurt",)),
    "down": ("slam", slice(22, 25), "dynamic", True, ("nohurt",)),
    "win": ("win1", slice(None), "static", False, ()),
    "taunt": ("taunt", slice(None), "static", False, ()),
}


# Clips whose active frames the reach rule cannot find (a rising uppercut
# has no forward reach: its hit box is the fist and arm over the head).
ACTIVE_OVERRIDE = {"uppercut": (3, 5, "top"), "j_lp": (2, 5, "reach")}


def load(path: Path) -> list[tuple[Image.Image, int]]:
    im = Image.open(path)
    out = []
    for i in range(im.n_frames):
        im.seek(i)
        out.append((im.convert("RGBA"), int(im.info.get("duration") or 70)))
    return out


def alpha_bbox(f: Image.Image):
    return f.getchannel("A").point(lambda v: 255 if v else 0).getbbox()


def foot_cx(f: Image.Image) -> float:
    a = f.getchannel("A")
    bb = alpha_bbox(f)
    if not bb:
        return f.width / 2
    px = a.load()
    tot = sx = 0
    for y in range(max(bb[1], bb[3] - 10), bb[3]):
        for x in range(f.width):
            if px[x, y]:
                tot += 1
                sx += x
    return sx / tot if tot else f.width / 2


def centroid_x(f: Image.Image) -> float:
    a = f.getchannel("A")
    px = a.load()
    tot = sx = 0
    for y in range(f.height):
        for x in range(f.width):
            if px[x, y]:
                tot += 1
                sx += x
    return sx / tot if tot else f.width / 2


def sil_bottom(f: Image.Image) -> int:
    bb = alpha_bbox(f)
    return bb[3] if bb else f.height


def bbox_of(f: Image.Image, x_lo: float, x_hi: float):
    """Bounding box (x0, y0, x1, y1; x1/y1 exclusive) of the opaque pixels
    with x_lo <= x < x_hi, or None."""
    px = f.getchannel("A").load()
    x0 = y0 = 10**9
    x1 = y1 = -1
    for y in range(f.height):
        for x in range(max(0, int(x_lo)), min(f.width, int(x_hi) + 1)):
            if px[x, y] and x_lo <= x < x_hi:
                x0 = min(x0, x)
                x1 = max(x1, x + 1)
                y0 = min(y0, y)
                y1 = max(y1, y + 1)
    return None if x1 < 0 else (x0, y0, x1, y1)


def preview(char: dict, blob: bytes, path: Path) -> None:
    """A sheet: a row per clip, the anchor (green), hurt (blue), hit (red)."""
    from PIL import ImageDraw

    pal = char["palette"]
    cw, ch, up = 140, 150, 130
    rows = [(c["name"], c) for c in char["clips"]]
    cols = min(14, max(len(c["frames"]) for _, c in rows))
    sheet = Image.new("RGBA", (cw * cols, ch * len(rows)), (60, 90, 60, 255))
    d = ImageDraw.Draw(sheet)
    for r, (name, clip) in enumerate(rows):
        d.text((2, r * ch), f"{name} active={clip['active']}", fill=(255, 255, 255, 255))
        for i, fid in enumerate(clip["frames"][:cols]):
            f = char["frames"][fid]
            im = Image.new("RGBA", (f["w"], f["h"]))
            px = im.load()
            for k, v in enumerate(blob[f["off"] : f["off"] + f["w"] * f["h"]]):
                if v:
                    px[k % f["w"], k // f["w"]] = (*pal[v], 255)
            gx, gy = i * cw + 50, r * ch + up
            sheet.alpha_composite(im, (gx + f["ox"], gy + f["oy"]))
            d.line([(gx, gy - 6), (gx, gy)], fill=(0, 255, 0, 255))
            d.line([(gx - 20, gy), (gx + 20, gy)], fill=(255, 255, 0, 255))
            for key, col in (("hurt", (80, 120, 255, 255)), ("hit", (255, 40, 40, 255))):
                b = f[key]
                if b:
                    d.rectangle([gx + b[0], gy + b[1], gx + b[2], gy + b[3]], outline=col)
    sheet.save(path)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--gifs", type=Path, default=DEFAULT_GIFS)
    ap.add_argument("--out", type=Path, default=Path("zig-out/sprites/ryu"))
    ap.add_argument("--report", action="store_true", help="print each clip's feet jitter (source px)")
    ap.add_argument("--preview", type=Path, help="also write a contact sheet of every clip with its boxes")
    args = ap.parse_args()

    palette: dict[tuple[int, int, int], int] = {}
    frames: list[dict] = []
    blob = bytearray()
    clips: dict[str, dict] = {}
    cache: dict[tuple, int] = {}

    for name, (gif, sl, mode, loop, flags) in CLIPS.items():
        src = load(args.gifs / f"ryu-{gif}.gif")[sl]
        air = "air" in flags
        ref_foot = foot_cx(src[0][0])
        ref_cent = centroid_x(src[0][0])
        # anchor x per frame
        if mode == "static":
            ax = [ref_foot] * len(src)
        else:
            raw = [centroid_x(f) - (ref_cent - ref_foot) for f, _ in src]
            ax = []
            for i in range(len(raw)):
                lo, hi = max(0, i - 1), min(len(raw), i + 2)
                ax.append(sum(raw[lo:hi]) / (hi - lo))
        # anchor y per frame
        if air and mode == "dynamic":
            ay = [sil_bottom(f) for f, _ in src]
        elif air:
            ay = [sil_bottom(src[0][0])] * len(src)
        else:
            ay = [f.height for f, _ in src]
        # reach and active frames
        reach = []
        for (f, _), a in zip(src, ax):
            bb = alpha_bbox(f)
            reach.append((bb[2] - a - TRUNK) if bb else 0)
        active = None
        if "attack" in flags:
            best = max(reach)
            idx = [i for i, r in enumerate(reach) if r >= max(12, 0.8 * best)]
            if idx:
                active = [idx[0], idx[-1]]
        top = False
        if name in ACTIVE_OVERRIDE:
            lo, hi, how = ACTIVE_OVERRIDE[name]
            active = [lo, hi]
            top = how == "top"
        if args.report and not air and "nohurt" not in flags:
            # Where the feet are against the anchor, frame to frame: a big
            # step is a foot that jumps when the fighter does not.
            rel = [foot_cx(f) - a for (f, _), a in zip(src, ax)]
            steps = [abs(b - a) for a, b in zip(rel, rel[1:])]
            print(f"  {name:10s} feet vs anchor: min {min(rel):6.1f} max {max(rel):6.1f}  largest step {max(steps, default=0):5.1f}")
        ids, ms = [], []
        for i, ((f, d), a, y) in enumerate(zip(src, ax, ay)):
            a = int(round(a))
            bb = alpha_bbox(f)
            if bb is None:
                bb = (0, 0, 1, 1)
            cropped = f.crop(bb)
            key = (gif, sl.start, i, a, y, name if active else "")
            fid = cache.get(key)
            if fid is None:
                px = cropped.load()
                idxs = bytearray()
                for yy in range(cropped.height):
                    for xx in range(cropped.width):
                        r, g, b, al = px[xx, yy]
                        if al == 0:
                            idxs.append(0)
                            continue
                        c = (r, g, b)
                        if c not in palette:
                            palette[c] = len(palette) + 1
                        idxs.append(palette[c])
                hurt = None
                if "nohurt" not in flags:
                    hb = bbox_of(f, a - TRUNK, a + TRUNK)
                    if hb:
                        hurt = [hb[0] - a, hb[1] - y, hb[2] - a, hb[3] - y]
                hit = None
                if active and active[0] <= i <= active[1]:
                    if top:
                        full = alpha_bbox(f)
                        lb = bbox_of(f.crop((0, 0, f.width, full[1] + (full[3] - full[1]) // 2)), a - 14, a + 40)
                    else:
                        lb = bbox_of(f, a + LIMB_FROM, 10**6)
                    if lb:
                        hit = [lb[0] - a, lb[1] - y, lb[2] - a, lb[3] - y]
                fid = len(frames)
                frames.append(
                    {
                        "w": cropped.width,
                        "h": cropped.height,
                        "ox": bb[0] - a,
                        "oy": bb[1] - y,
                        "off": len(blob),
                        "hurt": hurt,
                        "hit": hit,
                    }
                )
                blob += idxs
                cache[key] = fid
            ids.append(fid)
            ms.append(d)
        clips[name] = {"name": name, "frames": ids, "ms": ms, "loop": loop, "active": active}

    pal = [[0, 0, 0]] + [list(c) for c, _ in sorted(palette.items(), key=lambda kv: kv[1])]
    char = {"name": "ryu", "scale": 2, "palette": pal, "frames": frames, "clips": list(clips.values())}
    js = json.dumps(char, separators=(",", ":")).encode()
    args.out.mkdir(parents=True, exist_ok=True)
    with open(args.out / "pack.bin", "wb") as fh:
        fh.write(b"MK3P" + struct.pack("<I", len(js)) + js + bytes(blob))
    if args.preview:
        preview(char, bytes(blob), args.preview)
    print(
        f"{len(clips)} clips, {len(frames)} frames, {len(pal)} colours, "
        f"{len(blob) // 1024} KiB pixels -> {args.out / 'pack.bin'}"
    )


if __name__ == "__main__":
    main()
