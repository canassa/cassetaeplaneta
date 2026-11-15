//! Port unit `raycast` (module) of JARDIM.EXE. The walls: raycast_render_view (120 columns, the two
//! ray walks, the nearer hit, the column height and depth), the 32-bit walks 1008:0024/1010:0024
//! (transcribed, oracle-tested) and their 16:32 gateways, the four wall/door column drawers.
//!
//! The two walks are transcribed from the `objdump -mi386` listings of their segments (Ghidra
//! decodes them as 16-bit): 32-bit wrapping arithmetic (`mull`'s low half), `SAR` as `>>` on
//! `i32`, the cell byte zero-extended. The original reads the map through the backdrop's two
//! arrays of 80 row pointers with no bound on the row, nor on the column of a wall byte; a read
//! outside the 80 rows of 58 bytes is `error.Fault` here (BUGS.md "Latent (JARDIM)": a door on the
//! map border; `renderView` panics naming it). The 58th object pointer of a row (`objectRows[r][57]`,
//! read when a horizontal ray crosses x = 1824 exactly) is past the row's 57-pointer `GlobalAlloc`:
//! its zero-initialised slack, i.e. no object. The walks' calls of the 16:32 gateways go through
//! `gw` (`Gateways` in the game, a recorder in the tests), in the original's order.
//!
//! Proved against the original in tools/oracle (`tools/oracle/jardim32.py raycast`, vectors in
//! `src/jardim/testdata/raycast_walk.zig`).

const std = @import("std");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const SpriteQueue = world.SpriteQueue;
const position = @import("behaviour/position.zig");
const scaled = @import("scaled.zig");
const sprites = @import("sprites.zig");

pub const Error = error{Fault};

const map_rows = world.map_rows;
const map_cols = world.map_cols;
pub const WallRows = [map_rows][map_cols + 1]i8;
pub const ObjectRows = [map_rows][map_cols]?*Object;

/// The walk's "no hit": the ray left the map.
pub const no_hit: i32 = 0x7fffffff;

fn lo16(v: i32) i16 {
    return @truncate(v);
}

// ---- the map as the 32-bit code reads it ----

/// `lds (row ptr array + row*4)` then `movb (row + col)`: the cell byte, zero-extended.
fn wallAt(rows: *const WallRows, row: i32, col: i32) Error!i32 {
    if (row < 0 or row >= map_rows or col < 0 or col > map_cols) return error.Fault;
    return @as(u8, @bitCast(rows[@intCast(row)][@intCast(col)]));
}

/// The far pointer of the object row; column 57 is the row block's zeroed slack.
fn objectAt(rows: *const ObjectRows, row: i32, col: i32) Error!?*Object {
    if (row < 0 or row >= map_rows or col < 0 or col > map_cols) return error.Fault;
    if (col == map_cols) return null;
    return rows[@intCast(row)][@intCast(col)];
}

/// `(along << 16)` of the start: `shl $0x10`.
fn shl16(v: i32) i32 {
    return @bitCast(@as(u32, @bitCast(v)) << 16);
}

