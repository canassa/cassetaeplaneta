from __future__ import annotations

import json
import sqlite3
from pathlib import Path

import pytest
from typer.testing import CliRunner

from conftest import FakeSource, default_funcs, fn
from noite import ghidra, importer
from noite.cli import app
from noite.db import connect


def row(conn: sqlite3.Connection, addr: str) -> sqlite3.Row:
    r: sqlite3.Row = conn.execute("SELECT * FROM functions WHERE addr = ?", (addr,)).fetchone()
    return r


def test_import_classifies_and_seeds(conn: sqlite3.Connection, source: FakeSource) -> None:
    res = importer.run(conn, source)
    assert res.functions == 10 and res.new == 10 and res.handler_units == 1
    st = {r["addr"]: (r["kind"], r["status"]) for r in conn.execute("SELECT * FROM functions")}
    assert st["1008:001a"] == ("crt", "replaced")
    assert st["1108:0000"] == ("api", "replaced")
    assert st["1010:0400"] == ("thunk", "absorbed")
    assert st["1010:0500"] == ("default", "absorbed")
    assert st["1010:0600"] == ("type_test", "absorbed")
    assert st["1010:0700"] == ("dead", "dead")
    assert st["1010:0300"] == ("method", "pending")
    assert row(conn, "1010:0400")["absorbed_by"] == "1010:0100"
    u = conn.execute("SELECT * FROM units").fetchone()
    assert (u["name"], u["path"], u["kind"]) == (
        "handler_2fpontoc",
        "src/handlers/2fpontoc.zig",
        "handler",
    )
    assert row(conn, "1020:0000")["unit"] == "handler_2fpontoc"
    callees = conn.execute("SELECT callee FROM callees WHERE caller = '1010:0300'").fetchall()
    assert sorted(c[0] for c in callees) == ["1010:0100", "1010:0400"]
    assert conn.execute("SELECT count(*) FROM structs").fetchone()[0] == 3
    assert conn.execute("SELECT name FROM globals").fetchone()[0] == "g_lives"
    assert res.vtables == 2
    vt = conn.execute("SELECT * FROM vtables WHERE name = 'g_statusBarVtbl'").fetchone()
    assert (vt["addr"], vt["type"], vt["size"]) == ("1018:5f7e", "SceneObjectVtbl", 12)
    assert json.loads(vt["slots"]) == ["1010:0100", "1010:0400", "0000:0000"]


def test_vtable_detection_and_far_pointers() -> None:
    assert ghidra.is_vtable("g_statusBarVtbl", "SceneObjectVtbl", "1018:5f7e")
    assert ghidra.is_vtable("DAT_1010:a7b6", "VFunc *32[16]", "1010:a7b6")
    assert ghidra.is_vtable("x", "GameVtbl", "1018:c5bc")
    assert not ghidra.is_vtable("g_crtFloatHooks", "VFunc *32[7]", "1050:0f00")
    assert not ghidra.is_vtable("g_lives", "short", "1050:002a")
    data = [0x00, 0x00, 0x18, 0x10, 0xE8, 0x46, 0x10, 0x10]
    assert ghidra.far_pointers(data) == ("1018:0000", "1010:46e8")


def test_show_vtable(conn: sqlite3.Connection, source: FakeSource, tmp_path: Path) -> None:
    db = tmp_path / "show.sqlite"
    c = connect(db)
    importer.run(c, source)
    mp = pytest.MonkeyPatch()
    mp.setenv("NOITE_DB", str(db))
    try:
        out = CliRunner().invoke(app, ["show", "g_statusBarVtbl"]).output
        by_addr = CliRunner().invoke(app, ["show", "1018:1d9c"]).output
    finally:
        mp.undo()
    assert "1018:5f7e  g_statusBarVtbl  (SceneObjectVtbl, 12 bytes, 3 slots)" in out
    lines = out.splitlines()
    assert any(ln.split()[:4] == ["00", "destroy", "1010:0100", "leaf_a"] for ln in lines)
    # slot 1 is an absorbed thunk: shown with the function it forwards to.
    assert any("leaf_a_thunk_8 -> 1010:0100 leaf_a [pending]" in ln for ln in lines)
    assert any(ln.split()[:3] == ["02", "0000:0000", "-"] for ln in lines)
    assert "g_gameVtbl" in by_addr and "mid [pending]" in by_addr


def test_reimport_keeps_tracking(conn: sqlite3.Connection, source: FakeSource) -> None:
    importer.run(conn, source)
    conn.execute("INSERT INTO units (name, path, kind) VALUES ('core', 'src/core.zig', 'module')")
    conn.execute(
        "UPDATE functions SET status = 'ported', status_auto = 0, unit = 'core', notes = 'n', "
        "tested = 'asset' WHERE addr = '1010:0100'"
    )
    funcs = default_funcs()
    # leaf_a renamed in Ghidra; leaf_b renamed into a default stub; mid deleted.
    funcs[2] = fn("1010:0100", "leaf_renamed")
    funcs[3] = fn("1010:0200", "leaf_b_default")
    del funcs[4]
    res = importer.run(conn, FakeSource(funcs), decompile=False)
    assert res.gone == 1 and res.new == 0
    a = row(conn, "1010:0100")
    assert (a["name"], a["status"], a["unit"], a["notes"], a["tested"]) == (
        "leaf_renamed",
        "ported",
        "core",
        "n",
        "asset",
    )
    assert a["decompile"] == "void leaf_a(void) {}"  # kept: --no-decompile
    b = row(conn, "1010:0200")
    assert (b["kind"], b["status"]) == ("default", "absorbed")  # auto status follows kind
    assert row(conn, "1010:0300")["gone"] == 1


def test_reimport_keeps_hand_set_absorbed_by(conn: sqlite3.Connection) -> None:
    importer.run(conn, FakeSource(default_funcs()), decompile=False)
    conn.execute(
        "UPDATE functions SET status = 'absorbed', status_auto = 0, absorbed_by = '1010:0100' "
        "WHERE addr = '1010:0200'"
    )
    importer.run(conn, FakeSource(default_funcs()), decompile=False)
    b = row(conn, "1010:0200")
    assert (b["status"], b["absorbed_by"]) == ("absorbed", "1010:0100")
