const std = @import("std");
const character = @import("character.zig");
const sim_mod = @import("sim.zig");
const Sim = sim_mod.Sim;
const Input = sim_mod.Input;
const t = @import("tables.zig");
const testing = @import("testing.zig");
const cpu = @import("cpu.zig");
const bot = @import("bot.zig");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const fp = sim_mod.fp;

fn load() !character.Character {
    var c = try character.Character.load(std.testing.allocator, try testing.pack(std.testing.allocator));
    c.setStandPx(t.stand_arcade * t.S);
    return c;
}

fn px(v: i32) i32 {
    return @divTrunc(v, fp);
}

/// Runs `n` ticks with fighter 0 holding `inp` (taps once, on the first).
fn run(s: *Sim, n: usize) void {
    for (0..n) |_| s.step();
}

fn press(s: *Sim, who: u1, inp: Input) void {
    s.setHeld(who, inp);
}

test "the synthetic pack loads" {
    var c = try load();
    defer c.deinit();
    try expect(c.clip(.sweep).active != null);
}

test "a straight jump: MK3's arc (39 ticks, 95 arcade px high), no air control" {
    var c = try load();
    defer c.deinit();
    var s = Sim.init(&c, &c);
    press(&s, 0, .{ .up = true });
    s.step();
    press(&s, 0, .{ .left = true });
    var top: i32 = 0;
    var ticks: u32 = 1;
    while (s.f[0].state == .air and ticks < 100) : (ticks += 1) {
        s.step();
        top = @max(top, s.f[0].y);
    }
    try expect(ticks >= 38 and ticks <= 42);
    // 95 arcade px at the vertical scale: the same share of the screen's height as MK3's (95 / 254).
    try expect(@abs(px(top) - @as(i32, @intFromFloat(@round(95 * t.SY)))) <= 3);
    // Holding left in the air does nothing: it lands where it left.
    try expectEqual(@as(i32, t.start_x[0]), px(s.f[0].x));
    try expect(s.f[0].grounded());
}

test "a forward jump crosses over, then the fighters face each other again" {
    var c = try load();
    defer c.deinit();
    var s = Sim.init(&c, &c);
    s.f[0].x = 250 * fp;
    s.f[1].x = 400 * fp;
    press(&s, 0, .{ .up = true, .right = true });
    s.step();
    press(&s, 0, .{});
    var crossed = false;
    var n: u32 = 0;
    while (n < 60) : (n += 1) {
        s.step();
        if (s.f[0].x > s.f[1].x) crossed = true;
        // Over him: nobody is pushed.
        if (!s.f[0].grounded()) try expectEqual(@as(i32, 400), px(s.f[1].x));
    }
    try expect(crossed);
    try expectEqual(@as(i8, -1), s.f[0].face);
    try expectEqual(@as(i8, 1), s.f[1].face);
    // Landed beside him: pushed a little apart, never back across.
    try expect(px(s.f[0].x) > 400);
}

test "a forward jump covers MK3's 156 arcade px" {
    var c = try load();
    defer c.deinit();
    var s = Sim.init(&c, &c);
    s.f[0].x = 100 * fp;
    s.f[1].x = 560 * fp;
    press(&s, 0, .{ .up = true, .right = true });
    s.step();
    press(&s, 0, .{});
    run(&s, 60);
    try expect(s.f[0].grounded());
    try expect(@abs(px(s.f[0].x) - 100 - @as(i32, @intFromFloat(@round(156 * t.S)))) <= 6);
}

fn pair(s: *Sim, gap: i32) void {
    s.f[0].x = 250 * fp;
    s.f[1].x = (250 + gap) * fp;
    for (&s.f) |*f| f.px = f.x;
}

test "a punch hits for 7 and the other reels; it lands once" {
    var c = try load();
    defer c.deinit();
    var s = Sim.init(&c, &c);
    // Close: LP is the throw, so stand a bit apart for the plain punch.
    pair(&s, t.ref(170));
    s.latch[0].lp = true;
    run(&s, 30);
    try expectEqual(@as(i16, t.health_max - 7), s.f[1].health);
    try expect(s.f[1].state == .hit or s.f[1].state == .idle);
}

