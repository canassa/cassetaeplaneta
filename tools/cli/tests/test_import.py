from __future__ import annotations

import sqlite3

from conftest import FakeSource, default_funcs, fn
from noite import importer


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
