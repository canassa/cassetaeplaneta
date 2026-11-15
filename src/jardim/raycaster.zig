//! Not in the original (`Fixes.jardim_raycaster`, a Corrigida addition; docs/jardim/DESIGN.md "The
//! raycaster"): a proper raycaster for the 3-D view, replacing `raycast.renderView`'s walls.
//!
//! The 1995 view casts 120 rays, 0.5 degree apart, and draws each as a 4-px column from the whole-unit
//! ray length. This one:
//!
//! - casts **one ray per pixel column** (480) through a flat camera plane (a 60 degree field, the
//!   original's: the focal length is 240 / tan 30 px), so a straight wall is straight;
//! - walks the grid with the **DDA** (Lode Vandevenne's, the grid lines 32 units apart as the original's
//!   walks) and measures the **perpendicular** distance (no fisheye, nothing to correct);
//! - draws the wall slice from the exact distance: height 22500 / distance px (the original's
//!   scale), its top and bottom at the **sub-pixel**, the texture row stepped per pixel row and clipped
//!   when the slice is taller than the view; the texture column is the exact hit point, flipped on the
//!   faces that would mirror it, 4 times a cell on a wall and once on a door (`jardim_texture_per_pixel`'s
//!   choice);
//! - **casts the floor** per row in world space: row distance = eye height / (row - horizon), stepped along
//!   the camera plane, so the floor art stays on the ground as you walk and turn; the sky stays the
//!   backdrop's, scrolled by the original's turns;
//! - **filters the textures** a wall or the floor shows at a distance: the 32 x 300 wall textures and the
//!   floor tile are box-filtered into mip levels (per axis for the walls), each averaged texel snapped to
//!   the texture's own palette entries (the picture is 8-bit and the wall shading adds a fixed step to
//!   the entry, so no entry can be invented), and the level is chosen from the texels a pixel spans. A
//!   far wall is one flat tone instead of the static that sampling a noise texture one texel in five
//!   gives (docs/jardim/TEXTURES.md "The far wall");
//! - keeps a **1-D depth buffer** (`State.depth`, one distance per column) that the sprites are clipped
//!   against column by column (`drawSprite`), so an enemy hides behind a wall that cuts across it.
//!
//! The doors are the original's: an odd door seen along x-lines (even along y-lines) is a plane
//! recessed half a cell, reached only when the ray gets that far inside the cell; the other way
//! the ray stops at the door cell's face and the wall beyond it is drawn. The shading is the original's
//! (the palette has each wall colour four times, 23 entries apart: `min(3, distance >> 6)` steps), by the
//! perpendicular distance. The pose is the player's continuous position (`playerX` plus
//! `g.wolf.fracX`) and view angle. **Only the pixels change**: `raycast.renderView` still runs the 1995
//! walks (they build the sprite queue, flag the objects visible and fill `g.columnDepth`, the enemies'
//! 1995 logic reads them) and draws nothing for the walls; this draws the floor and the walls, and the
//! sprites are drawn by `sprites.drawEntry`, which calls `drawSprite` instead of the 1995 stretch blit
//! (the enemies' own logic keeps the original's visibility test).
//!
//! The walls and the floor are drawn from the surface's palette indexes; the pixels written are always
//! the backdrop's own (`bd.pixels`).

const std = @import("std");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const position = @import("behaviour/position.zig");
const sprites = @import("sprites.zig");

/// The view's pixel columns (the original draws 120 of 4 px).
pub const view_w = 480;
/// The wall textures: 32 texels wide, `tex_h` rows, six of them in one bitmap.
const tex_w: usize = 32;
const max_tex: usize = 6;
const lu_n: usize = 6; // 32 >> 5 = 1
const lv_n: usize = 9; // 300 >> 8 = 2 (the top level is 1 row: `(300 + 255) >> 8`)
/// The floor tile: a square of this many texels, mirrored where it repeats, one cell wide.
const floor_n: usize = 128;
const floor_levels: usize = 8;

/// Texels a cell spans across: the wall textures repeat 4 times a cell, a door once, the floor tile once
/// (the same scale as the walls: 4 texels a unit).
pub const wall_tiling = 4;
pub const door_tiling = 1;
/// The camera's field: 60 degrees, so the focal length is half the view over tan 30 degrees.
const half_tan: f64 = 0.5773502691896257;
/// The wall height 22500 px / distance in units (the original's `table[4]` scale); the eye is in the
/// middle of it.
const wall_scale: f64 = 22500.0;

/// The mip levels of the six wall textures, `levels[t]` the texels of texture t's (lu, lv) level.
const WallMips = struct {
    data: []u8,
    off: [max_tex][lu_n][lv_n]u32,
    tex_h: u16,
    count: u8,

    fn w(lu: usize) usize {
        return @max(tex_w >> @intCast(lu), 1);
    }

    fn h(self: *const WallMips, lv: usize) usize {
        return (@as(usize, self.tex_h) + (@as(usize, 1) << @intCast(lv)) - 1) >> @intCast(lv);
    }

    fn at(self: *const WallMips, t: usize, lu: usize, lv: usize) []const u8 {
        return self.data[self.off[t][lu][lv]..];
    }
};

/// The floor tile's mips: level l is `(128 >> l)` square.
const FloorMips = struct {
    data: []u8,
    off: [floor_levels]u32,
};