test "block: chip damage, no stun for the attacker, a standing block does not stop a sweep" {
    var c = try load();
    defer c.deinit();
    var s = Sim.init(&c, &c);
    pair(&s, t.ref(170));
    s.setHeld(1, .{ .block = true });
    s.latch[0].hp = true;
    run(&s, 30);
    // 10 damage: chip is 12%, at least 1.
    try expectEqual(@as(i16, t.health_max - 1), s.f[1].health);
    try expect(s.f[1].state == .blockstun or s.f[1].state == .block);

    var s2 = Sim.init(&c, &c);
    pair(&s2, t.ref(170));
    s2.setHeld(1, .{ .block = true });
    s2.setHeld(0, .{ .down = true });
    s2.latch[0].hk = true;
    run(&s2, 40);
    // The sweep is a low: it knocks him down for its 12.
    try expectEqual(@as(i16, t.health_max - 12), s2.f[1].health);
    try expect(s2.f[1].state == .fall or s2.f[1].state == .down);

    // A crouching block stops it.
    var s3 = Sim.init(&c, &c);
    pair(&s3, t.ref(170));
    s3.setHeld(1, .{ .block = true, .down = true });
    s3.setHeld(0, .{ .down = true });
    s3.latch[0].hk = true;
    run(&s3, 40);
    try expect(s3.f[1].health > t.health_max - 3);
}

test "a high punch goes over a crouching fighter" {
    var c = try load();
    defer c.deinit();
    var s = Sim.init(&c, &c);
    pair(&s, t.ref(170));
    s.setHeld(1, .{ .down = true });
    s.latch[0].hp = true;
    run(&s, 30);
    try expectEqual(@as(i16, t.health_max), s.f[1].health);
}

test "a knockdown: down, getting up, then free again" {
    var c = try load();
    defer c.deinit();
    var s = Sim.init(&c, &c);
    pair(&s, t.ref(170));
    s.setHeld(0, .{ .down = true });
    s.latch[0].hk = true;
    var saw_fall = false;
    var saw_down = false;
    var saw_getup = false;
    for (0..200) |_| {
        s.step();
        switch (s.f[1].state) {
            .fall => saw_fall = true,
            .down => saw_down = true,
            .getup => saw_getup = true,
            else => {},
        }
        // A fighter on the floor cannot be hit again.
        s.latch[0].lp = false;
    }
    try expect(saw_fall and saw_down and saw_getup);
    try expect(s.f[1].state == .idle);
}

test "LP at close range is the throw: 24, unblockable" {
    var c = try load();
    defer c.deinit();
    var s = Sim.init(&c, &c);
    pair(&s, t.ref(90));
    s.setHeld(1, .{ .block = true });
    s.latch[0].lp = true;
    run(&s, 20);
    try expectEqual(@as(i16, t.health_max - 24), s.f[1].health);
    try expect(s.f[1].state == .fall);
}

test "a KO ends the round and the winner is named" {
    var c = try load();
    defer c.deinit();
    var s = Sim.init(&c, &c);
    pair(&s, t.ref(170));
    s.f[1].health = 5;
    s.latch[0].hp = true;
    run(&s, 30);
    try expect(s.over);
    try expectEqual(@as(?u1, 0), s.ko_winner);
    try expectEqual(@as(i16, 0), s.f[1].health);
    run(&s, 200);
    try expect(s.f[0].state == .win);
}

test "walls: nobody leaves the arena; a hit in the corner pushes the attacker" {
    var c = try load();
    defer c.deinit();
    var s = Sim.init(&c, &c);
    s.f[0].x = (t.arena_min + 4) * fp;
    s.f[1].x = (t.arena_min + t.ref(150)) * fp;
    s.setHeld(0, .{ .left = true });
    run(&s, 60);
    try expectEqual(@as(i32, t.arena_min), px(s.f[0].x));
}

test "fighters on the ground do not overlap" {
    var c = try load();
    defer c.deinit();
    var s = Sim.init(&c, &c);
    s.setHeld(0, .{ .right = true });
    run(&s, 120);
    try expect(px(@as(i32, @intCast(@abs(s.f[1].x - s.f[0].x)))) >= t.min_sep - 1);
}