/// The body both segments share; `vertical` follows the lines x = 32k (1010), else y = 32k (1008).
/// `own` is the coordinate across the lines (x for 1010), `along` the other one.
fn walk(
    comptime vertical: bool,
    gw: anytype,
    angle: i32,
    x: i32,
    y: i32,
    t: i32,
    s: i32,
    pos_step: i32,
    queue: ?*SpriteQueue,
    wall_rows: *const WallRows,
    object_rows: *const ObjectRows,
    dist: *i32,
    cell: *i32,
    hit: *i32,
) Error!void {
    const own = if (vertical) x else y;
    const along = if (vertical) y else x;
    const back = if (vertical)
        !(angle < 0x2d0 or angle >= 0x870) // 3a-4d: 720 <= A < 2160 goes -x
    else
        (angle < 0 or angle >= 0x5a0); // 3a-4b: A outside 0..1439 goes -y
    var line: i32 = undefined; // [ebp-8]
    var step: i32 = undefined; // [ebp-0xc]
    var pos: i32 = undefined; // [ebp-4], 16.16 along the line
    if (back) {
        line = own & ~@as(i32, 31);
        step = -32;
        pos = shl16(along) +% (line -% own) *% t;
        line -%= 1;
    } else {
        line = if (vertical) (own & ~@as(i32, 31)) +% 32 else (own +% 31) & ~@as(i32, 31);
        step = 32;
        pos = shl16(along) +% (line -% own) *% t;
    }
    const limit: i32 = if (vertical) 0xa000000 else 0x7200000;
    while (true) {
        const across = line >> 5;
        const along_cell = pos >> 21;
        const row = if (vertical) along_cell else across;
        const col = if (vertical) across else along_cell;
        if (pos < 0 or pos > limit) {
            dist.* = no_hit;
            return;
        }
        const c = try wallAt(wall_rows, row, col);
        if (c == 0) {
            // 194: an object in an empty cell is flagged visible, then queued.
            if (try objectAt(object_rows, row, col)) |o| {
                gw.setVisible(o, 1);
                const d = ((line -% own) *% s) >> 16;
                gw.enqueue(queue, o, d, angle, col, row);
            }
            pos +%= pos_step;
            line +%= step;
            continue;
        }
        if (c <= 6) {
            dist.* = ((line -% own) *% s) >> 16;
            cell.* = c;
            hit.* = pos;
            return;
        }
        // A door: odd values are see-through for 1010, even ones for 1008; the others are a plane
        // recessed half a cell.
        const behind = if (vertical) c & 1 != 0 else c & 1 == 0;
        if (!behind) {
            const half = step >> 1;
            dist.* = ((half +% line -% own) *% s) >> 16;
            cell.* = c;
            hit.* = half *% t +% pos;
            return;
        }
        dist.* = ((line -% own) *% s) >> 16;
        const next = (line +% step) >> 5;
        cell.* = if (vertical) try wallAt(wall_rows, row, next) else try wallAt(wall_rows, next, col);
        hit.* = pos;
        return;
    }
}

// @orig 1008:0024 raycast_walk_horizontal
/// The DDA along the horizontal grid lines y = 32k (`cot`, `csc`, `x_step` = tables 1, 6, 3 at
/// `angle`): `dist` the ray length (`no_hit` off the map), `cell` the value hit (behind an even
/// door: the cell beyond it), `hit` the 16.16 x of the hit. Every object in an empty cell crossed
/// is flagged visible and queued. `cell`/`hit` are left alone off the map.
pub fn walkHorizontal(
    gw: anytype,
    angle: i32,
    x: i32,
    y: i32,
    cot: i32,
    csc: i32,
    x_step: i32,
    queue: ?*SpriteQueue,
    wall_rows: *const WallRows,
    object_rows: *const ObjectRows,
    dist: *i32,
    cell: *i32,
    hit: *i32,
) Error!void {
    return walk(false, gw, angle, x, y, cot, csc, x_step, queue, wall_rows, object_rows, dist, cell, hit);
}

// @orig 1010:0024 raycast_walk_vertical
/// The DDA along the vertical grid lines x = 32k (`tan`, `sec`, `y_step` = tables 0, 5, 2 at
/// `angle`); as `walkHorizontal` with x and y swapped, odd doors see-through.
pub fn walkVertical(
    gw: anytype,
    angle: i32,
    x: i32,
    y: i32,
    tan: i32,
    sec: i32,
    y_step: i32,
    queue: ?*SpriteQueue,
    wall_rows: *const WallRows,
    object_rows: *const ObjectRows,
    dist: *i32,
    cell: *i32,
    hit: *i32,
) Error!void {
    return walk(true, gw, angle, x, y, tan, sec, y_step, queue, wall_rows, object_rows, dist, cell, hit);
}

