"""Struct and global declarations, and which functions touch them.

Ghidra's snapshot gives structs (name, size, fields) and named globals (address,
type). Two things are derived here and stored by ``noite import``: a size for
each global (from its type string) and, per function, the structs and globals
its signature or decompilation mentions. The reference heuristic is lexical (a
whole-word match of the name), which is good enough: Ghidra's decompiler spells
a struct by its type name in casts, locals and signatures, and a global by its
label.
"""

from __future__ import annotations

import json
import re
import sqlite3
from collections.abc import Iterable, Mapping

_TOKEN = re.compile(r"[A-Za-z_]\w*")

# 16-bit Win16 MSVC sizes.
_BASE_SIZES = {
    "char": 1, "uchar": 1, "byte": 1, "undefined": 1, "undefined1": 1, "bool": 1,
    "schar": 1, "sbyte": 1,
    "short": 2, "ushort": 2, "int": 2, "uint": 2, "word": 2, "undefined2": 2,
    "long": 4, "ulong": 4, "dword": 4, "undefined4": 4, "float": 4,
    "longlong": 8, "double": 8, "qword": 8, "undefined8": 8,
}  # fmt: skip
_ARRAY = re.compile(r"\[(\d+)\]")


def type_size(type_str: str | None, struct_sizes: Mapping[str, int]) -> int | None:
    """Byte size of a Ghidra type string (``char[256]``, ``Game *32``), or None."""
    if not type_str:
        return None
    t = type_str.strip()
    count = 1
    for n in _ARRAY.findall(t):
        count *= int(n)
    base = _ARRAY.sub("", t).strip()
    if base.endswith("*32"):
        size = 4
    elif base.endswith("*16") or base.endswith("*"):
        size = 2
    else:
        base = base.removeprefix("struct ").removeprefix("const ").strip()
        found = _BASE_SIZES.get(base) or struct_sizes.get(base)
        return None if found is None else found * count
    return size * count


def mentioned(text: str | None, names: Iterable[str]) -> set[str]:
    """The ``names`` that occur in ``text`` as whole identifiers."""
    if not text:
        return set()
    return set(_TOKEN.findall(text)) & set(names)


def field_type_names(fields_json: str | None) -> set[str]:
    """Identifiers in the field types of a stored struct (to follow nested types)."""
    out: set[str] = set()
    for f in json.loads(fields_json or "[]"):
        out.update(_TOKEN.findall(f.get("type", "")))
    return out


def closure(conn: sqlite3.Connection, structs: Iterable[str]) -> list[str]:
    """``structs`` plus every struct their fields reach, sorted by name."""
    known = {r["name"]: r["fields"] for r in conn.execute("SELECT name, fields FROM structs")}
    seen: set[str] = set()
    todo = [s for s in structs if s in known]
    while todo:
        s = todo.pop()
        if s in seen:
            continue
        seen.add(s)
        todo.extend(n for n in field_type_names(known[s]) if n in known and n not in seen)
    return sorted(seen)


def render_struct(row: sqlite3.Row) -> str:
    lines = [f"struct {row['name']} {{  // size 0x{row['size'] or 0:x} ({row['size']})"]
    for f in json.loads(row["fields"] or "[]"):
        lines.append(
            f"    /* 0x{f['offset']:04x} */ {f['type']} {f['name']};  // {f['size']} bytes"
        )
    lines.append("};")
    return "\n".join(lines)


def render_global(row: sqlite3.Row) -> str:
    size = f"{row['size']} bytes" if row["size"] is not None else "size unknown"
    return f"{row['type'] or '?'} {row['name']};  // {row['addr']}, {size}, {row['xrefs']} xrefs"


def compute_refs(conn: sqlite3.Connection) -> tuple[int, int]:
    """Rebuild ``function_structs`` / ``function_globals`` from the stored text.

    Returns (struct refs, global refs). Caller holds the write transaction.
    """
    struct_names = {r["name"] for r in conn.execute("SELECT name FROM structs")}
    glob_addrs: dict[str, list[str]] = {}
    for r in conn.execute("SELECT addr, name FROM globals"):
        glob_addrs.setdefault(r["name"], []).append(r["addr"])
    srefs: list[tuple[str, str]] = []
    grefs: list[tuple[str, str]] = []
    for f in conn.execute("SELECT addr, signature, decompile FROM functions WHERE gone = 0"):
        text = f"{f['signature'] or ''}\n{f['decompile'] or ''}"
        tokens = set(_TOKEN.findall(text))
        srefs += [(f["addr"], n) for n in tokens & struct_names]
        grefs += [(f["addr"], a) for n in tokens & glob_addrs.keys() for a in glob_addrs[n]]
    conn.execute("DELETE FROM function_structs")
    conn.execute("DELETE FROM function_globals")
    conn.executemany("INSERT OR IGNORE INTO function_structs VALUES (?, ?)", srefs)
    conn.executemany("INSERT OR IGNORE INTO function_globals VALUES (?, ?)", grefs)
    return len(srefs), len(grefs)


def for_functions(
    conn: sqlite3.Connection, addrs: Iterable[str]
) -> tuple[list[str], list[sqlite3.Row]]:
    """(struct names incl. nested, global rows) touched by the given functions."""
    addr_list = list(addrs)
    marks = ",".join("?" * len(addr_list))
    structs = [
        r[0]
        for r in conn.execute(
            f"SELECT DISTINCT name FROM function_structs WHERE func IN ({marks})", addr_list
        )
    ]
    globs = conn.execute(
        f"SELECT * FROM globals WHERE addr IN "
        f"(SELECT global FROM function_globals WHERE func IN ({marks})) ORDER BY addr",
        addr_list,
    ).fetchall()
    # A global of struct type brings that struct's layout along.
    struct_names = {r["name"] for r in conn.execute("SELECT name FROM structs")}
    for g in globs:
        structs += [n for n in _TOKEN.findall(g["type"] or "") if n in struct_names]
    return closure(conn, structs), globs
