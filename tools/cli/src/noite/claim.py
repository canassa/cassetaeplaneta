"""The claim workflow: ``next`` → ``start`` → (port in the worktree) → ``finish``.

Each claimed unit gets a git worktree ``work/<unit>/`` on branch
``port/<unit>``, branched from ``main``. The claim itself is one
``BEGIN IMMEDIATE`` transaction on the shared DB, so concurrent agents can
never claim the same unit. ``finish`` serialises on a lock file in the git
directory, rebases the branch onto ``main``, runs the gates on the rebased
tree, fast-forwards ``main``, marks the unit's functions ported and removes
the worktree.

A unit is *ready* when every function its functions call (outside the unit)
is ported, absorbed, replaced or dead. A call to an absorbed thunk counts as a
call to the thunk's target. It must also have every *manual* unit dep done.
Virtual-call deps (``auto``, see ``deps``) are soft: they are reported but never
block, because every virtual slot's dispatcher is declared in the skeleton (a
panicking stub), so a caller compiles before the slot's owner is ported.
"""

from __future__ import annotations

import fcntl
import os
import secrets
import shutil
import sqlite3
import subprocess
from collections.abc import Iterator
from contextlib import contextmanager
from dataclasses import dataclass, field
from pathlib import Path

from noite import check, deps, paths, strrefs, types, units
from noite.db import DONE, Status, UnitStatus, now, tx

DB_REL = "db/port.sqlite"
INDEX_REL = units.INDEX.as_posix()


class ClaimError(RuntimeError):
    pass


def agent_id() -> str:
    return (
        os.environ.get("NOITE_AGENT") or f"{os.environ.get('USER', 'agent')}-{secrets.token_hex(3)}"
    )


# --------------------------------------------------------------------------- #
# readiness
# --------------------------------------------------------------------------- #


@dataclass(frozen=True)
class Blocker:
    addr: str
    name: str
    status: str
    unit: str | None


_resolve = deps.resolve_thunk


def blockers(conn: sqlite3.Connection, unit: str) -> list[Blocker]:
    funcs = {r["addr"]: r for r in conn.execute("SELECT * FROM functions")}
    members = [a for a, f in funcs.items() if f["unit"] == unit]
    calls = conn.execute(
        f"SELECT caller, callee FROM callees WHERE caller IN ({','.join('?' * len(members))})",
        members,
    ).fetchall()
    out: dict[str, Blocker] = {}
    for c in calls:
        target = _resolve(funcs, c["callee"])
        f = funcs.get(target)
        if f is None or f["unit"] == unit or f["status"] in DONE:
            continue
        out[target] = Blocker(target, f["name"], f["status"], f["unit"])
    return sorted(out.values(), key=lambda b: b.addr)


@dataclass(frozen=True)
class UnitState:
    name: str
    kind: str
    status: str
    todo: int  # functions still to port (pending/failed/in_progress)
    total: int
    blockers: list[Blocker]
    dep_blockers: list[str] = field(default_factory=list)  # manual deps not done (hard)
    soft_blockers: list[str] = field(default_factory=list)  # auto (virtual-call) deps not done

    @property
    def ready(self) -> bool:
        return (
            self.status in (UnitStatus.PENDING, UnitStatus.FAILED)
            and self.todo > 0
            and not self.blockers
            and not self.dep_blockers
        )


def unit_state(conn: sqlite3.Connection, u: sqlite3.Row, done: set[str] | None = None) -> UnitState:
    rows = conn.execute("SELECT status FROM functions WHERE unit = ?", (u["name"],)).fetchall()
    todo = sum(r["status"] in (Status.PENDING, Status.FAILED, Status.IN_PROGRESS) for r in rows)
    return UnitState(
        u["name"],
        u["kind"],
        u["status"],
        todo,
        len(rows),
        blockers(conn, u["name"]),
        deps.dep_blockers(conn, u["name"], done),
        deps.dep_blockers(conn, u["name"], done, source="auto"),
    )


def unit_states(conn: sqlite3.Connection) -> list[UnitState]:
    done = deps.done_units(conn)
    return [unit_state(conn, u, done) for u in conn.execute("SELECT * FROM units ORDER BY name")]


# --------------------------------------------------------------------------- #
# git
# --------------------------------------------------------------------------- #


def git(cwd: Path, *args: str, check_: bool = True) -> subprocess.CompletedProcess[str]:
    p = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)
    if check_ and p.returncode != 0:
        raise ClaimError(f"git {' '.join(args)} failed in {cwd}:\n{p.stderr.strip()}")
    return p


def _branch_exists(root: Path, branch: str) -> bool:
    return (
        git(
            root, "rev-parse", "--verify", "--quiet", f"refs/heads/{branch}", check_=False
        ).returncode
        == 0
    )