/// The renderer's state in `Game.rc`: the camera of the last frame (the sprites' projection), the depth
/// buffer, and the textures' mips (built the first frame, again if the phase brought other bitmaps).
pub const State = struct {
    /// The wall's perpendicular distance in units per pixel column of the view, from the last frame.
    depth: [view_w]f32 = @splat(0),
    /// A frame of the raycaster has been drawn: the depth buffer is valid.
    ready: bool = false,
    /// The last frame's camera, in units: the position and the unit direction and right vectors.
    px: f64 = 0,
    py: f64 = 0,
    dx: f64 = 1,
    dy: f64 = 0,
    focal: f64 = 240.0 / half_tan,
    walls: ?*WallMips = null,
    walls_for: ?[*]const u8 = null,
    floor: ?*FloorMips = null,
    floor_for: ?[*]const u8 = null,
    /// The backdrop the mips were built for (each phase has its own bitmaps).
    built_for: ?*const Backdrop = null,
};

fn rowStride(width: i32) usize {
    return @intCast(((@as(u32, @bitCast(width)) & 0xffff) + 3) & 0xfffc);
}

/// The offset of the surface's row `y` (top-down when its height is negative, as the game's is).
fn rowBase(bd: *const Backdrop, y: i32) usize {
    const stride = rowStride(bd.bmiHeader.biWidth);
    if (bd.bmiHeader.biHeight < 0) return @as(usize, @intCast(y)) * stride;
    return @as(usize, @intCast(@as(i32, @intCast(@abs(bd.bmiHeader.biHeight))) - 1 - y)) * stride;
}

// ---- the textures' mips ----

/// The palette entry among `allowed` nearest to the colour (r, g, b).
fn nearest(bd: *const Backdrop, allowed: []const u8, r: i32, g: i32, b: i32) u8 {
    var best: u8 = allowed[0];
    var best_d: i32 = std.math.maxInt(i32);
    for (allowed) |i| {
        const c = bd.bmiColors[i];
        const dr = r - c.red;
        const dg = g - c.green;
        const db = b - c.blue;
        const d = dr * dr + dg * dg + db * db;
        if (d < best_d) {
            best_d = d;
            best = i;
        }
    }
    return best;
}

/// The distinct palette entries of `src`, ascending.
fn distinct(src: []const u8, buf: *[256]u8) []const u8 {
    var seen: [256]bool = @splat(false);
    for (src) |p| seen[p] = true;
    var n: usize = 0;
    for (seen, 0..) |s, i| {
        if (s) {
            buf[n] = @intCast(i);
            n += 1;
        }
    }
    return buf[0..n];
}

/// Box-filters `src` (`w` x `h`, row-major, top row first) by `bw` x `bh` texels into `dst`
/// (`(w + bw - 1) / bw` by `(h + bh - 1) / bh`), each average snapped to an entry of `allowed`.
fn boxFilter(bd: *const Backdrop, allowed: []const u8, src: []const u8, w: usize, h: usize, bw: usize, bh: usize, dst: []u8) void {
    const ow = (w + bw - 1) / bw;
    const oh = (h + bh - 1) / bh;
    for (0..oh) |oy| {
        for (0..ow) |ox| {
            var sr: i32 = 0;
            var sg: i32 = 0;
            var sb: i32 = 0;
            var n: i32 = 0;
            var y = oy * bh;
            while (y < @min(h, (oy + 1) * bh)) : (y += 1) {
                var x = ox * bw;
                while (x < @min(w, (ox + 1) * bw)) : (x += 1) {
                    const c = bd.bmiColors[src[y * w + x]];
                    sr += c.red;
                    sg += c.green;
                    sb += c.blue;
                    n += 1;
                }
            }
            dst[oy * ow + ox] = if (bw == 1 and bh == 1) src[oy * w + ox] else nearest(bd, allowed, @divTrunc(sr, n), @divTrunc(sg, n), @divTrunc(sb, n));
        }
    }
}

/// The ripmaps of the wall strip's textures (`dib`: `tex_h` rows each, stacked, bottom-up in memory).
fn buildWalls(g: *Game, bd: *const Backdrop, dib: *const object.Dib, tex_h: u16) ?*WallMips {
    const arena = g.local();
    const m = arena.create(WallMips) catch return null;
    const stride = rowStride(dib.header.biWidth);
    const total_rows: usize = @intCast(@abs(dib.header.biHeight));
    const count: usize = @min(max_tex, total_rows / tex_h);
    m.tex_h = tex_h;
    m.count = @intCast(count);
    // The size of all the levels of one texture.
    var per_tex: usize = 0;
    for (0..lu_n) |lu| {
        for (0..lv_n) |lv| per_tex += WallMips.w(lu) * m.h(lv);
    }
    m.data = arena.alloc(u8, per_tex * count) catch return null;
    const base = arena.alloc(u8, tex_w * tex_h) catch return null;
    var at: usize = 0;
    for (0..count) |t| {
        // The texture's rows, top first (the picture is bottom-up).
        for (0..tex_h) |r| {
            const mem_row = total_rows - 1 - (t * tex_h + r);
            @memcpy(base[r * tex_w ..][0..tex_w], dib.bits[mem_row * stride ..][0..tex_w]);
        }
        var buf: [256]u8 = undefined;
        const allowed = distinct(base, &buf);
        for (0..lu_n) |lu| {
            for (0..lv_n) |lv| {
                m.off[t][lu][lv] = @intCast(at);
                const w = WallMips.w(lu);
                const h = m.h(lv);
                boxFilter(bd, allowed, base, tex_w, tex_h, @as(usize, 1) << @intCast(lu), @as(usize, 1) << @intCast(lv), m.data[at..][0 .. w * h]);
                at += w * h;
            }
        }
    }
    return m;
}

