"""``noite import``: snapshot the Ghidra program into the tracker DB.

Re-runnable. Ghidra-derived columns are refreshed; tracking columns are kept,
except an auto status (``status_auto = 1``), which follows the new kind.
Functions that vanished from Ghidra are flagged ``gone`` rather than deleted, so
their tracking survives a rename-by-recreate.
"""

from __future__ import annotations

import json
import re
import sqlite3
from collections import Counter
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

from noite import plan, types, units
from noite.classify import class_names, classify, initial_status
from noite.db import Kind, now, tx
from noite.ghidra import FunctionInfo, Source
from noite.types import type_size


@dataclass(frozen=True)
class ImportResult:
    functions: int
    new: int
    gone: int
    callees: int
    structs: int
    globals: int
    vtables: int
    struct_refs: int
    global_refs: int
    handler_units: int
    kinds: Counter[str]
    plan: plan.ApplyResult | None = None


_UPSERT = """
INSERT INTO functions (addr, name, segment, size, signature, plate, decompile, disasm,
                       ghidra_class, kind, absorbed_by, gone, imported_at, status, status_auto)
VALUES (:addr, :name, :segment, :size, :signature, :plate, :decompile, :disasm,
        :ghidra_class, :kind, :absorbed_by, 0, :imported_at, :status, 1)
ON CONFLICT(addr) DO UPDATE SET
    name = excluded.name, segment = excluded.segment, size = excluded.size,
    signature = excluded.signature, plate = excluded.plate,
    decompile = COALESCE(excluded.decompile, functions.decompile),
    disasm = excluded.disasm, ghidra_class = excluded.ghidra_class,
    kind = excluded.kind,
    absorbed_by = CASE WHEN functions.status_auto = 1 THEN excluded.absorbed_by
                       ELSE COALESCE(excluded.absorbed_by, functions.absorbed_by) END,
    gone = 0,
    imported_at = excluded.imported_at,
    status = CASE WHEN functions.status_auto = 1 THEN excluded.status
                  ELSE functions.status END
"""


_JMPF = re.compile(r"\bJMPF 0x([0-9a-fA-F]{4}):([0-9a-fA-F]{4})\b")


def far_jumps(disasm: str | None) -> tuple[str, ...]:
    """``JMPF seg:off`` targets: a far adjustor thunk's (TIRO's) only way out,
    which Ghidra does not list as a callee."""
    return tuple(sorted({f"{a}:{b}".lower() for a, b in _JMPF.findall(disasm or "")}))


def run(
    conn: sqlite3.Connection,
    source: Source,
    *,
    decompile: bool = True,
    with_types: bool = True,
    progress: Callable[[int, int], None] | None = None,
    plan_file: Path | None = None,
) -> ImportResult:
    listed = source.list_functions()
    addrs = [f.addr for f in listed]

    details: dict[str, FunctionInfo] = {}
    step = 100
    for i in range(0, len(addrs), step):
        details.update(source.function_details(addrs[i : i + step], decompile=decompile))
        if progress:
            progress(min(i + step, len(addrs)), len(addrs))

    structs = source.structs() if with_types else []
    globs = source.globals() if with_types else []
    vtables = source.vtables() if with_types else []
    if structs:
        classes = class_names(s.name for s in structs)
    else:
        classes = class_names(
            r["name"] for r in conn.execute("SELECT name FROM structs").fetchall()
        )

    sizes = {s.name: s.size for s in structs}
    stamp = now()
    kinds: Counter[str] = Counter()
    n_callees = 0
    with tx(conn):
        known = {r["addr"] for r in conn.execute("SELECT addr FROM functions")}
        for f in listed:
            d = details.get(f.addr, f)
            kind, absorbed_by = classify(
                f.addr,
                d.name,
                ghidra_thunk=f.is_thunk,
                callees=d.callees or far_jumps(d.disasm),
                classes=classes,
            )
            kinds[kind.value] += 1
            conn.execute(
                _UPSERT,
                {
                    "addr": f.addr,
                    "name": d.name,
                    "segment": f.addr[:4],
                    "size": d.size,
                    "signature": d.signature,
                    "plate": d.plate,
                    "decompile": d.decompile,
                    "disasm": d.disasm,
                    "ghidra_class": d.ghidra_class,
                    "kind": kind.value,
                    "absorbed_by": absorbed_by,
                    "imported_at": stamp,
                    "status": initial_status(kind).value,
                },
            )
            conn.execute("DELETE FROM callees WHERE caller = ?", (f.addr,))
            conn.executemany(
                "INSERT OR IGNORE INTO callees (caller, callee) VALUES (?, ?)",
                [(f.addr, c) for c in d.callees],
            )
            n_callees += len(d.callees)
        seen = set(addrs)
        gone = known - seen
        conn.executemany("UPDATE functions SET gone = 1 WHERE addr = ?", [(a,) for a in gone])

        if with_types:
            conn.execute("DELETE FROM structs")
            conn.executemany(
                "INSERT INTO structs (name, size, fields) VALUES (?, ?, ?)",
                [(s.name, s.size, json.dumps(s.fields)) for s in structs],
            )
            conn.execute("DELETE FROM globals")
            conn.executemany(
                "INSERT OR REPLACE INTO globals (addr, name, type, size, xrefs) "
                "VALUES (?, ?, ?, ?, ?)",
                [(g.addr, g.name, g.type, type_size(g.type, sizes), g.xrefs) for g in globs],
            )
            conn.execute("DELETE FROM vtables")
            conn.executemany(
                "INSERT OR REPLACE INTO vtables (addr, name, type, size, slots) "
                "VALUES (?, ?, ?, ?, ?)",
                [(v.addr, v.name, v.type, v.size, json.dumps(list(v.slots))) for v in vtables],
            )
        n_srefs, n_grefs = types.compute_refs(conn)
        conn.execute("INSERT OR REPLACE INTO meta (key, value) VALUES ('imported_at', ?)", (stamp,))
        # A fresh DB (no units yet) gets the committed plan before handlers are seeded.
        planned = None
        if plan_file is not None and plan_file.exists():
            (n_units,) = conn.execute("SELECT COUNT(*) FROM units").fetchone()
            if n_units == 0:
                planned = plan.apply(conn, plan_file.read_text())
        seeded = units.seed_handlers(conn)

    return ImportResult(
        functions=len(listed),
        new=len(seen - known),
        gone=len(gone),
        callees=n_callees,
        structs=len(structs),
        globals=len(globs),
        vtables=len(vtables),
        struct_refs=n_srefs,
        global_refs=n_grefs,
        handler_units=seeded,
        plan=planned,
        kinds=kinds,
    )


__all__ = ["ImportResult", "Kind", "run"]
