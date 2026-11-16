//! Port unit `piece` (module) of ENCAIXE.EXE. the Piece's game logic: spawn, new game, landing, line clear, PieceVtbl tryStep/moveTick, the score (cleared row, the %06d box).
//!
//! The falling piece lives in `PiecePart.board` as '1' cells, reached
//! through `PiecePart.cell` (the original's flat `col * 14 + row`). The
//! original reads some fields through `this` and others through `g_piece`
//! (the same object); the port keeps whichever the original used.
//! GetDC/ReleaseDC pairs are the platform screen's, `hwnd` is dropped.
//!
//! BUGS.md: E3 (an unknown kind leaves `bottomRow` uninitialised), E6 (the
//! result does not stop the landing), E7 (the speed-up is only tested after
//! the whole landing), E11 (the next piece keeps the landed one's previous
//! position); fixes behind `g.fixes.encaixe_*`. One more quirk not
//! in BUGS.md: `te_piece_clear_row` stops its shift at row 1, so row 0 is
//! never rewritten (its '0' branch and the `dib_copy_transparent` one are
//! dead code, kept).

const std = @import("std");
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const platform = @import("../platform/platform.zig");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const dib = @import("dib.zig");
const sound = @import("sound.zig");
const movement = @import("behaviour/movement.zig");
const visibility = @import("behaviour/visibility.zig");
const piece_sideways = @import("piece_sideways.zig");
const piece_vertical = @import("piece_vertical.zig");
const tall = @import("tall.zig");

/// PieceVtbl slot 01 tryStep (te_piece_try_move): the worker for `Mover.direction`; 0 = blocked.
// @orig 1008:f186 te_piece_try_move
pub fn tryStep(g: *Game, obj: *Object, bd: *Backdrop, kind: i16, rotation: i16) i16 {
    _ = bd;
    if (g.fixes.encaixe_tall_board) return tall.step(&g.tall, obj, obj.mover.direction, g.fixes.encaixe_wall_kicks);
    obj.piece.unk4E = 0;
    switch (obj.mover.direction) {
        1 => {
            calcRightCol(g, obj, kind, rotation);
            return piece_sideways.moveLeft(g, obj, kind, rotation);
        },
        2 => {
            calcRightCol(g, obj, kind, rotation);
            return piece_sideways.moveRight(g, obj, kind, rotation);
        },
        4 => return piece_vertical.rotate(g, obj, kind, rotation),
        8 => return piece_vertical.moveDown(obj, kind, rotation),
        else => return 0,
    }
}

/// PieceVtbl slot 02 moveTick (te_piece_step_move, hwnd dropped).
// @orig 1008:f1fe te_piece_step_move
pub fn moveTick(g: *Game, obj: *Object, bd: *Backdrop, kind: i16, rotation: i16) void {
    if (obj.mover.moving == 0) return;
    movement.moverStep(obj);
    if (tryStep(g, obj, bd, kind, rotation) == 0) {
        movement.stopMovingDc(g, obj, bd);
        obj.mover.moving = 0;
    } else {
        // Never step up.
        if (obj.y > obj.nextY) obj.nextY = obj.y +% cellPx(g);
        movement.placeAt(g, obj, obj.nextX, obj.nextY, bd);
        visibility.redrawOverlapping(g, obj, bd, 1);
        visibility.blitToDc(g, obj, bd);
    }
}

fn setCell(p: *object.PiecePart, col: i16, row: i16) void {
    p.cell(col, row).* = '1';
}

