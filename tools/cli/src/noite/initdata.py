"""Initial data: do the Zig defaults of ``// @orig g_*`` fields match the EXE?

A Zig struct field that ports a DGROUP global (``Game`` fields, a handler's
``State``) carries ``// @orig g_<name>`` on the line above it; its default value
must equal the bytes the original starts with: the global's bytes in the NE
data segments of ``assets/NOITE.EXE`` (DGROUP 1050 and the small segments
1030-1048; anything past a segment's stored length is BSS, i.e. zero).

The defaults are taken from the compiler, not parsed: a small Zig program is
generated that prints every tagged field's default value, built against the
port (``zig build initdata -Dinitdata-dump=<file>``). Each value is flattened to
integers (``bool`` 0/1, ``null`` 0, enums by value) and compared with the EXE
read as little-endian elements of the global's Ghidra type (``short`` 2 bytes,
``long``/far pointers 4, ``char``/``byte`` 1). A non-null pointer default or a
struct whose layout is unknown can only be compared as "all zero or not".

A tag with ``initdata=skip`` (and the reason) opts a field out: its global is
set up at run time before any use (static C++ initialisers, a pointer the port
keeps as a slice).

Tag forms: ``// @orig g_a`` (next field); ``// @orig g_a / g_b`` or
``g_waveCacheA/B/C`` (one global per following field when they share a type,
otherwise all of them laid end to end in the one field). Text after the names
is free.
"""

from __future__ import annotations

import dataclasses
import json
import re
import sqlite3
import subprocess
from dataclasses import dataclass
from pathlib import Path

from noite import program
from noite.ne import NeImage
from noite.tags import _SKIP_DIRS, _code

_TAG = re.compile(r"^\s*//\s*@orig\s+(g_[^(]*)")
_FIELD = re.compile(r'^\s*(\w+|@"[^"]+")\s*:\s*([^=]+?)\s*(?:=\s*(.*?))?\s*,?\s*(//.*)?$')
_STRUCT = re.compile(r"\b(?:pub\s+)?const\s+(\w+)\s*=\s*(?:extern\s+|packed\s+)?struct\b")


@dataclass
class Field:
    path: str  # relative to the tree root
    line: int
    struct: str  # dotted path inside the file ("State", "Game")
    name: str
    zig_type: str
    default: str | None  # source text (first line), None if none
    globals: list[str]  # g_ names, in address order as written
    skip: bool = False  # tagged ``initdata=skip``: set up at run time before any use


@dataclass
class Global:
    name: str
    addr: tuple[int, int]
    type: str
    size: int


@dataclass
class Result:
    field: Field
    ok: bool
    detail: str
    expect: list[int] = dataclasses.field(default_factory=list)


def _names(text: str) -> list[str]:
    """``g_a / g_b`` → [g_a, g_b]; ``g_cacheA/B/C`` → [g_cacheA, g_cacheB, g_cacheC]."""
    out: list[str] = []
    for part in re.sub(r",\s*(?=g_)", "/", text).split("/"):
        tok = part.strip().split()
        if not tok:
            continue
        word = tok[0].rstrip(",.;:")
        if word.startswith("g_"):
            out.append(word)
        elif out and re.fullmatch(r"\w+", word) and len(word) < len(out[-1]):
            out.append(out[-1][: -len(word)] + word)
        else:
            break
        if len(tok) > 1:  # free text follows the names
            break
    return out


def scan(root: Path) -> list[Field]:
    """Every field tagged ``// @orig g_*`` in the active program's source tree."""
    prog = program.current()
    fields: list[Field] = []
    for p in sorted((root / prog.src).rglob("*.zig")):
        rel = p.relative_to(root).as_posix()
        if _SKIP_DIRS & set(p.relative_to(root).parts):
            continue
        if any(rel.startswith(x + "/") for x in prog.exclude):
            continue
        fields.extend(_scan_file(p, p.relative_to(root).as_posix()))
    return fields


def _scan_file(p: Path, rel: str) -> list[Field]:
    lines = p.read_text(encoding="utf-8").splitlines()
    out: list[Field] = []
    stack: list[tuple[str, int]] = []  # (struct name, body depth)
    depth = 0
    pending: list[str] = []
    skip = False
    i = 0
    while i < len(lines):
        line = lines[i]
        code = _code(line)
        m_struct = _STRUCT.search(code)
        opens, closes = code.count("{"), code.count("}")
        m_tag = _TAG.match(line)
        if m_tag:
            pending = _names(m_tag.group(1))
            skip = "initdata=skip" in line
        elif pending and code.strip():
            m = _FIELD.match(line)
            in_struct = bool(stack) and stack[-1][1] == depth
            if m and in_struct and not m_struct:
                group = [(i, m)]
                if len(pending) > 1:  # consecutive fields of the same type
                    j = i + 1
                    while j < len(lines) and len(group) < len(pending):
                        mj = _FIELD.match(lines[j])
                        if not mj or _TAG.match(lines[j]) or mj.group(2) != m.group(2):
                            break
                        group.append((j, mj))
                        j += 1
                sname = ".".join(s for s, _ in stack)
                if len(group) == len(pending):
                    for (li, mm), g in zip(group, pending, strict=True):
                        out.append(_field(rel, li, sname, mm, [g], skip))
                else:
                    out.append(_field(rel, i, sname, m, pending, skip))
            pending = []
        depth += opens - closes
        if m_struct and opens > closes:
            stack.append((m_struct.group(1), depth))
        while stack and depth < stack[-1][1]:
            stack.pop()
        i += 1
    return out


