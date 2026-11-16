//! Not in the original (`Fixes.serial_loss_message`, a Corrigida addition): a short
//! message over the scene, drawn in the screen overlay (`Screen.overlay`, which the
//! backends put over the frame they present and the harness over its dumps), never
//! into the screen or the backdrop. NOITE has no message of its own for the player
//! (MessageBox is for errors, and only logged), so a handler that wants to tell
//! something calls `show`; `game_input.showDrag` calls `update` before every frame.
//!
//! The picture is drawn with the scene's palette on the first frame after `show`
//! (the scene may change between the two), by `core/controls_screen.zig`'s message.

const std = @import("std");
const Game = @import("core/game.zig").Game;
const platform = @import("platform/platform.zig");
const screen = @import("core/controls_screen.zig");

pub const Note = struct {
    active: bool = false,
    drawn: bool = false,
    /// `plat.ticks()` when it goes.
    until: u32 = 0,
    title: [64]u8 = @splat(0),
    title_len: u8 = 0,
    line: [64]u8 = @splat(0),
    line_len: u8 = 0,
};

pub const width: u16 = 300;
pub const height: u16 = 72;

/// Shows `title` and `line` (Windows-1252, at most 63 bytes each) for `ms`.
pub fn show(g: *Game, title: []const u8, line: []const u8, ms: u32) void {
    const n = &g.note;
    n.title_len = @intCast(@min(title.len, n.title.len));
    @memcpy(n.title[0..n.title_len], title[0..n.title_len]);
    n.line_len = @intCast(@min(line.len, n.line.len));
    @memcpy(n.line[0..n.line_len], line[0..n.line_len]);
    n.until = g.plat.ticks() +% ms;
    n.active = true;
    n.drawn = false;
}

/// Puts the note in the screen overlay while it lasts; false when there is none
/// (the overlay is left as it is).
pub fn update(g: *Game) bool {
    const n = &g.note;
    if (!n.active) return false;
    if (@as(i32, @bitCast(g.plat.ticks() -% n.until)) >= 0) {
        n.active = false;
        return false;
    }
    const scene = g.scene orelse return false;
    const bd = scene.backdrop orelse return false;
    const ov = &g.plat.screen().overlay;
    if (!n.drawn) {
        const pixels = ov.pixels[0 .. @as(usize, width) * height];
        const s: platform.Surface = .{ .pixels = pixels, .width = width, .height = height, .bottom_up = false, .colors = &bd.bmiColors };
        const lines = [_][]const u8{n.line[0..n.line_len]};
        screen.drawMessage(g.plat, s, .{
            .panel = .{ .x = 0, .y = 0, .w = width, .h = height },
            .title = n.title[0..n.title_len],
            .lines = &lines,
            .dimmed = false,
        });
        // An index the picture does not use is the one not drawn.
        var used: [256]bool = @splat(false);
        for (pixels) |c| used[c] = true;
        ov.transparent = for (used, 0..) |u, i| {
            if (!u) break @intCast(i);
        } else 0;
        n.drawn = true;
    }
    ov.width = width;
    ov.height = height;
    ov.x = @divTrunc(platform.screen_width - width, 2);
    ov.y = 170;
    ov.shown = true;
    return true;
}