/// Writes the shape of piece `kind` (rotation 0) at the spawn position
/// (columns 4-6, rows from `row`, which is set to 0 first) and sets
/// `column` = 4 (through g_piece), `moving` = 1, `canFall` = 1.
// @orig 1008:b898 te_piece_spawn_shape
pub fn spawnShape(g: *Game, obj: *Object, kind: i16) void {
    if (g.fixes.encaixe_tall_board) {
        // The piece is a mask over the well: nothing is written to it.
        obj.piece.column = tall.spawn_col;
        obj.piece.row = 0;
        obj.mover.moving = 1;
        obj.piece.canFall = 1;
        g.tall.rot = 0;
        return;
    }
    g.piece.?.piece.column = 4;
    const p = &obj.piece;
    p.row = 0;
    obj.mover.moving = 1;
    p.canFall = 1;
    switch (kind) {
        0, 1 => {
            setCell(p, 4, 0);
            const n: i16 = if (kind == 0) 4 else 2;
            var r = p.row;
            while (true) {
                setCell(p, 5, r);
                r += 1;
                if (!(r < p.row + n)) break;
            }
            setCell(p, 6, 0);
        },
        2 => {
            setCell(p, 4, 0);
            var r = p.row;
            while (true) {
                setCell(p, 5, r);
                r += 1;
                if (!(r < p.row + 3)) break;
            }
        },
        3 => {
            setCell(p, 5, 0);
            var r = p.row;
            while (true) {
                setCell(p, 4, r);
                r += 1;
                if (!(r < p.row + 3)) break;
            }
        },
        4 => {
            var r: i16 = 0;
            while (true) {
                setCell(p, 4, r);
                r += 1;
                if (!(r < p.row + 4)) break;
            }
        },
        5 => {
            var c: i16 = 4;
            while (c < 6) : (c += 1) {
                setCell(p, c, 0);
                setCell(p, c, 1);
            }
        },
        else => {},
    }
}

/// Clears the board, puts the piece at column 4 row 0 and spawns `kind`
/// (cdecl, on `g_piece`). `linesCleared` and the timer are untouched.
// @orig 1008:b9e2 te_piece_new_game
pub fn newGame(g: *Game, kind: i16) void {
    const obj = g.piece.?;
    obj.piece.unk48 = 1;
    obj.piece.unk4E = 0;
    obj.piece.board = @splat(@splat('0'));
    g.tall.board = @splat(@splat(false));
    g.piece.?.piece.column = 4;
    g.piece.?.piece.row = 0;
    spawnShape(g, g.piece.?, kind);
}

/// The piece fell as far as it could (`mover.moving` and `canFall` are 0).
/// `kind`/`rotation` are the SceneObject's curStrip/curFrame.
// @orig 1008:ba20 te_piece_on_landed
pub fn onLanded(g: *Game, obj: *Object, bd: *Backdrop, kind: i16, rotation: i16) void {
    if (g.fixes.encaixe_tall_board) tall.stamp(&g.tall, g.piece.?);
    // Game over: the piece's top is in the top three rows (a loss, wParam 0).
    if (g.piece.?.piece.row < 3) {
        _ = g.send(Msg.make(msg.wm.destroy, 0, 0, 0));
        // E6: the original carries on.
        if (g.fixes.encaixe_result_stops_landing) return;
    }
    const linesBefore = g.piece.?.piece.linesCleared;
    // E6: the win (wParam 0xffff) is sent from the row's scoring; the
    // original carries on here too.
    if (g.fixes.encaixe_tall_board) {
        if (clearFullLinesTall(g, g.piece.?, bd)) return;
    } else if (clearFullLines(g, g.piece.?, bd, kind, rotation)) return;
    const lines = g.piece.?.piece.linesCleared;
    // E7: the original tests only the count after the whole landing.
    const speedUp = if (g.fixes.encaixe_speed_up_on_crossing)
        lines != 0 and lines / 5 > linesBefore / 5
    else
        lines % 5 == 0 and lines != 0;
    if (speedUp) {
        // Uninitialised in the original for a multiple of 5 above 15 (the
        // game is won at 10 lines): taken as 0.
        var period: i16 = 0;
        if (g.fixes.encaixe_speed_up_on_crossing) {
            const level = lines - lines % 5;
            period = if (level == 5) 150 else if (level == 10) 100 else 55;
        } else if (lines == 15) {
            period = 55;
        } else if (lines < 16) {
            if (lines == 5) period = 150 else if (lines == 10) period = 100;
        }
        const id = g.piece.?.anim.timerId;
        g.piece.?.mover.timerPeriod = period;
        g.setSystemTimer(@bitCast(id), @bitCast(period));
    }
    // The next piece.
    g.lockActive = false;
    g.lockResets = 0;
    const p = g.piece.?;
    if (g.fixes.encaixe_next_piece) {
        p.curStrip = g.nextKind;
        g.nextKind = @rem(g.rand.rand(), 6);
    } else {
        p.curStrip = @rem(g.rand.rand(), 6);
    }
    p.curFrame = 0;
    spawnShape(g, g.piece.?, p.curStrip);
    const spawnX: i16 = if (g.fixes.encaixe_tall_board) tall.pixelX(tall.spawn_col) else 0xa0;
    const spawnY: i16 = if (g.fixes.encaixe_tall_board) tall.origin_y else 0;
    p.x = spawnX;
    p.nextX = spawnX;
    p.mover.targetX = spawnX;
    p.y = spawnY;
    p.mover.targetY = spawnY;
    p.nextY = spawnY;
    p.mover.direction = 8;
    movement.moveToEdgeV(g, p, bd, 8);
    g.piece.?.y = spawnY;
    g.piece.?.mover.targetY = spawnY;
    if (g.fixes.encaixe_next_piece) drawNext(g, bd);
    // E11: the original leaves the previous position where the last piece
    // landed, and the erase of the rotations before the first fall step
    // starts there (te_piece_restore_background).
    if (g.fixes.encaixe_spawn_syncs_previous_position) {
        p.mover.prevX = p.x;
        p.mover.prevY = p.y;
    }
    _ = obj;
}

