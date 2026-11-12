"""Parse ``// @orig`` origin tags out of Zig sources.

Syntax (one tag per original function, on the line above the Zig function,
``switch`` case or test it belongs to)::

    // @orig 1010:0c80 backdrop_ctor
    // @orig 1010:77b6 object3d_get_world_x_thunk_4be (absorbed)
    // @orig 1010:0c80 backdrop_ctor oracle=asset        <- above or inside a test

A tag is a *test tag* when it sits inside a ``test`` block or directly above
one; its ``oracle=`` says where the expected values come from (emulated, asset,
documented, trace). A test tag without one counts as ``none``. Tags that do not
name a ``seg:off`` address (``// @orig SceneObject+0x456`` on struct fields) are
not function tags and are ignored here.
"""

from __future__ import annotations

import re
from collections.abc import Iterator
from dataclasses import dataclass
from pathlib import Path

from noite.db import Oracle

_TAG = re.compile(r"//[/!]?\s*@orig\s+([0-9a-fA-F]{4}:[0-9a-fA-F]{4})\b(.*)$")
_TEST = re.compile(r"^\s*test\b")
_ORACLE = re.compile(r"\boracle=(\w+)")
_SKIP_DIRS = {".zig-cache", "zig-out", ".git", "work", ".ref"}


@dataclass(frozen=True)
class Tag:
    path: str  # relative to the scanned root
    line: int
    addr: str
    name: str | None
    absorbed: bool
    is_test: bool
    oracle: Oracle | None  # None unless is_test
    bad_oracle: str | None = None  # an oracle= value that is not an Oracle


def _code(line: str) -> str:
    """The line without comments, string and char literals (for brace counting)."""
    if line.lstrip().startswith("\\\\"):  # multiline string literal line
        return ""
    out = []
    i, n = 0, len(line)
    while i < n:
        c = line[i]
        if c == "/" and line.startswith("//", i):
            break
        if c in "\"'":
            q = c
            i += 1
            while i < n and line[i] != q:
                i += 2 if line[i] == "\\" else 1
            i += 1
            continue
        out.append(c)
        i += 1
    return "".join(out)


def parse(text: str, path: str) -> list[Tag]:
    lines = text.splitlines()
    tags: list[Tag] = []
    depth = 0
    test_depth: int | None = None  # depth outside the test block we are in
    for idx, line in enumerate(lines):
        code = _code(line)
        if test_depth is None and _TEST.match(code):
            test_depth = depth
        m = _TAG.search(line)
        if m:
            inside = test_depth is not None and depth > test_depth
            tags.append(_make(m, path, idx + 1, inside or _test_follows(lines, idx + 1)))
        depth += code.count("{") - code.count("}")
        if test_depth is not None and depth <= test_depth and "}" in code:
            test_depth = None
    return tags


def _test_follows(lines: list[str], start: int) -> bool:
    """Is the next line of code after ``start`` a ``test`` declaration?"""
    for line in lines[start:]:
        s = line.strip()
        if not s or s.startswith("//"):
            continue
        return bool(_TEST.match(s))
    return False


def _make(m: re.Match[str], path: str, line: int, is_test: bool) -> Tag:
    rest = m.group(2)
    words = [w for w in rest.split() if not w.startswith(("(", "oracle="))]
    name = words[0] if words else None
    oracle: Oracle | None = None
    bad: str | None = None
    if is_test:
        om = _ORACLE.search(rest)
        if om is None:
            oracle = Oracle.NONE
        else:
            try:
                oracle = Oracle(om.group(1))
            except ValueError:
                oracle, bad = Oracle.NONE, om.group(1)
    return Tag(
        path=path,
        line=line,
        addr=m.group(1).lower(),
        name=name,
        absorbed="(absorbed)" in rest,
        is_test=is_test,
        oracle=oracle,
        bad_oracle=bad,
    )


def zig_files(root: Path) -> Iterator[Path]:
    for sub in ("src", "tests"):
        base = root / sub
        if not base.is_dir():
            continue
        for p in sorted(base.rglob("*.zig")):
            if not _SKIP_DIRS.intersection(p.relative_to(root).parts):
                yield p


def scan(root: Path) -> list[Tag]:
    out: list[Tag] = []
    for p in zig_files(root):
        out += parse(p.read_text(errors="replace"), p.relative_to(root).as_posix())
    return out
