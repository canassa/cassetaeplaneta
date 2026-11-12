"""The tracker database (``db/port.sqlite``): schema, connection, transactions.

Two kinds of columns live side by side in ``functions``:

* **Ghidra-derived** (name, signature, decompile, kind, …) are rewritten by
  every ``noite import``.
* **Tracking** (status, unit, agent_id, tested, notes, …) belong to the port
  workflow; import never overwrites them. The one exception is a status that
  classification set (``status_auto = 1``): it follows the function's kind until
  a person or the workflow changes it.

Concurrency: WAL mode plus ``BEGIN IMMEDIATE`` for every read-modify-write, so
several agents can claim and finish units at once. Schema changes are
append-only entries in ``MIGRATIONS``, versioned by ``PRAGMA user_version``.
"""

from __future__ import annotations

import sqlite3
from collections.abc import Iterator
from contextlib import contextmanager
from enum import StrEnum
from pathlib import Path


class Status(StrEnum):
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    PORTED = "ported"
    FAILED = "failed"
    ABSORBED = "absorbed"
    REPLACED = "replaced"
    DEAD = "dead"


# A callee in one of these states no longer blocks its callers.
DONE = frozenset({Status.PORTED, Status.ABSORBED, Status.REPLACED, Status.DEAD})


class Kind(StrEnum):
    METHOD = "method"
    THUNK = "thunk"
    DEFAULT = "default"
    TYPE_TEST = "type_test"
    CTOR = "ctor"
    DTOR = "dtor"
    CRT = "crt"
    API = "api"
    HANDLER = "handler"
    DEAD = "dead"
    PLATFORM = "platform"


class UnitKind(StrEnum):
    MODULE = "module"
    BEHAVIOUR = "behaviour"
    HANDLER = "handler"


class UnitStatus(StrEnum):
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    DONE = "done"
    FAILED = "failed"


class Oracle(StrEnum):
    """What a test's expected values come from, strongest first."""

    EMULATED = "emulated"
    ASSET = "asset"
    DOCUMENTED = "documented"
    TRACE = "trace"
    NONE = "none"


ORACLE_RANK = {o: i for i, o in enumerate(Oracle)}


def _in(values: type[StrEnum]) -> str:
    return ", ".join(f"'{v.value}'" for v in values)


MIGRATIONS: list[str] = [
    f"""
    CREATE TABLE units (
        name        TEXT PRIMARY KEY
                    CHECK (name GLOB '[a-z]*' AND name NOT GLOB '*[^a-z0-9_]*'),
        path        TEXT NOT NULL UNIQUE,   -- the unit's Zig file, repo-relative
        kind        TEXT NOT NULL CHECK (kind IN ({_in(UnitKind)})),
        notes       TEXT,
        status      TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ({_in(UnitStatus)})),
        agent_id    TEXT,
        started_at  TEXT,
        finished_at TEXT,
        attempts    INTEGER NOT NULL DEFAULT 0,
        last_error  TEXT
    );
    CREATE TABLE functions (
        addr        TEXT PRIMARY KEY,       -- seg:off, lower case, e.g. 1010:0c80
        -- Ghidra-derived (refreshed by every import)
        name        TEXT NOT NULL,
        segment     TEXT NOT NULL,
        size        INTEGER,
        signature   TEXT,
        plate       TEXT,
        decompile   TEXT,
        disasm      TEXT,
        ghidra_class TEXT,                  -- Ghidra's own classification (stub, thunk, …)
        kind        TEXT NOT NULL CHECK (kind IN ({_in(Kind)})),
        absorbed_by TEXT,                   -- for a thunk: the function it forwards to
        gone        INTEGER NOT NULL DEFAULT 0,  -- no longer in Ghidra (kept for its tracking)
        imported_at TEXT,
        -- tracking (never overwritten by import)
        status      TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ({_in(Status)})),
        status_auto INTEGER NOT NULL DEFAULT 1, -- 1 = status set by classification
        unit        TEXT REFERENCES units(name) ON DELETE SET NULL,
        agent_id    TEXT,
        started_at  TEXT,
        finished_at TEXT,
        attempts    INTEGER NOT NULL DEFAULT 0,
        tested      TEXT NOT NULL DEFAULT 'none' CHECK (tested IN ({_in(Oracle)})),
        notes       TEXT
    );
    CREATE INDEX idx_functions_name ON functions(name);
    CREATE INDEX idx_functions_unit ON functions(unit);
    CREATE INDEX idx_functions_status ON functions(status);
    CREATE TABLE callees (
        caller TEXT NOT NULL,
        callee TEXT NOT NULL,
        PRIMARY KEY (caller, callee)
    );
    CREATE INDEX idx_callees_callee ON callees(callee);
    CREATE TABLE structs (
        name     TEXT PRIMARY KEY,
        size     INTEGER,
        fields   TEXT                       -- JSON: [{{offset, size, type, name}}]
    );
    CREATE TABLE globals (
        addr     TEXT PRIMARY KEY,
        name     TEXT NOT NULL,
        type     TEXT,
        xrefs    INTEGER
    );
    CREATE TABLE meta (
        key   TEXT PRIMARY KEY,
        value TEXT
    );
    """,
]


