"""Raw bytes of NOITE.EXE's segments, read straight from the 16-bit NE file.

Ghidra maps NE segment *n* (1-based) to selector ``0x1000 + (n-1)*8``; this
module does the same, so a ``seg:off`` from the tracker DB names the byte in
the file. Only the segment data stored in the file is available (no
relocations applied, no BSS beyond the stored length).

Used for ``.ref/strings.md``: the exact bytes of the string constants a
function pushes as far pointers.
"""

from __future__ import annotations

import struct
from dataclasses import dataclass
from pathlib import Path

DGROUP = 0x1050
MAX_STRING = 512


class NeError(RuntimeError):
    pass


@dataclass(frozen=True)
class Segment:
    selector: int
    data: bytes  # the bytes stored in the file (may be shorter than the segment)


@dataclass(frozen=True)
class NeImage:
    segments: dict[int, Segment]  # selector -> segment

    @classmethod
    def load(cls, path: Path) -> NeImage:
        return cls.parse(path.read_bytes())

    @classmethod
    def parse(cls, raw: bytes) -> NeImage:
        if raw[:2] != b"MZ":
            raise NeError("not an MZ executable")
        (ne,) = struct.unpack_from("<I", raw, 0x3C)
        if raw[ne : ne + 2] != b"NE":
            raise NeError("no NE header")
        (count,) = struct.unpack_from("<H", raw, ne + 0x1C)
        (table,) = struct.unpack_from("<H", raw, ne + 0x22)
        (shift,) = struct.unpack_from("<H", raw, ne + 0x32)
        segs: dict[int, Segment] = {}
        for i in range(count):
            sector, length, _flags, _minalloc = struct.unpack_from("<HHHH", raw, ne + table + i * 8)
            sel = 0x1000 + i * 8
            if sector == 0:  # nothing stored in the file (pure BSS)
                segs[sel] = Segment(sel, b"")
                continue
            start = sector << shift
            size = length or 0x10000
            segs[sel] = Segment(sel, raw[start : start + size])
        return cls(segs)

    def read(self, selector: int, offset: int, n: int) -> bytes:
        seg = self.segments.get(selector)
        return b"" if seg is None else seg.data[offset : offset + n]

    def c_string(self, selector: int, offset: int) -> bytes | None:
        """The NUL-terminated string at ``selector:offset`` (without the NUL), if the
        bytes there look like text: printable ASCII, Latin-1 letters, tab, CR, LF.
        An empty string (``""``) counts only in a code segment and right after
        another string's NUL (MSVC packs a function's literals there); in DGROUP
        a zero byte is far more often zeroed data."""
        seg = self.segments.get(selector)
        if seg is None or offset >= len(seg.data):
            return None
        end = seg.data.find(b"\0", offset, offset + MAX_STRING)
        if end == offset:
            ok = selector != DGROUP and offset > 0 and seg.data[offset - 1] == 0
            return b"" if ok else None
        if end < offset:
            return None
        s = seg.data[offset:end]
        return s if all(_texty(b) for b in s) else None


def _texty(b: int) -> bool:
    return 0x20 <= b < 0x7F or b in (0x09, 0x0A, 0x0D) or b >= 0xA0


_ESCAPES = {0x5C: "\\\\", 0x22: '\\"', 0x0A: "\\n", 0x0D: "\\r", 0x09: "\\t"}


def c_literal(s: bytes) -> str:
    """A C/Zig string literal spelling ``s`` byte for byte (``\\xe3`` for non-ASCII)."""
    out = []
    for b in s:
        if b in _ESCAPES:
            out.append(_ESCAPES[b])
        elif 0x20 <= b < 0x7F:
            out.append(chr(b))
        else:
            out.append(f"\\x{b:02x}")
    return '"' + "".join(out) + '"'