// @orig 1028:4b81 object_set_visible_from32
/// The walks' gateway: stores the low word of `visible` in the object's flag (a null object is
/// skipped).
pub fn objectSetVisibleFrom32(obj: ?*Object, visible: i32) void {
    if (obj) |o| o.visible = lo16(visible);
}

// @orig 1028:4b04 sprite_enqueue_from32
/// The walks' gateway to `sprites.insert`, with the low words of the 32-bit arguments.
pub fn spriteEnqueueFrom32(queue: ?*SpriteQueue, obj: ?*Object, dist: i32, angle: i32, col: i32, row: i32) void {
    _ = sprites.insert(queue.?, lo16(row), lo16(col), lo16(angle), lo16(dist), obj);
}

/// The game's gateways (the walks' 32-bit far calls into 1028).
pub const Gateways = struct {
    pub fn setVisible(_: Gateways, obj: *Object, visible: i32) void {
        objectSetVisibleFrom32(obj, visible);
    }
    pub fn enqueue(_: Gateways, queue: ?*SpriteQueue, obj: *Object, dist: i32, angle: i32, col: i32, row: i32) void {
        spriteEnqueueFrom32(queue, obj, dist, angle, col, row);
    }
};

// ---- the column drawers ----

/// The four drawers' common body (the four are byte-identical): the 4-px column of texture
/// `(value + 1) / 2 - 1` (rows of `framesLeft`), source column `(hitW - 1) & tex_col`, scaled to
/// `slice_h` rows at (`screen_x`, `slice_top`) with the shading of `dist`.
fn drawStrip(strip: *Object, dist: i32, tex_col: i32, value: i16, slice_h: i16, slice_top: i16, screen_x: i16, bd: *Backdrop) void {
    const tex_h = strip.framesLeft;
    const tex_row = (@divTrunc(value +% 1, 2) -% 1) *% strip.framesLeft;
    const col = (position.hitW(strip) -% 1) & lo16(tex_col);
    const d = position.dib(strip).?;
    _ = scaled.dibBlitScaledColumn(&bd.bmiHeader, bd.pixels, screen_x, slice_top, slice_h, d.bits, &d.header, col, tex_row, tex_h, dist);
}

// @orig 1028:482c wall_strip_draw_wall_a
/// A wall (1-6) hit by the horizontal walk.
pub fn drawWallA(strip: *Object, dist: i32, tex_col: i32, value: i16, slice_h: i16, slice_top: i16, screen_x: i16, bd: *Backdrop) void {
    drawStrip(strip, dist, tex_col, value, slice_h, slice_top, screen_x, bd);
}

// @orig 1028:48e2 wall_strip_draw_wall_b
/// A wall (1-6) hit by the vertical walk.
pub fn drawWallB(strip: *Object, dist: i32, tex_col: i32, value: i16, slice_h: i16, slice_top: i16, screen_x: i16, bd: *Backdrop) void {
    drawStrip(strip, dist, tex_col, value, slice_h, slice_top, screen_x, bd);
}

// @orig 1028:4998 wall_strip_draw_door_a
/// A door (7-12) hit by the horizontal walk.
pub fn drawDoorA(strip: *Object, dist: i32, tex_col: i32, value: i16, slice_h: i16, slice_top: i16, screen_x: i16, bd: *Backdrop) void {
    drawStrip(strip, dist, tex_col, value, slice_h, slice_top, screen_x, bd);
}

// @orig 1028:4a4e wall_strip_draw_door_b
/// A door (7-12) hit by the vertical walk.
pub fn drawDoorB(strip: *Object, dist: i32, tex_col: i32, value: i16, slice_h: i16, slice_top: i16, screen_x: i16, bd: *Backdrop) void {
    drawStrip(strip, dist, tex_col, value, slice_h, slice_top, screen_x, bd);
}

// ---- the view ----

const latent_border = "BUGS.md latent (JARDIM): a ray walk read outside the map (a door on the map border)";