/// `rightCol` = `column` + width - 1 for (kind, rotation); an unknown pair
/// leaves it unchanged.
// @orig 1008:bb2e te_piece_calc_right_col
pub fn calcRightCol(g: *Game, obj: *Object, kind: i16, rotation: i16) void {
    const add: i16 = switch (kind) {
        0 => switch (rotation) {
            0, 2 => 2,
            1, 3 => 3,
            else => return,
        },
        1 => switch (rotation) {
            0, 2 => 2,
            1, 3 => 1,
            else => return,
        },
        2, 3 => switch (rotation) {
            0, 2 => 1,
            1, 3 => 2,
            else => return,
        },
        4 => switch (rotation) {
            0, 2 => 0,
            1, 3 => 3,
            else => return,
        },
        5 => switch (rotation) {
            0...3 => 1,
            else => return,
        },
        else => return,
    };
    obj.piece.rightCol = g.piece.?.piece.column + add;
}

/// Removes the full rows among the rows the landed piece covers, bottom up.
/// True when the landing must stop (E6's fix, after the win).
// @orig 1008:eed8 te_piece_clear_full_lines
pub fn clearFullLines(g: *Game, obj: *Object, bd: *Backdrop, kind: i16, rotation: i16) bool {
    const p = &obj.piece;
    const topRow = p.row;
    // E3: no default in the original's switch, `bottomRow` is stack garbage
    // (taken as 0 here; the fix scans the top row only).
    var bottomRow: i16 = if (g.fixes.encaixe_clear_lines_unknown_kind) topRow else 0;
    switch (kind) {
        0 => switch (rotation) {
            0, 2 => bottomRow = p.row + 3,
            1, 3 => bottomRow = p.row + 2,
            else => {},
        },
        1 => switch (rotation) {
            0, 2 => bottomRow = p.row + 1,
            1, 3 => bottomRow = p.row + 2,
            else => {},
        },
        2, 3 => switch (rotation) {
            0, 2 => bottomRow = p.row + 2,
            1, 3 => bottomRow = p.row + 1,
            else => {},
        },
        4 => switch (rotation) {
            0, 2 => bottomRow = p.row + 3,
            1, 3 => bottomRow = p.row,
            else => {},
        },
        5 => switch (rotation) {
            0...3 => bottomRow = p.row + 1,
            else => {},
        },
        else => {},
    }
    var rowFull: [4]i16 = @splat(0);
    if (topRow <= bottomRow) {
        var row = topRow;
        var i: usize = 0;
        while (row <= bottomRow) : ({
            row += 1;
            i += 1;
        }) {
            rowFull[i] = 1;
            var col: i16 = 0;
            while (col < 11) : (col += 1) {
                if (p.cell(col, row).* == '0') rowFull[i] = 0;
            }
        }
    }
    var count: i16 = 0;
    var i: i16 = 3;
    while (i >= 0) : (i -= 1) {
        if (rowFull[@intCast(i)] != 0) {
            g.piece.?.piece.linesCleared +%= 1;
            if (clearRow(g, obj, bd, topRow + count + i)) return true;
            p.row += 1;
            count += 1;
        }
    }
    return false;
}

