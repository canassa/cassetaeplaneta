"""noite — the port tracker for the Zig rewrite of NOITE.EXE.

noite import              snapshot Ghidra into db/port.sqlite (re-runnable)
noite status              progress by status / kind / segment / unit
noite show FN             one function: row, callees, decompile
noite next                units ready to claim
noite start UNIT          claim a unit and make its worktree
noite finish UNIT         gate, merge to main, mark ported
noite failed UNIT REASON  give up on a claim, recording why
noite release UNIT        give a claim back untouched
noite check               @orig tags vs the DB
noite build / test        zig build / zig build test (-w UNIT for a worktree)
noite unit …              create units and assign functions
"""

from __future__ import annotations

import sqlite3
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Annotated

import typer

from noite import check as checkmod
from noite import claim, importer, paths, units
from noite.db import Status, UnitKind, connect, find_function, tx

app = typer.Typer(name="noite", help=__doc__, no_args_is_help=True, add_completion=False)
unit_app = typer.Typer(help="Port units: one Zig file each.", no_args_is_help=True)
app.add_typer(unit_app, name="unit")

WorkOpt = Annotated[
    str | None, typer.Option("--work", "-w", help="Operate on the worktree of this unit.")
]


def _db() -> sqlite3.Connection:
    return connect(paths.db_path())


def _die(msg: str) -> None:
    typer.echo(f"error: {msg}", err=True)
    raise typer.Exit(1)


def _table(rows: list[list[str]], header: list[str]) -> None:
    allrows = [header, *rows]
    widths = [max(len(r[i]) for r in allrows) for i in range(len(header))]
    for i, r in enumerate(allrows):
        typer.echo("  ".join(c.ljust(w) for c, w in zip(r, widths, strict=True)).rstrip())
        if i == 0:
            typer.echo("  ".join("-" * w for w in widths))


def _tree(work: str | None) -> Path:
    root = paths.repo_root()
    if work:
        wt = paths.worktree_path(root, work)
        if not wt.is_dir():
            _die(f"no worktree for unit {work} at {wt}")
        return wt
    return paths.tree_root()


# --------------------------------------------------------------------------- #
# import / status / show
# --------------------------------------------------------------------------- #


@app.command("import")
def import_cmd(
    url: Annotated[
        str, typer.Option(help="ghidra-mcp bridge endpoint.")
    ] = "http://127.0.0.1:8000/mcp",
    program: Annotated[str, typer.Option(help="Ghidra program name.")] = "NOITE.EXE",
    no_decompile: Annotated[
        bool, typer.Option("--no-decompile", help="Keep stored decompiles (fast refresh).")
    ] = False,
    no_types: Annotated[bool, typer.Option("--no-types", help="Skip structs and globals.")] = False,
) -> None:
    """Snapshot every function (and structs/globals) from Ghidra. Read-only on Ghidra."""
    from noite.ghidra import GhidraError, GhidraSource, McpClient

    conn = _db()
    src = GhidraSource(McpClient(url), program)

    def progress(done: int, total: int) -> None:
        typer.echo(f"\r  {done}/{total} functions", nl=done == total, err=True)

    try:
        res = importer.run(
            conn, src, decompile=not no_decompile, with_types=not no_types, progress=progress
        )
    except GhidraError as e:
        _die(str(e))
    typer.echo(
        f"imported {res.functions} functions ({res.new} new, {res.gone} gone), "
        f"{res.callees} call edges, {res.structs} structs, {res.globals} globals; "
        f"seeded {res.handler_units} handler units"
    )
    typer.echo("kinds: " + ", ".join(f"{k} {n}" for k, n in res.kinds.most_common()))


