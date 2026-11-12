from __future__ import annotations

import json
import sqlite3
from pathlib import Path

import pytest

from noite import claim, deps, units
from noite.db import UnitKind, tx

DESIGN = """\
### SceneObject slots (kinds)

| slot | behaviour | unit | default |
|---|---|---|---|
| 1B | draw | render | so_draw |
| 25 | hide | visibility | so_hide |
| 43 | isFoo | dead | x |

### Other vtables

| vtable | slots |
|---|---|
"""

DECOMPILE = """
void f(Obj *this)
{
  SceneObjectVtbl *pVtbl;
  Object3DVtbl_findSupportFn **pp;
  pVtbl = this->vtbl;
  (*pVtbl->draw)();
  pp = &((Object3DVtbl *)this->vtbl)->findSupport;
}
"""


def vtbl(conn: sqlite3.Connection, name: str, slots: list[str]) -> None:
    fields = [{"offset": i * 4, "size": 4, "type": "x", "name": n} for i, n in enumerate(slots)]
    conn.execute(
        "INSERT INTO structs (name, size, fields) VALUES (?, ?, ?)",
        (name, len(slots) * 4, json.dumps(fields)),
    )


def func(
    conn: sqlite3.Connection, addr: str, name: str, unit: str | None, text: str, disasm: str = ""
) -> None:
    conn.execute(
        "INSERT INTO functions (addr, name, segment, kind, unit, decompile, disasm) "
        "VALUES (?, ?, ?, 'method', ?, ?, ?)",
        (addr, name, addr[:4], unit, text, disasm),
    )


@pytest.fixture
def db(conn: sqlite3.Connection, tmp_path: Path) -> tuple[sqlite3.Connection, Path]:
    design = tmp_path / "DESIGN.md"
    design.write_text(DESIGN)
    with tx(conn):
        for n in ("render", "visibility", "space3d", "other"):
            units.create(conn, n, UnitKind.MODULE)
        vtbl(conn, "SceneObjectVtbl", ["a"] * 0x1B + ["draw"] + ["b"] * 9 + ["hide"])
        vtbl(conn, "Object3DVtbl", ["slot00", "findSupport"])
        func(conn, "1010:0001", "f", "other", DECOMPILE)
        func(conn, "1010:0002", "g", "render", DECOMPILE)
        func(conn, "1010:0003", "h", "visibility", "", "1010:0003  CALLF [BX + 0x6c]")
        func(conn, "1010:0004", "i", "other", "", "1010:0004  CALLF [BX + 0x94]\nCALLF [BX + 0x2]")
    return conn, design


def test_parse_table() -> None:
    assert deps.parse_scene_object_table(DESIGN) == {
        0x1B: "render",
        0x25: "visibility",
        0x43: "dead",
    }


def test_slots_called_by_decompile_and_asm(db: tuple[sqlite3.Connection, Path]) -> None:
    conn, _ = db
    lay = deps.vtable_layouts(conn)
    use = deps.slots_called(DECOMPILE, "CALLF [BX + 0x6c]", lay)
    assert use.pairs == {("SceneObjectVtbl", 0x1B), ("Object3DVtbl", 1)}
    assert not use.loose_offsets
    use = deps.slots_called("", "CALLF [BX + 0x30]\nCALLF [BX + 0x2]\nCALLF [0x10]", lay)
    assert use.loose_offsets == {0x30}


def test_infer_rerun_keeps_manual(db: tuple[sqlite3.Connection, Path]) -> None:
    conn, design = db
    with tx(conn):
        deps.add(conn, "visibility", "other", "by hand")
        r = deps.infer(conn, design)
    rows = {
        (d["unit"], d["depends_on"]): d["source"] for d in conn.execute("SELECT * FROM unit_deps")
    }
    # f (other) calls draw -> render; g (render) is a self dep; h guesses slot 0x1B; i guesses 0x25.
    assert rows[("other", "render")] == "auto"
    assert rows[("other", "visibility")] == "auto"
    assert rows[("visibility", "render")] == "auto"
    assert rows[("visibility", "other")] == "manual"
    assert ("render", "render") not in rows
    assert r.guessed == 2
    assert list(r.unresolved) == []
    with tx(conn):
        conn.execute("UPDATE functions SET unit = 'space3d' WHERE addr = '1010:0001'")
        deps.infer(conn, design)
    rows2 = {
        (d["unit"], d["depends_on"]): d["source"] for d in conn.execute("SELECT * FROM unit_deps")
    }
    assert ("space3d", "render") in rows2
    assert rows2[("visibility", "other")] == "manual"


def test_deps_block_readiness_and_cycles(db: tuple[sqlite3.Connection, Path]) -> None:
    conn, _ = db
    with tx(conn):
        deps.add(conn, "other", "render")
        deps.add(conn, "render", "other")
    states = {s.name: s for s in claim.unit_states(conn)}
    assert states["other"].dep_blockers == ["render"]
    assert not states["other"].ready
    assert deps.cycles(conn) == [["other", "render"]]
    with tx(conn):
        assert deps.remove(conn, "render", "other")
        conn.execute("UPDATE units SET status = 'done' WHERE name = 'render'")
    states = {s.name: s for s in claim.unit_states(conn)}
    assert states["other"].dep_blockers == []
    assert deps.cycles(conn) == []


def test_add_validates(db: tuple[sqlite3.Connection, Path]) -> None:
    conn, _ = db
    with pytest.raises(deps.DepError):
        deps.add(conn, "other", "other")
    with pytest.raises(deps.DepError):
        deps.add(conn, "other", "nope")