/// The floor tile: a `floor_n` square of the backdrop picture's floor (the sand of rows 192..341),
/// and its mip levels.
fn buildFloor(g: *Game, bd: *const Backdrop, bg: *const object.Dib) ?*FloorMips {
    const arena = g.local();
    const m = arena.create(FloorMips) catch return null;
    var total: usize = 0;
    for (0..floor_levels) |l| total += (floor_n >> @intCast(l)) * (floor_n >> @intCast(l));
    m.data = arena.alloc(u8, total) catch return null;
    const stride = rowStride(bg.header.biWidth);
    const rows: usize = @intCast(@abs(bg.header.biHeight));
    // The tile's top left in the picture: inside the floor's 480 x 150, off its frame.
    const x0: usize = @intCast(@as(i32, bd.viewX) + 176);
    const y0: usize = @intCast(@as(i32, bd.horizonY) + 11);
    var base: [floor_n * floor_n]u8 = undefined;
    for (0..floor_n) |y| {
        const mem_row = if (bg.header.biHeight < 0) y0 + y else rows - 1 - (y0 + y);
        @memcpy(base[y * floor_n ..][0..floor_n], bg.bits[mem_row * stride + x0 ..][0..floor_n]);
    }
    var buf: [256]u8 = undefined;
    const allowed = distinct(&base, &buf);
    var at: usize = 0;
    for (0..floor_levels) |l| {
        m.off[l] = @intCast(at);
        const n = floor_n >> @intCast(l);
        boxFilter(bd, allowed, &base, floor_n, floor_n, @as(usize, 1) << @intCast(l), @as(usize, 1) << @intCast(l), m.data[at..][0 .. n * n]);
        at += n * n;
    }
    return m;
}

/// The mips for this frame's bitmaps, built the first time (and again when the phase brought others).
fn prepare(g: *Game, bd: *Backdrop) bool {
    const rc = &g.rc;
    if (rc.built_for != bd) {
        rc.walls = null;
        rc.floor = null;
        rc.built_for = bd;
    }
    const strip = bd.wallStrip orelse return false;
    const wall_dib = position.dib(strip) orelse return false;
    if (rc.walls == null or rc.walls_for != wall_dib.bits.ptr) {
        rc.walls = buildWalls(g, bd, wall_dib, @intCast(strip.framesLeft));
        rc.walls_for = wall_dib.bits.ptr;
    }
    const bg = bd.background orelse return false;
    if (rc.floor == null or rc.floor_for != bg.bits.ptr) {
        rc.floor = buildFloor(g, bd, bg);
        rc.floor_for = bg.bits.ptr;
    }
    return rc.walls != null and rc.floor != null;
}

// ---- the camera ----

const Camera = struct {
    /// The position in cells.
    px: f64,
    py: f64,
    /// The unit direction and the right-hand vector (the screen's right).
    dx: f64,
    dy: f64,
    rx: f64,
    ry: f64,
    focal: f64,
};

/// The view angle as the tables' (`(i | 1)` units of 2 pi / 2880, nudged off the axes), so the walls and
/// the sprites the original's tables project agree.
fn viewTheta(angle: i32) f64 {
    const units: f64 = @floatFromInt(angle | 1);
    return units * (2.0 * std.math.pi / @as(f64, world.full_turn)) + 0.0003272;
}

fn camera(g: *Game, bd: *const Backdrop, x: i32, y: i32, angle: i32) Camera {
    var fx: f64 = 0;
    var fy: f64 = 0;
    if (g.fixes.jardim_smooth_movement) {
        fx = @as(f64, @floatFromInt(g.wolf.fracX)) / 65536.0;
        fy = @as(f64, @floatFromInt(g.wolf.fracY)) / 65536.0;
    }
    const t = viewTheta(angle);
    const c = @cos(t);
    const s = @sin(t);
    return .{
        .px = (@as(f64, @floatFromInt(x)) + fx) / 32.0,
        .py = (@as(f64, @floatFromInt(y)) + fy) / 32.0,
        .dx = c,
        .dy = s,
        .rx = s,
        .ry = -c,
        .focal = @as(f64, @floatFromInt(bd.viewW)) / 2.0 / half_tan,
    };
}

// ---- one frame ----

fn cellAt(bd: *const Backdrop, row: i32, col: i32) i32 {
    // Off the map is solid: the shipped maps are closed, a door on the border is the original's fault.
    if (row < 0 or row >= world.map_rows or col < 0 or col >= world.map_cols) return 1;
    return @as(u8, @bitCast(bd.wallRows[@intCast(row)][@intCast(col)]));
}

/// What a ray hit.
const Hit = struct {
    /// The perpendicular distance in cells.
    t: f64,
    /// The cell value the texture comes from (1..12).
    cell: i32,
    /// The position along the wall in cells, mirrored where the face would show the texture reversed.
    along: f64,
    /// The texels one pixel column advances along the wall (positive), for the mip level.
    du: f64,
};

fn faceFlip(side: u1, step: i32) bool {
    // y is up on the map: looking along +x the screen's right is -y, along +y it is +x. The texture
    // runs to the viewer's right: along y (on an x face) against +x travel, along x (on a y face)
    // against -y travel.
    return if (side == 0) step > 0 else step < 0;
}

