//! Port unit `labmap` (module) of JARDIM.EXE. The labyrinth's map: the 80 rows of walls and of objects, raymapN.dat, placing and removing an object.
//!
//! The map lives in `Backdrop.wallRows` / `Backdrop.objectRows` (fixed arrays, so the
//! original's 160 `GlobalAlloc`s are the arrays themselves). `row` is the map's y: row 0
//! is the file's LAST line.
//!
//! Latent faults of the original (no BUGS.md flag, the port panics where it would run
//! them): `place_object` with a row or column of 0 or less, or an object position outside
//! the map, writes outside the row arrays.

const std = @import("std");
const msg = @import("../core/msg.zig");
const cstr = @import("../core/cstr.zig");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const position = @import("behaviour/position.zig");

const map_cols = world.map_cols;
const map_rows = world.map_rows;

// @orig 1028:04fe labyrinth_alloc_map_rows
/// The per-row storage of the map: wallRows[row] (58 bytes) and objectRows[row] (57
/// far pointers), GMEM_ZEROINIT. The rows are fixed arrays here, so this clears them.
pub fn allocMapRows(bd: *Backdrop) void {
    var row: usize = 0;
    while (row < map_rows) : (row += 1) {
        bd.wallRows[row] = @splat(0);
        bd.objectRows[row] = @splat(null);
    }
}

/// The CRT's text-mode `getc` (`fp->_cnt` / `_filbuf`): CRLF reads as LF, Ctrl-Z and the
/// end of the file read as EOF (-1, over and over).
const TextFile = struct {
    g: *Game,
    f: @import("../platform/platform.zig").File,
    buf: [512]u8 = undefined,
    pos: usize = 0,
    len: usize = 0,
    eof: bool = false,

    fn raw(t: *TextFile) ?u8 {
        if (t.pos >= t.len) {
            if (t.eof) return null;
            t.len = t.g.plat.read(t.f, &t.buf);
            t.pos = 0;
            if (t.len == 0) {
                t.eof = true;
                return null;
            }
        }
        const c = t.buf[t.pos];
        t.pos += 1;
        return c;
    }

    fn getc(t: *TextFile) i8 {
        var c = t.raw() orelse return -1;
        if (c == 0x1a) {
            t.eof = true;
            t.len = 0;
            t.pos = 0;
            return -1;
        }
        if (c == '\r') {
            // CR is dropped when an LF follows.
            const next = t.raw();
            if (next) |n| {
                if (n == '\n') {
                    c = '\n';
                } else t.pos -= 1;
            }
        }
        return @bitCast(c);
    }
};

// @orig 1028:056c labyrinth_load_map oracle=asset
/// Parses `raymapN.dat` (80 lines of 57 characters, no per-line check; LFs are skipped)
/// into the map. False if the file does not open. The row is reversed (file line 0
/// is row 79) and every object cell is cleared.
pub fn loadMap(g: *Game, bd: *Backdrop, file_name: []const u8) bool {
    const f = g.plat.open(cstr.slice(file_name), .read) orelse return false;
    var t: TextFile = .{ .g = g, .f = f };
    var file_row: usize = 0;
    while (file_row < map_rows) : (file_row += 1) {
        var col: usize = 0;
        while (col < map_cols) : (col += 1) {
            var ch: i8 = undefined;
            while (true) {
                ch = t.getc();
                if (ch != '\n') break;
            }
            if (ch == ' ') {
                ch = 0;
            } else if (ch < 'A') {
                ch = ch -% 0x30;
            } else {
                ch = @bitCast(std.ascii.toUpper(@intCast(ch)) -% 0x37);
            }
            bd.wallRows[map_rows - 1 - file_row][col] = ch;
            bd.objectRows[map_rows - 1 - file_row][col] = null;
        }
    }
    g.plat.close(f);
    return true;
}

/// `(%2.2d,%2.2d)` of the original's cell text (col, row).
fn cellText(buf: []u8, col: i16, row: i16) []const u8 {
    return cstr.print(buf, "({s}{d:0>2},{s}{d:0>2})", .{
        if (col < 0) "-" else "",
        @abs(@as(i32, col)),
        if (row < 0) "-" else "",
        @abs(@as(i32, row)),
    });
}