/// BitBlt(dc, 0x20, destY, 0x160, 0x20, dc, 0x20, srcY, SRCCOPY) on one of
/// the backdrop's bitmaps, clipped to it.
fn shiftStrip(s: platform.Surface, src_y: i16, dest_y: i16) void {
    shiftBand(s, 0x20, 0x160, 0x20, src_y, dest_y);
}

/// Copies the band of `h` rows at `src_y`, `w` pixels from `x`, to `dest_y`.
fn shiftBand(s: platform.Surface, x: i16, w: i16, h: i16, src_y: i16, dest_y: i16) void {
    const stride = s.stride();
    const bw: i32 = s.width;
    const bh: i32 = s.height;
    const x0: i32 = x;
    const x1: i32 = @min(@as(i32, x) + w, bw);
    if (x1 <= x0) return;
    var row: i32 = 0;
    while (row < h) : (row += 1) {
        const sy = @as(i32, src_y) + row;
        const dy = @as(i32, dest_y) + row;
        if (sy < 0 or sy >= bh or dy < 0 or dy >= bh) continue;
        const sr: usize = @intCast(if (s.bottom_up) bh - 1 - sy else sy);
        const dr: usize = @intCast(if (s.bottom_up) bh - 1 - dy else dy);
        const a = dr * stride + @as(usize, @intCast(x0));
        const b = sr * stride + @as(usize, @intCast(x0));
        const n: usize = @intCast(x1 - x0);
        if (a + n > s.pixels.len or b + n > s.pixels.len) continue;
        std.mem.copyForwards(u8, s.pixels[a..][0..n], s.pixels[b..][0..n]);
    }
}

/// Fills the band of `h` rows at `y`, `w` pixels from `x`, with `v`.
fn fillBand(s: platform.Surface, x: i16, w: i16, y: i16, h: i16, v: u8) void {
    const stride = s.stride();
    const bh: i32 = s.height;
    var row: i32 = 0;
    while (row < h) : (row += 1) {
        const yy = @as(i32, y) + row;
        if (yy < 0 or yy >= bh) continue;
        const r: usize = @intCast(if (s.bottom_up) bh - 1 - yy else yy);
        const a = r * stride + @as(usize, @intCast(x));
        const n: usize = @intCast(w);
        if (a + n > s.pixels.len) continue;
        @memset(s.pixels[a..][0..n], v);
    }
}

/// The step in pixels: one cell.
pub fn cellPx(g: *const Game) i16 {
    return if (g.fixes.encaixe_tall_board) tall.cell else 0x20;
}

/// `te_piece_clear_full_lines` for the tall well: the full rows among the
/// four the piece covers, bottom up (true when E6's fix stops after the win).
pub fn clearFullLinesTall(g: *Game, obj: *Object, bd: *Backdrop) bool {
    var cleared: i16 = 0;
    var i: i16 = 3;
    while (i >= 0) : (i -= 1) {
        const row = obj.piece.row + i;
        if (row >= tall.rows) continue;
        // The rows below that went already moved this one down.
        const now = row + cleared;
        if (now >= tall.rows or !tall.rowFull(&g.tall, now)) continue;
        g.piece.?.piece.linesCleared +%= 1;
        if (clearRowTall(g, bd, now)) return true;
        cleared += 1;
    }
    return false;
}

/// `te_piece_clear_row` for the tall well: scores the row, then moves every
/// row above one down, on the board and in both bitmaps (no row keeps its
/// cells: the top one is emptied).
fn clearRowTall(g: *Game, bd: *Backdrop, row: i16) bool {
    if (scoreClearedRow(g, bd) and g.fixes.encaixe_result_stops_landing) return true;
    tall.removeRow(&g.tall, row);
    const w = tall.cols * tall.cell;
    var r = row;
    while (r > 0) : (r -= 1) {
        const dest = tall.origin_y + r * tall.cell;
        shiftBand(bd.surface(), tall.origin_x, w, tall.cell, dest - tall.cell, dest);
        shiftBand(bd.surface2(), tall.origin_x, w, tall.cell, dest - tall.cell, dest);
    }
    fillBand(bd.surface(), tall.origin_x, w, tall.origin_y, tall.cell, g.tall.fill);
    fillBand(bd.surface2(), tall.origin_x, w, tall.origin_y, tall.cell, g.tall.fill);
    g.plat.wingBitBlt(0, 0, bd.viewWidth, bd.viewHeight, bd.surface(), bd.originX, bd.originY);
    return false;
}