/// The wall one column's ray meets (the DDA).
fn castRay(bd: *const Backdrop, cam: Camera, q: f64) Hit {
    const rdx = cam.dx + cam.rx * q;
    const rdy = cam.dy + cam.ry * q;
    var map_x: i32 = @intFromFloat(@floor(cam.px));
    var map_y: i32 = @intFromFloat(@floor(cam.py));
    const inf = std.math.inf(f64);
    const ddx = if (rdx == 0) inf else @abs(1.0 / rdx);
    const ddy = if (rdy == 0) inf else @abs(1.0 / rdy);
    const step_x: i32 = if (rdx < 0) -1 else 1;
    const step_y: i32 = if (rdy < 0) -1 else 1;
    var side_x = if (rdx < 0) (cam.px - @as(f64, @floatFromInt(map_x))) * ddx else (@as(f64, @floatFromInt(map_x)) + 1.0 - cam.px) * ddx;
    var side_y = if (rdy < 0) (cam.py - @as(f64, @floatFromInt(map_y))) * ddy else (@as(f64, @floatFromInt(map_y)) + 1.0 - cam.py) * ddy;
    var side: u1 = 0;
    var steps: u32 = 0;
    while (steps < 400) : (steps += 1) {
        if (side_x < side_y) {
            side_x += ddx;
            map_x += step_x;
            side = 0;
        } else {
            side_y += ddy;
            map_y += step_y;
            side = 1;
        }
        const enter = if (side == 0) side_x - ddx else side_y - ddy;
        const c = cellAt(bd, map_y, map_x);
        if (c == 0) continue;
        var t = enter;
        var cell = c;
        if (c > 6) {
            // A door: `recessed` is the plane half a cell inside; else the cell beyond is drawn at the face.
            const even = c & 1 == 0;
            const recessed = if (side == 0) even else !even;
            if (recessed) {
                const t_plane = if (side == 0)
                    (@as(f64, @floatFromInt(map_x)) + 0.5 - cam.px) / rdx
                else
                    (@as(f64, @floatFromInt(map_y)) + 0.5 - cam.py) / rdy;
                // The ray must still be inside the cell when it gets there.
                if (t_plane >= @min(side_x, side_y)) continue;
                t = t_plane;
            } else {
                cell = if (side == 0) cellAt(bd, map_y, map_x + step_x) else cellAt(bd, map_y + step_y, map_x);
                if (cell < 1 or cell > 12) cell = 1;
            }
        }
        var along = if (side == 0) cam.py + t * rdy else cam.px + t * rdx;
        along -= @floor(along);
        if (faceFlip(side, if (side == 0) step_x else step_y)) along = 1.0 - along;
        // The wall's texels per pixel column: d(along)/d(column) = t / |rd component| / focal.
        const rd_across = if (side == 0) @abs(rdx) else @abs(rdy);
        const per_col = t / rd_across / cam.focal;
        const tiling: f64 = if (cell > 6) door_tiling else wall_tiling;
        return .{ .t = t, .cell = cell, .along = along, .du = per_col * tiling * @as(f64, @floatFromInt(tex_w)) };
    }
    return .{ .t = 1e9, .cell = 1, .along = 0, .du = 0 };
}

fn log2floor(v: f64) usize {
    if (v < 2) return 0;
    return @intFromFloat(@floor(@log2(v)));
}

/// The wall slice of one pixel column at screen x `sx`.
fn drawWall(bd: *Backdrop, mips: *const WallMips, hit: Hit, sx: usize) void {
    const dist = hit.t * 32.0; // units
    const horizon: f64 = @floatFromInt(bd.horizonY);
    const view_top: i32 = bd.viewY;
    const view_bottom: i32 = bd.viewY + bd.viewH;
    const line_h = wall_scale / dist;
    const top = horizon - line_h / 2.0;
    // The rows whose centre is inside the slice.
    const y0: i32 = @max(view_top, @as(i32, @intFromFloat(@ceil(@max(top - 0.5, -1e6)))));
    const y1: i32 = @min(view_bottom, @as(i32, @intFromFloat(@ceil(@min(top + line_h - 0.5, 1e6)))));
    if (y1 <= y0) return;
    const tex_h: f64 = @floatFromInt(mips.tex_h);
    const per_row = tex_h / line_h; // texture rows a pixel row advances
    const tex: usize = @intCast(@divTrunc(hit.cell + 1, 2) - 1);
    if (tex >= mips.count) return;
    const lu = @min(log2floor(hit.du), lu_n - 1);
    const lv = @min(log2floor(per_row), lv_n - 1);
    const data = mips.at(tex, lu, lv);
    const mw = WallMips.w(lu);
    const mh = mips.h(lv);
    // The texel column: the position along the wall times the tiling, wrapped.
    const tiling: f64 = if (hit.cell > 6) door_tiling else wall_tiling;
    var u = hit.along * tiling;
    u -= @floor(u);
    const col: usize = @min(@as(usize, @intFromFloat(u * @as(f64, @floatFromInt(tex_w)))) >> @intCast(lu), mw - 1);
    // v in 16.16 mip rows at the first row's centre.
    const mip_row = @as(f64, @floatFromInt(@as(usize, 1) << @intCast(lv)));
    const step: i64 = @intFromFloat(per_row / mip_row * 65536.0);
    var v: i64 = @intFromFloat(((@as(f64, @floatFromInt(y0)) + 0.5 - top) * per_row / mip_row) * 65536.0);
    const k: i32 = if (dist >= 192) 3 else @as(i32, @intFromFloat(dist)) >> 6;
    const shade: u8 = @intCast(k * 0x17);
    var y = y0;
    while (y < y1) : (y += 1) {
        const ty: usize = @intCast(std.math.clamp(v >> 16, 0, @as(i64, @intCast(mh)) - 1));
        bd.pixels[rowBase(bd, y) + sx] = data[ty * mw + col] +% shade;
        v += step;
    }
}

