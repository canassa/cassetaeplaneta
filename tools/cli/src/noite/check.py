"""``noite check``: hold the ``@orig`` tags and the tracker DB to each other.

Errors: a tag naming an unknown address; two code tags for one address (a
function ported twice); a function marked ported with no code tag; a test tag
with an unknown oracle. Warnings: a tag whose name differs from Ghidra's; a tag
for a function owned by a different unit than the file's; a tag on a
crt/api/dead function; a unit file that nothing imports (its tests never run).

``unit`` (``check -w UNIT``): the tree is that unit's worktree, which may have
branched before other units were finished on main. Their ported functions have
no tags here; they are summarised as one "behind main" warning instead of an
error each (``noite finish`` rebases before it checks).

``fix_status`` brings the DB in line with the tags: tagged pending/failed
functions become ported, ported functions that lost their tag go back to
pending, and every function's ``tested`` becomes its strongest test oracle.
"""

from __future__ import annotations

import contextlib
import re
import sqlite3
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path

from noite import tags as tagmod
from noite.db import ORACLE_RANK, Oracle, Status, tx
from noite.tags import Tag


@dataclass
class Report:
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    code_tags: dict[str, list[Tag]] = field(default_factory=dict)
    tested: dict[str, Oracle] = field(default_factory=dict)

    @property
    def ok(self) -> bool:
        return not self.errors


def _loc(t: Tag) -> str:
    return f"{t.path}:{t.line}"


def run(
    conn: sqlite3.Connection,
    root: Path,
    scanned: list[Tag] | None = None,
    unit: str | None = None,
) -> Report:
    found = tagmod.scan(root) if scanned is None else scanned
    rep = Report()
    funcs = {r["addr"]: r for r in conn.execute("SELECT * FROM functions")}
    unit_of_path = {r["path"]: r["name"] for r in conn.execute("SELECT name, path FROM units")}

    code: dict[str, list[Tag]] = defaultdict(list)
    for t in found:
        f = funcs.get(t.addr)
        if f is None or f["gone"]:
            rep.errors.append(f"{_loc(t)}: @orig {t.addr}: no such function in Ghidra")
            continue
        if t.name and t.name != f["name"]:
            rep.warnings.append(f"{_loc(t)}: @orig {t.addr} says {t.name}, Ghidra: {f['name']}")
        if t.is_test:
            if t.bad_oracle:
                rep.errors.append(
                    f"{_loc(t)}: unknown oracle={t.bad_oracle} "
                    f"(use {', '.join(o.value for o in Oracle if o is not Oracle.NONE)})"
                )
            o = t.oracle or Oracle.NONE
            cur = rep.tested.get(t.addr)
            if cur is None or ORACLE_RANK[o] < ORACLE_RANK[cur]:
                rep.tested[t.addr] = o
            continue
        code[t.addr].append(t)
        if f["kind"] in ("crt", "api") or f["status"] == Status.DEAD:
            rep.warnings.append(f"{_loc(t)}: {t.addr} {f['name']} is {f['kind']}/{f['status']}")
        owner = unit_of_path.get(t.path)
        if owner and f["unit"] and f["unit"] != owner:
            rep.warnings.append(
                f"{_loc(t)}: {t.addr} {f['name']} belongs to unit {f['unit']}, not {owner}"
            )

    for addr, ts in code.items():
        if len(ts) > 1:
            where = ", ".join(_loc(t) for t in ts)
            rep.errors.append(f"{addr} {funcs[addr]['name']} is ported more than once: {where}")
    behind: dict[str, int] = defaultdict(int)
    for addr, f in funcs.items():
        if f["status"] == Status.PORTED and addr not in code and not f["gone"]:
            if unit is not None and f["unit"] != unit:
                behind[f["unit"] or "(no unit)"] += 1
                continue
            rep.errors.append(f"{addr} {f['name']} is marked ported but has no @orig tag")
    if behind:
        rep.warnings.append(
            f"worktree is behind main: {sum(behind.values())} functions ported on main have no "
            f"tag here (units {', '.join(sorted(behind))}); `noite finish` rebases first"
        )

    rep.warnings += unreachable_units(conn, root)
    rep.code_tags = dict(code)
    return rep


def imported_paths(root: Path) -> set[str]:
    """Repo-relative paths of every .zig file some other .zig file @imports."""
    out: set[str] = set()
    pat = re.compile(r'@import\("([^"]+\.zig)"\)')
    for p in tagmod.zig_files(root):
        for m in pat.finditer(p.read_text(errors="replace")):
            target = (p.parent / m.group(1)).resolve()
            with contextlib.suppress(ValueError):
                out.add(target.relative_to(root.resolve()).as_posix())
    return out


def unreachable_units(conn: sqlite3.Connection, root: Path) -> list[str]:
    reach = imported_paths(root)
    return [
        f"unit {r['name']}: {r['path']} is not imported anywhere (run `noite unit sync`)"
        for r in conn.execute("SELECT name, path FROM units ORDER BY name")
        if (root / r["path"]).exists() and r["path"] not in reach
    ]


@dataclass(frozen=True)
class Fixed:
    ported: list[str]
    unported: list[str]
    tested: int


def fix_status(conn: sqlite3.Connection, rep: Report) -> Fixed:
    ported, unported = [], []
    with tx(conn):
        for r in conn.execute("SELECT addr, status, gone FROM functions").fetchall():
            addr, st = r["addr"], r["status"]
            if addr in rep.code_tags and st in (Status.PENDING, Status.FAILED):
                ported.append(addr)
            elif addr not in rep.code_tags and st == Status.PORTED and not r["gone"]:
                unported.append(addr)
        conn.executemany(
            "UPDATE functions SET status = 'ported', status_auto = 0, agent_id = NULL "
            "WHERE addr = ?",
            [(a,) for a in ported],
        )
        conn.executemany(
            "UPDATE functions SET status = 'pending', status_auto = 0 WHERE addr = ?",
            [(a,) for a in unported],
        )
        n = apply_tested(conn, rep)
    return Fixed(ported, unported, n)


def apply_tested(conn: sqlite3.Connection, rep: Report, only: set[str] | None = None) -> int:
    """Set ``tested`` from the report's test tags (``none`` where there are none)."""
    n = 0
    for r in conn.execute("SELECT addr, tested FROM functions").fetchall():
        if only is not None and r["addr"] not in only:
            continue
        want = rep.tested.get(r["addr"], Oracle.NONE).value
        if r["tested"] != want:
            conn.execute("UPDATE functions SET tested = ? WHERE addr = ?", (want, r["addr"]))
            n += 1
    return n
