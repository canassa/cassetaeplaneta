from __future__ import annotations

import sqlite3
from pathlib import Path

from conftest import FakeSource
from noite import check, importer


def write(root: Path, rel: str, text: str) -> None:
    p = root / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text)


def test_check_and_fix(conn: sqlite3.Connection, source: FakeSource, tmp_path: Path) -> None:
    importer.run(conn, source)
    conn.execute("UPDATE functions SET status = 'ported', status_auto = 0 WHERE addr = '1010:0200'")
    root = tmp_path / "tree"
    write(
        root,
        "src/a.zig",
        (
            "// @orig 1010:0100 leaf_a\nfn a() void {}\n"
            "// @orig 1010:0100 leaf_a\nfn again() void {}\n"
            "// @orig 1010:0300 wrong_name\nfn m() void {}\n"
            "// @orig 1010:dead\n"
            "// @orig 1010:9999 nobody\nfn x() void {}\n"
            '// @orig 1010:0300 mid oracle=documented\ntest "m" {}\n'
        ),
    )
    write(root, "src/handlers/2fpontoc.zig", "// @orig 1010:0300 mid\n")
    rep = check.run(conn, root)
    errs = "\n".join(rep.errors)
    assert "1010:9999: no such function" in errs
    assert "1010:0100 leaf_a is ported more than once" in errs
    assert "1010:0200 leaf_b is marked ported but has no @orig tag" in errs
    assert "1010:0300 mid is ported more than once" in errs
    warns = "\n".join(rep.warnings)
    assert "says wrong_name" in warns
    assert "src/handlers/2fpontoc.zig is not imported anywhere" in warns
    assert rep.tested == {"1010:0300": "documented"}

    fx = check.fix_status(conn, rep)
    assert sorted(fx.ported) == ["1010:0100", "1010:0300"]
    assert fx.unported == ["1010:0200"]
    st = dict(conn.execute("SELECT addr, status FROM functions").fetchall())
    assert st["1010:0100"] == "ported" and st["1010:0200"] == "pending"
    assert (
        conn.execute("SELECT tested FROM functions WHERE addr = '1010:0300'").fetchone()[0]
        == "documented"
    )


def test_check_in_a_worktree_behind_main(
    conn: sqlite3.Connection, source: FakeSource, tmp_path: Path
) -> None:
    importer.run(conn, source)
    conn.execute(
        "INSERT OR IGNORE INTO units (name, kind, path) VALUES ('mine', 'module', 'src/mine.zig')"
    )
    conn.execute(
        "INSERT OR IGNORE INTO units (name, kind, path) VALUES ('other', 'module', 'src/o.zig')"
    )
    conn.execute("UPDATE functions SET unit = 'mine', status = 'ported' WHERE addr = '1010:0100'")
    conn.execute("UPDATE functions SET unit = 'other', status = 'ported' WHERE addr = '1010:0200'")
    root = tmp_path / "wt"
    write(root, "src/mine.zig", "")
    rep = check.run(conn, root, unit="mine")
    assert [e for e in rep.errors if "1010:0100" in e]  # own unit: still an error
    assert not [e for e in rep.errors if "1010:0200" in e]
    assert any("behind main" in w and "other" in w for w in rep.warnings)