/// The distance (perpendicular, cells) of the floor row whose centre is `below` px under the horizon.
fn floorDist(below: f64) f64 {
    return (wall_scale / 2.0) / below / 32.0;
}

/// The world point (cells) the floor shows `across` px right of the view's centre and `below` px under the
/// horizon: the camera plane's ray through the pixel, taken to the row's distance.
fn floorPoint(cam: Camera, across: f64, below: f64) [2]f64 {
    const d = floorDist(below);
    const q = across / cam.focal;
    return .{ cam.px + (cam.dx + cam.rx * q) * d, cam.py + (cam.dy + cam.ry * q) * d };
}

/// A floor row's walk across the view in 16.16 texels of the tile (wrapping modulo 65536 texels), and
/// the mip level its pixels need.
const FloorRow = struct { u: u32, v: u32, du: u32, dv: u32, level: usize };

fn texels16(v: f64) u32 {
    const scale = @as(f64, @floatFromInt(floor_n)) * 65536.0;
    // The world is wrapped modulo 512 cells (65536 texels) so the product stays in range.
    const m = @mod(v, 512.0);
    return @truncate(@as(u64, @bitCast(@as(i64, @intFromFloat(m * scale)))));
}

fn floorRow(cam: Camera, below: f64, half_w: f64) FloorRow {
    const d = floorDist(below);
    // The footprint of a pixel in texels: across the row, and down the screen.
    const across = d * 32.0 / cam.focal * wall_tiling;
    const downwards = d * d * 32.0 / (wall_scale / 2.0) * wall_tiling;
    const p = floorPoint(cam, 0.5 - half_w, below);
    return .{
        .u = texels16(p[0]),
        .v = texels16(p[1]),
        .du = texels16(cam.rx * d / cam.focal),
        .dv = texels16(cam.ry * d / cam.focal),
        .level = @min(log2floor(@sqrt(across * downwards)), floor_levels - 1),
    };
}

/// The floor, row by row: the row's distance from its height under the horizon, the world point of its
/// first pixel and the step along the camera plane, so the tile is fixed to the ground.
fn drawFloor(bd: *Backdrop, mips: *const FloorMips, cam: Camera) void {
    const horizon: f64 = @floatFromInt(bd.horizonY);
    const half_w: f64 = @as(f64, @floatFromInt(bd.viewW)) / 2.0;
    var y: i32 = bd.horizonY;
    const bottom: i32 = bd.viewY + bd.viewH;
    while (y < bottom) : (y += 1) {
        const row = floorRow(cam, @as(f64, @floatFromInt(y)) + 0.5 - horizon, half_w);
        const n: usize = floor_n >> @intCast(row.level);
        const data = mips.data[mips.off[row.level]..];
        var u = row.u;
        var v = row.v;
        var di = rowBase(bd, y) + @as(usize, @intCast(bd.viewX));
        for (0..view_w) |_| {
            const tu = mirror(@as(usize, u >> 16));
            const tv = mirror(@as(usize, v >> 16));
            bd.pixels[di] = data[(tv >> @intCast(row.level)) * n + (tu >> @intCast(row.level))];
            u +%= row.du;
            v +%= row.dv;
            di += 1;
        }
    }
}

/// A texel coordinate of the repeating, mirrored tile.
fn mirror(c: usize) usize {
    const m = c & (2 * floor_n - 1);
    return if (m >= floor_n) 2 * floor_n - 1 - m else m;
}

