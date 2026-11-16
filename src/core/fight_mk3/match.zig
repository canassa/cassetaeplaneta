//! A round of the MK3 fight: the simulation (`sim.zig`), its two controllers
//! (the player's keys or a test bot, the CPU drone `cpu.zig`), the clock that
//! turns the host's milliseconds into fixed ticks, and the picture
//! (`view`), built at the display rate between ticks by interpolating the
//! fighters' positions. No game state: `xilindro.zig` ties it to a game.

const std = @import("std");
const platform = @import("../../platform/platform.zig");
const Screen = platform.Screen;
const character = @import("character.zig");
const Character = character.Character;
const render = @import("render.zig");
const sim_mod = @import("sim.zig");
const Sim = sim_mod.Sim;
const Input = sim_mod.Input;
const cpu_mod = @import("cpu.zig");
const bot_mod = @import("bot.zig");
const t = @import("tables.zig");

pub const tick_us: u64 = 1_000_000 / t.tick_hz;

/// The longest gap the clock catches up with (a hidden page, a pause).
const max_catch_up_ms: u32 = 250;

/// Keys (Windows virtual-key codes).
pub const vk = struct {
    pub const left: u16 = 0x25;
    pub const up: u16 = 0x26;
    pub const right: u16 = 0x27;
    pub const down: u16 = 0x28;
    pub const space: u16 = 0x20;
    pub const z: u16 = 0x5a;
    pub const a: u16 = 0x41;
    pub const s: u16 = 0x53;
    pub const d: u16 = 0x44;
    pub const f: u16 = 0x46;
};

/// The background the arena band is restored from (the game's DIB).
pub const Background = struct {
    bits: []const u8,
    width: i32,
    height: i32,
    bottom_up: bool,
};

/// Prints one line per presented frame (`--fight-bot ...,log`): where each
/// fighter's feet were drawn and which frame, for `tools/fight_mk3_smooth.py`.
pub var trace: bool = false;