@app.command()
def status(
    by_segment: Annotated[
        bool, typer.Option("--segments", help="Add the per-segment table.")
    ] = False,
) -> None:
    """Progress: functions by status and kind, units by state."""
    conn = _db()
    rows = conn.execute(
        "SELECT kind, status, segment, unit FROM functions WHERE gone = 0"
    ).fetchall()
    statuses = [s.value for s in Status]
    by_status = Counter(r["status"] for r in rows)
    typer.echo(
        f"{len(rows)} functions: "
        + ", ".join(f"{s} {by_status[s]}" for s in statuses if by_status[s])
    )
    typer.echo()
    present = [s for s in statuses if by_status[s]]

    def grid(key: str) -> None:
        cnt: dict[str, Counter[str]] = defaultdict(Counter)
        for r in rows:
            cnt[r[key]][r["status"]] += 1
        _table(
            [
                [k, str(sum(c.values())), *(str(c[s] or "") for s in present)]
                for k, c in sorted(cnt.items())
            ],
            [key, "total", *present],
        )
        typer.echo()

    grid("kind")
    if by_segment:
        grid("segment")
    states = claim.unit_states(conn)
    if states:
        ucount = Counter(s.status for s in states)
        typer.echo(
            f"{len(states)} units: "
            + ", ".join(f"{k} {v}" for k, v in sorted(ucount.items()))
            + f"; ready {sum(s.ready for s in states)}"
        )
        unassigned = sum(1 for r in rows if r["unit"] is None and r["status"] == Status.PENDING)
        typer.echo(f"pending functions with no unit: {unassigned}")


@app.command()
def show(
    fn: Annotated[str, typer.Argument(help="Address (1010:0c80) or exact Ghidra name.")],
    asm: Annotated[bool, typer.Option("--asm", help="Also print the disassembly.")] = False,
) -> None:
    """One function: tracking row, callers/callees, plate and decompilation."""
    conn = _db()
    f = find_function(conn, fn)
    if f is None:
        like = conn.execute(
            "SELECT addr, name FROM functions WHERE name LIKE ? ORDER BY addr LIMIT 20",
            (f"%{fn}%",),
        ).fetchall()
        _die(
            f"no function {fn!r}"
            + (
                "; did you mean: " + ", ".join(f"{r['addr']} {r['name']}" for r in like)
                if like
                else ""
            )
        )
        return
    typer.echo(f"{f['addr']}  {f['name']}")
    typer.echo(
        f"  kind {f['kind']}  status {f['status']}  unit {f['unit'] or '-'}  "
        f"tested {f['tested']}  size {f['size']}" + ("  GONE from Ghidra" if f["gone"] else "")
    )
    if f["absorbed_by"]:
        typer.echo(f"  absorbed by {f['absorbed_by']}")
    if f["agent_id"]:
        typer.echo(f"  agent {f['agent_id']} since {f['started_at']}")
    if f["notes"]:
        typer.echo(f"  notes: {f['notes']}")
    typer.echo(f"  {f['signature']}")
    for label, sql in (
        (
            "calls",
            "SELECT g.addr, g.name, g.status, g.unit FROM callees c JOIN functions g "
            "ON g.addr = c.callee WHERE c.caller = ? ORDER BY g.addr",
        ),
        (
            "called by",
            "SELECT g.addr, g.name, g.status, g.unit FROM callees c JOIN functions g "
            "ON g.addr = c.caller WHERE c.callee = ? ORDER BY g.addr",
        ),
    ):
        rel = conn.execute(sql, (f["addr"],)).fetchall()
        if rel:
            typer.echo(f"  {label}:")
            for r in rel:
                typer.echo(
                    f"    {r['addr']} {r['name']} [{r['status']}"
                    + (f", {r['unit']}]" if r["unit"] else "]")
                )
    typer.echo(f["decompile"] or "\n// (no decompilation stored)")
    if asm:
        typer.echo(f["disasm"] or "")