/// The sprite of `obj` (the strip `src`'s current frame, its pixels `bits`) drawn from its map position
/// (`worldX`, `worldY`: the cell's centre, or where a fair enemy walks) against the last frame's camera:
/// standing on the floor (the same scale as the wall of its distance: 22500 / depth px for 300 texels),
/// each pixel column kept only where the sprite is nearer than the wall's depth. True if a column showed.
pub fn drawSprite(g: *Game, bd: *Backdrop, obj: *Object, bits: []const u8) bool {
    const rc = &g.rc;
    const src = position.dib(obj) orelse return false;
    const rel_x = @as(f64, @floatFromInt(obj.worldX)) - rc.px;
    const rel_y = @as(f64, @floatFromInt(obj.worldY)) - rc.py;
    const depth = rel_x * rc.dx + rel_y * rc.dy;
    if (depth < 1.0) return false;
    const lateral = rel_x * rc.dy - rel_y * rc.dx; // right of the view axis
    const scale = wall_scale / depth;
    const sw: i32 = position.width(obj);
    const sh: i32 = position.height(obj);
    if (sw <= 0 or sh <= 0) return false;
    const wf = @as(f64, @floatFromInt(sw)) * scale / 300.0;
    const hf = @as(f64, @floatFromInt(sh)) * scale / 300.0;
    const cx = @as(f64, @floatFromInt(bd.viewX)) + @as(f64, @floatFromInt(bd.viewW)) / 2.0 + rc.focal * lateral / depth;
    const left = cx - wf / 2.0;
    const bottom = @as(f64, @floatFromInt(bd.horizonY)) + scale / 2.0;
    const top = bottom - hf;
    const x0: i32 = @max(bd.viewX, @as(i32, @intFromFloat(@ceil(std.math.clamp(left - 0.5, -1e6, 1e6)))));
    const x1: i32 = @min(bd.viewX + bd.viewW, @as(i32, @intFromFloat(@ceil(std.math.clamp(left + wf - 0.5, -1e6, 1e6)))));
    const y0: i32 = @max(bd.viewY, @as(i32, @intFromFloat(@ceil(std.math.clamp(top - 0.5, -1e6, 1e6)))));
    const y1: i32 = @min(bd.viewY + bd.viewH, @as(i32, @intFromFloat(@ceil(std.math.clamp(bottom - 0.5, -1e6, 1e6)))));
    if (x1 <= x0 or y1 <= y0) return false;
    // The source row of each destination row, once.
    var rows: [world.max_view_h]u16 = undefined;
    const n_rows: usize = @intCast(y1 - y0);
    if (n_rows > rows.len) return false;
    const src_rows: i32 = @intCast(@abs(src.header.biHeight));
    const src_stride = rowStride(src.header.biWidth);
    const base_y: i32 = position.frameSrcY(obj);
    const base_x: i32 = position.frameSrcX(obj);
    for (0..n_rows) |i| {
        const f = (@as(f64, @floatFromInt(y0 + @as(i32, @intCast(i)))) + 0.5 - top) / hf;
        const r: i32 = std.math.clamp(@as(i32, @intFromFloat(@floor(f * @as(f64, @floatFromInt(sh))))), 0, sh - 1) + base_y;
        const mem: i32 = if (src.header.biHeight < 0) r else src_rows - 1 - r;
        rows[i] = @intCast(std.math.clamp(mem, 0, src_rows - 1));
    }
    var shown = false;
    var x = x0;
    while (x < x1) : (x += 1) {
        if (rc.depth[@intCast(x - bd.viewX)] < depth) continue;
        const f = (@as(f64, @floatFromInt(x)) + 0.5 - left) / wf;
        const c: i32 = std.math.clamp(@as(i32, @intFromFloat(@floor(f * @as(f64, @floatFromInt(sw))))), 0, sw - 1) + base_x;
        var painted = false;
        for (0..n_rows) |i| {
            const px = bits[@as(usize, rows[i]) * src_stride + @as(usize, @intCast(c))];
            if (px == g.spriteKey) continue;
            bd.pixels[rowBase(bd, y0 + @as(i32, @intCast(i))) + @as(usize, @intCast(x))] = px;
            painted = true;
        }
        if (painted) shown = true;
    }
    return shown;
}

/// One frame of the 3-D view: the floor, then the walls; the depth buffer and the sprite queue are
/// left for `sprites.flush`.
pub fn render(g: *Game, bd: *Backdrop, x: i32, y: i32, angle: i32) void {
    if (bd.viewW != view_w or !prepare(g, bd)) return;
    const rc = &g.rc;
    const cam = camera(g, bd, x, y, angle);
    rc.px = cam.px * 32.0;
    rc.py = cam.py * 32.0;
    rc.dx = cam.dx;
    rc.dy = cam.dy;
    rc.focal = cam.focal;
    drawFloor(bd, rc.floor.?, cam);
    const mips = rc.walls.?;
    for (0..view_w) |i| {
        // The pixel column's offset from the view's centre, in focal lengths.
        const q = ((@as(f64, @floatFromInt(i)) + 0.5) - @as(f64, @floatFromInt(view_w)) / 2.0) / cam.focal;
        const hit = castRay(bd, cam, q);
        rc.depth[i] = @floatCast(hit.t * 32.0);
        drawWall(bd, mips, hit, @as(usize, @intCast(bd.viewX)) + i);
    }
    rc.ready = true;
}

// ---- tests ----

const testing = std.testing;
const game_mod = @import("core/game.zig");

/// A game with a closed box of walls and the real bitmaps' shapes (32 x 1800 wall strip, 640 x 480
/// background), the palette entries of the wall texture distinct so a texel can be told apart.
const Fixture = struct {
    t: game_mod.TestGame,
    bd: *Backdrop,
    pixels: []u8,
    tex: []u8,
    bg: []u8,
    tex_dib: *object.Dib,
    bg_dib: *object.Dib,
    frames: [1]object.Frame,
    strip: Object,

    fn init(self: *Fixture) !void {
        self.t = try game_mod.TestGame.init(testing.allocator);
        const g = self.t.game;
        g.fixes.jardim_raycaster = true;
        self.bd = try testing.allocator.create(Backdrop);
        self.bd.* = .{};
        const bd = self.bd;
        self.pixels = try testing.allocator.alloc(u8, 640 * 480);
        @memset(self.pixels, 0);
        bd.pixels = self.pixels;
        bd.bmiHeader = .{ .biWidth = 640, .biHeight = -480 };
        bd.viewX = 20;
        bd.viewY = 42;
        bd.viewW = 480;
        bd.viewH = 300;
        bd.viewHalfH = 150;
        bd.horizonY = 192;
        // The wall texture: texel (x, row) of texture t has the entry 1 + x (the column, 32 of them).
        self.tex = try testing.allocator.alloc(u8, 32 * 1800);
        for (self.tex, 0..) |*p, i| p.* = @intCast(i % 32 + 1);
        self.tex_dib = try testing.allocator.create(object.Dib);
        self.tex_dib.* = .{ .header = .{ .biWidth = 32, .biHeight = 1800 }, .colors = @splat(.{}), .bits = self.tex };
        self.frames = .{.{ .width = 32, .height = 1800, .count = 1, .dib = self.tex_dib, .hitW = 32 }};
        self.strip = .{ .kind = .wall_strip };
        self.strip.frames = &self.frames;
        self.strip.framesLeft = 300;
        bd.wallStrip = &self.strip;
        // The background: the floor is the entry 200 (one colour: the tile is one colour at every level).
        self.bg = try testing.allocator.alloc(u8, 640 * 480);
        @memset(self.bg, 200);
        self.bg_dib = try testing.allocator.create(object.Dib);
        self.bg_dib.* = .{ .header = .{ .biWidth = 640, .biHeight = 480 }, .colors = @splat(.{}), .bits = self.bg };
        bd.background = self.bg_dib;
        // A room: walls round the cells 35..45 on both axes.
        for (35..46) |i| {
            bd.wallRows[35][i] = 1;
            bd.wallRows[45][i] = 1;
            bd.wallRows[i][35] = 1;
            bd.wallRows[i][45] = 1;
        }
    }

    fn deinit(self: *Fixture) void {
        testing.allocator.destroy(self.tex_dib);
        testing.allocator.destroy(self.bg_dib);
        testing.allocator.free(self.tex);
        testing.allocator.free(self.bg);
        testing.allocator.free(self.pixels);
        testing.allocator.destroy(self.bd);
        self.t.deinit();
    }
};

