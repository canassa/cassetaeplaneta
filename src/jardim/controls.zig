//! Not in the original: the Corrigida's controls for JARDIM, in front of the game
//! (`app.wndProc` hands every message to `gate` once WM_CREATE has run).
//!
//! - `Fixes.jardim_controls_screen`: from WM_CREATE a screen lists the keys and the goal
//!   (`core/controls_screen.zig`, the fights' drawing) over the first frame; the game gets
//!   no input and no timer (no tick, no motion, no enemy) until a key or a click takes it
//!   down. The protocol with NOITE (0x40b, 0x40c, 0x40a), WM_PAINT, WM_DESTROY, the music's
//!   and the waves' notifications pass as ever; ESC still quits. The time the screen was up
//!   is added to `g_startTick` (J1's fixed bonus counts the time played).
//! - `Fixes.jardim_wolf_keys`: Space fires (VK_CONTROL) and E opens (VK_SPACE, which the
//!   phase handler and the backdrop read); W, S, A and D are polled by the motion step
//!   (`wolf.zig`) or, without `jardim_smooth_movement`, W and S are Up and Down.

const std = @import("std");
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const wm = msg.wm;
const screen = @import("../core/controls_screen.zig");
const Game = @import("core/game.zig").Game;
const world = @import("core/world.zig");
const wolf = @import("wolf.zig");

const vk_control: u16 = 0x11;
const vk_escape: u16 = 0x1b;
const vk_space: u16 = 0x20;
const vk_up: u16 = 0x26;
const vk_down: u16 = 0x28;
const vk_e: u16 = 0x45;
const vk_s: u16 = 0x53;
const vk_w: u16 = 0x57;

/// Puts the screen up (WM_CREATE, `jardim_controls_screen`).
pub fn open(g: *Game) void {
    g.controls = .{ .up = true, .shownAt = g.plat.ticks() };
}

/// `jardim_wolf_keys`: the key pressed to the key the game reads.
pub fn translate(g: *const Game, vk: u16) u16 {
    return switch (vk) {
        vk_space => vk_control,
        vk_e => vk_space,
        vk_w => if (g.fixes.jardim_smooth_movement) vk else vk_up,
        vk_s => if (g.fixes.jardim_smooth_movement) vk else vk_down,
        else => vk,
    };
}

fn isInput(id: u16) bool {
    return switch (id) {
        wm.keydown, wm.keyup, wm.mousemove, wm.lbuttondown, wm.lbuttonup, wm.rbuttondown, wm.rbuttonup, wm.systimer => true,
        else => false,
    };
}

/// The message the game gets instead of `m`, or null: kept from it.
pub fn gate(g: *Game, m: Msg) ?Msg {
    if (g.controls.up) {
        switch (m.id) {
            wm.keydown => if (m.wparam != vk_escape) {
                dismiss(g, m.wparam);
                return null;
            },
            wm.lbuttondown, wm.rbuttondown => {
                dismiss(g, null);
                return null;
            },
            else => {},
        }
        if (isInput(m.id) and !(m.id == wm.keydown and m.wparam == vk_escape)) return null;
        return m;
    }
    if (g.controls.heldKey) |k| if ((m.id == wm.keydown or m.id == wm.keyup) and m.wparam == k) {
        if (m.id == wm.keyup) g.controls.heldKey = null;
        return null;
    };
    var out = m;
    if (g.fixes.jardim_wolf_keys and (m.id == wm.keydown or m.id == wm.keyup)) out.wparam = translate(g, m.wparam);
    return out;
}

/// The key that took the screen down, while it is held: the motion step ignores it.
pub fn isHeldKey(g: *const Game, vk: u16) bool {
    return g.controls.heldKey == vk;
}

/// The screen goes: the game's clock and the motion count from now, a full repaint.
fn dismiss(g: *Game, key: ?u16) void {
    const now = g.plat.ticks();
    g.controls.up = false;
    g.controls.heldKey = key;
    g.startTick +%= now -% g.controls.shownAt;
    if (g.fixes.jardim_smooth_movement) wolf.restart(g);
    g.queue.paint_pending = true;
}

/// The panel: over the view, the minimap and the HUD.
pub const panel: screen.Rect = .{ .x = 40, .y = 8, .w = 560, .h = 464 };

const Row = screen.Row;

