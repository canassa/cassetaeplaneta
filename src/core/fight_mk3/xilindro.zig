//! XILINDRO's side of the MK3 fight (`fixes.fight_mk3`): loading the sprite
//! pack, the key codes, the energies the old code reads (the clock's
//! tie-break, the score NOITE gets), the sounds and the presented picture.
//! Generic over XILINDRO's `Game` (`anytype`, as `fight_smooth.zig`); the
//! handler's own part is `arena.zig`'s `mk3Update`.

const std = @import("std");
const platform = @import("../../platform/platform.zig");
const fight_bot = @import("../fight_bot.zig");
const match = @import("match.zig");
pub const Match = match.Match;
const bot_mod = @import("bot.zig");
const t = @import("tables.zig");
const sim_mod = @import("sim.zig");

/// The pack's name in the game's files (`zig-out/sprites/ryu/pack.bin`
/// natively; `ryu/pack.bin` in the web build's files, when it has one).
pub const pack_name = "ryu\\pack.bin";

/// Reads the pack through the platform; null when there is none.
fn readPack(gpa: std.mem.Allocator, plat: platform.Platform) ?[]u8 {
    const f = plat.open(pack_name, .read) orelse return null;
    defer plat.close(f);
    const size = plat.seek(f, 0, .end);
    if (size <= 8) return null;
    _ = plat.seek(f, 0, .set);
    const buf = gpa.alloc(u8, @intCast(size)) catch return null;
    if (plat.read(f, buf) != buf.len) {
        gpa.free(buf);
        return null;
    }
    return buf;
}

/// WM_CREATE: the match, when the flag is on and the pack is there; the
/// old fight plays otherwise.
pub fn start(g: anytype) void {
    if (!g.fixes.fight_mk3 or g.mk3 != null) return;
    const bytes = readPack(g.gpa, g.plat) orelse {
        std.log.warn("fight_mk3: no sprite pack ({s}): the old fight plays (tools/ryu_pack.py)", .{pack_name});
        return;
    };
    const seed: u32 = if (fight_bot.config) |c| @truncate(c.seed) else g.plat.ticks() | 1;
    const m = Match.create(g.gpa, bytes, seed) catch |e| {
        std.log.warn("fight_mk3: the pack is not usable ({t}): the old fight plays", .{e});
        g.gpa.free(bytes);
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
