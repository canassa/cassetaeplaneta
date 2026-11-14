"""A second program (ENCAIXE.EXE): its own DB, plan, tree, rules."""

from __future__ import annotations

import sqlite3
from pathlib import Path

import pytest
from typer.testing import CliRunner

from conftest import git
from noite import claim, deps, ghidra, paths, plan, program, strrefs, tags, units
from noite.classify import classify
from noite.cli import app
from noite.db import Kind, UnitKind, connect, tx
from noite.ghidra import FunctionInfo
from noite.importer import far_jumps
from noite.importer import run as import_run
from noite.ne import NeImage, Segment


@pytest.fixture
def encaixe(monkeypatch: pytest.MonkeyPatch) -> program.Program:
    monkeypatch.setenv(program.ENV, "encaixe")
    return program.current()


def test_default_is_noite_and_paths_follow_the_program(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    assert program.current().name == "noite"
    assert paths.db_path(tmp_path) == tmp_path / "db/port.sqlite"
    assert paths.branch_name("app") == "port/app"
    assert plan.plan_rel() == "db/plan.tsv"
    monkeypatch.setenv(program.ENV, "encaixe")
    assert paths.db_path(tmp_path) == tmp_path / "db/encaixe.sqlite"
    assert paths.worktree_path(tmp_path, "app") == tmp_path / "work/encaixe-app"
    assert paths.branch_name("app") == "port/encaixe-app"
    assert plan.plan_rel() == "db/encaixe-plan.tsv"
    assert units.index_path() == Path("src/encaixe/units.zig")
    with pytest.raises(ValueError):
        program.get("bogus")


def test_cli_rejects_an_unknown_program() -> None:
    res = CliRunner().invoke(app, ["-p", "bogus", "status"])
    assert res.exit_code == 1 and "unknown program" in res.output


def test_classify_encaixe(encaixe: program.Program) -> None:
    def kind(addr: str, name: str, thunk: bool = False) -> Kind:
        return classify(
            addr, name, ghidra_thunk=thunk, callees=(), classes=frozenset({"animation"})
        )[0]

    assert kind("1030:0010", "POSTMESSAGE") is Kind.API
    assert kind("1008:05e8", "rand") is Kind.CRT
    assert kind("1008:1bde", "dib_copy_transparent") is Kind.METHOD
    assert kind("1008:4a8e", "animation_erase_thunk_m6") is Kind.THUNK
    assert kind("1008:5572", "scene_object_is_player") is Kind.TYPE_TEST
    # NOITE's dead classes are live here.
    assert kind("1008:58bc", "actor2d_get_timer_id") is Kind.METHOD
    assert kind("1008:89cc", "WinMain") is Kind.PLATFORM


def test_units_live_in_the_programs_tree(encaixe: program.Program, tmp_path: Path) -> None:
    conn = connect(tmp_path / "e.sqlite")
    with tx(conn):
        assert (
            units.create(conn, "render", UnitKind.BEHAVIOUR) == "src/encaixe/behaviour/render.zig"
        )
        assert units.create(conn, "app", UnitKind.MODULE) == "src/encaixe/app.zig"
        with pytest.raises(units.UnitError):
            units.create(conn, "bad", UnitKind.MODULE, path="src/bad.zig")
    r = units.sync(conn, tmp_path)
    assert sorted(r.stubs) == ["src/encaixe/app.zig", "src/encaixe/behaviour/render.zig"]
    index = (tmp_path / "src/encaixe/units.zig").read_text()
    assert 'pub const render = @import("behaviour/render.zig");' in index


def test_tags_are_scanned_per_program(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    (tmp_path / "src/encaixe").mkdir(parents=True)
    (tmp_path / "src/a.zig").write_text("// @orig 1008:0100 noite_fn\nfn a() void {}\n")
    (tmp_path / "src/encaixe/b.zig").write_text("// @orig 1008:0100 encaixe_fn\nfn b() void {}\n")
    assert [t.name for t in tags.scan(tmp_path)] == ["noite_fn"]
    monkeypatch.setenv(program.ENV, "encaixe")
    assert [t.name for t in tags.scan(tmp_path)] == ["encaixe_fn"]


def test_finish_keeps_each_program_in_its_tree(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    conn = connect(tmp_path / "p.sqlite")
    with tx(conn):
        units.create(conn, "app", UnitKind.MODULE)
    assert claim.check_ownership(conn, "app", ["src/app.zig"]) == []
    assert claim.check_ownership(conn, "app", ["src/encaixe/app.zig"])
    monkeypatch.setenv(program.ENV, "encaixe")
    econn = connect(tmp_path / "e.sqlite")
    with tx(econn):
        units.create(econn, "app", UnitKind.MODULE)
    assert claim.check_ownership(econn, "app", ["src/encaixe/app.zig"]) == []
    bad = claim.check_ownership(econn, "app", ["src/core/game.zig", "src/encaixe/units.zig"])
    assert len(bad) == 2


def test_near_vtable_slots_and_virtual_calls(encaixe: program.Program) -> None:
    assert ghidra.near_pointers([0x2C, 0x52, 0x86, 0xF1], "1008") == ("1008:522c", "1008:f186")
    layouts = {"SceneObjectVtbl": {f"slot{i:02x}": i for i in range(0x5D)}}
    use = deps.slots_called(
        "(*(code *)p->vtbl[0])(p); SceneObjectVtbl *v;",
        "1008:1000  CALL word ptr [BX + 0x36]\n1008:1003  CALLF [BX + 0x8]",
        layouts,
    )
    assert use.pairs == {("SceneObjectVtbl", 0x1B)}
    assert deps.other_vtables()["PieceVtbl"][1] == "piece"


def test_strings_of_a_small_model_program(encaixe: program.Program, tmp_path: Path) -> None:
    conn = connect(tmp_path / "e.sqlite")
    conn.execute(
        "INSERT INTO globals (addr, name, type) VALUES ('1018:0014', 's_appName', 'char[17]')"
    )
    conn.execute("INSERT INTO function_globals (func, global) VALUES ('1008:8886', '1018:0014')")
    assert strrefs.named_strings(conn) == {"1008:8886": ["1018:0014"]}

    data = bytes(0x14) + b"Encaixe Perfeito\0" + bytes(8)
    image = NeImage({0x1018: Segment(0x1018, data)})
    found = strrefs.find("1008:8886  PUSH 0x14", image, named=["1018:0014"])
    assert [(r.addr, r.data) for r in found] == [("1018:0014", b"Encaixe Perfeito")]
    # An empty string in DGROUP is zeroed data, not a literal.
    assert strrefs.find(None, image, named=["1018:0004"]) == []


def test_import_and_plan_for_encaixe(encaixe: program.Program, repo: Path) -> None:
    class Src:
        def list_functions(self) -> list[FunctionInfo]:
            return [FunctionInfo("1008:f2a2", "te_scene_handle_message", False)]

        def function_details(self, addrs: object, *, decompile: bool) -> dict[str, FunctionInfo]:
            return {"1008:f2a2": FunctionInfo("1008:f2a2", "te_scene_handle_message", False)}

        def structs(self) -> list[ghidra.StructInfo]:
            return []

        def globals(self) -> list[ghidra.GlobalInfo]:
            return []

        def vtables(self) -> list[ghidra.VtableInfo]:
            return []

    plan_file = repo / plan.plan_rel()
    plan_file.parent.mkdir(parents=True, exist_ok=True)
    plan_file.write_text(
        "unit\ttetris\tmodule\tsrc/encaixe/tetris.zig\tthe scene\n"
        "fn\t1008:f2a2\ttetris\tte_scene_handle_message\n"
    )
    conn: sqlite3.Connection = connect(paths.db_path(repo))
    res = import_run(conn, Src(), plan_file=plan_file)
    assert res.plan is not None and res.plan.units == 1
    row = conn.execute("SELECT unit, kind FROM functions WHERE addr = '1008:f2a2'").fetchone()
    assert tuple(row) == ("tetris", "method")
    units.sync(conn, repo)
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "-m", "encaixe")
    s = claim.start(conn, repo, "tetris", "agent")
    assert s.worktree == repo / "work/encaixe-tetris" and s.branch == "port/encaixe-tetris"
    assert "NOITE_PROGRAM=encaixe" in (s.worktree / ".ref/env.sh").read_text()
    claim.release(conn, repo, "tetris")


@pytest.fixture
def tiro(monkeypatch: pytest.MonkeyPatch) -> program.Program:
    monkeypatch.setenv(program.ENV, "tiro")
    return program.current()


def test_tiro_layout(tiro: program.Program, tmp_path: Path) -> None:
    assert paths.db_path(tmp_path) == tmp_path / "db/tiro.sqlite"
    assert paths.worktree_path(tmp_path, "gallery") == tmp_path / "work/tiro-gallery"
    assert plan.plan_rel() == "db/tiro-plan.tsv"
    assert units.index_path() == Path("src/tiro/units.zig")

    def kind(addr: str, name: str, callees: tuple[str, ...] = ()) -> tuple[Kind, str | None]:
        return classify(addr, name, ghidra_thunk=False, callees=callees, classes=frozenset())

    assert kind("10a8:0010", "POSTMESSAGE")[0] is Kind.API
    assert kind("1080:02ae", "_purecall")[0] is Kind.CRT
    assert kind("1068:1790", "tiro_scene_handle_message")[0] is Kind.METHOD
    # A far adjustor thunk's only way out is its JMPF.
    asm = "1088:485a  MOV BX, SP\n1088:4869  JMPF 0x1068:07f4"
    assert far_jumps(asm) == ("1068:07f4",)
    assert kind("1088:485a", "target_tick_thunk", far_jumps(asm)) == (Kind.THUNK, "1068:07f4")
    # Far 4-byte slots, `CALLF [BX+off]` as in NOITE.
    layouts = {"SceneObjectVtbl": {f"slot{i:02x}": i for i in range(0x5B)}}
    use = deps.slots_called("SceneObjectVtbl *v;", "1068:08a0  CALLF [BX + 0xb4]", layouts)
    assert use.pairs == {("SceneObjectVtbl", 0x2D)}
    assert deps.other_vtables()["ProjectileVtbl"][3] == "arrow"
    assert 0x58 in deps.type_test_slots()


def test_noite_does_not_scan_tiro(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    (tmp_path / "src/tiro").mkdir(parents=True)
    (tmp_path / "src/a.zig").write_text("// @orig 1008:0100 noite_fn\nfn a() void {}\n")
    (tmp_path / "src/tiro/b.zig").write_text("// @orig 1068:0100 tiro_fn\nfn b() void {}\n")
    assert [t.name for t in tags.scan(tmp_path)] == ["noite_fn"]
    monkeypatch.setenv(program.ENV, "tiro")
    assert [t.name for t in tags.scan(tmp_path)] == ["tiro_fn"]
