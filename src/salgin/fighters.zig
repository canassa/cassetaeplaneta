//! Port unit `fighters` (module) of SALGIN.EXE. The two fighters' own methods: the opponent's creation, FighterVtbl startTimer/walk, OpponentVtbl walk (the wall and stand-off clamps), the opponent's attack choice (srand(time) + rand), the blow and pain wave pairs.
//!
//! Each function carries `// @orig <seg:xxxx> <name>` with the SALGIN
//! address. The hwnd parameters are dropped (the platform's window), except
//! `playMane`'s notify window.

const msg = @import("../core/msg.zig");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const object_create = @import("object_create.zig");
const sound = @import("sound.zig");
const animation = @import("behaviour/animation.zig");
const movement = @import("behaviour/movement.zig");
const occupancy = @import("behaviour/occupancy.zig");

pub const Error = object_create.Error;

// @orig 1068:0000 salgin_create_opponent
/// Builds the computer fighter (11 `ma*.bmp` strips 216 x 295, steps 32 x 0,
/// timer 10 / 0x44c, hit box = the strip, at (200, 0x8c)), attaches it, sets
/// strip 4 (walk), frame 0, direction 1 and the frame count, plays it and
/// starts it walking left (moveToEdgeH, dir 1). contactMark '0', frameCount
/// 0, health 91, hitLock 0.
pub fn createOpponent(g: *Game, bd: *Backdrop) Error!void {
    const o = g.local().create(Object) catch return error.OutOfMemory;
    o.* = .{ .kind = .opponent };
    try object_create.opponentCtor(
        g,
        o,
        200,
        0x8c,
        0xb,
        g.opponentStripFiles[0..],
        g.opponentStripFrames[0..],
        g.opponentStripWidths[0..],
        g.opponentStripHeights[0..],
        0,
        0,
        g.opponentStripWidths[0],
        g.opponentStripHeights[0],
        10,
        0x44c,
        0x20,
        0,
        1,
        0,
        true,
    );
    g.opponent = o;
    _ = occupancy.attach(g, o, bd);
    o.curStrip = 4;
    o.curFrame = 0;
    o.mover.direction = 1;
    o.anim.framesLeft = g.opponentStripFrames[@as(u16, @bitCast(o.curStrip))];
    animation.play(g, o, bd);
    movement.moveToEdgeH(g, o, bd, 1);
    o.opponent.contactMark = 0x30;
    o.opponent.frameCount = 0;
    o.opponent.health = 0x5b;
    o.opponent.hitLock = 0;
}

// @orig 1088:56ec fighter_start_timer
/// FighterVtbl slot 01 startTimer (hwnd dropped): stores `timer_id` in
/// `Fighter.timerId` and starts the system timer; returns the object.
pub fn startTimer(g: *Game, obj: *Object, timer_id: i16, period: i16) *Object {
    obj.fighter.timerId = timer_id;
    g.setSystemTimer(@bitCast(timer_id), @bitCast(period));
    return obj;
}

/// FighterVtbl slot 02 / OpponentVtbl slot 01 walk (hwnd dropped):
/// fighter_walk (fighter), opponent_walk (opponent): one 32-px step of the
/// walk in `mover.direction`, or the stop at a wall.
pub fn walk(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .fighter => fighterWalk(g, obj, bd),
        .opponent => opponentWalk(g, obj, bd),
        else => unreachable,
    }
}

fn min16(a: i16, b: i16) i16 {
    return if (a < b) a else b;
}

// @orig 1068:0672 fighter_walk
/// Left: x < 1 stops, else step -32 towards target 0. Right: x >= 400 stops;
/// nextX < opponent.x - 100 steps +32, else nextX = opponent.x - 100 and
/// still steps +32 (BUGS.md S10: 68 px from the opponent;
/// `salgin_standoff_100`: no step after the clamp). The walls test x before
/// the step (S11; `salgin_walls_after_step` cuts the step to land on 0 / 400).
fn fighterWalk(g: *Game, obj: *Object, bd: *Backdrop) void {
    const m = &obj.mover;
    if (m.direction == 1) {
        if (obj.x < 1) {
            movement.stopMoving(g, obj, bd);
        } else {
            m.stepX = if (g.fixes.salgin_walls_after_step) -min16(0x20, obj.x) else -0x20;
            m.targetX = 0;
            movement.moveTick(g, obj, bd);
        }
    } else if (m.direction == 2) {
        if (obj.x < 400) {
            const stand = g.opponent.?.x -% 100;
            var step: i16 = 0x20;
            if (obj.nextX >= stand) {
                obj.nextX = stand;
                if (g.fixes.salgin_standoff_100) step = 0;
            }
            if (g.fixes.salgin_walls_after_step) step = min16(step, 400 - obj.x);
            m.stepX = step;
            movement.moveTick(g, obj, bd);
        } else {
            movement.stopMoving(g, obj, bd);
        }
    }
}

