from __future__ import annotations

from noite.db import Oracle
from noite.tags import parse

SRC = """\
const std = @import("std");

// @orig 1010:0C80 backdrop_ctor
pub fn init() void {
    const s = "{ not a brace";
    _ = s;
}

pub fn tick(kind: Kind) void {
    switch (kind) {
        // @orig 1010:77b6 object3d_get_world_x_thunk_4be (absorbed)
        .a => {},
        else => {},
    }
}

// @orig SceneObject+0x456
visible: bool,

// @orig 1010:0c80 backdrop_ctor oracle=asset
test "backdrop loads the BMP" {
    // @orig 1010:041c load_dib oracle=emulated
    try std.testing.expect(true);
}

test "no oracle" {
    // @orig 1010:0e18
}

// @orig 1010:0dca backdrop_is_rect_occupied_default
fn after() void {}
"""


def test_parse() -> None:
    tags = parse(SRC, "src/x.zig")
    got = [(t.addr, t.name, t.absorbed, t.is_test, t.oracle) for t in tags]
    assert got == [
        ("1010:0c80", "backdrop_ctor", False, False, None),
        ("1010:77b6", "object3d_get_world_x_thunk_4be", True, False, None),
        ("1010:0c80", "backdrop_ctor", False, True, Oracle.ASSET),
        ("1010:041c", "load_dib", False, True, Oracle.EMULATED),
        ("1010:0e18", None, False, True, Oracle.NONE),
        ("1010:0dca", "backdrop_is_rect_occupied_default", False, False, None),
    ]
    assert [t.line for t in tags] == [3, 11, 20, 22, 27, 30]


def test_bad_oracle() -> None:
    (t,) = parse('// @orig 1010:0100 f oracle=vibes\ntest "x" {}\n', "t.zig")
    assert t.is_test and t.oracle is Oracle.NONE and t.bad_oracle == "vibes"