def remove_worktree(root: Path, unit: str, *, delete_branch: bool = True) -> None:
    wt = paths.worktree_path(root, unit)
    if wt.exists():
        git(root, "worktree", "remove", "--force", str(wt), check_=False)
        if wt.exists():
            shutil.rmtree(wt)
    git(root, "worktree", "prune", check_=False)
    branch = paths.branch_name(unit)
    if delete_branch and _branch_exists(root, branch):
        git(root, "branch", "-D", branch, check_=False)


@contextmanager
def finish_lock(root: Path) -> Iterator[None]:
    """One finish at a time touches ``main``."""
    lock = paths.git_common_dir(root) / "noite-finish.lock"
    with open(lock, "w") as fh:
        fcntl.flock(fh, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(fh, fcntl.LOCK_UN)


# --------------------------------------------------------------------------- #
# start / release / failed
# --------------------------------------------------------------------------- #


@dataclass(frozen=True)
class Started:
    unit: str
    agent: str
    worktree: Path
    branch: str
    path: str  # the unit's Zig file, relative to the worktree
    functions: list[sqlite3.Row]


def start(
    conn: sqlite3.Connection, root: Path, unit: str, agent: str, *, force: bool = False
) -> Started:
    u = units.get(conn, unit)
    _require_claimable(root, u)
    if git(root, "cat-file", "-e", f"main:{u['path']}", check_=False).returncode != 0:
        raise ClaimError(
            f"{u['path']} is not on main yet: run `noite unit sync` in the main checkout and commit"
        )
    with tx(conn):
        u = units.get(conn, unit)
        _require_claimable(root, u)
        state = unit_state(conn, u)
        if state.todo == 0:
            raise ClaimError(f"unit {unit} has no functions left to port")
        if state.blockers and not force:
            listed = "\n  ".join(
                f"{b.addr} {b.name} [{b.status}{', ' + b.unit if b.unit else ', no unit'}]"
                for b in state.blockers
            )
            raise ClaimError(f"unit {unit} is not ready; it calls unported functions:\n  {listed}")
        if state.dep_blockers and not force:
            raise ClaimError(
                f"unit {unit} is not ready; it depends (manual dep) on units not done: "
                + ", ".join(state.dep_blockers)
                + " (`noite unit dep show`)"
            )
        stamp = now()
        conn.execute(
            "UPDATE units SET status = 'in_progress', agent_id = ?, started_at = ?, "
            "finished_at = NULL, attempts = attempts + 1, last_error = NULL WHERE name = ?",
            (agent, stamp, unit),
        )
        conn.execute(
            "UPDATE functions SET status = 'in_progress', status_auto = 0, agent_id = ?, "
            "started_at = ?, attempts = attempts + 1 "
            "WHERE unit = ? AND status IN ('pending', 'failed')",
            (agent, stamp, unit),
        )
    wt = paths.worktree_path(root, unit)
    branch = paths.branch_name(unit)
    try:
        if wt.exists():
            raise ClaimError(f"{wt} already exists; `noite release {unit}` cleans it up")
        wt.parent.mkdir(parents=True, exist_ok=True)
        if _branch_exists(root, branch):
            git(root, "worktree", "add", str(wt), branch)
        else:
            git(root, "worktree", "add", "-b", branch, str(wt), "main")
    except ClaimError:
        _unclaim(conn, unit, to=Status.PENDING, unit_status=UnitStatus.PENDING, note=None)
        raise
    funcs = conn.execute("SELECT * FROM functions WHERE unit = ? ORDER BY addr", (unit,)).fetchall()
    write_reference(wt, funcs, conn)
    return Started(unit, agent, wt, branch, u["path"], funcs)


def _require_claimable(root: Path, u: sqlite3.Row) -> None:
    name = u["name"]
    if u["status"] == UnitStatus.IN_PROGRESS:
        wt = paths.worktree_path(root, name).relative_to(root)
        raise ClaimError(
            f"unit {name} is already claimed by {u['agent_id'] or '?'} since "
            f"{u['started_at'] or '?'} (worktree {wt}); `noite release {name}` to give it back"
        )
    if u["status"] == UnitStatus.DONE:
        raise ClaimError(f"unit {name} is already done")
    if u["status"] not in (UnitStatus.PENDING, UnitStatus.FAILED):
        raise ClaimError(f"unit {name} is {u['status']}")


# Sourced in a worktree: reuse the main checkout's venv instead of building one per
# worktree (NO_SYNC keeps uv from re-pointing its editable install at the worktree),
# and silence nix's "Git tree is dirty" warning.
ENV_SH = """export UV_PROJECT_ENVIRONMENT={venv}
export UV_NO_SYNC=1
export NIX_CONFIG="warn-dirty = false"
"""


def write_reference(
    wt: Path, funcs: list[sqlite3.Row], conn: sqlite3.Connection, *, exe_root: Path | None = None
) -> Path:
    """Drop each function's Ghidra snapshot under ``.ref/`` (git-ignored), plus
    ``types.md`` (the layouts of the structs and the globals the unit touches) and
    ``strings.md`` (the string constants each function references, exact bytes from
    ``<exe_root>/assets/NOITE.EXE``; default: the main checkout)."""
    ref = wt / ".ref"
    ref.mkdir(exist_ok=True)
    for f in funcs:
        fstructs, fglobs = types.for_functions(conn, [f["addr"]])
        body = [
            f"// {f['addr']} {f['name']}  [{f['kind']}, {f['status']}]",
            f"// {f['signature'] or ''}",
        ]
        if fstructs or fglobs:
            names = [*fstructs, *(g["name"] for g in fglobs)]
            body.append(f"// types: {', '.join(names)}  (layouts in types.md)")
        if f["addr"].startswith("1000:"):
            body.append(
                "// segment 1000 runs as 32-bit code: Ghidra's 16-bit listing below is garbage"
                " past the prologue (and stops early); disassemble it with objdump -mi386"
                " (CLAUDE.md, Binary facts)."
            )
        if f["plate"]:
            body += ["/*", f["plate"], "*/"]
        body += [
            f["decompile"] or "// (no decompilation)",
            "",
            "/* disassembly",
            f["disasm"] or "",
            "*/",
            "",
        ]
        (ref / f"{f['addr'].replace(':', '_')}_{f['name']}.c").write_text("\n".join(body))
    structs, globs = types.for_functions(conn, [f["addr"] for f in funcs])
    doc = ["# Types touched by this unit", "", "Ghidra snapshot; offsets and sizes in bytes.", ""]
    if globs:
        doc += ["## Globals", "", "```c", *(types.render_global(g) for g in globs), "```", ""]
    for name in structs:
        row = conn.execute("SELECT * FROM structs WHERE name = ?", (name,)).fetchone()
        doc += [f"## {name}", "", "```c", types.render_struct(row), "```", ""]
    (ref / "types.md").write_text("\n".join(doc))
    image = strrefs.load_image(exe_root or paths.repo_root(wt))
    (ref / "strings.md").write_text(
        strrefs.render(funcs, image, strrefs.non_string_globals(conn)), encoding="utf-8"
    )
    (ref / "env.sh").write_text(ENV_SH.format(venv=paths.repo_root(wt) / ".venv"))
    return ref


def _unclaim(
    conn: sqlite3.Connection, unit: str, *, to: Status, unit_status: UnitStatus, note: str | None
) -> None:
    with tx(conn):
        conn.execute(
            "UPDATE units SET status = ?, agent_id = NULL, last_error = COALESCE(?, last_error) "
            "WHERE name = ?",
            (unit_status.value, note, unit),
        )
        conn.execute(
            "UPDATE functions SET status = ?, agent_id = NULL, "
            "notes = CASE WHEN ? IS NULL THEN notes ELSE ? END "
            "WHERE unit = ? AND status = 'in_progress'",
            (to.value, note, note, unit),
        )


def _require_claimed(conn: sqlite3.Connection, unit: str) -> sqlite3.Row:
    u = units.get(conn, unit)
    if u["status"] != UnitStatus.IN_PROGRESS:
        raise ClaimError(f"unit {unit} is {u['status']}, not in_progress")
    return u


def release(conn: sqlite3.Connection, root: Path, unit: str, *, keep: bool = False) -> None:
    _require_claimed(conn, unit)
    _unclaim(conn, unit, to=Status.PENDING, unit_status=UnitStatus.PENDING, note=None)
    if not keep:
        remove_worktree(root, unit)


def failed(
    conn: sqlite3.Connection, root: Path, unit: str, reason: str, *, keep: bool = False
) -> None:
    _require_claimed(conn, unit)
    _unclaim(conn, unit, to=Status.FAILED, unit_status=UnitStatus.FAILED, note=reason)
    if not keep:
        remove_worktree(root, unit)


# --------------------------------------------------------------------------- #
# finish
# --------------------------------------------------------------------------- #


@dataclass(frozen=True)
class Finished:
    unit: str
    ported: list[str]
    commits: int
    pushed: bool | None  # None = not attempted
    warnings: list[str]


def run_gate(cwd: Path, cmd: list[str]) -> None:
    if shutil.which(cmd[0]) is None:
        raise ClaimError(
            f"{cmd[0]} not on PATH — run inside the dev shell (`nix develop` / direnv)"
        )
    p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if p.returncode != 0:
        out = (p.stdout + p.stderr).strip()
        raise ClaimError(f"gate `{' '.join(cmd)}` failed:\n{out[-4000:]}")


def changed_files(wt: Path) -> list[str]:
    out = git(wt, "diff", "--name-only", "main...HEAD").stdout
    return [line for line in out.splitlines() if line]


def check_ownership(conn: sqlite3.Connection, unit: str, files: list[str]) -> list[str]:
    """Paths the branch must not touch: the DB, the generated index, other units' files."""
    others = {
        r["path"]: r["name"]
        for r in conn.execute("SELECT name, path FROM units WHERE name != ?", (unit,))
    }
    bad = []
    for f in files:
        if f.startswith("db/"):
            bad.append(f"{f}: the tracker DB lives in the main checkout only")
        elif f == INDEX_REL:
            bad.append(f"{f}: generated by `noite unit sync` on main")
        elif f in others:
            bad.append(f"{f}: owned by unit {others[f]}")
    return bad


def unported_stubs(path: Path) -> list[str]:
    """``stub.unported(...)`` calls left in a unit file (the skeleton's
    dispatcher bodies the unit must replace), as ``line: text``."""
    if not path.exists():
        return []
    return [
        f"{i}: {line.strip()}"
        for i, line in enumerate(path.read_text().splitlines(), 1)
        if "stub.unported(" in line
    ]


def finish(conn: sqlite3.Connection, root: Path, unit: str, *, push: bool = True) -> Finished:
    u = _require_claimed(conn, unit)
    wt = paths.worktree_path(root, unit)
    if not wt.is_dir():
        raise ClaimError(f"no worktree at {wt}")
    if git(wt, "status", "--porcelain").stdout.strip():
        raise ClaimError(f"{wt} has uncommitted changes; commit them first")
    if git(root, "symbolic-ref", "--short", "HEAD").stdout.strip() != "main":
        raise ClaimError(f"the main checkout {root} is not on branch main")

    with finish_lock(root):
        if git(wt, "rebase", "main", check_=False).returncode != 0:
            git(wt, "rebase", "--abort", check_=False)
            raise ClaimError(f"rebasing port/{unit} onto main conflicts; resolve in {wt} and retry")
        files = changed_files(wt)
        if not files:
            raise ClaimError(f"port/{unit} has no commits beyond main")
        bad = check_ownership(conn, unit, files)
        if bad:
            raise ClaimError("the branch touches files it does not own:\n  " + "\n  ".join(bad))

        zig_changed = [f for f in files if f.endswith(".zig") and (wt / f).exists()]
        if zig_changed:
            run_gate(wt, ["zig", "fmt", "--check", *zig_changed])
        run_gate(wt, ["zig", "build"])
        run_gate(wt, ["zig", "build", "test"])

        rep = check.run(conn, wt)
        if not rep.ok:
            raise ClaimError("`noite check` failed:\n  " + "\n  ".join(rep.errors))
        members = conn.execute(
            "SELECT addr, name, status FROM functions WHERE unit = ?", (unit,)
        ).fetchall()
        untagged = [
            f"{r['addr']} {r['name']}"
            for r in members
            if r["status"] == Status.IN_PROGRESS and r["addr"] not in rep.code_tags
        ]
        if untagged:
            raise ClaimError(
                "functions of the unit have no @orig tag (port them, or "
                "`noite unit rm` them before start next time):\n  " + "\n  ".join(untagged)
            )
        if u["path"] not in check.imported_paths(wt):
            raise ClaimError(f"{u['path']} is not imported anywhere, so its tests never run")
        stubs = unported_stubs(wt / u["path"])
        if stubs:
            raise ClaimError(
                f"{u['path']} still has skeleton stubs (replace each body, keep the signature):\n  "
                + "\n  ".join(stubs)
            )
        unit_warnings = [w for w in rep.warnings if u["path"] in w]

        commits = int(git(wt, "rev-list", "--count", "main..HEAD").stdout.strip())
        git(root, "merge", "--ff-only", paths.branch_name(unit))

        ported = [r["addr"] for r in members if r["status"] == Status.IN_PROGRESS]
        stamp = now()
        with tx(conn):
            conn.executemany(
                "UPDATE functions SET status = 'ported', status_auto = 0, agent_id = NULL, "
                "finished_at = ? WHERE addr = ?",
                [(stamp, a) for a in ported],
            )
            check.apply_tested(conn, rep)
            conn.execute(
                "UPDATE units SET status = 'done', agent_id = NULL, finished_at = ? WHERE name = ?",
                (stamp, unit),
            )
        remove_worktree(root, unit)

        pushed: bool | None = None
        if push and git(root, "remote", check_=False).stdout.strip():
            pushed = git(root, "push", check_=False).returncode == 0
    return Finished(unit, ported, commits, pushed, unit_warnings)