/// The cell of an object's own position: (worldX & 0xffe7) >> 3 / 4 is x >> 5.
fn ownCell(obj: *const Object) struct { row: i16, col: i16 } {
    const x: i16 = @bitCast(@as(u16, @bitCast(obj.worldX)) & 0xffe7);
    const y: i16 = @bitCast(@as(u16, @bitCast(obj.worldY)) & 0xffe7);
    return .{ .row = (y >> 3) >> 2, .col = (x >> 3) >> 2 };
}

fn cellIndex(v: i16, limit: usize) usize {
    if (v < 0 or v >= limit) @panic("BUGS.md latent (JARDIM): unchecked cells, table entries and divisors (labmap: an object outside the map)");
    return @intCast(v);
}

// @orig 1028:2034 labyrinth_place_object
/// objectRows[row][col] = obj. With row or col == -1 the cell is the object's own
/// (worldY >> 5, worldX >> 5); otherwise row and col are 1-BASED: outside the map is a
/// fatal box and WM_DESTROY, a wall cell a warning (the placement goes on).
pub fn placeObject(g: *Game, bd: *Backdrop, row: i16, col: i16, obj: *Object) void {
    if (col == -1 or row == -1) {
        const c = ownCell(obj);
        bd.objectRows[cellIndex(c.row, map_rows)][cellIndex(c.col, map_cols)] = obj;
        return;
    }
    var buf: [12]u8 = undefined;
    if (col < 0x39 and row < 0x50) {
        if (wallAt(bd, row, col) > 0) {
            const text = cellText(&buf, col, row);
            position.messageBoxPrintf(g, "Aviso !!!", "Objeto posicionado dentro de parede, nas coordenadas %s", text);
        }
    } else {
        const text = cellText(&buf, col, row);
        position.messageBoxPrintf(g, "Erro Fatal !!!", "Objeto posicionado fora do labirinto, nas coordenadas %s", text);
        _ = g.post(msg.Msg.make(msg.wm.destroy, 0, 0, 0));
    }
    bd.objectRows[cellIndex(row - 1, map_rows)][cellIndex(col - 1, map_cols)] = obj;
}

fn wallAt(bd: *const Backdrop, row: i16, col: i16) i8 {
    return bd.wallRows[cellIndex(row - 1, map_rows)][cellIndex(col - 1, map_cols + 1)];
}

// @orig 1028:214e labyrinth_remove_object
/// objectRows[worldY >> 5][worldX >> 5] = NULL.
pub fn removeObject(bd: *Backdrop, obj: *Object) void {
    const c = ownCell(obj);
    bd.objectRows[cellIndex(c.row, map_rows)][cellIndex(c.col, map_cols)] = null;
}

const testing = std.testing;
const game_mod = @import("core/game.zig");

test "loadMap reads the maps of the disc, the last line being row 0" {
    const t = try game_mod.TestGame.init(testing.allocator);
    defer t.deinit();
    const bd = try testing.allocator.create(Backdrop);
    defer testing.allocator.destroy(bd);
    bd.* = .{};
    const names = [_][]const u8{ "RAYMAP1.DAT", "RAYMAP2.DAT", "RAYMAP3.DAT" };
    for (names) |name| {
        var path_buf: [64]u8 = undefined;
        var disc_buf: [64]u8 = undefined;
        const disc = try std.fmt.bufPrint(&disc_buf, "assets/JARDIM/{s}", .{name});
        const file = try std.Io.Dir.cwd().readFileAlloc(testing.io, disc, testing.allocator, .limited(1 << 20));
        defer testing.allocator.free(file);
        const path = try std.fmt.bufPrint(&path_buf, "\\JARDIM\\{s}", .{name});
        try testing.expect(loadMap(t.game, bd, path));
        var lines = std.mem.splitSequence(u8, file, "\r\n");
        var n: usize = 0;
        while (lines.next()) |line| : (n += 1) {
            if (n >= map_rows) break;
            try testing.expectEqual(@as(usize, map_cols), line.len);
            for (line, 0..) |c, col| {
                const want: i8 = if (c == ' ') 0 else if (c < 'A') @intCast(c - '0') else @intCast(std.ascii.toUpper(c) - 0x37);
                try testing.expectEqual(want, bd.wallRows[map_rows - 1 - n][col]);
                try testing.expect(bd.objectRows[map_rows - 1 - n][col] == null);
            }
        }
    }
    try testing.expect(!loadMap(t.game, bd, "NOSUCH.DAT"));
}
