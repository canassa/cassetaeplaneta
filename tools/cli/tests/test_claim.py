from __future__ import annotations

import sqlite3
import threading
from pathlib import Path

import pytest

from conftest import FakeSource, git
from noite import claim, importer, units
from noite.db import UnitKind, connect, tx


@pytest.fixture
def setup(repo: Path, source: FakeSource) -> tuple[sqlite3.Connection, Path]:
    conn = connect(repo / "db" / "port.sqlite")
    importer.run(conn, source)
    with tx(conn):
        units.create(conn, "leaves", UnitKind.MODULE)
        units.add(conn, "leaves", units.resolve_functions(conn, ["1010:0100", "1010:0200"]))
        units.create(conn, "middle", UnitKind.MODULE)
        units.add(conn, "middle", units.resolve_functions(conn, ["mid"]))
    units.sync(conn, repo)
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "-m", "units")
    return conn, repo


def ready(conn: sqlite3.Connection) -> list[str]:
    return [s.name for s in claim.unit_states(conn) if s.ready]


def test_sync_writes_stubs_and_index(setup: tuple[sqlite3.Connection, Path]) -> None:
    _, repo = setup
    assert (repo / "src/leaves.zig").read_text().startswith("//! Port unit `leaves`")
    index = (repo / "src/units.zig").read_text()
    assert 'pub const handler_2fpontoc = @import("handlers/2fpontoc.zig");' in index
    assert 'pub const leaves = @import("leaves.zig");' in index


def test_readiness_follows_thunks(setup: tuple[sqlite3.Connection, Path]) -> None:
    conn, _ = setup
    # mid calls leaf_a directly and through an absorbed thunk; the handler calls mid.
    assert ready(conn) == ["leaves"]
    bl = claim.blockers(conn, "middle")
    assert [b.addr for b in bl] == ["1010:0100"]
    conn.execute("UPDATE functions SET status = 'ported' WHERE unit = 'leaves'")
    assert ready(conn) == ["middle"]


def test_start_release_failed(setup: tuple[sqlite3.Connection, Path]) -> None:
    conn, repo = setup
    with pytest.raises(claim.ClaimError, match="not ready"):
        claim.start(conn, repo, "middle", "a1")
    s = claim.start(conn, repo, "leaves", "a1")
    assert s.worktree == repo / "work" / "leaves" and (s.worktree / "src/leaves.zig").exists()
    assert len(list((s.worktree / ".ref").iterdir())) == 2
    assert git(s.worktree, "branch", "--show-current").strip() == "port/leaves"
    st = dict(conn.execute("SELECT addr, status FROM functions WHERE unit = 'leaves'").fetchall())
    assert set(st.values()) == {"in_progress"}
    with pytest.raises(claim.ClaimError, match="in_progress"):
        claim.start(conn, repo, "leaves", "a2")

    claim.failed(conn, repo, "leaves", "no oracle for leaf_b")
    assert not s.worktree.exists()
    u = units.get(conn, "leaves")
    assert (u["status"], u["last_error"], u["attempts"]) == ("failed", "no oracle for leaf_b", 1)
    assert ready(conn) == ["leaves"]  # failed units are retry targets

    claim.start(conn, repo, "leaves", "a2")
    claim.release(conn, repo, "leaves")
    assert units.get(conn, "leaves")["status"] == "pending"
    assert "port/leaves" not in git(repo, "branch")


def test_concurrent_claims_have_one_winner(setup: tuple[sqlite3.Connection, Path]) -> None:
    _, repo = setup
    db = repo / "db" / "port.sqlite"
    wins: list[str] = []
    errors: list[str] = []
    barrier = threading.Barrier(6)

    def worker(i: int) -> None:
        c = connect(db)
        barrier.wait()
        try:
            claim.start(c, repo, "leaves", f"agent{i}")
            wins.append(f"agent{i}")
        except claim.ClaimError as e:
            errors.append(str(e))

    threads = [threading.Thread(target=worker, args=(i,)) for i in range(6)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    assert len(wins) == 1 and len(errors) == 5
    assert units.get(connect(db), "leaves")["agent_id"] == wins[0]


def test_finish(setup: tuple[sqlite3.Connection, Path], monkeypatch: pytest.MonkeyPatch) -> None:
    conn, repo = setup
    gates: list[list[str]] = []
    monkeypatch.setattr(claim, "run_gate", lambda cwd, cmd: gates.append(cmd))
    s = claim.start(conn, repo, "leaves", "a1")
    wt = s.worktree
    (wt / "src/leaves.zig").write_text("// @orig 1010:0100 leaf_a\npub fn a() void {}\n")
    git(wt, "commit", "-qam", "port leaf_a")

    with pytest.raises(claim.ClaimError, match="1010:0200 leaf_b"):
        claim.finish(conn, repo, "leaves", push=False, snapshot=False)

    (wt / "src/leaves.zig").write_text(
        "// @orig 1010:0100 leaf_a\npub fn a() void {}\n"
        "// @orig 1010:0200 leaf_b\npub fn b() void {}\n"
        '// @orig 1010:0200 leaf_b oracle=asset\ntest "b" {}\n'
    )
    git(wt, "commit", "-qam", "port leaf_b")
    # main moves on meanwhile: finish rebases onto it.
    (repo / "README").write_text("x\n")
    git(repo, "add", "README")
    git(repo, "commit", "-qm", "unrelated")

    r = claim.finish(conn, repo, "leaves", push=False, snapshot=True)
    assert sorted(r.ported) == ["1010:0100", "1010:0200"] and r.commits == 2
    assert ["zig", "build", "test"] in gates
    assert "@orig 1010:0200" in (repo / "src/leaves.zig").read_text()
    assert not wt.exists() and "port/leaves" not in git(repo, "branch")
    rows = dict(
        conn.execute(
            "SELECT addr, status || '/' || tested FROM functions WHERE unit = 'leaves'"
        ).fetchall()
    )
    assert rows == {"1010:0100": "ported/none", "1010:0200": "ported/asset"}
    assert units.get(conn, "leaves")["status"] == "done"
    assert ready(conn) == ["middle"]
    assert "record leaves as ported" in git(repo, "log", "-1", "--format=%s")


def test_finish_rejects_foreign_files(
    setup: tuple[sqlite3.Connection, Path], monkeypatch: pytest.MonkeyPatch
) -> None:
    conn, repo = setup
    monkeypatch.setattr(claim, "run_gate", lambda cwd, cmd: None)
    s = claim.start(conn, repo, "leaves", "a1")
    (s.worktree / "src/middle.zig").write_text("// mine now\n")
    git(s.worktree, "commit", "-qam", "touch another unit")
    with pytest.raises(claim.ClaimError, match="owned by unit middle"):
        claim.finish(conn, repo, "leaves", push=False, snapshot=False)
