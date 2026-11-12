from __future__ import annotations

import sqlite3
from pathlib import Path

from conftest import FakeSource
from noite import deps, importer, plan, units
from noite.db import UnitKind, connect, tx


def build(conn: sqlite3.Connection, source: FakeSource, plan_file: Path | None = None) -> None:
    importer.run(conn, source, plan_file=plan_file)


def test_roundtrip_rebuilds_plan(tmp_path: Path, source: FakeSource) -> None:
    a = connect(tmp_path / "a.sqlite")
    build(a, source)
    with tx(a):
        units.create(a, "leaves", UnitKind.MODULE, notes="tabs\tand\nnewlines \\ ok")
        units.create(a, "middle", UnitKind.MODULE)
        units.add(a, "leaves", units.resolve_functions(a, ["1010:0100"]))
        units.add(a, "middle", units.resolve_functions(a, ["mid"]))
        a.execute(
            "UPDATE functions SET status='dead', status_auto=0, notes='unused' "
            "WHERE addr='1010:0200'"
        )
        deps.add(a, "middle", "leaves", "why\tnot")
    f = tmp_path / "plan.tsv"
    assert plan.write(a, f)
    assert not plan.write(a, f)

    b = connect(tmp_path / "b.sqlite")
    build(b, source, f)  # empty DB: the plan is applied after the snapshot
    assert plan.render(b) == f.read_text()
    row = b.execute("SELECT status, status_auto, notes FROM functions WHERE addr='1010:0200'")
    assert tuple(row.fetchone()) == ("dead", 0, "unused")
    assert b.execute("SELECT notes FROM units WHERE name='leaves'").fetchone()[0] == (
        "tabs\tand\nnewlines \\ ok"
    )

    # not applied again on a DB that already has units
    with tx(b):
        b.execute("DELETE FROM unit_deps")
    build(b, source, f)
    assert b.execute("SELECT COUNT(*) FROM unit_deps").fetchone()[0] == 0