@app.command()
def mark(
    fns: Annotated[list[str], typer.Argument(help="Addresses or names.")],
    to: Annotated[Status, typer.Option("--status", "-s", help="New status.")],
    by: Annotated[str | None, typer.Option(help="absorbed_by target (with -s absorbed).")] = None,
    note: Annotated[str | None, typer.Option(help="Note to record.")] = None,
) -> None:
    """Set functions' status by hand (e.g. dead code the classifier missed)."""
    conn = _db()
    with tx(conn):
        for ref in fns:
            f = find_function(conn, ref)
            if f is None:
                _die(f"no function {ref!r}")
                return
            target = None
            if by:
                t = find_function(conn, by)
                if t is None:
                    _die(f"no function {by!r}")
                    return
                target = t["addr"]
            conn.execute(
                "UPDATE functions SET status = ?, status_auto = 0, "
                "absorbed_by = COALESCE(?, absorbed_by), notes = COALESCE(?, notes) WHERE addr = ?",
                (to.value, target, note, f["addr"]),
            )
            typer.echo(f"{f['addr']} {f['name']}: {f['status']} -> {to.value}")


# --------------------------------------------------------------------------- #
# claim workflow
# --------------------------------------------------------------------------- #


@app.command("next")
def next_cmd(
    blocked: Annotated[
        bool, typer.Option("--blocked", help="Also list blocked units and why.")
    ] = False,
) -> None:
    """Units ready to claim: every callee outside the unit is done."""
    conn = _db()
    states = claim.unit_states(conn)
    ready = [s for s in states if s.ready]
    ready.sort(key=lambda s: (s.status == "failed", s.name))
    if ready:
        _table(
            [[s.name, s.kind, f"{s.todo}/{s.total}", s.status] for s in ready],
            ["ready unit", "kind", "todo", "status"],
        )
    else:
        typer.echo("no unit is ready")
    if blocked:
        typer.echo()
        for s in states:
            if s.blockers and s.status in ("pending", "failed") and s.todo:
                typer.echo(
                    f"{s.name}: blocked by "
                    + ", ".join(
                        f"{b.addr} {b.name} [{b.status}, {b.unit or 'no unit'}]"
                        for b in s.blockers[:8]
                    )
                    + (f" … +{len(s.blockers) - 8}" if len(s.blockers) > 8 else "")
                )


@app.command()
def start(
    unit: str,
    agent: Annotated[str | None, typer.Option(help="Agent id (default $NOITE_AGENT).")] = None,
    force: Annotated[
        bool, typer.Option("--force", help="Claim even if callees are unported.")
    ] = False,
) -> None:
    """Claim UNIT (atomically) and create its worktree work/UNIT on branch port/UNIT."""
    conn = _db()
    try:
        s = claim.start(conn, paths.repo_root(), unit, agent or claim.agent_id(), force=force)
    except (claim.ClaimError, units.UnitError) as e:
        _die(str(e))
        return
    typer.echo(f"claimed {s.unit} as {s.agent}")
    typer.echo(f"  worktree  {s.worktree}  (branch {s.branch})")
    typer.echo(f"  unit file {s.path}")
    typer.echo(f"  reference {s.worktree / '.ref'}  (decompile + disasm per function)")
    typer.echo("  functions:")
    for f in s.functions:
        typer.echo(f"    {f['addr']} {f['name']} [{f['kind']}, {f['status']}]")
    typer.echo(
        f"next: cd {s.worktree}; write {s.path} with one `// @orig <addr> <name>` per function;\n"
        f"      `uv run noite test`, commit, then `uv run noite finish {s.unit}`"
    )


@app.command()
def finish(
    unit: str,
    no_push: Annotated[bool, typer.Option("--no-push", help="Don't push main.")] = False,
) -> None:
    """Rebase UNIT's branch on main, run the gates, fast-forward main, mark ported."""
    conn = _db()
    try:
        r = claim.finish(conn, paths.repo_root(), unit, push=not no_push)
    except (claim.ClaimError, units.UnitError) as e:
        _die(str(e))
        return
    typer.echo(f"{unit}: {len(r.ported)} functions ported, {r.commits} commits merged into main")
    for w in r.warnings:
        typer.echo(f"  warning: {w}")
    if r.pushed is False:
        typer.echo("  warning: push failed; main is ahead of the remote", err=True)