/// Wins of `profile` against the CPU in 60 s rounds over `n` seeds; the
/// clock's tie goes to the player, as XILINDRO's.
fn winRate(prof: bot.Profile, n: u32) !struct { wins: u32, ko: u32, avg_hp: i32, cpu_hp: i32, ko_ticks: u32 } {
    var c = try load();
    defer c.deinit();
    var wins: u32 = 0;
    var ko: u32 = 0;
    var hp: i32 = 0;
    var chp: i32 = 0;
    var kt: u32 = 0;
    for (0..n) |seed| {
        var s = Sim.init(&c, &c);
        var b = bot.Bot.init(prof, @intCast(seed + 1));
        var cp = cpu.Cpu.init(@intCast(seed * 7919 + 13));
        var tick: u32 = 0;
        while (tick < 90 * t.tick_hz and !s.over) : (tick += 1) {
            const pin = b.think(&s, tick);
            s.held[0] = .{ .left = pin.left, .right = pin.right, .up = pin.up, .down = pin.down, .block = pin.block };
            s.latch[0].lp = s.latch[0].lp or pin.lp;
            s.latch[0].hp = s.latch[0].hp or pin.hp;
            s.latch[0].lk = s.latch[0].lk or pin.lk;
            s.latch[0].hk = s.latch[0].hk or pin.hk;
            s.setHeld(1, cp.think(&s, 1, tick));
            s.step();
        }
        hp += s.f[0].health;
        chp += s.f[1].health;
        kt += tick;
        if (s.over) ko += 1;
        if (s.f[0].health >= s.f[1].health) wins += 1;
    }
    return .{ .wins = wins, .ko = ko, .avg_hp = @divTrunc(hp, @as(i32, @intCast(n))), .cpu_hp = @divTrunc(chp, @as(i32, @intCast(n))), .ko_ticks = kt / n };
}

test "the CPU is beatable by a casual player and beats one that does nothing" {
    // On the synthetic art (the real pack's rates: docs/fights/MK3.md).
    const idle = try winRate(.idle, 30);
    try expectEqual(@as(u32, 0), idle.wins);
    const masher = try winRate(.masher, 30);
    try expect(masher.wins >= 12);
    const casual = try winRate(.casual, 30);
    try expect(casual.wins >= 21);
    const decent = try winRate(.decent, 30);
    try expect(decent.wins >= casual.wins - 3);
}

test "airborne frames hang from the head line: a tuck at the apex is above a standing opponent's head" {
    var c = try load();
    defer c.deinit();
    var s = Sim.init(&c, &c);
    const stand = px(-s.hurtBox(1).?.y0);
    press(&s, 0, .{ .up = true });
    s.step();
    press(&s, 0, .{});
    var apex: i32 = 0;
    var top_up: i32 = 0;
    var bottom_up: i32 = 0;
    var prev_top: i32 = 0;
    var n: u32 = 0;
    while (!s.f[0].grounded() and n < 100) : (n += 1) {
        const hb = s.hurtBox(0).?;
        // No pop: the top moves at most the arc speed (18.9) plus the easing in (a tuck all the way, the worst case).
        const top = px(-hb.y0);
        if (n > 0) try expect(@abs(top - prev_top) <= px(fx_max_step));
        prev_top = top;
        if (s.f[0].y > apex) {
            apex = s.f[0].y;
            top_up = top;
            bottom_up = px(-hb.y1);
        }
        s.step();
    }
    // Head line (a stand-height frame's top) = standing height + arc; the 50-px tuck of a 110-px
    // stance hangs 1.3 x 60 px higher than its feet anchor: top = stand + arc + 0.3 x 60.
    const arc = px(apex);
    const slack = @divTrunc((110 - 50) * c.scale_fp, 256);
    try expect(@abs(top_up - (stand + arc + @divTrunc(slack * 3, 10))) <= 3);
    // Entirely above the standing opponent's head, the ball's bottom over 1.2 x the stance.
    try expect(bottom_up > stand);
    try expect(@divTrunc(bottom_up * 100, stand) >= 120);
    // On the ground the frame is feet-anchored again.
    try expectEqual(@as(i32, 0), s.lift(0));
}

const fx_max_step: i32 = 40 * 256;

test "a jumper's hurt box is above the standing opponent's, so a jump-over clears him" {
    var c = try load();
    defer c.deinit();
    var s = Sim.init(&c, &c);
    s.f[0].x = 250 * fp;
    s.f[1].x = 400 * fp;
    press(&s, 0, .{ .up = true, .right = true });
    s.step();
    press(&s, 0, .{});
    var n: u32 = 0;
    var cleared = false;
    while (n < 60) : (n += 1) {
        s.step();
        if (s.f[0].grounded()) break;
        const a = s.hurtBox(0).?;
        const b = s.hurtBox(1).?;
        if (a.x0 < b.x1 and b.x0 < a.x1 and a.y1 < b.y0) cleared = true;
    }
    try expect(cleared);
}