fn testCamera(fx: *Fixture, x: f64, y: f64, angle: i32) Camera {
    return camera(fx.t.game, fx.bd, @intFromFloat(@floor(x)), @intFromFloat(@floor(y)), angle);
}

test "a wall facing the camera is at one perpendicular distance in every column, and not fisheyed" {
    const fx = try testing.allocator.create(Fixture);
    defer testing.allocator.destroy(fx);
    try fx.init();
    defer fx.deinit();
    // The middle of cell (40, 40), looking +x at the east wall's face, x = 45 cells: 5 - 0.5 = 4.5 cells
    // away along x, whose perpendicular distance is that over cos(theta) (theta: 1 table unit off x).
    const cam = camera(fx.t.game, fx.bd, 40 * 32 + 16, 40 * 32 + 16, 0);
    const want = 4.5 / (cam.dx);
    for (0..view_w) |i| {
        const q = ((@as(f64, @floatFromInt(i)) + 0.5) - 240.0) / cam.focal;
        const hit = castRay(fx.bd, cam, q);
        // Across the 60-degree field the distance moves only with the camera plane's 0.125 degree tilt.
        try testing.expectApproxEqRel(want, hit.t, 0.003);
        try testing.expectEqual(@as(i32, 1), hit.cell);
    }
    // The height is the original's 22500 / distance, at the middle column.
    const mid = castRay(fx.bd, cam, 0.5 / cam.focal);
    try testing.expectApproxEqAbs(22500.0 / (4.5 * 32.0), wall_scale / (mid.t * 32.0), 0.5);
}

test "the texture runs left to right on every face (not mirrored)" {
    const fx = try testing.allocator.create(Fixture);
    defer testing.allocator.destroy(fx);
    try fx.init();
    defer fx.deinit();
    // Looking +x, +y, -x, -y (0, 720, 1440, 2160) from the room's middle at its four walls.
    for ([_]i32{ 0, 720, 1440, 2160 }) |angle| {
        const cam = camera(fx.t.game, fx.bd, 40 * 32 + 5, 40 * 32 + 9, angle);
        var prev: f64 = -1;
        for (0..view_w) |i| {
            const q = ((@as(f64, @floatFromInt(i)) + 0.5) - 240.0) / cam.focal;
            const hit = castRay(fx.bd, cam, q);
            if (prev >= 0) {
                var d = hit.along - prev;
                if (d < -0.5) d += 1; // crossed a cell: the position wraps
                if (d > 0.5) d -= 1;
                try testing.expect(d > 0);
            }
            prev = hit.along;
        }
    }
}

test "a recessed door is hit half a cell in, the other way the wall beyond is drawn at the face" {
    const fx = try testing.allocator.create(Fixture);
    defer testing.allocator.destroy(fx);
    try fx.init();
    defer fx.deinit();
    const bd = fx.bd;
    // A door in the east wall's cell (40, 45), the room's row 40.
    const cam = camera(fx.t.game, bd, 40 * 32 + 16, 40 * 32 + 16, 0);
    const q = 0.5 / cam.focal;
    bd.wallRows[40][45] = 8; // even: a plane perpendicular to x, recessed for the ray along x
    const recessed = castRay(bd, cam, q);
    try testing.expectEqual(@as(i32, 8), recessed.cell);
    try testing.expectApproxEqRel(5.0 / cam.dx, recessed.t, 0.003); // x = 45.5 from 40.5
    bd.wallRows[40][45] = 7; // odd: seen through along x: the face at x = 45, the cell beyond (empty: a wall 1)
    const through = castRay(bd, cam, q);
    try testing.expectEqual(@as(i32, 1), through.cell);
    try testing.expectApproxEqRel(4.5 / cam.dx, through.t, 0.003);
}