/// Draws the next kind in its box (both bitmaps) and shows it; only with the
/// tall well, whose art has the box.
pub fn drawNext(g: *Game, bd: *Backdrop) void {
    if (!g.fixes.encaixe_tall_board) return;
    const bg = bd.background orelse return;
    const x = tall.box_x;
    const y = tall.box_y;
    const w = tall.box_w;
    const h = tall.box_h;
    _ = dib.copyTransparent(&bd.bmiHeader, bd.pixels, x, y, bg.bits, &bg.header, x, y, w, h, g.unk0012) catch {};
    _ = dib.copyTransparent(&bd.bmiHeader, bd.pixels2, x, y, bg.bits, &bg.header, x, y, w, h, g.unk0012) catch {};
    const style: platform.TextStyle = .{ .color = 0xedeeee, .bk_mode = .transparent };
    _ = g.plat.textOut(bd.surface(), style, x + 14, y + 6, "PR\xd3XIMA");
    _ = g.plat.textOut(bd.surface2(), style, x + 14, y + 6, "PR\xd3XIMA");
    if (g.tall.mini[@intCast(g.nextKind)]) |d| {
        const orient: i16 = @truncate(g.piece.?.dibFormatOk);
        // Centre the shape's cells (rotation 0) in the 72 x 72 area.
        const m = tall.masks[@intCast(g.nextKind)][0];
        var minc: i16 = 4;
        var maxc: i16 = 0;
        var minr: i16 = 4;
        var maxr: i16 = 0;
        for (0..4) |r| {
            for (0..4) |c| {
                if (m & (@as(u16, 1) << @intCast(r * 4 + c)) == 0) continue;
                minc = @min(minc, @as(i16, @intCast(c)));
                maxc = @max(maxc, @as(i16, @intCast(c)));
                minr = @min(minr, @as(i16, @intCast(r)));
                maxr = @max(maxr, @as(i16, @intCast(r)));
            }
        }
        const cw = (maxc - minc + 1) * tall.mini_cell;
        const ch = (maxr - minr + 1) * tall.mini_cell;
        const px = x + @divTrunc(w - cw, 2) - minc * tall.mini_cell;
        const py = y + 24 + @divTrunc(h - 24 - ch, 2) - minr * tall.mini_cell;
        const size = tall.mini_cell * 4;
        _ = dib.copyTransparent(&bd.bmiHeader, bd.pixels, px, py, d.bits, &d.header, 0, 0, size, size *% orient, g.unk0012) catch {};
        _ = dib.copyTransparent(&bd.bmiHeader, bd.pixels2, px, py, d.bits, &d.header, 0, 0, size, size *% orient, g.unk0012) catch {};
    }
    g.plat.wingBitBlt(x, y, w, h, bd.surface2(), x, y);
}

/// Scores the row (`te_score_cleared_row`), then moves every row from `row`
/// down to row 1 one down, on the board and in both backdrop bitmaps, and
/// repaints the window after each. True when E6's fix stops after the win.
/// BUGS.md E10: row 0 is never rewritten (the top-row branches are dead);
/// no flag.
// @orig 1008:f042 te_piece_clear_row
pub fn clearRow(g: *Game, obj: *Object, bd: *Backdrop, row: i16) bool {
    // E6: the original goes on shifting after the win.
    if (scoreClearedRow(g, bd) and g.fixes.encaixe_result_stops_landing) return true;
    if (!(0 < row)) return false;
    const p = &obj.piece;
    var srcY: i16 = (row - 1) *% 0x20;
    var r: i16 = row;
    while (true) {
        const destY = srcY +% 0x20;
        var col: i16 = 0;
        while (col < 11) : (col += 1) {
            // Dead: `srcY` is never below -0x1f in this loop.
            if (srcY < -0x1f) {
                p.cell(col, 0).* = '0';
            } else {
                p.cell(col, r).* = p.cell(col, r - 1).*;
            }
        }
        if (srcY < 0) {
            // Dead as well.
            if (bd.background != null) {
                _ = dib.copyTransparent(&bd.bmiHeader, bd.pixels, 0x20, 0x20, bd.pixels, &bd.bmiHeader, 0x20, 0x20, 0x160, 0x20, g.unk0012) catch {};
            }
        } else {
            shiftStrip(bd.surface(), srcY, destY);
            shiftStrip(bd.surface2(), srcY, destY);
        }
        g.plat.wingBitBlt(0, 0, bd.viewWidth, bd.viewHeight, bd.surface(), bd.originX, bd.originY);
        r -= 1;
        srcY -%= 0x20;
        if (srcY == -0x20) break;
    }
    return false;
}

