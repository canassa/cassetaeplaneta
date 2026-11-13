"""String constants a function references, found in its stored disassembly.

MSVC passes a string as a far pointer: segment then offset, so the listing shows
``PUSH 0x1018`` / ``PUSH 0x36d8`` (a code-segment string), ``PUSH DS`` (or
``PUSH 0x1050``) / ``PUSH 0x...`` (DGROUP), ``PUSH CS`` / ``PUSH 0x...`` (the
function's own segment), a 66-prefixed ``PUSH 0x101836d8``, or the pair loaded
into registers (``MOV DX, 0x1018`` next to ``MOV AX, 0x36d8``). Each candidate is
kept only when the bytes at that address in ``assets/NOITE.EXE`` look like a
NUL-terminated string (see :meth:`noite.ne.NeImage.c_string`), so stray pairs of
constants drop out.
"""

from __future__ import annotations

import re
import sqlite3
from collections.abc import Iterable
from collections.abc import Set as AbstractSet
from dataclasses import dataclass
from pathlib import Path

from noite.ne import DGROUP, NeImage, c_literal

_LINE = re.compile(r"^([0-9a-fA-F]{4}):[0-9a-fA-F]{4}\s+(\w+)\s*(.*)$")
_IMM = re.compile(r"-?0x[0-9a-fA-F]+|-?\d+")


@dataclass(frozen=True)
class StringRef:
    selector: int
    offset: int
    data: bytes

    @property
    def addr(self) -> str:
        return f"{self.selector:04x}:{self.offset:04x}"

    def render(self) -> str:
        return f"- {self.addr} {c_literal(self.data)} ({len(self.data)} bytes)"


def _imm(text: str) -> int | None:
    return int(text.strip(), 0) if _IMM.fullmatch(text.strip()) else None


def _imm16(text: str) -> int | None:
    """A 16-bit immediate (Ghidra prints some as negative: ``-0x50aa``)."""
    v = _imm(text)
    return v & 0xFFFF if v is not None and -0x8000 <= v <= 0xFFFF else None


def candidates(disasm: str | None, selectors: Iterable[int]) -> list[tuple[int, int]]:
    """(selector, offset) far-pointer constants in a listing, in order."""
    sels = set(selectors)
    ins: list[tuple[int, str, str]] = []
    for line in (disasm or "").splitlines():
        m = _LINE.match(line.strip())
        if m:
            ins.append((int(m.group(1), 16), m.group(2).upper(), m.group(3).strip()))
    out: list[tuple[int, int]] = []
    for i, (cs, op, arg) in enumerate(ins):
        nxt = ins[i + 1] if i + 1 < len(ins) else None
        if op == "PUSH":
            v = _imm(arg)
            if v is not None and v > 0xFFFF:
                if v >> 16 in sels:
                    out.append((v >> 16, v & 0xFFFF))
                continue
            seg = {"DS": DGROUP, "CS": cs}.get(arg.upper(), v)
            off = _imm16(nxt[2]) if nxt and nxt[1] == "PUSH" else None
            if seg in sels and off is not None:
                out.append((seg, off))
        elif op == "MOV" and nxt and nxt[1] == "MOV":
            ma, mb = _mov_imm(arg), _mov_imm(nxt[2])
            if ma is None or mb is None or ma[0] == mb[0]:
                continue
            (_, a), (_, b) = ma, mb
            if a in sels and b not in sels:
                out.append((a, b))
            elif b in sels and a not in sels:
                out.append((b, a))
    return out


def _mov_imm(arg: str) -> tuple[str, int] | None:
    """(register, 16-bit immediate) of ``MOV reg, imm`` (general registers only)."""
    reg, _, src = arg.partition(",")
    reg = reg.strip().upper()
    v = _imm16(src)
    if v is None or not re.fullmatch(r"[A-D]X|SI|DI|BP", reg):
        return None
    return reg, v


def find(
    disasm: str | None, image: NeImage, skip: AbstractSet[str] = frozenset()
) -> list[StringRef]:
    """The string constants ``disasm`` references (each once, first use first).
    ``skip``: addresses known not to be strings (typed non-char globals)."""
    sels = {s for s, seg in image.segments.items() if seg.data}
    out: dict[tuple[int, int], StringRef] = {}
    for sel, off in candidates(disasm, sels):
        if (sel, off) in out or f"{sel:04x}:{off:04x}" in skip:
            continue
        s = image.c_string(sel, off)
        if s is not None:
            out[(sel, off)] = StringRef(sel, off, s)
    return list(out.values())


def non_string_globals(conn: sqlite3.Connection) -> set[str]:
    """Addresses of globals typed as something other than text (pointers, structs, numbers)."""
    structs = {r["name"] for r in conn.execute("SELECT name FROM structs")}
    out = set()
    for g in conn.execute("SELECT addr, type FROM globals WHERE type IS NOT NULL"):
        t = g["type"]
        base = re.sub(r"\[\d+\]", "", t).strip()
        if "*" in t or base in structs or base in ("short", "ushort", "int", "uint", "long"):
            out.add(g["addr"])
    return out


def render(
    funcs: Iterable[sqlite3.Row], image: NeImage | None, skip: AbstractSet[str] = frozenset()
) -> str:
    doc = [
        "# Strings referenced by this unit",
        "",
        "Exact bytes from assets/NOITE.EXE (escaped: `\\xNN` for non-ASCII, `\\\\`, `\\r`, "
        "`\\n`; the length excludes the NUL). Found from far-pointer pushes in the "
        "disassembly, so a string reached another way is missing.",
        "",
    ]
    if image is None:
        return "\n".join([*doc, "assets/NOITE.EXE not found; no strings extracted.", ""])
    any_ = False
    for f in funcs:
        refs = find(f["disasm"], image, skip)
        if refs:
            any_ = True
            doc += [f"## {f['addr']} {f['name']}", "", *(r.render() for r in refs), ""]
    if not any_:
        doc += ["No string constants found.", ""]
    return "\n".join(doc)


def load_image(root: Path) -> NeImage | None:
    exe = root / "assets" / "NOITE.EXE"
    return NeImage.load(exe) if exe.is_file() else None