test "the wall slice's top and bottom rows follow the exact height, the floor below it" {
    const fx = try testing.allocator.create(Fixture);
    defer testing.allocator.destroy(fx);
    try fx.init();
    defer fx.deinit();
    const g = fx.t.game;
    const bd = fx.bd;
    render(g, bd, 40 * 32 + 16, 40 * 32 + 16, 0);
    const col: usize = 240;
    const depth: f64 = g.rc.depth[col];
    const line_h = wall_scale / depth;
    const top = 192.0 - line_h / 2.0;
    const first: usize = @intFromFloat(@ceil(top - 0.5));
    const last: usize = @as(usize, @intFromFloat(@ceil(top + line_h - 0.5))) - 1;
    const px = fx.pixels;
    const x = 20 + col;
    try testing.expectEqual(@as(u8, 0), px[(first - 1) * 640 + x]); // above: the sky, not drawn here
    try testing.expect(px[first * 640 + x] != 0 and px[first * 640 + x] != 200);
    try testing.expect(px[last * 640 + x] != 0 and px[last * 640 + x] != 200);
    try testing.expectEqual(@as(u8, 200), px[(last + 1) * 640 + x]); // below: the floor
    // The slice at 4.5 cells (144 units) is at shade step 2 (144 >> 6): the entry is 1 + the texel's
    // column (the texture's entries), 2 * 0x17 more.
    const entry = px[192 * 640 + x] -% 2 * 0x17;
    try testing.expect(entry >= 1 and entry <= 32);
}

test "the floor stays on the ground: the same world point is the same texel after a step and a turn" {
    const fx = try testing.allocator.create(Fixture);
    defer testing.allocator.destroy(fx);
    try fx.init();
    defer fx.deinit();
    const a = testCamera(fx, 40 * 32 + 16, 40 * 32 + 16, 0);
    // One walking step (2.6 units) forward and 14 angle units (a tic's turn) later.
    const b = camera(fx.t.game, fx.bd, 40 * 32 + 16 + 3, 40 * 32 + 16, 14);
    for ([_][2]f64{ .{ 37.5, 100.5 }, .{ -150.5, 40.5 }, .{ 200.5, 148.5 } }) |s| {
        const p = floorPoint(a, s[0], s[1]);
        // Where B sees p: its depth along B's axis gives the row, its offset the column.
        const rx = p[0] - b.px;
        const ry = p[1] - b.py;
        const depth = rx * b.dx + ry * b.dy;
        const lateral = rx * b.rx + ry * b.ry;
        const below = (wall_scale / 2.0) / (depth * 32.0);
        const across = b.focal * lateral / depth;
        const q = floorPoint(b, across, below);
        try testing.expectApproxEqAbs(p[0], q[0], 1e-9);
        try testing.expectApproxEqAbs(p[1], q[1], 1e-9);
    }
    // And the row's 16.16 walk across the view is the exact point's texel, to a hundredth of a texel.
    var y: i32 = 192;
    while (y < 342) : (y += 7) {
        const below = @as(f64, @floatFromInt(y)) + 0.5 - 192.0;
        const row = floorRow(a, below, 240.0);
        var u = row.u;
        var v = row.v;
        for (0..view_w) |k| {
            const p = floorPoint(a, @as(f64, @floatFromInt(k)) + 0.5 - 240.0, below);
            const du: i32 = @bitCast(u -% texels16(p[0]));
            const dv: i32 = @bitCast(v -% texels16(p[1]));
            try testing.expect(@abs(du) < 655 and @abs(dv) < 655);
            u +%= row.du;
            v +%= row.dv;
        }
    }
}

test "a sprite is clipped column by column against the wall depths, not only at its ends" {
    const fx = try testing.allocator.create(Fixture);
    defer testing.allocator.destroy(fx);
    try fx.init();
    defer fx.deinit();
    const g = fx.t.game;
    const bd = fx.bd;
    var sprite_bits: [64 * 64]u8 = @splat(50);
    var dib: object.Dib = .{ .header = .{ .biWidth = 64, .biHeight = 64 }, .colors = @splat(.{}), .bits = &sprite_bits };
    var frames: [1]object.Frame = .{.{ .width = 64, .height = 64, .count = 1, .dib = &dib }};
    var obj: Object = .{ .kind = .portable };
    obj.frames = &frames;
    const cam = camera(g, bd, 40 * 32 + 16, 40 * 32 + 16, 0);
    g.rc.px = cam.px * 32;
    g.rc.py = cam.py * 32;
    g.rc.dx = cam.dx;
    g.rc.dy = cam.dy;
    g.rc.focal = cam.focal;
    // 3 cells ahead on the axis; a pillar nearer than it in columns 230..249.
    obj.worldX = 43 * 32 + 16;
    obj.worldY = 40 * 32 + 16;
    @memset(&g.rc.depth, 1000);
    for (230..250) |c| g.rc.depth[c] = 20;
    try testing.expect(drawSprite(g, bd, &obj, &sprite_bits));
    // Its size: 64/300 of the 22500/96 px slice wall: 50 px, on the floor line of 192 + 117.
    var painted: usize = 0;
    for (20..500) |x| {
        const row = 280 * 640 + x; // a row inside the sprite (its bottom is at 192 + scale / 2 = 309)
        const hid = x >= 250 and x < 270;
        if (fx.pixels[row] == 50) painted += 1;
        if (hid) try testing.expectEqual(@as(u8, 0), fx.pixels[row]);
    }
    try testing.expect(painted >= 28 and painted <= 32); // 50 px wide less the pillar's 20
    // Left and right of the pillar both show a piece: the span was cut in the middle.
    var left_piece = false;
    var right_piece = false;
    for (20..500) |x| {
        if (fx.pixels[280 * 640 + x] != 50) continue;
        if (x < 250) left_piece = true else right_piece = true;
    }
    try testing.expect(left_piece and right_piece);
}