def _field(rel: str, li: int, sname: str, m: re.Match[str], names: list[str], skip: bool) -> Field:
    name = m.group(1)
    if name.startswith('@"'):
        name = name[2:-1]
    return Field(rel, li + 1, sname, name, m.group(2).strip(), m.group(3), names, skip)


def module_expr(rel: str, units: set[str]) -> str | None:
    """The Zig expression (from the dump program) naming the file's module."""
    prog = program.current()
    parts = rel.removeprefix(prog.src + "/").removesuffix(".zig").split("/")
    if parts[0] == "core" and len(parts) == 2:
        return f"{prog.zig_module}.core.{parts[1]}"
    handler = parts[0] == "handlers" and len(parts) == 2
    name = f"handler_{parts[1]}" if handler else parts[-1]
    return f"{prog.zig_module}.units.{name}" if name in units else None


def _units(root: Path) -> set[str]:
    text = (root / program.current().index).read_text(encoding="utf-8")
    return set(re.findall(r"pub const (\w+) = @import", text))


_PRELUDE = """\
//! Generated by `noite initdata`: prints the default of every field tagged
//! `// @orig g_*`, one `<index>\\t<json>` line each.
const std = @import("std");
const noite = @import("noite");

fn emit(w: *std.Io.Writer, v: anytype) std.Io.Writer.Error!void {
    const T = @TypeOf(v);
    switch (@typeInfo(T)) {
        .int, .comptime_int => try w.print("{d}", .{v}),
        .bool => try w.print("{d}", .{@intFromBool(v)}),
        .@"enum" => try w.print("{d}", .{@intFromEnum(v)}),
        .optional => if (v) |x| try emit(w, x) else try w.writeAll("0"),
        .pointer => |p| try w.writeAll(if (p.size == .slice) "\\"slice\\"" else "\\"ptr\\""),
        .array => {
            try w.writeAll("[");
            for (v, 0..) |x, i| {
                if (i > 0) try w.writeAll(",");
                try emit(w, x);
            }
            try w.writeAll("]");
        },
        .@"struct" => |s| {
            try w.writeAll("{");
            inline for (s.field_names, 0..) |n, i| {
                if (i > 0) try w.writeAll(",");
                try w.print("\\"{s}\\":", .{n});
                try emit(w, @field(v, n));
            }
            try w.writeAll("}");
        },
        else => try w.writeAll("\\"?\\""),
    }
}

fn dflt(comptime T: type, comptime name: []const u8) ?@FieldType(T, name) {
    const info = @typeInfo(T).@"struct";
    inline for (info.field_names, info.field_types, info.field_attrs) |n, FT, a| {
        if (comptime std.mem.eql(u8, n, name)) return a.defaultValue(FT);
    }
    unreachable;
}

fn one(w: *std.Io.Writer, idx: usize, comptime T: type, comptime name: []const u8) !void {
    try w.print("{d}\\t", .{idx});
    if (comptime dflt(T, name)) |v| try emit(w, v) else try w.writeAll("\\"none\\"");
    try w.writeAll("\\n");
}

pub fn main(init: std.process.Init) !void {
    var buf: [1 << 16]u8 = undefined;
    var fw = std.Io.File.stdout().writer(init.io, &buf);
    const w = &fw.interface;
"""


def generate(fields: list[Field], units: set[str]) -> tuple[str, dict[int, str]]:
    """The dump program, and the fields it cannot reach (index → why)."""
    body: list[str] = []
    skipped: dict[int, str] = {}
    for i, f in enumerate(fields):
        mod = module_expr(f.path, units)
        if f.skip:
            skipped[i] = "tagged initdata=skip"
        elif mod is None:
            skipped[i] = "file is not a module the dump can import"
        elif f.default is not None and f.default.strip().rstrip(",") == "undefined":
            skipped[i] = "default is `undefined` (initialised at run time)"
        else:
            body.append(f'    try one(w, {i}, {mod}.{f.struct}, "{f.name}");')
    return _PRELUDE + "\n".join(body) + "\n    try w.flush();\n}\n", skipped


def dump(root: Path, src: str) -> dict[int, object]:
    """Build and run the dump program; index → decoded default."""
    path = root / ".zig-cache" / "initdata" / "dump.zig"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(src, encoding="utf-8")
    p = subprocess.run(
        ["zig", "build", "initdata", f"-Dinitdata-dump={path}"],
        cwd=root,
        capture_output=True,
        text=True,
    )
    if p.returncode != 0:
        raise RuntimeError(p.stderr.strip() or "zig build initdata failed")
    out: dict[int, object] = {}
    for line in p.stdout.splitlines():
        idx, _, js = line.partition("\t")
        out[int(idx)] = json.loads(js)
    return out


