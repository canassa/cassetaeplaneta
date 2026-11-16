//! Not in the original (`Fixes.inv_controls_screen`, with the arcade rules): the Corrigida's controls
//! screen in front of the game (`app.wndProc` hands every message to `gate` once WM_CREATE has
//! run), the fights', JARDIM's and SAUNA's drawing (`core/controls_screen.zig`) with INV's rows.
//!
//! From WM_CREATE the presented picture (`view.zig`) shows the panel over the first frame; the game
//! gets no input and no timer until a key or a click takes it down (Esc leaves). The protocol with
//! NOITE (0x40b, 0x40c, 0x40a), WM_PAINT, WM_DESTROY, the music's and the waves' notifications pass
//! as ever.

const std = @import("std");
const msg = @import("../../core/msg.zig");
const Msg = msg.Msg;
const wm = msg.wm;
const screen = @import("../../core/controls_screen.zig");
const platform = @import("../../platform/platform.zig");
const Game = @import("../core/game.zig").Game;
const glue = @import("glue.zig");

const vk_escape: u16 = 0x1b;

/// Puts the screen up (WM_CREATE).
pub fn open(g: *Game) void {
    g.arcade.ctl = .{ .up = true };
}

fn isInput(id: u16) bool {
    return switch (id) {
        wm.keydown, wm.keyup, wm.mousemove, wm.lbuttondown, wm.lbuttonup, wm.rbuttondown, wm.rbuttonup, wm.systimer => true,
        else => false,
    };
}

/// The message the game gets instead of `m`, or null: kept from it.
pub fn gate(g: *Game, m: Msg) ?Msg {
    const c = &g.arcade.ctl;
    if (c.up) {
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
    if (c.held_key) |k| if ((m.id == wm.keydown or m.id == wm.keyup) and m.wparam == k) {
        if (m.id == wm.keyup) c.held_key = null;
        return null;
    };
    return m;
}

/// The screen goes and the game starts.
fn dismiss(g: *Game, key: ?u16) void {
    g.arcade.ctl.up = false;
    g.arcade.ctl.held_key = key;
    glue.go(g);
}

pub const panel: screen.Rect = .{ .x = 60, .y = 70, .w = 520, .h = 300 };

const Row = screen.Row;

// Windows-1252 (the system font's).
const rows = [_]Row{
    .{ .caps = &.{ .left, .right }, .text = "mover o canh\xe3o" },
    .{ .caps = &.{ .a, .d }, .text = "o mesmo, no teclado" },
    .{ .caps = &.{.space}, .text = "atirar (um tiro de cada vez)" },
    .{ .caps = &.{.esc}, .text = "abandonar o jogo (conta como derrota)" },
};

const goal = [_][]const u8{
    "Destrua os invasores antes que eles pousem.",
    "Os abrigos protegem, mas as bombas os destroem.",
    "Voc\xea tem tr\xeas vidas.",
};

/// Draws the screen over `surface`.
pub fn draw(g: *Game, surface: platform.Surface) void {
    screen.draw(g.plat, surface, .{
        .panel = panel,
        .title = "INVASORES",
        .rows = &rows,
        .caps_x = 50,
        .text_x = 230,
        .row_gap = 8,
        .goal = &goal,
    });
}

test "the screen keeps the game until a key; Esc leaves it up for the game to quit" {
    const TestGame = @import("../core/game.zig").TestGame;
    const t = try TestGame.init(std.testing.allocator);
    defer t.deinit();
    const g = t.game;
    open(g);
    try std.testing.expect(gate(g, .{ .id = wm.systimer, .wparam = 1 }) == null);
    try std.testing.expect(gate(g, .{ .id = msg.noite.minigame_hello }) != null);
    try std.testing.expect(gate(g, .{ .id = wm.keydown, .wparam = vk_escape }) != null);
    try std.testing.expect(g.arcade.ctl.up);
    try std.testing.expect(gate(g, .{ .id = wm.keydown, .wparam = 'A' }) == null);
    try std.testing.expect(!g.arcade.ctl.up and g.arcade.ctl.held_key.? == 'A');
    try std.testing.expect(gate(g, .{ .id = wm.keyup, .wparam = 'A' }) == null);
    try std.testing.expect(g.arcade.ctl.held_key == null);
    try std.testing.expect(gate(g, .{ .id = wm.keydown, .wparam = 'A' }) != null);
}
