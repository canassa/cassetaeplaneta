#!/usr/bin/env python3
"""Smoothness of the MK3 fight's picture, from a headless run's frame trace.

    zig-out/bin/noite --headless --minigame xilindro --ms 40000 --fix all,fight_mk3 \\
        --fight-bot masher,5,log --dump zig-out/mk3-dump --dump-every 16 \\
        --epoch 800000005 2> trace.log
    python3 tools/fight_mk3_smooth.py trace.log

Every presented frame logs `[ms] mk3-frame X0 Y0 X1 Y1 anim0:frame0 anim1:frame1`
(the feet of each fighter on the 640x480 picture and the frame shown). It
reports the frames per second shown, the time between frames, and the
largest step of each fighter's feet between two frames: the fastest
motion in the game is a knock-back or fall (150 px over 8 ticks of 18 ms:
about 20 px a frame at 60 Hz); a larger step is a jump (a bug).
"""

import re
import statistics
import sys

LINE = re.compile(r"^\[(\d+)\] mk3-frame (-?\d+) (-?\d+) (-?\d+) (-?\d+) (\S+) (\S+)$")


def main() -> int:
    frames = []
    for line in open(sys.argv[1], errors="replace"):
        m = LINE.match(line.strip())
        if m:
            frames.append(tuple(int(m.group(i)) for i in range(1, 6)) + (m.group(6), m.group(7)))
    # The intro stands still; keep the frames with the round running.
    frames = [f for f in frames if f[0] > 0]
    if len(frames) < 10:
        print("no frames in the trace")
        return 2
    dts = [b[0] - a[0] for a, b in zip(frames, frames[1:]) if b[0] != a[0]]
    span_s = (frames[-1][0] - frames[0][0]) / 1000
    print(f"frames {len(frames)} over {span_s:.1f} s")
    print(f"distinct presented times {len(dts) + 1}: {len(dts) / (sum(dts) / 1000):.1f} per second; "
          f"interval ms: median {statistics.median(dts)}, max {max(dts)}")
    worst = 0
    for who, (ix, iy) in enumerate(((1, 2), (3, 4))):
        steps = []
        for a, b in zip(frames, frames[1:]):
            if a[0] == b[0]:
                continue
            steps.append((max(abs(b[ix] - a[ix]), abs(b[iy] - a[iy])), b[0], b[5 + who]))
        top = max(steps)
        worst = max(worst, top[0])
        print(f"fighter {who}: largest feet step between frames {top[0]} px (at {top[1]} ms, {top[2]}); "
              f"99th percentile {sorted(s[0] for s in steps)[int(len(steps) * 0.99)]} px")
    limit = 26
    print("OK: no frame where a fighter's feet jump" if worst <= limit else f"FAIL: a step above {limit} px")
    return 0 if worst <= limit else 1


if __name__ == "__main__":
    sys.exit(main())
