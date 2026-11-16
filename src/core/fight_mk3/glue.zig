//! The games' side of the MK3 fight (`fixes.fight_mk3`), shared by XILINDRO
//! and SALGIN: building the characters from the game's strips (each game's
//! table, `art_xilindro.zig` / `art_salgin.zig`, is passed in), the energies
//! the old code reads (the clock's tie-break, the score NOITE gets) and the
//! presented picture. Generic over the game's `Game` (`anytype`, as
//! `fight_smooth.zig`); each handler's own part is its `arena.zig`'s
//! `mk3Update`.

const std = @import("std");
const platform = @import("../../platform/platform.zig");
const fight_bot = @import("../fight_bot.zig");
const match = @import("match.zig");
pub const Match = match.Match;
const bot_mod = @import("bot.zig");
const t = @import("tables.zig");
const strips = @import("strips.zig");
const Character = @import("character.zig").Character;
const sim_mod = @import("sim.zig");

/// A fighter object's 11 strips as the converter's `Art`.
fn artOf(obj: anytype) ?strips.Art {
    var art: strips.Art = undefined;
    if (obj.frames.len < strips.strip_count) return null;
    for (obj.frames[0..strips.strip_count], 0..) |fr, i| {
        const d = fr.dib orelse return null;
        if (fr.width <= 0 or fr.height <= 0 or fr.count <= 0) return null;
        art.strips[i] = .{
            .bits = d.bits,
            .width = @intCast(fr.width),
            .height = @intCast(fr.height),
            .count = @intCast(fr.count),
            .bottom_up = d.header.biHeight > 0,
        };
        if (d.bits.len < @as(usize, (@as(u32, @intCast(fr.width)) + 3) & ~@as(u32, 3)) * @as(usize, @intCast(fr.height)) * @as(usize, @intCast(fr.count))) return null;
        if (i == 0) for (&art.palette, d.colors) |*p, q| {
            p.* = .{ q.red, q.green, q.blue };
        };
    }
    return art;
}

/// The game's own art: the player's and the opponent's strips the game has
/// loaded, converted (`strips.zig`) by the game's table `pair`.
fn loadOriginal(g: anytype, pair: strips.Pair, chars: *[2]Character) bool {
    const f = g.fighter orelse return false;
    const o = g.opponent orelse return false;
    const fa = artOf(f) orelse return false;
    const oa = artOf(o) orelse return false;
    chars[0] = strips.build(g.gpa, &fa, pair[0]) catch |e| {
        std.log.warn("fight_mk3: {s}'s strips are not usable ({t})", .{ pair[0].name, e });
        return false;
    };
    chars[1] = strips.build(g.gpa, &oa, pair[1]) catch |e| {
        std.log.warn("fight_mk3: {s}'s strips are not usable ({t})", .{ pair[1].name, e });
        chars[0].deinit();
        return false;
    };
    return true;
}

/// WM_CREATE: the match, when the flag is on: the game's own strips,
/// converted by `pair`. The old fight plays when the art cannot be made.
pub fn start(g: anytype, pair: strips.Pair) void {
    if (!g.fixes.fight_mk3 or g.mk3 != null) return;
    var chars: [2]Character = undefined;
    if (!loadOriginal(g, pair, &chars)) {
        std.log.warn("fight_mk3: no usable art: the old fight plays", .{});
        return;
    }
    const seed: u32 = if (fight_bot.config) |c| @truncate(c.seed) else g.plat.ticks() | 1;
    const m = Match.create(g.gpa, chars, seed) catch |e| {
        std.log.warn("fight_mk3: no match ({t}): the old fight plays", .{e});
        for (&chars) |*c| c.deinit();
        return;
    };
    if (fight_bot.config) |c| {
        match.trace = c.log_keys;
        m.bot = bot_mod.Bot.init(switch (c.profile) {
            .idle => .idle,
            .masher => .masher,
            .novice => .casual,
            .decent, .expert => .decent,
        }, @truncate(c.seed));
    }
    g.mk3 = m;
}

pub fn stop(g: anytype) void {
    if (g.mk3) |m| m.destroy();
    g.mk3 = null;
}

/// The old energy bar's number (0-91) for a health.
pub fn energyOf(health: i16) i16 {
    if (health <= 0) return 0;
    return @intCast(@divTrunc(@as(i32, health) * 91 + t.health_max - 1, t.health_max));
}

/// The picture to present: the screen with the arena rebuilt, or null (the
/// flag is off or no match, the controls screen is up).
pub fn view(g: anytype, now: u32) ?*const platform.Screen {
    const m = g.mk3 orelse return null;
    if (g.controls.phase == .screen) return null;
    m.advance(now);
    const scene = g.scene orelse return null;
    const bd = scene.backdrop orelse return null;
    var bg: ?match.Background = null;
    if (bd.background) |b| {
        bg = .{
            .bits = b.bits,
            .width = b.header.biWidth,
            .height = @intCast(@abs(b.header.biHeight)),
            .bottom_up = b.header.biHeight > 0,
        };
    }
    m.debug = g.fair.overlay;
    return m.view(g.plat.screen(), bg);
}