/// One cleared row: the sound, +100, the box; 1000 is a win (wParam 0xffff,
/// true).
// @orig 1008:f67a te_score_cleared_row
pub fn scoreClearedRow(g: *Game, bd: *Backdrop) bool {
    _ = sound.play(g, 0, g.tetrisWave);
    g.score +%= 100;
    drawScore(g, bd);
    blitScoreBox(g, bd);
    if (g.score != 1000) return false;
    _ = g.send(Msg.make(msg.wm.destroy, 0xffff, 0, 0));
    return true;
}

/// WinGBitBlt of the 192x32 score box at (0x1a0, 0x160) from the second
/// bitmap to the window.
// @orig 1008:f6d4 te_blit_score_box
pub fn blitScoreBox(g: *Game, bd: *Backdrop) void {
    g.plat.wingBitBlt(0x1a0, 0x160, 0xc0, 0x20, bd.surface2(), 0x1a0, 0x160);
}

/// Restores the score box from the background on both bitmaps and draws
/// `sprintf("%06d", score)` one TextOut per character at x = 429 + 32 i,
/// y = 360.
// @orig 1008:f710 te_draw_score
pub fn drawScore(g: *Game, bd: *Backdrop) void {
    if (bd.background) |bg| {
        _ = dib.copyTransparent(&bd.bmiHeader, bd.pixels, 0x1a0, 0x160, bg.bits, &bg.header, 0x1a0, 0x160, 0xc0, 0x20, g.unk0012) catch {};
        _ = dib.copyTransparent(&bd.bmiHeader, bd.pixels2, 0x1a0, 0x160, bg.bits, &bg.header, 0x1a0, 0x160, 0xc0, 0x20, g.unk0012) catch {};
    }
    const style: platform.TextStyle = .{ .color = 0xedeeee, .bk_mode = .transparent };
    var buf: [16]u8 = undefined;
    const v: i32 = g.score;
    const text = if (v < 0)
        std.fmt.bufPrint(&buf, "-{d:0>5}", .{@abs(v)}) catch unreachable
    else
        std.fmt.bufPrint(&buf, "{d:0>6}", .{@abs(v)}) catch unreachable;
    var x: i16 = 0x1ad;
    for (text, 0..) |_, i| {
        _ = g.plat.textOut(bd.surface(), style, x, 0x168, text[i..][0..1]);
        _ = g.plat.textOut(bd.surface2(), style, x, 0x168, text[i..][0..1]);
        x +%= 0x20;
    }
}

// ---- tests ----

const TestGame = @import("core/game.zig").TestGame;

fn fnv(h: u32, bs: []const u8) u32 {
    var x = h;
    for (bs) |b| x = (x ^ b) *% 16777619;
    return x;
}

/// The board generator shared with the emulator run: an LCG, '1' unless
/// (v % 8 == 0).
fn randomBoard(x: *u32, p: *object.PiecePart) void {
    const flat: *[154]u8 = @ptrCast(&p.board);
    for (flat) |*c| {
        x.* = x.* *% 1103515245 +% 12345;
        c.* = if (((x.* >> 16) & 0x7fff) % 8 != 0) '1' else '0';
    }
}

// @orig 1008:f042 te_piece_clear_row oracle=emulated
test "clearRow shifts the board like the original (row 0 is never rewritten)" {
    var t = try TestGame.init(std.testing.allocator);
    defer t.deinit();
    const g = t.game;
    var obj: Object = .{ .kind = .piece };
    g.piece = &obj;
    var bd: Backdrop = .{};
    var x: u32 = 1;
    var h: u32 = 2166136261;
    for (0..500) |i| {
        randomBoard(&x, &obj.piece);
        _ = clearRow(g, &obj, &bd, @intCast(i % 14));
        h = fnv(h, std.mem.asBytes(&obj.piece.board));
    }
    try std.testing.expectEqual(@as(u32, 192922056), h);
}