pub const Match = struct {
    gpa: std.mem.Allocator,
    char: Character,
    sim: Sim,
    cpu: cpu_mod.Cpu,
    bot: ?bot_mod.Bot = null,
    /// The keys held now (directions, block); taps go straight to the sim.
    keys: Input = .{},
    started: bool = false,
    last_ms: u32 = 0,
    acc_us: u64 = 0,
    /// Total ticks simulated.
    ticks: u32 = 0,
    // The picture.
    out: ?*Screen = null,
    pal_valid: bool = false,
    pal: [256]platform.Rgb = undefined,
    luts: [2]render.Lut = undefined,
    /// F9: boxes drawn over the fighters.
    debug: bool = false,
    /// What the last `view` drew (tests, the smoothness check).
    shown: [2]struct { x: i32 = 0, y: i32 = 0 } = .{ .{}, .{} },

    /// Takes the pack's bytes (`Character.load`).
    pub fn create(gpa: std.mem.Allocator, pack: []u8, seed: u32) !*Match {
        const m = try gpa.create(Match);
        errdefer gpa.destroy(m);
        m.* = .{
            .gpa = gpa,
            .char = try Character.load(gpa, pack),
            .sim = undefined,
            .cpu = cpu_mod.Cpu.init(seed),
        };
        m.char.setStandPx(t.stand_arcade * t.S);
        m.sim = Sim.init(&m.char, &m.char);
        return m;
    }

    pub fn destroy(m: *Match) void {
        if (m.out) |o| m.gpa.destroy(o);
        m.char.deinit();
        const gpa = m.gpa;
        gpa.destroy(m);
    }

    /// The round starts at `now`.
    pub fn begin(m: *Match, now: u32) void {
        m.started = true;
        m.last_ms = now;
        m.acc_us = 0;
    }

    pub fn over(m: *const Match) bool {
        return m.sim.over;
    }

    /// A key press or release (the player's controls).
    pub fn key(m: *Match, code: u16, down: bool) void {
        switch (code) {
            vk.left => m.keys.left = down,
            vk.right => m.keys.right = down,
            vk.up => m.keys.up = down,
            vk.down => m.keys.down = down,
            vk.space, vk.z => m.keys.block = down,
            vk.a, vk.s, vk.d, vk.f => if (down) {
                const l = &m.sim.latch[0];
                switch (code) {
                    vk.a => l.lp = true,
                    vk.s => l.hp = true,
                    vk.d => l.lk = true,
                    else => l.hk = true,
                }
            },
            else => {},
        }
    }

    /// Runs the simulation up to `now`.
    pub fn advance(m: *Match, now: u32) void {
        if (!m.started) {
            m.last_ms = now;
            return;
        }
        var dt: u32 = now -% m.last_ms;
        if (dt > 0x8000_0000) dt = 0;
        m.last_ms = now;
        dt = @min(dt, max_catch_up_ms);
        m.acc_us += @as(u64, dt) * 1000;
        while (m.acc_us >= tick_us) {
            m.acc_us -= tick_us;
            m.tick();
        }
    }

    /// One fixed step: the controllers, then the simulation.
    pub fn tick(m: *Match) void {
        if (m.bot) |*b| {
            const inp = b.think(&m.sim, m.ticks);
            m.sim.held[0] = .{ .left = inp.left, .right = inp.right, .up = inp.up, .down = inp.down, .block = inp.block };
            m.sim.latch[0].lp = m.sim.latch[0].lp or inp.lp;
            m.sim.latch[0].hp = m.sim.latch[0].hp or inp.hp;
            m.sim.latch[0].lk = m.sim.latch[0].lk or inp.lk;
            m.sim.latch[0].hk = m.sim.latch[0].hk or inp.hk;
        } else {
            m.sim.held[0] = m.keys;
        }
        const cin = m.cpu.think(&m.sim, 1, m.ticks);
        m.sim.setHeld(1, cin);
        m.sim.step();
        m.ticks +%= 1;
    }

    // ---- the picture -----------------------------------------------------

    fn alpha(m: *const Match) i32 {
        return @intCast(@divTrunc(m.acc_us * 256, tick_us));
    }

    /// Where fighter `who` is drawn now: feet x and y on the screen.
    pub fn feet(m: *const Match, who: u1) struct { x: i32, y: i32 } {
        const a = m.alpha();
        return .{
            .x = @divTrunc(m.sim.lerpX(who, a), sim_mod.fp),
            .y = t.ground_y - @divTrunc(m.sim.lerpY(who, a), sim_mod.fp),
        };
    }

    fn refreshLuts(m: *Match, pal: *const [256]platform.Rgb) void {
        if (m.pal_valid and std.mem.eql(u8, std.mem.asBytes(&m.pal), std.mem.asBytes(pal))) return;
        m.pal = pal.*;
        m.pal_valid = true;
        render.buildLut(&m.char, pal, .none, &m.luts[0]);
        render.buildLut(&m.char, pal, .blue_gold, &m.luts[1]);
    }

    /// The picture for the window: `screen` (the clock and the portraits as
    /// the game drew them) with the arena band rebuilt from `bg`, the two
    /// fighters and the energy bars. Null when it cannot be made.
    pub fn view(m: *Match, screen: *const Screen, bg: ?Background) ?*const Screen {
        const out = m.out orelse blk: {
            const o = m.gpa.create(Screen) catch return null;
            m.out = o;
            break :blk o;
        };
        out.* = screen.*;
        m.refreshLuts(&screen.palette);
        if (bg) |b| restoreBand(out, b);
        // The one that struck last is drawn in front.
        const order: [2]u1 = if (m.sim.f[0].state == .attack or m.sim.f[0].state == .air_attack) .{ 1, 0 } else .{ 0, 1 };
        const a = m.alpha();
        for (order) |who| {
            const fr = m.sim.frameOf(who);
            const x = @divTrunc(m.sim.lerpX(who, a), sim_mod.fp);
            const y = t.ground_y - @divTrunc(m.sim.lerpY(who, a), sim_mod.fp);
            m.shown[who] = .{ .x = x, .y = y };
            render.drawFrame(&out.pixels, &m.char, &m.luts[who], fr, x, y, m.sim.f[who].face < 0);
        }
        if (trace or m.debug) {
            std.debug.print("[{d}] mk3-frame {d} {d} {d} {d} {t}:{d} {t}:{d}\n", .{
                m.last_ms,       m.shown[0].x,        m.shown[0].y,    m.shown[1].x,        m.shown[1].y,
                m.sim.f[0].anim, m.sim.frameIndex(0), m.sim.f[1].anim, m.sim.frameIndex(1),
            });
        }
        m.drawBars(out);
        if (m.debug) m.drawBoxes(out);
        return out;
    }

    fn drawBars(m: *Match, out: *Screen) void {
        const pal = &m.pal;
        const dark = render.nearest(pal, 90, 0, 0);
        // The background has the full yellow bar under the clock: the lost
        // part is painted over, from the clock outward.
        const bar_h = [2]i32{ 20, 40 };
        const left_x0: i32 = 66;
        const left_x1: i32 = 290;
        const right_x0: i32 = 333;
        const right_x1: i32 = 574;
        const f0 = m.sim.f[0].health;
        const f1 = m.sim.f[1].health;
        const lost0 = @divTrunc((left_x1 - left_x0) * (t.health_max - @as(i32, f0)), t.health_max);
        const lost1 = @divTrunc((right_x1 - right_x0) * (t.health_max - @as(i32, f1)), t.health_max);
        // Both bars drain from the clock outward, as the Original's tiles do.
        render.fillRect(&out.pixels, left_x1 - lost0, bar_h[0], left_x1, bar_h[1], dark);
        render.fillRect(&out.pixels, right_x0, bar_h[0], right_x0 + lost1, bar_h[1], dark);
    }

    fn drawBoxes(m: *Match, out: *Screen) void {
        const hurt = render.nearest(&m.pal, 0, 0, 255);
        const hit = render.nearest(&m.pal, 255, 0, 0);
        const ground = render.nearest(&m.pal, 0, 255, 0);
        for ([2]u1{ 0, 1 }) |w| {
            const f = m.shown[w];
            render.fillRect(&out.pixels, f.x - 1, f.y - 1, f.x + 2, f.y + 2, ground);
            if (m.sim.hurtBox(w)) |b| drawRect(out, b, f.x, f.y, m.sim.f[w], hurt);
            if (m.sim.hitBox(w)) |b| drawRect(out, b, f.x, f.y, m.sim.f[w], hit);
        }
    }

    fn drawRect(out: *Screen, b: Sim.Rect, sx: i32, sy: i32, f: sim_mod.Fighter, col: u8) void {
        // World boxes are at the tick's position: offset to where the
        // picture shows the fighter.
        const dx = sx - @divTrunc(f.x, sim_mod.fp);
        const dy = sy - (t.ground_y - @divTrunc(f.y, sim_mod.fp));
        render.rectOutline(&out.pixels, @divTrunc(b.x0, sim_mod.fp) + dx, t.ground_y + @divTrunc(b.y0, sim_mod.fp) + dy, @divTrunc(b.x1, sim_mod.fp) + dx, t.ground_y + @divTrunc(b.y1, sim_mod.fp) + dy, col);
    }
};

/// The arena band (y `t.band_y`, `t.band_h` rows) of the background over
/// the picture.
fn restoreBand(out: *Screen, b: Background) void {
    const stride: usize = (@as(usize, @intCast(b.width)) + 3) & ~@as(usize, 3);
    const w: usize = @intCast(@min(b.width, platform.screen_width));
    var y: i32 = t.band_y;
    while (y < t.band_y + t.band_h and y < platform.screen_height and y < b.height) : (y += 1) {
        const row: usize = @intCast(if (b.bottom_up) b.height - 1 - y else y);
        if ((row + 1) * stride > b.bits.len) continue;
        @memcpy(out.pixels[@as(usize, @intCast(y)) * platform.screen_width ..][0..w], b.bits[row * stride ..][0..w]);
    }
}
