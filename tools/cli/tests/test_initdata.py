from __future__ import annotations

from pathlib import Path

import pytest

from noite import initdata
from noite.ne import NeImage, Segment

EXE = Path(__file__).resolve().parents[3] / "assets" / "NOITE.EXE"


def test_names() -> None:
    assert initdata._names("g_lives") == ["g_lives"]
    assert initdata._names("g_a / g_b (both)") == ["g_a", "g_b"]
    assert initdata._names("g_waveCacheA/B/C") == ["g_waveCacheA", "g_waveCacheB", "g_waveCacheC"]
    assert initdata._names("g_x only ever written") == ["g_x"]
    assert initdata._names("g_a, g_b (x)") == ["g_a", "g_b"]


def test_scan(tmp_path: Path) -> None:
    src = tmp_path / "src" / "handlers"
    src.mkdir(parents=True)
    (src / "x.zig").write_text(
        "pub const State = struct {\n"
        "    // @orig g_sxA / g_sxB\n"
        "    a: i16 = 0,\n"
        "    b: i16 = 1,\n"
        "    // @orig g_sxPath / g_sxBuf\n"
        "    path: [4]u8 = @splat(0),\n"
        "    other: u8 = 0,\n"
        "    inner: struct { x: u8 = 0 } = .{},\n"
        "    // @orig g_sxSkip initdata=skip (run time)\n"
        "    s: u8 = 0,\n"
        "};\n"
        "fn f() void {\n"
        "    // @orig g_notAField\n"
        "    const v = 1;\n"
        "}\n",
        encoding="utf-8",
    )
    got = [(f.struct, f.name, f.globals, f.skip) for f in initdata.scan(tmp_path)]
    assert got == [
        ("State", "a", ["g_sxA"], False),
        ("State", "b", ["g_sxB"], False),
        ("State", "path", ["g_sxPath", "g_sxBuf"], False),
        ("State", "s", ["g_sxSkip"], True),
    ]
    assert initdata.module_expr("src/handlers/x.zig", {"handler_x"}) == "noite.units.handler_x"
    assert initdata.module_expr("src/core/game.zig", set()) == "noite.core.game"


def _field(name: str) -> initdata.Field:
    return initdata.Field("src/x.zig", 1, "State", "f", "i16", "0", [name])


def test_compare() -> None:
    img = NeImage({0x1050: Segment(0x1050, b"\x01\x00\xff\xff")})
    globs = {
        "g_one": initdata.Global("g_one", (0x1050, 0), "short", 2),
        "g_neg": initdata.Global("g_neg", (0x1050, 2), "short", 2),
        "g_bss": initdata.Global("g_bss", (0x1050, 8), "long", 4),
    }
    assert initdata.compare(_field("g_one"), 1, globs, img).ok
    assert not initdata.compare(_field("g_one"), 0, globs, img).ok
    assert initdata.compare(_field("g_neg"), -1, globs, img).ok
    assert initdata.compare(_field("g_bss"), 0, globs, img).ok  # past the stored data
    assert not initdata.compare(_field("g_nope"), 0, globs, img).ok


def test_far_pointer_fixups() -> None:
    if not EXE.is_file():
        pytest.skip("assets/NOITE.EXE not extracted")
    img = NeImage.load(EXE)
    # g_assetRoot (1050:0330) starts as &g_driveCD; g_gameName points at "Casseta".
    assert img.resolved(0x1050, 0x330, 4) == bytes.fromhex("30005010")
    assert img.resolved(0x1050, 0xB08, 4) == bytes.fromhex("68c51810")
