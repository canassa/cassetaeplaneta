"""Unit-level dependencies: what the callee graph cannot see.

``callees`` only holds direct calls. A virtual call (``CALLF [BX+off]``, slot =
off / 4) reaches whichever unit owns that vtable slot. ``unit_deps`` records
those edges (``auto``: derived by :func:`infer`; ``manual``: set by a person and
kept across re-inference).

``auto`` deps are *soft*: they are shown (``next --blocked``, ``unit show``,
``unit dep show``) but never block a claim. Every virtual slot's dispatcher is
declared in the skeleton (a panicking stub until its owner is ported), so a
caller compiles and its own tests run before the slot's owner exists. ``manual``
deps and direct calls into unported functions are *hard*: they block, and only
they can form a cycle that stops units from ever becoming ready (:func:`cycles`).

Slot ownership comes from the "SceneObject slots" table in ``docs/DESIGN.md``
(parsed at run time) and :data:`OTHER_VTABLES` below, which transcribes the
design's "Other vtables" table. Vtable layouts come from the ``structs`` table.
"""

from __future__ import annotations

import json
import re
import sqlite3
import sys
from collections import defaultdict
from collections.abc import Callable, Mapping
from dataclasses import dataclass, field
from pathlib import Path

from noite import program
from noite.db import DONE, Status, UnitStatus


class DepError(RuntimeError):
    pass


# --------------------------------------------------------------------------- #
# slot ownership
# --------------------------------------------------------------------------- #

SCENE_OBJECT = "SceneObjectVtbl"
# A raw `CALLF [BX+off]` the decompiler could not type is taken as a SceneObject slot
# when off is at least this (the small offsets also fit Condition, Mover, Animation, ...).
GUESS_MIN_OFFSET = 0x10
# Slots with no owning unit by design (Object.is/as type tests).
TYPE_TEST_SLOTS = set(range(0x43, 0x58)) | {0x5D, 0x5E}

_AVI_SLOTS = {i: "avi" for i in range(7)} | {7: "animation"}


def _flat(unit: str, n: int) -> dict[int, str]:
    return dict.fromkeys(range(n), unit)


# vtable -> {slot index: unit}, from DESIGN.md "Other vtables".
OTHER_VTABLES: dict[str, dict[int, str]] = {
    "Object3DVtbl": _flat("space3d", 8),
    "AnimationVtbl": _AVI_SLOTS,
    "MoverVtbl": {0: "movement"},
    "DirectionalPlayerVtbl": {0: "movement", 1: "animation"},
    # 17 slots; the design's "08-10" is hex: slots 8..0x10 are plain panel functions.
    "ControlPanelVtbl": _AVI_SLOTS | dict.fromkeys(range(8, 17), "panels"),
    # Flattened to the one backdrop unit (grid queries are not split out).
    "BackdropVtbl": _flat("backdrop", 32),
    "GridBackdropVtbl": _flat("backdrop", 32),
    "PerspectiveBackdropVtbl": _flat("backdrop", 32),
    "SceneVtbl": _flat("scene", 16) | {7: "scene_loader"},
    "GameVtbl": (
        {0: "game_input", 1: "game_hook"}
        | dict.fromkeys(range(2, 7), "game")
        | {7: "game_scenes", 8: "game"}
        | {9: "save", 10: "save", 11: "save", 12: "game_scenes", 13: "game_scenes"}
    ),
    "ConditionVtbl": _flat("condition", 3),
}