@app.command()
def failed(
    unit: str,
    reason: str,
    keep: Annotated[
        bool, typer.Option("--keep", "-k", help="Keep the worktree and branch.")
    ] = False,
) -> None:
    """Abandon a claim, recording REASON; the unit becomes a retry target."""
    conn = _db()
    try:
        claim.failed(conn, paths.repo_root(), unit, reason, keep=keep)
    except (claim.ClaimError, units.UnitError) as e:
        _die(str(e))
    typer.echo(f"{unit}: failed ({reason})")


@app.command()
def release(
    unit: str,
    keep: Annotated[
        bool, typer.Option("--keep", "-k", help="Keep the worktree and branch.")
    ] = False,
) -> None:
    """Give a claim back (unit pending again); removes the worktree unless --keep."""
    conn = _db()
    try:
        claim.release(conn, paths.repo_root(), unit, keep=keep)
    except (claim.ClaimError, units.UnitError) as e:
        _die(str(e))
    typer.echo(f"{unit}: released")


@app.command()
def path(unit: str) -> None:
    """Print UNIT's worktree path (cd $(uv run noite path UNIT))."""
    typer.echo(paths.worktree_path(paths.repo_root(), unit))


# --------------------------------------------------------------------------- #
# check / build / test
# --------------------------------------------------------------------------- #


@app.command()
def check(
    work: WorkOpt = None,
    fix_status: Annotated[
        bool, typer.Option("--fix-status", help="Sync statuses and `tested` from the tags.")
    ] = False,
) -> None:
    """Check @orig tags against the DB (unknown addresses, duplicates, untagged ports)."""
    conn = _db()
    root = _tree(work)
    rep = checkmod.run(conn, root)
    for w in rep.warnings:
        typer.echo(f"warning: {w}")
    for e in rep.errors:
        typer.echo(f"error: {e}")
    tested = Counter(rep.tested.values())
    typer.echo(
        f"{sum(len(v) for v in rep.code_tags.values())} code tags, "
        f"{len(rep.tested)} tested functions"
        + (" (" + ", ".join(f"{k.value} {n}" for k, n in tested.items()) + ")" if tested else "")
        + f"; {len(rep.errors)} errors, {len(rep.warnings)} warnings"
    )
    if fix_status:
        fx = checkmod.fix_status(conn, rep)
        typer.echo(
            f"fixed: {len(fx.ported)} -> ported, {len(fx.unported)} -> pending, "
            f"{fx.tested} tested updated"
        )
    if not rep.ok:
        raise typer.Exit(1)


# The port always builds in Debug with Zig's self-hosted backend: LLVM is far
# too slow for the edit-build loop.
_FORBIDDEN = ("-Doptimize=Release", "-fllvm", "-flld", "--release")


def _zig(work: str | None, args: list[str]) -> None:
    bad = [a for a in args if a.startswith(_FORBIDDEN)]
    if bad:
        _die(f"{' '.join(bad)}: the port builds in Debug with the self-hosted backend only")
    root = _tree(work)
    try:
        code = subprocess.call(["zig", "build", *args], cwd=root)
    except FileNotFoundError:
        _die("zig not on PATH — run inside the dev shell (`nix develop` / direnv)")
        return
    raise typer.Exit(code)


@app.command(context_settings={"allow_extra_args": True, "ignore_unknown_options": True})
def build(ctx: typer.Context, work: WorkOpt = None) -> None:
    """`zig build` in the current tree (or UNIT's worktree with -w); extra args pass through."""
    _zig(work, list(ctx.args))


@app.command(context_settings={"allow_extra_args": True, "ignore_unknown_options": True})
def test(ctx: typer.Context, work: WorkOpt = None) -> None:
    """`zig build test` in the current tree (or UNIT's worktree with -w)."""
    _zig(work, ["test", *ctx.args])


# --------------------------------------------------------------------------- #
# units
# --------------------------------------------------------------------------- #


