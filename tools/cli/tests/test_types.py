from __future__ import annotations

import sqlite3
from pathlib import Path

from typer.testing import CliRunner

from conftest import FakeSource, fn
from noite import claim, cli, importer, types
from noite.ghidra import FunctionInfo, GlobalInfo, StructInfo


class TypedSource(FakeSource):
    def __init__(self) -> None:
        super().__init__()
        f = fn("1010:0800", "ini_find", "1010:0100")
        body = "void ini_find(IniSection *s) { g_lives = g_buf[0]; Other o; }"
        self.funcs.append(FunctionInfo(**{**f.__dict__, "decompile": body}))

    def structs(self) -> list[StructInfo]:
        return [
            StructInfo(
                "IniSection",
                44,
                [
                    {"offset": 0, "size": 40, "type": "char[40]", "name": "name"},
                    {"offset": 40, "size": 4, "type": "Inner *32", "name": "inner"},
                ],
            ),
            StructInfo("Inner", 2, [{"offset": 0, "size": 2, "type": "int", "name": "x"}]),
            StructInfo("Other", 2),
        ]

    def globals(self) -> list[GlobalInfo]:
        return [
            GlobalInfo("1050:002a", "g_lives", "short", 24),
            GlobalInfo("1050:0030", "g_buf", "char[256]", 9),
            GlobalInfo("1050:0040", "g_tbl", "IniSection[3]", 1),
        ]


def test_type_size() -> None:
    sizes = {"IniSection": 44}
    assert types.type_size("char[256]", sizes) == 256
    assert types.type_size("IniSection[3]", sizes) == 132
    assert types.type_size("Game *32", sizes) == 4
    assert types.type_size("long", sizes) == 4
    assert types.type_size("Mystery", sizes) is None


def test_refs_and_reference_files(conn: sqlite3.Connection, repo: Path) -> None:
    res = importer.run(conn, TypedSource())
    assert res.struct_refs == 2 and res.global_refs == 2
    sizes = dict(conn.execute("SELECT name, size FROM globals").fetchall())
    assert sizes == {"g_lives": 2, "g_buf": 256, "g_tbl": 132}
    structs, globs = types.for_functions(conn, ["1010:0800"])
    assert structs == ["Inner", "IniSection", "Other"] or sorted(structs) == sorted(
        ["Inner", "IniSection", "Other"]
    )
    assert [g["name"] for g in globs] == ["g_lives", "g_buf"]

    wt = repo
    funcs = conn.execute("SELECT * FROM functions WHERE addr = '1010:0800'").fetchall()
    ref = claim.write_reference(wt, funcs, conn)
    doc = (ref / "types.md").read_text()
    assert "struct IniSection" in doc and "struct Inner" in doc and "char[256] g_buf" in doc
    assert "env.sh" in {p.name for p in ref.iterdir()}


def test_show_struct_and_global(conn: sqlite3.Connection, tmp_path: Path) -> None:
    db = tmp_path / "t.sqlite"
    import pytest

    mp = pytest.MonkeyPatch()
    mp.setenv("NOITE_DB", str(db))
    try:
        from noite.db import connect

        c = connect(db)
        importer.run(c, TypedSource())
        r = CliRunner().invoke(cli.app, ["show", "IniSection"])
        assert r.exit_code == 0 and "char[40] name" in r.output and "ini_find" in r.output
        r = CliRunner().invoke(cli.app, ["show", "g_buf"])
        assert r.exit_code == 0 and "256 bytes" in r.output
        r = CliRunner().invoke(cli.app, ["show", "nonesuch"])
        assert r.exit_code == 1
    finally:
        mp.undo()


def test_zig_summary() -> None:
    out = "Build Summary: 3/3 steps succeeded; 5/5 tests passed\n"
    assert cli._zig_summary(out, "test") == "test ok: 5/5 tests passed"
    assert cli._zig_summary("Build Summary: 2/2 steps succeeded (1 cached)", "build") == (
        "build ok: 2/2 steps succeeded, 1 cached"
    )
