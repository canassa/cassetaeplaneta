"""The programs the tracker ports: NOITE.EXE (the main game) and its minigames.

Each program has its own Ghidra program, EXE, tracker DB, committed plan, Zig
source tree and unit index, so ``@orig`` addresses (which collide between
programs: every one of them has a ``1008:xxxx``) are only ever checked against
their own program. The active one comes from ``noite --program NAME`` or the
``NOITE_PROGRAM`` environment variable (a minigame worktree's ``.ref/env.sh``
sets it); the default is ``noite``.

What differs in the binary is here too: where the CRT and the import thunks
are, DGROUP, the pointer size of a vtable slot (far 4 bytes in NOITE, near 2
in the small-model minigames) and the shape of a virtual call.
"""

from __future__ import annotations

import os
import re
from dataclasses import dataclass, field


@dataclass(frozen=True)
class Program:
    name: str  # CLI name, lower case
    ghidra: str  # Ghidra program name
    exe: str  # the EXE, repo-relative
    db: str  # tracker DB, repo-relative
    plan: str  # committed plan, repo-relative
    src: str  # the program's Zig tree (units live under it)
    index: str  # the generated unit index
    design: str  # the design doc (its SceneObject slot table feeds `dep infer`)
    # The program's root as seen from `src/main.zig`'s module (`noite initdata`'s dump).
    zig_module: str = "noite"
    # Source directories under `src` that belong to another program.
    exclude: tuple[str, ...] = ()
    # Worktree / branch name prefix (`work/<prefix><unit>`, `port/<prefix><unit>`).
    prefix: str = ""
    api_segments: frozenset[str] = frozenset()
    # CRT: whole segments, or [lo, hi] address ranges (inclusive).
    crt_segments: frozenset[str] = frozenset()
    crt_ranges: tuple[tuple[str, str], ...] = ()
    dgroup: int = 0x1050
    # Data segments whose initial bytes `noite initdata` reads.
    data_segments: tuple[int, ...] = (0x1050,)
    slot_size: int = 4
    # Near vtable slots point into this code segment.
    code_segment: str = ""
    # Data type categories holding the program's own structs (not archives).
    type_categories: tuple[str, ...] = ("/",)
    # A virtual call in the listing: group 1 = the slot's byte offset (or none).
    vcall: re.Pattern[str] = field(
        default=re.compile(r"\bCALLF \[(?:BX|SI|DI)(?: \+ (0x[0-9a-fA-F]+|\d+))?\]")
    )
    dead_prefixes: tuple[str, ...] = ()
    dead_addrs: frozenset[str] = frozenset()
    platform_names: frozenset[str] = frozenset()
    platform_prefixes: tuple[str, ...] = ()
    # Type-test targets with no struct of their own (classes the program dropped).
    type_test_classes: frozenset[str] = frozenset()

    def in_crt(self, addr: str) -> bool:
        if addr[:4] in self.crt_segments:
            return True
        return any(lo <= addr <= hi for lo, hi in self.crt_ranges)

    def worktree_name(self, unit: str) -> str:
        return f"{self.prefix}{unit}"


NOITE = Program(
    name="noite",
    ghidra="NOITE.EXE",
    exe="assets/NOITE.EXE",
    db="db/port.sqlite",
    plan="db/plan.tsv",
    src="src",
    index="src/units.zig",
    design="docs/DESIGN.md",
    exclude=("src/encaixe",),
    api_segments=frozenset({"1108"}),
    crt_segments=frozenset({"1008"}),
    dgroup=0x1050,
    data_segments=(0x1030, 0x1038, 0x1040, 0x1048, 0x1050),
    # Classes that are never instantiated (no constructor stores their vtables):
    # Actor2D and the Player2D derived from it.
    dead_prefixes=("actor2d_", "player2d_"),
    # Unreferenced duplicate bodies left in the binary.
    dead_addrs=frozenset({"1010:468c", "1018:2608", "1018:2686"}),
    platform_names=frozenset({"WinMain", "?APPWNDPROC@@ZCJIIIJ@Z", "?APPABOUT@@ZCHIIIJ@Z"}),
    platform_prefixes=("app_",),
)

# ENCAIXE.EXE ("Encaixe Perfeito"), small model: one code segment 1008 holding
# the CRT (0012-1bdd) and everything else, DGROUP 1018, imports in 1030, near
# 2-byte vtable slots called as `CALL word ptr [BX+off]`.
ENCAIXE = Program(
    name="encaixe",
    ghidra="ENCAIXE.EXE",
    exe="assets/ENCAIXE/ENCAIXE.EXE",
    db="db/encaixe.sqlite",
    plan="db/encaixe-plan.tsv",
    src="src/encaixe",
    index="src/encaixe/units.zig",
    design="docs/encaixe/DESIGN.md",
    zig_module="noite.encaixe",
    prefix="encaixe-",
    api_segments=frozenset({"1030"}),
    crt_ranges=(("1008:0000", "1008:1bdd"),),
    dgroup=0x1018,
    data_segments=(0x1018,),
    slot_size=2,
    code_segment="1008",
    type_categories=("/", "/encaixe"),
    vcall=re.compile(r"\bCALL word ptr \[(?:BX|SI|DI)(?: \+ (0x[0-9a-fA-F]+|\d+))?\]"),
    # Dead classes and code are listed in the plan (status `dead`), not here.
    type_test_classes=frozenset({"player", "directional_player", "exit", "portable"}),
    platform_names=frozenset({"WinMain", "?APPWNDPROC@@ZCJIIIJ@Z", "?APPABOUT@@ZCHIIIJ@Z"}),
)

PROGRAMS = {p.name: p for p in (NOITE, ENCAIXE)}
ENV = "NOITE_PROGRAM"


def get(name: str) -> Program:
    try:
        return PROGRAMS[name.lower()]
    except KeyError:
        raise ValueError(f"unknown program {name!r} (one of {', '.join(PROGRAMS)})") from None


def current() -> Program:
    return get(os.environ.get(ENV) or "noite")


def select(name: str) -> Program:
    """Make ``name`` the active program for this process (and its children)."""
    p = get(name)
    os.environ[ENV] = p.name
    return p