# The same for ENCAIXE (docs/encaixe/DESIGN.md "Other vtables").
ENCAIXE_OTHER_VTABLES: dict[str, dict[int, str]] = {
    "Object3DVtbl": _flat("space3d", 8),
    "AnimationVtbl": {0: "animation"},
    "MoverVtbl": {0: "movement"},
    "PieceVtbl": {0: "movement", 1: "piece", 2: "piece"},
    "ControlPanelVtbl": {0: "animation"} | dict.fromkeys(range(1, 9), "panels"),
    "GameVtbl": {0: "game_input"} | dict.fromkeys(range(1, 7), "game"),
    "SceneVtbl": _flat("scene", 13) | {0: "tetris", 5: "tetris", 7: "tetris"},
    "BackdropVtbl": _flat("backdrop", 19),
    "GridBackdropVtbl": _flat("backdrop", 20),
    "ConditionVtbl": _flat("game", 3),
    "FrameVtbl": {0: "object_create"},
}
# ENCAIXE's SceneObject type-test slots (3C-4D, 54/55; docs/encaixe/DATA.md).
ENCAIXE_TYPE_TEST_SLOTS = set(range(0x3C, 0x4E)) | {0x54, 0x55}


def other_vtables() -> dict[str, dict[int, str]]:
    return ENCAIXE_OTHER_VTABLES if program.current().name == "encaixe" else OTHER_VTABLES


def type_test_slots() -> set[int]:
    return ENCAIXE_TYPE_TEST_SLOTS if program.current().name == "encaixe" else TYPE_TEST_SLOTS


_SLOT_ROW = re.compile(r"^\|\s*([0-9A-Fa-f]{2})\s*\|\s*(\w+)\s*\|\s*(\w+)\s*\|")


def parse_scene_object_table(text: str) -> dict[int, str]:
    """slot index -> unit, from the DESIGN.md SceneObject slot table."""
    out: dict[int, str] = {}
    start = text.find("### SceneObject slots")
    if start < 0:
        raise DepError("docs/DESIGN.md has no '### SceneObject slots' section")
    for line in text[start:].splitlines()[1:]:
        if line.startswith("## ") or line.startswith("### Other vtables"):
            break
        m = _SLOT_ROW.match(line)
        if m:
            out[int(m.group(1), 16)] = m.group(3)
    if not out:
        raise DepError("no slot rows found in the SceneObject slot table")
    return out


def slot_owners(design: Path) -> dict[str, dict[int, str]]:
    owners = {k: dict(v) for k, v in other_vtables().items()}
    owners[SCENE_OBJECT] = parse_scene_object_table(design.read_text())
    return owners