// @orig 1068:0a08 opponent_walk
/// One step of the opponent's walk; it never sets stepX (negated to -32 by
/// create's moveToEdgeH). Direction 1 at x < 1 or direction 2 at x > 499
/// stops; else a step, after clamping nextX to fighter.x + 100 when it is not
/// farther (dead in practice).
fn opponentWalk(g: *Game, obj: *Object, bd: *Backdrop) void {
    const f = g.fighter.?;
    const m = &obj.mover;
    if (m.direction == 1 and obj.x < 1) {
        movement.stopMoving(g, obj, bd);
    } else if (m.direction == 2 and 499 < obj.x) {
        movement.stopMoving(g, obj, bd);
    } else if (f.x +% 100 < obj.nextX) {
        movement.moveTick(g, obj, bd);
    } else {
        obj.nextX = f.x +% 100;
        movement.moveTick(g, obj, bd);
    }
}

// @orig 1068:0b85 opponent_choose_attack
/// The opponent's attack: `srand(time(NULL))` (before every choice, BUGS.md
/// S5; `salgin_seed_once`: only before the first), then curStrip = rand() % 4
/// (against the player's strip 5 a 2 becomes 3), framesLeft from the strip
/// table, frameCount 0. The compiled if-chain on `fighter_strip` assigns
/// rand() % 4 in every other branch.
pub fn chooseAttack(g: *Game, obj: *Object, fighter_strip: i16) void {
    if (!g.fixes.salgin_seed_once or !g.randSeeded) {
        g.rand.srand(@truncate(@as(u32, @bitCast(g.plat.unixTime()))));
        g.randSeeded = true;
    }
    obj.curStrip = @rem(g.rand.rand(), 4);
    if (fighter_strip == 5 and obj.curStrip == 2) obj.curStrip = 3;
    obj.anim.framesLeft = g.opponentStripFrames[@as(u16, @bitCast(obj.curStrip))];
    obj.opponent.frameCount = 0;
}

// @orig 1068:2bb3 salgin_play_counter_wave
/// By the opponent's attack strip: 0 punch_pain4, 1/3/4 kick_pain4, 2 punch2.
pub fn playCounterWave(g: *Game, attack_strip: i16) void {
    switch (attack_strip) {
        0 => playPunchPain4(g),
        1, 3, 4 => playKickPain4(g),
        2 => playPunch2(g),
        else => {},
    }
}

// @orig 1068:2c01 salgin_play_kick_pain2
pub fn playKickPain2(g: *Game) void {
    _ = sound.play(g, 0, g.kickWave);
    _ = sound.play(g, 0, g.pain2Wave);
}

// @orig 1068:2c39 salgin_play_punch_pain2
pub fn playPunchPain2(g: *Game) void {
    _ = sound.play(g, 0, g.punchWave);
    _ = sound.play(g, 0, g.pain2Wave);
}

// @orig 1068:2c71 salgin_play_punch2
// @orig 1068:2d2d salgin_play_punch2_again
pub fn playPunch2(g: *Game) void {
    _ = sound.play(g, 0, g.punch2Wave);
}

// @orig 1068:2c97 salgin_play_boos
pub fn playBoos(g: *Game) void {
    _ = sound.play(g, 0, g.boosWave);
}

// @orig 1068:2cbd salgin_play_kick_pain4
pub fn playKickPain4(g: *Game) void {
    _ = sound.play(g, 0, g.kickWave);
    _ = sound.play(g, 0, g.pain4Wave);
}

// @orig 1068:2cf5 salgin_play_punch_pain4
pub fn playPunchPain4(g: *Game) void {
    _ = sound.play(g, 0, g.punchWave);
    _ = sound.play(g, 0, g.pain4Wave);
}

// @orig 1068:2d53 salgin_play_mane
/// mane.WAV with `hwnd` notified at its end (the opponent won the round).
pub fn playMane(g: *Game, hwnd: msg.Hwnd) void {
    _ = sound.play(g, hwnd, g.maneWave);
}
