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
const render = @import("render.zig");
const strips = @import("strips.zig");
const Character = @import("character.zig").Character;
const sim_mod = @import("sim.zig");

/// The Ryu pack's name in the game's files (`zig-out/sprites/ryu/pack.bin`
/// natively; `ryu/pack.bin` in a web build that ships it), for the
/// `fight_mk3_ryu` option.
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

/// SF3 Ryu on both sides (the private pack, the opponent palette-swapped),
/// sized to MK3's standing height.
fn loadRyu(g: anytype, chars: *[2]Character) bool {
    const bytes = readPack(g.gpa, g.plat) orelse return false;
    const copy = g.gpa.dupe(u8, bytes) catch {
        g.gpa.free(bytes);
        return false;
    };
    chars[0] = Character.load(g.gpa, bytes) catch {
        g.gpa.free(bytes);
        g.gpa.free(copy);
        return false;
    };
    chars[1] = Character.load(g.gpa, copy) catch {
        chars[0].deinit();
        g.gpa.free(copy);
        return false;
    };
    for (chars) |*c| c.setStandPx(t.stand_arcade * t.S);
    return true;
}

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

/// XILINDRO's own art (the default): the fighter's and the inmate's strips
/// the game has loaded, converted (`strips.zig`).
fn loadOriginal(g: anytype, chars: *[2]Character) bool {
    const f = g.fighter orelse return false;
    const o = g.opponent orelse return false;
    const fa = artOf(f) orelse return false;
    const oa = artOf(o) orelse return false;
    chars[0] = strips.build(g.gpa, &fa, .fighter) catch |e| {
        std.log.warn("fight_mk3: the fighter's strips are not usable ({t})", .{e});
        return false;
    };
    chars[1] = strips.build(g.gpa, &oa, .inmate) catch |e| {
        std.log.warn("fight_mk3: the inmate's strips are not usable ({t})", .{e});
        chars[0].deinit();
        return false;
    };
    return true;
}

/// WM_CREATE: the match, when the flag is on: the game's own strips, or
/// (`fight_mk3_ryu`) the private Ryu pack when it is there. The old fight
/// plays when the art cannot be made.
pub fn start(g: anytype) void {
    if (!g.fixes.fight_mk3 or g.mk3 != null) return;
    var chars: [2]Character = undefined;
    var swap: [2]render.Swap = .{ .none, .none };
    var have = false;
    if (g.fixes.fight_mk3_ryu) {
        have = loadRyu(g, &chars);
        if (have) swap = .{ .none, .blue_gold } else std.log.warn("fight_mk3: no Ryu pack ({s}): XILINDRO's own art plays (tools/ryu_pack.py)", .{pack_name});
    }
    if (!have and !loadOriginal(g, &chars)) {
        std.log.warn("fight_mk3: no usable art: the old fight plays", .{});
        return;
    }
    const seed: u32 = if (fight_bot.config) |c| @truncate(c.seed) else g.plat.ticks() | 1;
    const m = Match.create(g.gpa, chars, swap, seed) catch |e| {
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