def _globals(conn: sqlite3.Connection) -> dict[str, Global]:
    out: dict[str, Global] = {}
    for addr, name, typ, size in conn.execute("SELECT addr, name, type, size FROM globals"):
        seg, off = addr.split(":")
        out[name] = Global(name, (int(seg, 16), int(off, 16)), typ or "", size or 0)
    return out


def _elem_size(typ: str, size: int) -> int:
    """Bytes per element of a Ghidra type string (0 = unknown layout)."""
    base = re.sub(r"\[\d+\]", "", typ).strip()
    if base.endswith("*32") or base.endswith("* 32"):
        return 4
    if base.endswith("*") or base.endswith("*16"):
        return 2
    sizes = {
        "char": 1, "uchar": 1, "byte": 1, "undefined1": 1, "bool": 1, "BYTE": 1,
        "short": 2, "ushort": 2, "int": 2, "uint": 2, "word": 2, "undefined2": 2,
        "WORD": 2, "HWND": 2, "HANDLE": 2, "HGLOBAL": 2, "HFILE": 2, "BOOL": 2,
        "long": 4, "ulong": 4, "dword": 4, "undefined4": 4, "DWORD": 4, "LONG": 4,
        "pointer": 4,
    }  # fmt: skip
    if base in sizes:
        return sizes[base]
    return size if size in (1, 2, 4) and "[" not in typ else 0


def _flatten(v: object) -> list[object]:
    if isinstance(v, list):
        return [x for e in v for x in _flatten(e)]
    if isinstance(v, dict):
        return [x for e in v.values() for x in _flatten(e)]
    return [v]


def _read(image: NeImage, g: Global) -> bytes:
    seg, off = g.addr
    data = image.resolved(seg, off, g.size)
    return data + bytes(g.size - len(data))


def compare(f: Field, value: object, globs: dict[str, Global], image: NeImage) -> Result:
    gs = [globs.get(n) for n in f.globals]
    missing = [n for n, g in zip(f.globals, gs, strict=True) if g is None]
    if missing:
        return Result(f, False, f"unknown global(s) {', '.join(missing)} (not in the DB)")
    known = [g for g in gs if g is not None]
    if any(g.addr[0] not in program.current().data_segments for g in known):
        return Result(f, True, "not in a data segment (skipped)")
    raw = b"".join(_read(image, g) for g in known)
    flat = _flatten(value)
    esizes = {_elem_size(g.type, g.size) for g in known}
    esz = esizes.pop() if len(esizes) == 1 else 0
    if (not esz or len(raw) != esz * len(flat)) and flat and len(raw) % len(flat) == 0:
        esz = len(raw) // len(flat) if len(raw) // len(flat) in (1, 2, 4) else 0  # struct array
    if value == "none":
        return Result(f, all(b == 0 for b in raw), "field has no default; EXE " + _hex(raw))
    if esz and len(raw) % esz == 0 and len(raw) // esz == len(flat):
        expect = [int.from_bytes(raw[k : k + esz], "little") for k in range(0, len(raw), esz)]
        bad: list[tuple[int, object, int]] = []
        for k, (z, e) in enumerate(zip(flat, expect, strict=True)):
            if z == "ptr":
                if e == 0:
                    bad.append((k, z, e))
            elif not isinstance(z, int) or (z - e) % (1 << (8 * esz)) != 0:
                bad.append((k, z, e))
        if not bad:
            return Result(f, True, "ok")
        shown = ", ".join(f"[{k}] zig {z} exe {e:#x}" for k, z, e in bad[:6])
        more = f" (+{len(bad) - 6} more)" if len(bad) > 6 else ""
        return Result(f, False, shown + more, expect)
    # Unknown or different layout: only "all zero" can be compared.
    zig_zero = all(z == 0 for z in flat)
    exe_zero = all(b == 0 for b in raw)
    if zig_zero and exe_zero:
        return Result(f, True, "ok (all zero)")
    if zig_zero != exe_zero or not zig_zero:
        return Result(
            f,
            False,
            f"layout not comparable ({len(flat)} zig values, {len(raw)} EXE bytes, "
            f"type {known[0].type!r}); zig {_short(value)} exe {_hex(raw)}",
        )
    return Result(f, True, "ok")


def _hex(raw: bytes) -> str:
    if all(b == 0 for b in raw):
        return f"{len(raw)} zero bytes"
    s = raw[:32].hex(" ")
    return s + (" …" if len(raw) > 32 else "")


def _short(v: object) -> str:
    s = json.dumps(v)
    return s if len(s) <= 80 else s[:77] + "..."


def run(conn: sqlite3.Connection, root: Path, exe: Path) -> tuple[list[Result], dict[int, str]]:
    fields = scan(root)
    src, skipped = generate(fields, _units(root))
    values = dump(root, src)
    globs = _globals(conn)
    image = NeImage.load(exe)
    results = []
    for i, f in enumerate(fields):
        if i in skipped:
            continue
        results.append(compare(f, values[i], globs, image))
    return results, {i: f"{fields[i].path}:{fields[i].line} {why}" for i, why in skipped.items()}