// @orig 1008:eed8 te_piece_clear_full_lines oracle=emulated
test "clearFullLines matches the original for every kind, rotation and row" {
    var t = try TestGame.init(std.testing.allocator);
    defer t.deinit();
    const g = t.game;
    var obj: Object = .{ .kind = .piece };
    g.piece = &obj;
    var bd: Backdrop = .{};
    var x: u32 = 1;
    // The generator continues from the first test's 500 boards.
    var skip: object.PiecePart = .{};
    for (0..500) |_| randomBoard(&x, &skip);
    var h: u32 = 2166136261;
    for (0..2000) |i| {
        randomBoard(&x, &obj.piece);
        obj.piece.row = @intCast((i / 24) % 11);
        obj.piece.linesCleared = 0;
        _ = clearFullLines(g, &obj, &bd, @intCast(i % 6), @intCast((i / 6) % 4));
        h = fnv(h, std.mem.asBytes(&obj.piece.board));
        h = fnv(h, std.mem.asBytes(&obj.piece.row));
        h = fnv(h, std.mem.asBytes(&obj.piece.linesCleared));
    }
    try std.testing.expectEqual(@as(u32, 337744369), h);
}

// @orig 1008:f67a te_score_cleared_row oracle=documented
test "ten cleared rows win (WM_DESTROY wParam 0xffff), each row is +100" {
    var t = try TestGame.init(std.testing.allocator);
    defer t.deinit();
    const g = t.game;
    var bd: Backdrop = .{};
    var log: std.ArrayList(u8) = .empty;
    defer log.deinit(g.gpa);
    g.trace = &log;
    var i: usize = 0;
    while (i < 9) : (i += 1) try std.testing.expect(!scoreClearedRow(g, &bd));
    try std.testing.expectEqual(@as(i16, 900), g.score);
    try std.testing.expectEqual(@as(usize, 0), log.items.len);
    try std.testing.expect(scoreClearedRow(g, &bd));
    try std.testing.expectEqual(@as(i16, 1000), g.score);
    try std.testing.expect(std.mem.indexOf(u8, log.items, " S 0002 ffff 00000000") != null);
}

// @orig 1008:f042 te_piece_clear_row oracle=documented
test "E6: the winning row is still shifted down unless fixed" {
    var t = try TestGame.init(std.testing.allocator);
    defer t.deinit();
    const g = t.game;
    var obj: Object = .{ .kind = .piece };
    g.piece = &obj;
    var bd: Backdrop = .{};
    obj.piece.board = @splat(@splat('0'));
    obj.piece.cell(3, 4).* = '1';
    g.score = 900;
    try std.testing.expect(!clearRow(g, &obj, &bd, 5));
    try std.testing.expectEqual(@as(u8, '1'), obj.piece.cell(3, 5).*);
    g.fixes.encaixe_result_stops_landing = true;
    g.score = 900;
    obj.piece.board = @splat(@splat('0'));
    obj.piece.cell(3, 4).* = '1';
    try std.testing.expect(clearRow(g, &obj, &bd, 5));
    try std.testing.expectEqual(@as(u8, '0'), obj.piece.cell(3, 5).*);
}

// @orig 1008:ba20 te_piece_on_landed oracle=documented
test "landing in the top rows sends a loss; E6 carries on unless fixed" {
    var t = try TestGame.init(std.testing.allocator);
    defer t.deinit();
    const g = t.game;
    var obj: Object = .{ .kind = .piece };
    g.piece = &obj;
    var bd: Backdrop = .{};
    var log: std.ArrayList(u8) = .empty;
    defer log.deinit(g.gpa);
    g.trace = &log;
    // Empty board, row 2: a loss; the original then spawns the next piece.
    obj.piece.row = 2;
    var frames = @as([6]object.Frame, @splat(.{ .width = 128, .height = 128, .count = 4 }));
    obj.frames = &frames;
    onLandedNoMove(g, &obj, &bd);
    try std.testing.expect(std.mem.indexOf(u8, log.items, " S 0002 0000 00000000") != null);
    try std.testing.expectEqual(@as(i16, 4), obj.piece.column);
    try std.testing.expectEqual(@as(i16, 8), obj.mover.direction);
    // E6 fixed: nothing else happens after the loss.
    log.clearRetainingCapacity();
    g.fixes.encaixe_result_stops_landing = true;
    obj.mover.direction = 0;
    obj.piece.row = 2;
    onLandedNoMove(g, &obj, &bd);
    try std.testing.expect(std.mem.indexOf(u8, log.items, " S 0002 0000") != null);
    try std.testing.expectEqual(@as(i16, 0), obj.mover.direction);
}

