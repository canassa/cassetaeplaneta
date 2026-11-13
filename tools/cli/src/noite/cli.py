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
noite initdata            defaults of @orig g_* fields vs the EXE's initial data
noite build / test        zig build / zig build test (-w UNIT for a worktree)
noite unit …              create units and assign functions
"""

from __future__ import annotations

import json
import re
import sqlite3
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Annotated

import typer

from noite import check as checkmod
from noite import claim, deps, importer, initdata, paths, plan, types, units
from noite.db import Status, UnitKind, connect, find_function, norm_addr, tx

app = typer.Typer(name="noite", help=__doc__, no_args_is_help=True, add_completion=False)
unit_app = typer.Typer(help="Port units: one Zig file each.", no_args_is_help=True)
app.add_typer(unit_app, name="unit")
dep_app = typer.Typer(
    help="Unit dependencies: manual (hard) and virtual-call auto (soft).", no_args_is_help=True
)
unit_app.add_typer(dep_app, name="dep")
plan_app = typer.Typer(help="The committed unit plan (db/plan.tsv).", no_args_is_help=True)
app.add_typer(plan_app, name="plan")

WorkOpt = Annotated[
    str | None, typer.Option("--work", "-w", help="Operate on the worktree of this unit.")
]


def _db() -> sqlite3.Connection:
    return connect(paths.db_path())


def _plan_sync(conn: sqlite3.Connection) -> None:
    """Keep db/plan.tsv in step with the DB after a plan-changing command (main checkout
    only: worktrees never edit db/)."""
    root = paths.repo_root()
    if paths.tree_root() != root:
        return
    if plan.write(conn, root / plan.PLAN_REL):
        typer.echo(f"  {plan.PLAN_REL} updated (commit it)", err=True)


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
            conn,
            src,
            decompile=not no_decompile,
            with_types=not no_types,
            progress=progress,
            plan_file=paths.repo_root() / plan.PLAN_REL,
        )
    except GhidraError as e:
        _die(str(e))
    typer.echo(
        f"imported {res.functions} functions ({res.new} new, {res.gone} gone), "
        f"{res.callees} call edges, {res.structs} structs, {res.globals} globals, "
        f"{res.vtables} vtables "
        f"({res.struct_refs} struct and {res.global_refs} global references); "
        f"seeded {res.handler_units} handler units"
    )
    typer.echo("kinds: " + ", ".join(f"{k} {n}" for k, n in res.kinds.most_common()))
    if res.plan:
        p = res.plan
        typer.echo(
            f"applied {plan.PLAN_REL}: {p.units} units, {p.functions} assignments, "
            f"{p.statuses} statuses, {p.deps} deps ({p.skipped} skipped); "
            "run `noite check --fix-status` for ported functions"
        )


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
    fn: Annotated[
        str,
        typer.Argument(
            help="Function address (1010:0c80) or name, or a vtable, struct or global name/address."
        ),
    ],
    asm: Annotated[bool, typer.Option("--asm", help="Also print the disassembly.")] = False,
) -> None:
    """One function (tracking row, callers/callees, decompilation), or a vtable's slots,
    or a struct or global."""
    conn = _db()
    f = find_function(conn, fn)
    if f is None and (_show_vtable(conn, fn) or _show_type(conn, fn)):
        return
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


def _show_vtable(conn: sqlite3.Connection, ref: str) -> bool:
    """Print a vtable's slots and the functions they point to."""
    addr = norm_addr(ref)
    vt = conn.execute(
        "SELECT * FROM vtables WHERE name = ? OR addr = ?", (ref, addr or ref)
    ).fetchone()
    if vt is None:
        return False
    st = conn.execute("SELECT fields FROM structs WHERE name = ?", (vt["type"],)).fetchone()
    names = {f["offset"] // 4: f["name"] for f in json.loads(st["fields"] or "[]")} if st else {}
    funcs = {r["addr"]: r for r in conn.execute("SELECT * FROM functions")}
    slots = json.loads(vt["slots"] or "[]")
    typer.echo(
        f"{vt['addr']}  {vt['name']}  ({vt['type']}, {vt['size']} bytes, {len(slots)} slots)"
    )

    def label(f: sqlite3.Row) -> str:
        return f"{f['name']} [{f['status']}" + (f", {f['unit']}]" if f["unit"] else "]")

    rows = []
    for i, target in enumerate(slots):
        f = funcs.get(target)
        if f is None:
            desc = "-" if target == "0000:0000" else "(no function)"
        else:
            real = funcs.get(deps.resolve_thunk(funcs, target))
            desc = (
                f"{f['name']} -> {real['addr']} {label(real)}"
                if real is not None and real["addr"] != target
                else label(f)
            )
        rows.append([f"{i:02x}", names.get(i, ""), target, desc])
    _table(rows, ["slot", "field", "target", "function"])
    return True


def _show_type(conn: sqlite3.Connection, ref: str) -> bool:
    """Print a struct's layout or a global's declaration, with the functions using it."""
    st = conn.execute("SELECT * FROM structs WHERE name = ?", (ref,)).fetchone()
    addr = norm_addr(ref)
    globs = conn.execute(
        "SELECT * FROM globals WHERE name = ? OR addr = ?", (ref, addr or ref)
    ).fetchall()
    if st is None and not globs:
        return False

    def users(sql: str, key: str) -> None:
        rows = conn.execute(sql, (key,)).fetchall()
        if rows:
            typer.echo(f"  used by {len(rows)}: " + ", ".join(f"{r['name']}" for r in rows[:30]))
            if len(rows) > 30:
                typer.echo(f"    … +{len(rows) - 30} more")

    if st is not None:
        typer.echo(types.render_struct(st))
        users(
            "SELECT f.name FROM function_structs s JOIN functions f ON f.addr = s.func "
            "WHERE s.name = ? ORDER BY f.addr",
            ref,
        )
    for g in globs:
        typer.echo(types.render_global(g))
        users(
            "SELECT f.name FROM function_globals s JOIN functions f ON f.addr = s.func "
            "WHERE s.global = ? ORDER BY f.addr",
            g["addr"],
        )
        nested = types.closure(conn, [n for n in re.findall(r"[A-Za-z_]\w*", g["type"] or "")])
        if nested:
            typer.echo(f"  type layouts: noite show {nested[0]}")
    return True


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
    _plan_sync(conn)


# --------------------------------------------------------------------------- #
# claim workflow
# --------------------------------------------------------------------------- #


@app.command("next")
def next_cmd(
    blocked: Annotated[
        bool, typer.Option("--blocked", help="Also list blocked units and why.")
    ] = False,
) -> None:
    """Units ready to claim: every callee outside the unit is done and every unit it
    depends on by a manual dep is done (virtual-call `auto` deps are soft: listed by
    --blocked, never blocking)."""
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
        in_cycle = deps.cycle_members(conn)
        for s in states:
            if not (s.status in ("pending", "failed") and s.todo and not s.ready):
                continue
            parts = []
            if s.blockers:
                parts.append(
                    "calls "
                    + ", ".join(
                        f"{b.addr} {b.name} [{b.status}, {b.unit or 'no unit'}]"
                        for b in s.blockers[:8]
                    )
                    + (f" … +{len(s.blockers) - 8}" if len(s.blockers) > 8 else "")
                )
            if s.dep_blockers:
                parts.append("depends (manual) on units " + ", ".join(s.dep_blockers))
            cyc = in_cycle(s.name)
            if cyc:
                parts.append("in dependency cycle " + " <-> ".join(cyc))
            typer.echo(f"{s.name}: blocked by " + "; ".join(parts))
            if s.soft_blockers:
                typer.echo("  soft: virtual-call owners not done: " + ", ".join(s.soft_blockers))


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
    typer.echo(f"  reference {s.worktree / '.ref'}  (decompile + disasm per function, types.md)")
    typer.echo(
        f"  env       source {s.worktree / '.ref' / 'env.sh'}  (shared venv, no nix dirty warning)"
    )
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
    rep = checkmod.run(conn, root, unit=work)
    for w in rep.warnings:
        typer.echo(f"warning: {w}")
    for e in rep.errors:
        typer.echo(f"error: {e}")
    tested = Counter(rep.tested.values())
    typer.echo(
        ("check ok: " if rep.ok else "check FAILED: ")
        + f"{sum(len(v) for v in rep.code_tags.values())} code tags, "
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


@app.command("initdata")
def initdata_cmd(
    work: WorkOpt = None,
    verbose: Annotated[bool, typer.Option("--verbose", "-v", help="List matches too.")] = False,
) -> None:
    """Compare the defaults of fields tagged `// @orig g_*` with the EXE's initial data."""
    conn = _db()
    root = _tree(work)
    exe = paths.repo_root() / "assets" / "NOITE.EXE"
    try:
        results, skipped = initdata.run(conn, root, exe)
    except FileNotFoundError:
        _die("zig not on PATH — run inside the dev shell (`nix develop` / direnv)")
        return
    except RuntimeError as e:
        _die(str(e))
        return
    bad = [r for r in results if not r.ok]
    for r in results:
        if verbose or not r.ok:
            f = r.field
            mark = "ok  " if r.ok else "DIFF"
            names = " / ".join(f.globals)
            typer.echo(f"{mark} {f.path}:{f.line} {f.struct}.{f.name} ({names}): {r.detail}")
    for why in skipped.values():
        typer.echo(f"skip {why}")
    typer.echo(
        ("initdata ok: " if not bad else "initdata FAILED: ")
        + f"{len(results)} fields compared, {len(bad)} differ, {len(skipped)} skipped"
    )
    if bad:
        raise typer.Exit(1)


# The port always builds in Debug with Zig's self-hosted backend: LLVM is far
# too slow for the edit-build loop.
_FORBIDDEN = ("-Doptimize=Release", "-fllvm", "-flld", "--release")


def _zig(work: str | None, args: list[str], what: str) -> None:
    bad = [a for a in args if a.startswith(_FORBIDDEN)]
    if bad:
        _die(f"{' '.join(bad)}: the port builds in Debug with the self-hosted backend only")
    root = _tree(work)
    # Zig is silent on success; ask for its summary so we can report one line.
    quiet = not any(a.startswith("--summary") for a in args)
    cmd = ["zig", "build", *args, *(["--summary", "all"] if quiet else [])]
    try:
        p = subprocess.run(cmd, cwd=root, capture_output=quiet, text=True)
    except FileNotFoundError:
        _die("zig not on PATH — run inside the dev shell (`nix develop` / direnv)")
        return
    if quiet:
        out = p.stdout + p.stderr
        if p.returncode != 0:
            typer.echo(out, nl=False, err=True)
            typer.echo(f"{what} FAILED (exit {p.returncode})", err=True)
        else:
            typer.echo(_zig_summary(out, what))
    raise typer.Exit(p.returncode)


def _zig_summary(out: str, what: str) -> str:
    """One line from `zig build --summary all` output."""
    m = re.search(r"(\d+)/(\d+) tests passed", out)
    if m:
        return f"{what} ok: {m.group(1)}/{m.group(2)} tests passed"
    m = re.search(r"(\d+)/(\d+) steps succeeded(?: \((\d+) cached\))?", out)
    if m:
        cached = f", {m.group(3)} cached" if m.group(3) else ""
        return f"{what} ok: {m.group(1)}/{m.group(2)} steps succeeded{cached}"
    return f"{what} ok"


@app.command(context_settings={"allow_extra_args": True, "ignore_unknown_options": True})
def build(ctx: typer.Context, work: WorkOpt = None) -> None:
    """`zig build` in the current tree (or UNIT's worktree with -w); extra args pass through."""
    _zig(work, list(ctx.args), "build")


@app.command(context_settings={"allow_extra_args": True, "ignore_unknown_options": True})
def test(ctx: typer.Context, work: WorkOpt = None) -> None:
    """`zig build test` in the current tree (or UNIT's worktree with -w)."""
    _zig(work, ["test", *ctx.args], "test")


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
    _plan_sync(conn)


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
    _plan_sync(conn)


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
    _plan_sync(conn)


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
    done = deps.done_units(conn)
    db = deps.dep_blockers(conn, unit, done)
    if db:
        typer.echo("depends (manual) on units not done: " + ", ".join(db))
    soft = deps.dep_blockers(conn, unit, done, source="auto")
    if soft:
        typer.echo("soft: virtual-call owners not done: " + ", ".join(soft))


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
                "yes"
                if s.ready
                else (
                    f"{len(s.blockers)} blockers + {len(s.dep_blockers)} units"
                    if s.blockers and s.dep_blockers
                    else f"{len(s.blockers)} blockers"
                    if s.blockers
                    else f"{len(s.dep_blockers)} units"
                    if s.dep_blockers
                    else ""
                ),
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


# --------------------------------------------------------------------------- #
# unit dependencies
# --------------------------------------------------------------------------- #


@dep_app.command("add")
def dep_add(
    unit: str,
    depends_on: str,
    note: Annotated[str | None, typer.Option(help="Why.")] = None,
) -> None:
    """UNIT cannot start until DEPENDS_ON is done (manual; kept by `infer`)."""
    conn = _db()
    try:
        with tx(conn):
            deps.add(conn, unit, depends_on, note)
    except deps.DepError as e:
        _die(str(e))
    typer.echo(f"{unit} depends on {depends_on}")
    _plan_sync(conn)


@dep_app.command("rm")
def dep_rm(unit: str, depends_on: str) -> None:
    """Drop a dependency (an `auto` one returns on the next `infer`)."""
    conn = _db()
    with tx(conn):
        gone = deps.remove(conn, unit, depends_on)
    if not gone:
        _die(f"{unit} does not depend on {depends_on}")
    typer.echo(f"removed {unit} -> {depends_on}")
    _plan_sync(conn)


@dep_app.command("show")
def dep_show(unit: str) -> None:
    """What UNIT depends on, and which units depend on it."""
    conn = _db()
    try:
        units.get(conn, unit)
    except units.UnitError as e:
        _die(str(e))
    done = deps.done_units(conn)

    def rows(items: list[sqlite3.Row], key: str) -> list[list[str]]:
        return [
            [
                r[key],
                "done" if r[key] in done else "todo",
                "auto (soft)" if r["source"] == "auto" else r["source"],
                r["note"] or "",
            ]
            for r in items
        ]

    header = ["unit", "state", "source", "note"]
    typer.echo(f"{unit} depends on:")
    _table(rows(deps.deps_of(conn, unit), "depends_on"), header)
    typer.echo(f"\nunits depending on {unit}:")
    _table(rows(deps.dependents_of(conn, unit), "unit"), header)


@dep_app.command("infer")
def dep_infer() -> None:
    """Derive `auto` deps from the virtual slots each function calls (replaces
    `auto`, keeps `manual`). Slot owners: docs/DESIGN.md + noite/deps.py."""
    conn = _db()
    design = paths.repo_root() / "docs" / "DESIGN.md"
    try:
        with tx(conn):
            r = deps.infer(conn, design)
    except (deps.DepError, OSError) as e:
        _die(str(e))
        return
    typer.echo(
        f"{r.deps} auto deps from {r.functions} functions with virtual calls "
        f"({r.kept_manual} already manual; {r.skipped_no_unit} calls from functions with no unit; "
        f"{r.guessed} raw offsets guessed as SceneObject slots)"
    )
    if r.unmapped:
        typer.echo(f"{len(r.unmapped)} slots with no owning unit (no dep added):")
        for k, why in sorted(r.unmapped.items()):
            typer.echo(f"  {k}: {why}")
    if r.unresolved:
        typer.echo(
            f"{len(r.unresolved)} functions call virtual slots whose vtable is unknown "
            "(offset only; no dep added):"
        )
        for addr, offs in sorted(r.unresolved.items())[:20]:
            typer.echo(f"  {addr}: " + " ".join(f"+{o:#x}" for o in offs))
        if len(r.unresolved) > 20:
            typer.echo(f"  … +{len(r.unresolved) - 20}")
    cyc = deps.cycles(conn)
    if cyc:
        typer.echo(f"{len(cyc)} dependency cycles on hard deps (see `noite unit dep cycles`)")


@dep_app.command("cycles")
def dep_cycles(
    all_: Annotated[
        bool, typer.Option("--all", help="Also count soft virtual-call (auto) deps.")
    ] = False,
) -> None:
    """Groups of units that block each other (none of them can become ready). Hard
    edges only: direct calls into unported functions of another unit, and manual deps."""
    conn = _db()
    comps = deps.cycles(conn, include_auto=all_)
    if not comps:
        typer.echo("no dependency cycles" + (" (incl. auto deps)" if all_ else " on hard deps"))
        return
    for i, c in enumerate(comps, 1):
        typer.echo(f"cycle {i}: {len(c.units)} units: {', '.join(c.units)}")
        for e in c.edges:
            what = f"call: {e.note}" if e.source == "call" else f"[{e.source}] {e.note}"
            typer.echo(f"  {e.unit} -> {e.on}  {what}".rstrip())
    typer.echo(
        "break one by moving functions between units / merging units (call edges), "
        "or `noite unit dep rm A B` (a manual dep)"
    )


@plan_app.command("export")
def plan_export() -> None:
    """Write db/plan.tsv from the DB (main checkout)."""
    conn = _db()
    root = paths.repo_root()
    changed = plan.write(conn, root / plan.PLAN_REL)
    typer.echo(f"{plan.PLAN_REL} {'updated' if changed else 'unchanged'}")


@plan_app.command("apply")
def plan_apply() -> None:
    """Load db/plan.tsv into the DB (adds and updates; never clears)."""
    conn = _db()
    f = paths.repo_root() / plan.PLAN_REL
    if not f.exists():
        _die(f"no {plan.PLAN_REL}")
    try:
        with tx(conn):
            r = plan.apply(conn, f.read_text())
    except (plan.PlanError, sqlite3.DatabaseError) as e:
        _die(str(e))
        return
    typer.echo(
        f"applied: {r.units} units, {r.functions} assignments, {r.statuses} statuses, "
        f"{r.deps} deps ({r.skipped} skipped: not in the DB)"
    )


def main() -> None:
    try:
        app()
    except subprocess.CalledProcessError as e:
        typer.echo(f"error: {e.cmd[0]} failed: {e.stderr or e}", err=True)
        sys.exit(1)
