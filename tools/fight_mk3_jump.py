#!/usr/bin/env python3
"""Heights of a jump in the MK3 fight's picture, from a headless run's frame trace.

    zig-out/bin/noite --headless --minigame xilindro --ms 6200 --fix all \\
        --input tools/play/xilindro-mk3-jump.input 2> trace.log
    python3 tools/fight_mk3_jump.py trace.log [zig-out/sprites/ryu/pack.bin]

The input's F9 turns the frame trace on (`[ms] mk3-frame X0 Y0 X1 Y1
anim0:frame0 anim1:frame1`: the feet of each fighter on the 640x480 picture, the
frame of the clip shown). With the pack's frame sizes this gives, for the
jumper (fighter 0), the height of the figure's bottom and top over the floor
(ground line y 424) at the apex of its flight, in screen px and as multiples
of the standing height (180 px: 144 arcade x 1.25), the numbers MK3.md section 3
compares with MK3's own picture (bottom about 1.4, top about 1.8).
"""

import json
import re
import struct
import sys

GROUND_Y = 424
STAND_PX = 180.0
CLIPS = ["stance", "crouch", "walk_f", "walk_b", "jump_u", "jump_f", "jump_b"]
# The pack's clip names (tools/ryu_pack.py) of the traced anims.
CLIP_OF = {"jump_u": "jump_u", "jump_f": "jump_f", "jump_b": "jump_b", "stance": "stance"}
LINE = re.compile(r"^\[(\d+)\] mk3-frame (-?\d+) (-?\d+) (-?\d+) (-?\d+) (\w+):(\d+) (\w+):(\d+)$")


def main() -> int:
    pack_path = sys.argv[2] if len(sys.argv) > 2 else "zig-out/sprites/ryu/pack.bin"
    b = open(pack_path, "rb").read()
    n = struct.unpack("<I", b[4:8])[0]
    pack = json.loads(b[8 : 8 + n])
    scale = STAND_PX / pack["stand"]
    clips = {c["name"]: c["frames"] for c in pack["clips"]}
    best = None
    rows = []
    for line in open(sys.argv[1], errors="replace"):
        m = LINE.match(line.strip())
        if not m:
            continue
        ms, y0 = int(m.group(1)), int(m.group(3))
        anim, idx = m.group(6), int(m.group(7))
        if y0 >= GROUND_Y or anim not in clips:
            continue
        f = pack["frames"][clips[anim][idx]]
        bottom = GROUND_Y - (y0 + (f["oy"] + f["h"]) * scale)
        top = GROUND_Y - (y0 + f["oy"] * scale)
        rows.append((ms, anim, idx, f["h"], bottom, top))
        if best is None or top > best[5]:
            best = rows[-1]
    print("ms anim frame src_h bottom_px top_px (over the floor)")
    for r in rows:
        print(f"{r[0]:6d} {r[1]:7s} {r[2]:2d} {r[3]:4d} {r[4]:6.0f} {r[5]:6.0f}")
    if best:
        ms, anim, idx, h, bottom, top = best
        print(f"highest point at {ms} ms ({anim} frame {idx}, {h} source px): "
              f"bottom {bottom:.0f} px = {bottom / STAND_PX:.2f} x standing, "
              f"top {top:.0f} px = {top / STAND_PX:.2f} x standing (standing = {STAND_PX:.0f} px)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