/// A column of the nearer hit: the height (`_aFldiv` of the fisheye entry by the distance, the
/// high word), the top, the cell value forced into 1..12, the drawer, the depth.
fn drawColumn(g: *Game, bd: *Backdrop, comptime horizontal: bool, dist: i32, cell_in: i32, hit: i32, fisheye: i32, col_x: i32, col_idx: i32) void {
    var wall_h: i32 = 0x65ae;
    if (dist != 0) {
        if (dist == -1 and fisheye == std.math.minInt(i32))
            @panic("BUGS.md latent (JARDIM): unchecked cells, table entries and divisors (raycast_render_view: a divide fault)");
        wall_h = lo16(@divTrunc(fisheye, dist) >> 16); // MOV AX,DX; CWD
    }
    const top: i32 = ((@as(i32, bd.viewH) -% wall_h) >> 1) +% bd.viewY;
    var cell = cell_in;
    if (cell < 1 or cell > 12) cell = 1;
    // The hit's integer part & ~3, sign-extended (AND AX,0xfffc; CWD).
    const hit_col: i32 = @as(i16, @truncate(hit >> 16)) & @as(i16, @bitCast(@as(u16, 0xfffc)));
    const strip = bd.wallStrip.?;
    if (cell > 6) {
        const draw = if (horizontal) drawDoorA else drawDoorB;
        draw(strip, dist, hit_col, lo16(cell), lo16(wall_h), lo16(top), lo16(col_x), bd);
    } else {
        // J4: a wall gets the screen x as its texture column, so the texture stays on the screen.
        const tex_col = if (g.fixes.jardim_wall_texture_on_wall) hit_col else col_x;
        const draw = if (horizontal) drawWallA else drawWallB;
        draw(strip, dist, tex_col, lo16(cell), lo16(wall_h), lo16(top), lo16(col_x), bd);
    }
    g.columnDepth[@intCast(col_idx)] = dist;
}

/// A table entry at a ray angle (the original's pointers into the tables; the angle stays in
/// 0..2879 for the callers' view angles 0..2879).
fn at(table: []const i32, i: i32) i32 {
    if (i < 0 or i >= table.len) @panic("BUGS.md latent (JARDIM): unchecked cells, table entries and divisors (raycast: a ray angle outside the tables)");
    return table[@intCast(i)];
}

// @orig 1028:0951 raycast_render_view
/// One frame of the 3-D view from (`x`, `y`) (1/32 cell) at `angle` (0..2879): 120 columns of
/// 4 px from the right (x = 496, the ray 30° right of the view) to the left (x = 20), 4 angle
/// units each; per column both walks, the nearer hit (equal: the horizontal one) drawn and its
/// distance stored in `g.columnDepth`. Sways the hands (`g_handsBobPos`/`Step`) first and moves
/// them last.
pub fn renderView(g: *Game, bd: *Backdrop, x: i32, y: i32, angle_in: i32) void {
    var angle = angle_in -% 0xf0;
    if (angle < 0) angle +%= 0xb40;
    const bob = g.handsBobPos;
    if ((if (bob < 0) 0 -% bob else bob) >= 4) g.handsBobStep = 0 -% g.handsBobStep;
    g.handsBobPos +%= g.handsBobStep;

    const t = &g.tables.trig;
    var fisheye: i32 = 0; // index into table 4
    // The walks' outputs live across the columns: off the map a walk leaves cell/hit as they
    // were (the original's uninitialised stack words in the first column; with the shipped
    // maps' closed borders the nearer walk always hits).
    var v_dist: i32 = 0;
    var v_cell: i32 = 0;
    var v_hit: i32 = 0;
    var h_dist: i32 = 0;
    var h_cell: i32 = 0;
    var h_hit: i32 = 0;
    const gw: Gateways = .{};
    var col_idx: i32 = 0x77;
    var col_x: i32 = 0x1f0;
    while (col_x >= 0x14) : ({
        col_idx -%= 1;
        col_x -%= 4;
    }) {
        walkVertical(gw, angle, x, y, at(t[0], angle), at(t[5], angle), at(t[2], angle), bd.spriteQueue, &bd.wallRows, &bd.objectRows, &v_dist, &v_cell, &v_hit) catch @panic(latent_border);
        walkHorizontal(gw, angle, x, y, at(t[1], angle), at(t[6], angle), at(t[3], angle), bd.spriteQueue, &bd.wallRows, &bd.objectRows, &h_dist, &h_cell, &h_hit) catch @panic(latent_border);
        const fish = at(t[4], fisheye);
        if (h_dist <= v_dist) {
            drawColumn(g, bd, true, h_dist, h_cell, h_hit, fish, col_x, col_idx);
        } else {
            drawColumn(g, bd, false, v_dist, v_cell, v_hit, fish, col_x, col_idx);
        }
        fisheye += 4;
        angle +%= 4;
        if (angle >= 0xb40) angle -%= 0xb40;
    }
    const hands = bd.hands.?;
    hands.y +%= g.handsBobStep;
}

