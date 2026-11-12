from __future__ import annotations

import sqlite3
import subprocess
from collections.abc import Sequence
from pathlib import Path

import pytest

from noite.db import connect
from noite.ghidra import FunctionInfo, GlobalInfo, StructInfo


class FakeSource:
    """A tiny program: a CRT and an API function, a thunk, a default stub, a type
    test, a dead-class method, a handler and a few plain methods."""

    def __init__(self, funcs: list[FunctionInfo] | None = None) -> None:
        self.funcs = funcs if funcs is not None else default_funcs()

    def list_functions(self) -> list[FunctionInfo]:
        return [FunctionInfo(f.addr, f.name, f.is_thunk) for f in self.funcs]

    def function_details(self, addrs: Sequence[str], *, decompile: bool) -> dict[str, FunctionInfo]:
        by = {f.addr: f for f in self.funcs}
        out = {}
        for a in addrs:
            f = by[a]
            out[a] = (
                f
                if decompile
                else FunctionInfo(
                    f.addr,
                    f.name,
                    f.is_thunk,
                    f.size,
                    f.signature,
                    f.plate,
                    None,
                    f.disasm,
                    f.ghidra_class,
                    f.callees,
                )
            )
        return out

    def structs(self) -> list[StructInfo]:
        return [
            StructInfo("StatusBar", 0x4A2),
            StructInfo("SceneObjectVtbl", 0x198),
            StructInfo("RECT", 8),
        ]

    def globals(self) -> list[GlobalInfo]:
        return [GlobalInfo("1050:002a", "g_lives", "short", 24)]


def fn(addr: str, name: str, *callees: str, thunk: bool = False) -> FunctionInfo:
    return FunctionInfo(
        addr,
        name,
        thunk,
        10,
        f"void {name}(void)",
        None,
        f"void {name}(void) {{}}",
        f"{addr}  RETF",
        None,
        tuple(callees),
    )


def default_funcs() -> list[FunctionInfo]:
    return [
        fn("1008:001a", "entry"),
        fn("1108:0000", "WAVEMIXACTIVATE", thunk=True),
        fn("1010:0100", "leaf_a"),
        fn("1010:0200", "leaf_b", "1108:0000"),
        fn("1010:0300", "mid", "1010:0100", "1010:0400"),
        fn("1010:0400", "leaf_a_thunk_8", "1010:0100"),
        fn("1010:0500", "game_create_player_default"),
        fn("1010:0600", "scene_object_is_status_bar"),
        fn("1010:0700", "actor2d_move_tick", "1010:0100"),
        fn("1020:0000", "handler_2fpontoc", "1010:0300", "1010:0200"),
    ]


@pytest.fixture
def conn(tmp_path: Path) -> sqlite3.Connection:
    return connect(tmp_path / "port.sqlite")


@pytest.fixture
def source() -> FakeSource:
    return FakeSource()


def git(cwd: Path, *args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=cwd, check=True, capture_output=True, text=True
    ).stdout


@pytest.fixture
def repo(tmp_path: Path) -> Path:
    """A git repo with a main branch, like the real one."""
    root = tmp_path / "repo"
    root.mkdir()
    git(root, "init", "-q", "-b", "main")
    git(root, "config", "user.email", "t@example.com")
    git(root, "config", "user.name", "t")
    (root / ".gitignore").write_text("/work/\n.ref/\ndb/*.sqlite-wal\ndb/*.sqlite-shm\n")
    (root / "src").mkdir()
    (root / "src" / "main.zig").write_text('test {\n    _ = @import("units.zig");\n}\n')
    git(root, "add", "-A")
    git(root, "commit", "-q", "-m", "init")
    return root