// Windows-1252 (the system font's).
const wolf_head = [_]Row{
    .{ .caps = &.{ .w, .up }, .text = "andar para a frente" },
    .{ .caps = &.{ .s, .down }, .text = "andar para tr\xe1s" },
    .{ .caps = &.{ .a, .d }, .text = "andar de lado" },
    .{ .caps = &.{ .left, .right }, .text = "virar" },
    .{ .caps = &.{.shift}, .text = "correr (segure junto)" },
    .{ .caps = &.{ .ctrl, .space }, .text = "atirar (sem arma, um soco)" },
};
const wolf_tail = [_]Row{
    .{ .caps = &.{.e}, .text = "abrir a porta / sair pela porta de sa\xedda" },
    .{ .caps = &.{.esc}, .text = "abandonar o jogo" },
};

const old_head = [_]Row{
    .{ .caps = &.{ .up, .down }, .text = "andar" },
    .{ .caps = &.{ .left, .right }, .text = "virar" },
    .{ .caps = &.{.shift}, .text = "correr (segure junto)" },
    .{ .caps = &.{.ctrl}, .text = "atirar (sem arma, um soco)" },
};
const old_tail = [_]Row{
    .{ .caps = &.{.space}, .text = "abrir a porta / sair pela porta de sa\xedda" },
    .{ .caps = &.{.esc}, .text = "abandonar o jogo" },
};

/// `jardim_weapon_inventory`: the row after the fire row.
const weapon_row = [_]Row{
    .{ .caps = &.{ .n1, .n2, .n3, .q }, .text = "trocar de arma (Q: a pr\xf3xima)" },
};

const wolf_rows = wolf_head ++ wolf_tail;
const old_rows = old_head ++ old_tail;
const wolf_weapon_rows = wolf_head ++ weapon_row ++ wolf_tail;
const old_weapon_rows = old_head ++ weapon_row ++ old_tail;

fn rowsFor(g: *const Game) []const Row {
    const wolf_keys = g.fixes.jardim_wolf_keys;
    if (g.fixes.jardim_weapon_inventory) return if (wolf_keys) &wolf_weapon_rows else &old_weapon_rows;
    return if (wolf_keys) &wolf_rows else &old_rows;
}

const goal = [_][]const u8{
    "Ache a porta de sa\xedda de cada um dos tr\xeas labirintos;",
    "no terceiro, alcance a mo\xe7a de mai\xf4 para vencer.",
    "Armas, muni\xe7\xe3o e comida est\xe3o pelo caminho (a cerveja",
    "d\xe1 pontos mas tira sa\xfade). Inimigos tiram sa\xfade ou uma",
    "vida; sa\xfade zero custa uma vida, e sem vidas o jogo acaba.",
};

/// Draws the screen over the backdrop's surface (after the frame WM_PAINT drew).
pub fn draw(g: *Game, bd: *world.Backdrop) void {
    screen.draw(g.plat, bd.surface(), .{
        .panel = panel,
        .title = "NOITE ANIMAL JARDIM",
        .rows = rowsFor(g),
        .caps_x = 50,
        .text_x = 190,
        .row_gap = 5,
        .goal = &goal,
    });
}

test "Space fires, E opens, the screen keeps the game until a key" {
    const TestGame = @import("core/game.zig").TestGame;
    const t = try TestGame.init(std.testing.allocator);
    defer t.deinit();
    const g = t.game;
    g.fixes.jardim_wolf_keys = true;
    g.fixes.jardim_smooth_movement = true;
    open(g);
    try std.testing.expect(gate(g, .{ .id = wm.systimer, .wparam = 1 }) == null);
    try std.testing.expect(gate(g, .{ .id = msg.noite.minigame_hello }) != null);
    try std.testing.expect(gate(g, .{ .id = wm.keydown, .wparam = vk_w }) == null);
    try std.testing.expect(!g.controls.up and isHeldKey(g, vk_w));
    try std.testing.expect(gate(g, .{ .id = wm.keyup, .wparam = vk_w }) == null);
    try std.testing.expectEqual(vk_control, gate(g, .{ .id = wm.keydown, .wparam = vk_space }).?.wparam);
    try std.testing.expectEqual(vk_space, gate(g, .{ .id = wm.keydown, .wparam = vk_e }).?.wparam);
    try std.testing.expectEqual(vk_w, gate(g, .{ .id = wm.keydown, .wparam = vk_w }).?.wparam);
}