// ---- tests ----

const testing = std.testing;
const game_mod = @import("core/game.zig");
const tables = @import("tables.zig");
const labmap = @import("labmap.zig");
const walk_cases = @import("testdata/raycast_walk.zig");

/// Records the gateway calls as the oracle saw them (objects by index).
const Recorder = struct {
    objs: *const [60]Object,
    calls: *std.ArrayList(walk_cases.Call),

    fn id(r: Recorder, o: *Object) u8 {
        const base = @intFromPtr(&r.objs[0]);
        return @intCast((@intFromPtr(o) - base) / @sizeOf(Object));
    }
    pub fn setVisible(r: Recorder, o: *Object, v: i32) void {
        r.calls.append(testing.allocator, .{ .vis = true, .obj = r.id(o), .dist = v, .angle = 0, .col = 0, .row = 0 }) catch unreachable;
    }
    pub fn enqueue(r: Recorder, q: ?*SpriteQueue, o: *Object, d: i32, a: i32, c: i32, w: i32) void {
        _ = q;
        r.calls.append(testing.allocator, .{ .vis = false, .obj = r.id(o), .dist = d, .angle = a, .col = c, .row = w }) catch unreachable;
    }
};

fn loadMaps(g: *Game, bds: *[3]Backdrop) !void {
    const names = [_][]const u8{ "\\JARDIM\\RAYMAP1.DAT", "\\JARDIM\\RAYMAP2.DAT", "\\JARDIM\\RAYMAP3.DAT" };
    for (names, 0..) |name, i| {
        bds[i] = .{};
        try testing.expect(labmap.loadMap(g, &bds[i], name));
    }
}

const sentinel: i32 = @bitCast(@as(u32, 0xaaaaaaaa));