def vtable_layouts(conn: sqlite3.Connection) -> dict[str, dict[str, int]]:
    """vtable name -> {slot field name: slot index}."""
    out: dict[str, dict[str, int]] = {}
    for r in conn.execute("SELECT name, fields FROM structs WHERE name LIKE '%Vtbl'"):
        fields = json.loads(r["fields"] or "[]")
        size = program.current().slot_size
        out[r["name"]] = {f["name"]: f["offset"] // size for f in fields}
    return out


# --------------------------------------------------------------------------- #
# finding the slots a function calls
# --------------------------------------------------------------------------- #

_VTBL_WORD = re.compile(r"\b(\w+Vtbl)\b")
_SLOT_TYPE = re.compile(r"\b(\w+Vtbl)_(\w+)Fn\b")
_VAR_DECL = re.compile(r"\b(\w+Vtbl) \*+(\w+)")
_CAST = re.compile(r"\((\w+Vtbl) \*\)[^;]*?\)->(\w+)")


@dataclass
class SlotUse:
    pairs: set[tuple[str, int]] = field(default_factory=set)
    # asm virtual-call offsets no vtable could be assigned to
    loose_offsets: set[int] = field(default_factory=set)


def slots_called(
    decompile: str | None, disasm: str | None, layouts: dict[str, dict[str, int]]
) -> SlotUse:
    use = SlotUse()
    text = decompile or ""

    def add(vtbl: str, slot: str) -> None:
        idx = layouts.get(vtbl, {}).get(slot)
        if idx is not None:
            use.pairs.add((vtbl, idx))

    for m in _SLOT_TYPE.finditer(text):
        add(m.group(1), m.group(2))
    for m in _CAST.finditer(text):
        add(m.group(1), m.group(2))
    for vt, var in set(_VAR_DECL.findall(text)):
        for m in re.finditer(rf"\b{re.escape(var)}->(\w+)", text):
            add(vt, m.group(1))
    # Asm calls the decompiler left as raw offsets: use the one vtable the
    # function mentions, if there is exactly one.
    mentioned = {v for v in _VTBL_WORD.findall(text) if v in layouts}
    prog = program.current()
    size = prog.slot_size
    covered = {i * size for _, i in use.pairs}
    for m in prog.vcall.finditer(disasm or ""):
        off = int(m.group(1), 0) if m.group(1) else 0
        if off % size or off in covered:
            continue
        if len(mentioned) == 1:
            (vt,) = mentioned
            if off // size < len(layouts[vt]):
                use.pairs.add((vt, off // size))
                continue
        use.loose_offsets.add(off)
    return use


# --------------------------------------------------------------------------- #
# inference
# --------------------------------------------------------------------------- #


@dataclass
class InferResult:
    deps: int = 0
    kept_manual: int = 0
    functions: int = 0
    skipped_no_unit: int = 0
    # "Vtbl.slot" -> reason, for slots that name no unit
    unmapped: dict[str, str] = field(default_factory=dict)
    # functions with virtual calls whose vtable is unknown: addr -> offsets
    unresolved: dict[str, list[int]] = field(default_factory=dict)
    guessed: int = 0  # raw offsets >= GUESS_MIN_OFFSET taken as SceneObject slots


def infer(conn: sqlite3.Connection, design: Path) -> InferResult:
    """Replace every ``auto`` dep with the ones derived from the slots called.
    Runs inside the caller's transaction."""
    owners = slot_owners(design)
    layouts = vtable_layouts(conn)
    names = {v: {i: n for n, i in f.items()} for v, f in layouts.items()}
    units_ = {r["name"] for r in conn.execute("SELECT name FROM units")}
    res = InferResult()
    size = program.current().slot_size
    # (unit, owner) -> examples
    found: dict[tuple[str, str], list[str]] = defaultdict(list)
    skip = (Status.ABSORBED, Status.REPLACED, Status.DEAD)
    for f in conn.execute(
        "SELECT addr, name, unit, status, decompile, disasm FROM functions WHERE gone = 0"
    ).fetchall():
        if f["status"] in skip:
            continue
        use = slots_called(f["decompile"], f["disasm"], layouts)
        if not use.pairs and not use.loose_offsets:
            continue
        res.functions += 1
        pairs = set(use.pairs)
        loose = []
        for off in sorted(use.loose_offsets):
            if off >= GUESS_MIN_OFFSET and off // size in layouts.get(SCENE_OBJECT, {}).values():
                pairs.add((SCENE_OBJECT, off // size))
                res.guessed += 1
            else:
                loose.append(off)
        if loose:
            res.unresolved[f["addr"]] = loose
        for vt, idx in sorted(pairs):
            label = f"{vt.removesuffix('Vtbl')}.{names[vt].get(idx, f'slot{idx:02x}')}"
            owner = owners.get(vt, {}).get(idx)
            if owner is None:
                reason = (
                    "type test (Object.is/as)"
                    if vt == SCENE_OBJECT and idx in type_test_slots()
                    else "no owner in the design"
                )
                res.unmapped.setdefault(label, reason)
                continue
            if owner not in units_:
                res.unmapped.setdefault(label, f"owner {owner!r} is not a unit")
                continue
            if f["unit"] is None:
                res.skipped_no_unit += 1
                continue
            if owner == f["unit"]:
                continue
            ex = found[(f["unit"], owner)]
            tag = f"{f['name']} -> {label}"
            if len(ex) < 3 and tag not in ex:
                ex.append(tag)
    conn.execute("DELETE FROM unit_deps WHERE source = 'auto'")
    manual = {(r[0], r[1]) for r in conn.execute("SELECT unit, depends_on FROM unit_deps")}
    for (unit, owner), ex in sorted(found.items()):
        if (unit, owner) in manual:
            res.kept_manual += 1
            continue
        conn.execute(
            "INSERT INTO unit_deps (unit, depends_on, source, note) VALUES (?, ?, 'auto', ?)",
            (unit, owner, "; ".join(ex)),
        )
        res.deps += 1
    return res


# --------------------------------------------------------------------------- #
# manual edits and queries
# --------------------------------------------------------------------------- #


def _check_unit(conn: sqlite3.Connection, name: str) -> None:
    if conn.execute("SELECT 1 FROM units WHERE name = ?", (name,)).fetchone() is None:
        raise DepError(f"no unit named {name!r} (see `noite unit list`)")


def add(conn: sqlite3.Connection, unit: str, on: str, note: str | None = None) -> None:
    _check_unit(conn, unit)
    _check_unit(conn, on)
    if unit == on:
        raise DepError("a unit cannot depend on itself")
    conn.execute(
        "INSERT INTO unit_deps (unit, depends_on, source, note) VALUES (?, ?, 'manual', ?) "
        "ON CONFLICT (unit, depends_on) DO UPDATE SET source = 'manual', note = excluded.note",
        (unit, on, note),
    )


def remove(conn: sqlite3.Connection, unit: str, on: str) -> bool:
    """Drop a dep of either source. An ``auto`` one returns on the next ``infer``
    (the fix for those is a merge or a different unit assignment)."""
    cur = conn.execute("DELETE FROM unit_deps WHERE unit = ? AND depends_on = ?", (unit, on))
    return cur.rowcount > 0


def deps_of(conn: sqlite3.Connection, unit: str) -> list[sqlite3.Row]:
    return conn.execute(
        "SELECT * FROM unit_deps WHERE unit = ? ORDER BY depends_on", (unit,)
    ).fetchall()


def dependents_of(conn: sqlite3.Connection, unit: str) -> list[sqlite3.Row]:
    return conn.execute(
        "SELECT * FROM unit_deps WHERE depends_on = ? ORDER BY unit", (unit,)
    ).fetchall()


def done_units(conn: sqlite3.Connection) -> set[str]:
    """Units whose dependents are no longer blocked by them: marked done, or
    with every function in a finished state."""
    done = set()
    for r in conn.execute(
        "SELECT u.name, u.status, COUNT(f.addr) AS total, "
        "SUM(f.status IN ('pending','failed','in_progress')) AS todo "
        "FROM units u LEFT JOIN functions f ON f.unit = u.name GROUP BY u.name"
    ):
        if r["status"] == UnitStatus.DONE or (r["total"] > 0 and not r["todo"]):
            done.add(r["name"])
    return done


def dep_blockers(
    conn: sqlite3.Connection,
    unit: str,
    done: set[str] | None = None,
    *,
    source: str = "manual",
) -> list[str]:
    """Units ``unit`` depends on (``source``: ``manual`` = hard, ``auto`` = soft) that
    are not done."""
    done = done_units(conn) if done is None else done
    return [
        r["depends_on"]
        for r in deps_of(conn, unit)
        if r["source"] == source and r["depends_on"] not in done
    ]


def resolve_thunk(funcs: Mapping[str, sqlite3.Row], addr: str) -> str:
    """Follow absorbed thunks to the function that does the work."""
    seen = set()
    while addr in funcs and addr not in seen:
        seen.add(addr)
        f = funcs[addr]
        if f["status"] == Status.ABSORBED and f["absorbed_by"]:
            addr = f["absorbed_by"]
        else:
            break
    return addr


# --------------------------------------------------------------------------- #
# the blocking graph and its cycles
# --------------------------------------------------------------------------- #


@dataclass
class Edge:
    unit: str
    on: str
    source: str  # 'call', 'manual' or 'auto'
    note: str = ""

    @property
    def hard(self) -> bool:
        return self.source != "auto"


def call_edges(conn: sqlite3.Connection, examples: int = 3) -> list[Edge]:
    """Unit edges from direct calls that still block: caller's unit -> callee's unit
    (absorbed thunks followed), different units, callee not done."""
    funcs = {r["addr"]: r for r in conn.execute("SELECT * FROM functions")}
    found: dict[tuple[str, str], list[str]] = defaultdict(list)
    for c in conn.execute("SELECT caller, callee FROM callees ORDER BY caller, callee"):
        f = funcs.get(c["caller"])
        g = funcs.get(resolve_thunk(funcs, c["callee"]))
        if f is None or g is None or not f["unit"] or not g["unit"] or f["unit"] == g["unit"]:
            continue
        if g["status"] in DONE:
            continue
        ex = found[(f["unit"], g["unit"])]
        tag = f"{f['name']} -> {g['name']}"
        if len(ex) < examples and tag not in ex:
            ex.append(tag)
    return [Edge(u, on, "call", "; ".join(ex)) for (u, on), ex in sorted(found.items())]


def graph_edges(conn: sqlite3.Connection, *, include_auto: bool = False) -> list[Edge]:
    """Every unit edge that still blocks (direct calls + manual deps on units not
    done), plus the soft ``auto`` ones with ``include_auto``."""
    edges = call_edges(conn)
    done = done_units(conn)
    for r in conn.execute("SELECT * FROM unit_deps ORDER BY unit, depends_on"):
        if r["depends_on"] in done:
            continue
        if r["source"] == "manual" or include_auto:
            edges.append(Edge(r["unit"], r["depends_on"], r["source"], r["note"] or ""))
    return edges


def find_cycles(edges: list[tuple[str, str]]) -> list[list[str]]:
    """Strongly connected components with more than one unit (Tarjan)."""
    graph: dict[str, list[str]] = defaultdict(list)
    for a, b in edges:
        graph[a].append(b)
        graph.setdefault(b, [])
    index: dict[str, int] = {}
    low: dict[str, int] = {}
    stack: list[str] = []
    on: set[str] = set()
    out: list[list[str]] = []
    counter = [0]

    def visit(v: str) -> None:
        index[v] = low[v] = counter[0]
        counter[0] += 1
        stack.append(v)
        on.add(v)
        for w in graph[v]:
            if w not in index:
                visit(w)
                low[v] = min(low[v], low[w])
            elif w in on:
                low[v] = min(low[v], index[w])
        if low[v] == index[v]:
            comp = []
            while True:
                w = stack.pop()
                on.discard(w)
                comp.append(w)
                if w == v:
                    break
            if len(comp) > 1:
                out.append(sorted(comp))

    sys.setrecursionlimit(max(sys.getrecursionlimit(), 10000))
    for v in sorted(graph):
        if v not in index:
            visit(v)
    return sorted(out)


@dataclass
class Cycle:
    units: list[str]
    edges: list[Edge]  # the edges between its units


def cycles(conn: sqlite3.Connection, *, include_auto: bool = False) -> list[Cycle]:
    """Groups of units that (transitively) block each other. By default only hard
    edges count: soft ``auto`` deps never block, so they cannot deadlock."""
    edges = graph_edges(conn, include_auto=include_auto)
    out = []
    for comp in find_cycles([(e.unit, e.on) for e in edges]):
        members = set(comp)
        inner = [e for e in edges if e.unit in members and e.on in members]
        out.append(Cycle(comp, sorted(inner, key=lambda e: (e.unit, e.on, e.source))))
    return out


def cycle_members(conn: sqlite3.Connection) -> Callable[[str], list[str] | None]:
    comps = [c.units for c in cycles(conn)]

    def lookup(unit: str) -> list[str] | None:
        for c in comps:
            if unit in c:
                return c
        return None

    return lookup