@unit_app.command("new")
def unit_new(
    name: str,
    kind: Annotated[UnitKind, typer.Option("--kind", "-k")] = UnitKind.MODULE,
    file: Annotated[str | None, typer.Option("--path", help="Zig file (default by kind).")] = None,
    notes: Annotated[str | None, typer.Option(help="What the unit covers.")] = None,
) -> None:
    """Create a unit (then `noite unit sync` writes its stub and the index)."""
    conn = _db()
    try:
        with tx(conn):
            p = units.create(conn, name, kind, file, notes)
    except units.UnitError as e:
        _die(str(e))
        return
    typer.echo(f"unit {name} ({kind.value}) -> {p}")


@unit_app.command("add")
def unit_add(
    unit: str,
    fns: Annotated[list[str] | None, typer.Argument(help="Addresses or names.")] = None,
    match: Annotated[
        str | None, typer.Option(help="Also every function whose name GLOBs this.")
    ] = None,
    move: Annotated[bool, typer.Option("--move", help="Take functions from other units.")] = False,
) -> None:
    """Assign functions to UNIT."""
    conn = _db()
    try:
        with tx(conn):
            n = units.add(conn, unit, units.resolve_functions(conn, fns or [], match), move=move)
    except units.UnitError as e:
        _die(str(e))
        return
    typer.echo(f"{unit}: +{n} functions")


@unit_app.command("rm")
def unit_rm(fns: Annotated[list[str], typer.Argument(help="Addresses or names.")]) -> None:
    """Take functions out of their unit."""
    conn = _db()
    try:
        with tx(conn):
            n = units.remove(conn, units.resolve_functions(conn, fns))
    except units.UnitError as e:
        _die(str(e))
        return
    typer.echo(f"removed {n} functions from their units")


@unit_app.command("show")
def unit_show(unit: str) -> None:
    """A unit and its functions."""
    conn = _db()
    try:
        u = units.get(conn, unit)
    except units.UnitError as e:
        _die(str(e))
        return
    typer.echo(
        f"{u['name']} ({u['kind']}) -> {u['path']}  [{u['status']}]"
        + (f" by {u['agent_id']} since {u['started_at']}" if u["agent_id"] else "")
    )
    if u["notes"]:
        typer.echo(f"  {u['notes']}")
    if u["last_error"]:
        typer.echo(f"  last failure: {u['last_error']}")
    rows = conn.execute("SELECT * FROM functions WHERE unit = ? ORDER BY addr", (unit,)).fetchall()
    _table(
        [[r["addr"], r["name"], r["kind"], r["status"], r["tested"]] for r in rows],
        ["addr", "name", "kind", "status", "tested"],
    )
    bl = claim.blockers(conn, unit)
    if bl:
        typer.echo(
            f"blocked by {len(bl)}: " + ", ".join(f"{b.addr} {b.name} [{b.status}]" for b in bl)
        )


@unit_app.command("list")
def unit_list(
    kind: Annotated[UnitKind | None, typer.Option("--kind", "-k")] = None,
) -> None:
    """Every unit with its progress."""
    conn = _db()
    states = [s for s in claim.unit_states(conn) if kind is None or s.kind == kind.value]
    agents = {r["name"]: r["agent_id"] for r in conn.execute("SELECT name, agent_id FROM units")}
    _table(
        [
            [
                s.name,
                s.kind,
                s.status,
                f"{s.total - s.todo}/{s.total}",
                "yes" if s.ready else ("" if not s.blockers else f"{len(s.blockers)} blockers"),
                agents.get(s.name) or "",
            ]
            for s in states
        ],
        ["unit", "kind", "status", "done", "ready", "agent"],
    )


@unit_app.command("sync")
def unit_sync() -> None:
    """Write missing unit stubs and regenerate src/units.zig (main checkout only)."""
    conn = _db()
    root = paths.repo_root()
    if paths.tree_root() != root:
        _die("run `noite unit sync` in the main checkout, not a worktree")
    r = units.sync(conn, root)
    typer.echo(
        f"{len(r.stubs)} stubs written; index {'updated' if r.index_changed else 'unchanged'}"
    )


def main() -> None:
    try:
        app()
    except subprocess.CalledProcessError as e:
        typer.echo(f"error: {e.cmd[0]} failed: {e.stderr or e}", err=True)
        sys.exit(1)