// @orig 1008:0024 raycast_walk_horizontal oracle=emulated
// @orig 1010:0024 raycast_walk_vertical oracle=emulated
test "the ray walks against the original (2,000 rays over the three maps)" {
    const t = try game_mod.TestGame.init(testing.allocator);
    defer t.deinit();
    const g = t.game;
    try tables.build(g);
    const bds = try testing.allocator.create([3]Backdrop);
    defer testing.allocator.destroy(bds);
    try loadMaps(g, bds);
    var objs: [3][60]Object = undefined;
    for (&objs, 0..) |*m, mi| {
        for (m, 0..) |*o, k| {
            o.* = .{ .kind = .portable };
            const c = walk_cases.objects[mi][k];
            bds[mi].objectRows[c.row][c.col] = o;
        }
    }
    var calls: std.ArrayList(walk_cases.Call) = .empty;
    defer calls.deinit(testing.allocator);
    var queue: SpriteQueue = .{};
    var off_map: usize = 0;
    var queued: usize = 0;
    for (walk_cases.cases, 0..) |c, n| {
        const bd = &bds[c.map - 1];
        const rec: Recorder = .{ .objs = &objs[c.map - 1], .calls = &calls };
        calls.clearRetainingCapacity();
        var dist = sentinel;
        var cell = sentinel;
        var hit = sentinel;
        const a: usize = @intCast(c.angle);
        const tr = &g.tables.trig;
        const r = if (c.vertical)
            walkVertical(rec, c.angle, c.x, c.y, tr[0][a], tr[5][a], tr[2][a], &queue, &bd.wallRows, &bd.objectRows, &dist, &cell, &hit)
        else
            walkHorizontal(rec, c.angle, c.x, c.y, tr[1][a], tr[6][a], tr[3][a], &queue, &bd.wallRows, &bd.objectRows, &dist, &cell, &hit);
        errdefer std.debug.print("case {d}: map {d} {s} angle {d} ({d}, {d})\n", .{ n, c.map, if (c.vertical) "v" else "h", c.angle, c.x, c.y });
        try testing.expectEqual(c.fault, std.meta.isError(r));
        try testing.expectEqual(c.dist, dist);
        try testing.expectEqual(c.cell, cell);
        try testing.expectEqual(c.hit, hit);
        try testing.expectEqualSlices(walk_cases.Call, walk_cases.calls[c.first..][0..c.count], calls.items);
        if (dist == no_hit) off_map += 1;
        queued += c.count;
    }
    try testing.expect(off_map > 0 and queued > 0);
}

test "a see-through door on the map border reads outside the map" {
    var rows: WallRows = @splat(@splat(0));
    const objs: ObjectRows = @splat(@splat(null));
    // A wall-free row 40 with an odd door in column 0: the vertical walk going -x reads column -1.
    rows[40][0] = 9;
    var dist: i32 = 0;
    var cell: i32 = 0;
    var hit: i32 = 0;
    const gw: Gateways = .{};
    try testing.expectError(error.Fault, walkVertical(gw, 1440, 100, 40 * 32 + 16, 0, -65536, 0, null, &rows, &objs, &dist, &cell, &hit));
    // dist is stored before the read of the cell behind.
    try testing.expectEqual(@as(i32, ((31 - 100) * -65536) >> 16), dist);
    // An even door there is a recessed plane: no read.
    rows[40][0] = 8;
    try walkVertical(gw, 1440, 100, 40 * 32 + 16, 0, -65536, 0, null, &rows, &objs, &dist, &cell, &hit);
    try testing.expectEqual(@as(i32, 8), cell);
}

const ViewFixture = struct {
    t: game_mod.TestGame,
    bd: *Backdrop,
    pixels: []u8,
    tex: []u8,
    dib: *object.Dib,
    frames: [1]object.Frame,
    strip: Object,
    hands: Object,
    queue: SpriteQueue,

    fn init(self: *ViewFixture) !void {
        self.t = try game_mod.TestGame.init(testing.allocator);
        const g = self.t.game;
        try tables.build(g);
        self.bd = try testing.allocator.create(Backdrop);
        self.bd.* = .{};
        try testing.expect(labmap.loadMap(g, self.bd, "\\JARDIM\\RAYMAP1.DAT"));
        self.pixels = try testing.allocator.alloc(u8, 640 * 480);
        @memset(self.pixels, 0);
        self.bd.pixels = self.pixels;
        self.bd.bmiHeader = .{ .biWidth = 640, .biHeight = -480 };
        self.bd.viewY = 42;
        self.bd.viewH = 300;
        // paredesN.bmp's shape: 32 x 1800, six textures of 300 rows; each pixel its column.
        self.tex = try testing.allocator.alloc(u8, 32 * 1800);
        for (self.tex, 0..) |*p, i| p.* = @intCast(i % 32 + 1);
        self.dib = try testing.allocator.create(object.Dib);
        self.dib.* = .{ .header = .{ .biWidth = 32, .biHeight = 1800 }, .colors = @splat(.{}), .bits = self.tex };
        self.frames = .{.{ .width = 32, .height = 1800, .count = 1, .dib = self.dib, .hitW = 32 }};
        self.strip = .{ .kind = .wall_strip };
        self.strip.frames = &self.frames;
        self.strip.framesLeft = 300;
        self.hands = .{ .kind = .scene_object };
        self.queue = .{};
        self.bd.wallStrip = &self.strip;
        self.bd.hands = &self.hands;
        self.bd.spriteQueue = &self.queue;
    }

    fn deinit(self: *ViewFixture) void {
        testing.allocator.free(self.tex);
        testing.allocator.destroy(self.dib);
        testing.allocator.free(self.pixels);
        testing.allocator.destroy(self.bd);
        self.t.deinit();
    }
};