def _statements(script: str) -> Iterator[str]:
    buf = ""
    for line in script.splitlines(keepends=True):
        buf += line
        if sqlite3.complete_statement(buf):
            yield buf
            buf = ""
    if buf.strip():
        yield buf


def apply_migrations(conn: sqlite3.Connection) -> None:
    (version,) = conn.execute("PRAGMA user_version").fetchone()
    if version >= len(MIGRATIONS):
        return
    # Re-read the version under the write lock: another process may have
    # migrated between our first read and the lock.
    with tx(conn):
        (version,) = conn.execute("PRAGMA user_version").fetchone()
        for i, script in enumerate(MIGRATIONS[version:], start=version + 1):
            for stmt in _statements(script):
                conn.execute(stmt)
            conn.execute(f"PRAGMA user_version = {i}")


def connect(path: Path) -> sqlite3.Connection:
    """Open (creating if needed) the tracker DB in autocommit mode; use :func:`tx`
    for anything that must be atomic."""
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path, timeout=60, isolation_level=None)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode = WAL")
    conn.execute("PRAGMA busy_timeout = 60000")
    conn.execute("PRAGMA foreign_keys = ON")
    apply_migrations(conn)
    return conn


@contextmanager
def tx(conn: sqlite3.Connection) -> Iterator[sqlite3.Connection]:
    """A write transaction taken up front (``BEGIN IMMEDIATE``), so two agents can
    never both read a unit as free and then both claim it."""
    conn.execute("BEGIN IMMEDIATE")
    try:
        yield conn
    except BaseException:
        conn.execute("ROLLBACK")
        raise
    conn.execute("COMMIT")


def now() -> str:
    from datetime import UTC, datetime

    return datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def norm_addr(ref: str) -> str | None:
    """``1010:0C80`` / ``1010_0c80`` / ``FUN_1010_0c80`` → ``1010:0c80``; else None."""
    import re

    m = re.fullmatch(r"(?:FUN_)?([0-9a-fA-F]{4})[:_]([0-9a-fA-F]{4})", ref.strip())
    if not m:
        return None
    return f"{m.group(1).lower()}:{m.group(2).lower()}"


def find_function(conn: sqlite3.Connection, ref: str) -> sqlite3.Row | None:
    """Look a function up by address or exact Ghidra name."""
    addr = norm_addr(ref)
    if addr is not None:
        row: sqlite3.Row | None = conn.execute(
            "SELECT * FROM functions WHERE addr = ?", (addr,)
        ).fetchone()
        if row is not None:
            return row
    rows = conn.execute("SELECT * FROM functions WHERE name = ?", (ref,)).fetchall()
    return rows[0] if len(rows) == 1 else None