fn onLandedNoMove(g: *Game, obj: *Object, bd: *Backdrop) void {
    onLanded(g, obj, bd, 5, 0);
}

/// Lands a piece resting at column 0 (x 32, y 320, previous position the
/// same, as `te_piece_stop_moving_dc` leaves it), then runs the next
/// piece's first erase (`te_piece_restore_background`, what each rotation
/// before the first fall step does) over a working bitmap of 1s and a clean
/// one of 0s. Returns the 1s left in the new piece's 128×128 frame.
fn spawnEraseLeftovers(g: *Game) !usize {
    const render = @import("behaviour/render.zig");
    var obj: Object = .{ .kind = .piece };
    g.piece = &obj;
    var frames = @as([6]object.Frame, @splat(.{ .width = 128, .height = 128, .count = 4 }));
    obj.frames = &frames;
    obj.piece.row = 10;
    obj.x = 32;
    obj.y = 320;
    obj.mover.prevX = 32;
    obj.mover.prevY = 320;
    obj.mover.stepX = 32;
    obj.mover.stepY = 32;
    var bd: Backdrop = .{ .bgWidth = 640, .bgHeight = 480, .dibOrientation = -1 };
    bd.pixels = try std.testing.allocator.alloc(u8, 640 * 480);
    defer std.testing.allocator.free(bd.pixels);
    bd.pixels2 = try std.testing.allocator.alloc(u8, 640 * 480);
    defer std.testing.allocator.free(bd.pixels2);
    @memset(bd.pixels, 1);
    @memset(bd.pixels2, 0);
    onLandedNoMove(g, &obj, &bd);
    try std.testing.expectEqual(@as(i16, 0xa0), obj.x);
    try std.testing.expectEqual(@as(i16, 0), obj.y);
    render.restoreBackground(g, &obj, &bd, 1);
    var left: usize = 0;
    for (0..128) |r| {
        for (0..128) |c| left += bd.pixels[r * 640 + 0xa0 + c];
    }
    return left;
}

// @orig 1008:ba20 te_piece_on_landed oracle=documented
test "E11: the next piece's first erase misses its frame right of x 192 unless fixed" {
    var t = try TestGame.init(std.testing.allocator);
    defer t.deinit();
    const g = t.game;
    // The original erases x 32-191 (min(x, prevX) = 32, 32 + 128 wide):
    // the frame's columns 192-287 keep what was drawn there.
    try std.testing.expectEqual(@as(usize, 96 * 128), try spawnEraseLeftovers(g));
    g.fixes.encaixe_spawn_syncs_previous_position = true;
    try std.testing.expectEqual(@as(usize, 0), try spawnEraseLeftovers(g));
}

// @orig 1008:b898 te_piece_spawn_shape oracle=documented
// @orig 1008:b9e2 te_piece_new_game oracle=documented
// @orig 1008:bb2e te_piece_calc_right_col oracle=documented
test "new game spawns the shapes of GAME.md and rightCol follows the width" {
    var t = try TestGame.init(std.testing.allocator);
    defer t.deinit();
    const g = t.game;
    var obj: Object = .{ .kind = .piece };
    g.piece = &obj;
    const cells = [6]usize{ 6, 4, 4, 4, 4, 4 };
    for (0..6) |k| {
        newGame(g, @intCast(k));
        var n: usize = 0;
        for (std.mem.asBytes(&obj.piece.board)) |c| n += @intFromBool(c == '1');
        try std.testing.expectEqual(cells[k], n);
        try std.testing.expectEqual(@as(i16, 1), obj.mover.moving);
    }
    calcRightCol(g, &obj, 4, 1);
    try std.testing.expectEqual(@as(i16, 7), obj.piece.rightCol);
    calcRightCol(g, &obj, 0, 2);
    try std.testing.expectEqual(@as(i16, 6), obj.piece.rightCol);
    calcRightCol(g, &obj, 1, 7);
    try std.testing.expectEqual(@as(i16, 6), obj.piece.rightCol);
}