// @orig 1028:0951 raycast_render_view oracle=documented
// @orig 1028:0951 raycast_render_view oracle=documented
test "renderView: the nearer walk per column, the depths, the hands' sway and J4" {
    const fx = try testing.allocator.create(ViewFixture);
    defer testing.allocator.destroy(fx);
    try fx.init();
    defer fx.deinit();
    const g = fx.t.game;
    const bd = fx.bd;
    // Phase 1's start: row 2, column 1 (x 48, y 80), looking along +y.
    const px: i32 = 48;
    const py: i32 = 80;
    const ang: i32 = 720;
    // The texture column each screen column shows (each texture pixel is its column + 1), in the
    // original (J4: the screen x for a wall, the hit & ~3 for a door) and with the fix.
    var want_orig: [120]u8 = undefined;
    var want_fix: [120]u8 = undefined;
    var depth: [120]i32 = undefined;
    var a: i32 = ang - 240;
    var col: usize = 120;
    const tr = &g.tables.trig;
    const none: Gateways = .{};
    while (col > 0) {
        col -= 1;
        var vd: i32 = 0;
        var vc: i32 = 0;
        var vh: i32 = 0;
        var hd: i32 = 0;
        var hc: i32 = 0;
        var hh: i32 = 0;
        const i: usize = @intCast(a);
        try walkVertical(none, a, px, py, tr[0][i], tr[5][i], tr[2][i], bd.spriteQueue, &bd.wallRows, &bd.objectRows, &vd, &vc, &vh);
        try walkHorizontal(none, a, px, py, tr[1][i], tr[6][i], tr[3][i], bd.spriteQueue, &bd.wallRows, &bd.objectRows, &hd, &hc, &hh);
        const h = hd <= vd;
        depth[col] = if (h) hd else vd;
        const cell = if (h) hc else vc;
        const hit_col: u8 = @intCast(((if (h) hh else vh) >> 16) & 0x1c);
        const sx: u8 = @intCast((20 + 4 * col) & 31);
        want_orig[col] = 1 + if (cell > 6 and cell <= 12) hit_col else sx;
        want_fix[col] = 1 + hit_col;
        a += 4;
    }
    renderView(g, bd, px, py, ang);
    try testing.expectEqual(@as(i16, 2), g.handsBobPos);
    try testing.expectEqual(@as(i16, 2), fx.hands.y);
    try testing.expectEqualSlices(i32, &depth, &g.columnDepth);
    // The middle row of the view (192) is in every column's slice.
    const mid = 192 * 640;
    for (0..120) |c| try testing.expectEqual(want_orig[c] +% shade(depth[c]), fx.pixels[mid + 20 + 4 * c]);
    g.fixes.jardim_wall_texture_on_wall = true;
    @memset(fx.pixels, 0);
    renderView(g, bd, px, py, ang);
    try testing.expectEqual(@as(i16, 4), g.handsBobPos);
    for (0..120) |c| try testing.expectEqual(want_fix[c] +% shade(depth[c]), fx.pixels[mid + 20 + 4 * c]);
    try testing.expect(!std.mem.eql(u8, &want_orig, &want_fix));
}

/// The shading `blit_scaled_column` adds for a distance: k * 0x17, k = min(3, dist >> 6).
fn shade(d: i32) u8 {
    const k: i32 = if (d > 3 << 6) 3 else d >> 6;
    return @intCast(k * 0x17);
}
