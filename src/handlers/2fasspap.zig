//! Port unit `handler_2fasspap` (handler). scene handler 1020:07aa.
//!
//! The hitman reaction test: the voice names one of ten spots on the paper
//! and the player must right-click it within ten seconds. A hit leads to the
//! party arrival (2ffesta3); a miss or the time-out plays the shot, costs a
//! life (with no game-over test, BUGS.md B1) and returns to the street.
//!
//! Timers: 0x1f (10 s) is the answer deadline; 0x1e (2 s) follows a wrong
//! click and ends the same way.

const Game = @import("../core/game.zig").Game;
const Object = @import("../core/object.zig").Object;
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const backdrop = @import("../backdrop.zig");
const cstr = @import("../core/cstr.zig");
const frames = @import("../frames.zig");
const game_scenes = @import("../game_scenes.zig");
const ini = @import("../ini.zig");
const platform = @import("../platform/platform.zig");
const sound = @import("../sound.zig");
const update_list = @import("../update_list.zig");
const animation = @import("../behaviour/animation.zig");
const render = @import("../behaviour/render.zig");
const tick = @import("../behaviour/tick.zig");
const visibility = @import("../behaviour/visibility.zig");

const Rect = struct { left: i16 = 0, top: i16 = 0, right: i16 = 0, bottom: i16 = 0 };

pub const State = struct {
    // @orig g_s2fasspapTarget
    target: i16 = 0,
    // @orig g_s2fasspapIntro
    intro: i16 = 0,
    // @orig g_s2fasspapTimedOut
    timedOut: i16 = 0,
    // @orig g_s2fasspapAwaitingClick
    awaitingClick: i16 = 0,
    // @orig g_s2fasspapHitObject
    hitObject: ?*Object = null,
    // @orig g_s2fasspapHitResult
    hitResult: i8 = 0,
    // @orig g_s2fasspapSassv
    sassv: ?*Object = null,
    // @orig g_s2fasspapAssassin
    assassin: ?*Object = null,
    // @orig g_s2fasspapSaras
    saras: ?*Object = null,
    // @orig g_s2fasspapShotAnim
    shotAnim: ?*Object = null,
    // @orig g_s2fasspapPaper
    paper: ?*Object = null,
    // @orig g_s2fasspapCueWave
    cueWave: ?platform.Wave = null,
    // @orig g_s2fasspapPaperX
    paperX: i16 = 0,
    // @orig g_s2fasspapPaperY
    paperY: i16 = 0,
    // @orig g_s2fasspapTargetRects
    targetRects: [10]Rect = @splat(.{}),
};

/// Offsets (left, top, right, bottom) of the ten spots; left/right are
/// relative to the paper's x, top/bottom absolute.
const spots = [10][4]i16{
    .{ 0x6a, 0x147, 0xad, 0x179 },
    .{ 0x35, 0xfc, 0xf1, 0x121 },
    .{ 0x29, 0x89, 0xf2, 0xb4 },
    .{ 0x31, 0x14a, 0xeb, 0x177 },
    .{ 0x3e, 0x138, 0xd9, 0x15c },
    .{ 0x2f, 0xad, 0xda, 0xd8 },
    .{ 0x21, 0xf2, 0xf3, 0x116 },
    .{ 0x32, 0xd5, 0xe4, 0xfb },
    .{ 0x25, 0xe7, 0xe7, 0x10d },
    .{ 0x21, 0xda, 0xec, 0x108 },
};

fn ptInRect(r: Rect, x: i16, y: i16) bool {
    return x >= r.left and x < r.right and y >= r.top and y < r.bottom;
}

fn obj(o: ?*Object) *Object {
    return o.?;
}

/// reset_rects + draw (slot 1B).
fn resetAndDraw(g: *Game, o: *Object) void {
    frames.resetRects(o);
    render.draw(g, o, g.scene.?.backdrop.?);
}

// @orig 1020:07aa handler_2fasspap
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.rbuttondown => return rightButton(g, s, m),
        msg.wm.timer => {
            if (m.wparam == 0x1e) {
                g.killTimer(0x1e);
            } else if (m.wparam != 0x1f) {
                return 1;
            }
            g.killTimer(0x1f);
            s.timedOut = 1;
            const bd = g.scene.?.backdrop.?;
            frames.resetRects(obj(s.paper));
            visibility.hideAndInvalidate(g, obj(s.paper), 0, bd);
            resetAndDraw(g, obj(s.saras));
            resetAndDraw(g, obj(s.sassv));
            resetAndDraw(g, obj(s.shotAnim));
            resetAndDraw(g, obj(s.assassin));
            backdrop.blitToDc(g, g.scene.?.backdrop.?);
            update_list.discard(&g.updateList);
            animation.playOnce(g, obj(s.shotAnim), g.scene.?.backdrop.?);
            _ = sound.play(g, msg.main_window, obj(s.shotAnim).wave);
            return 1;
        },
        msg.wm.lbuttondown => return 1,
        msg.wm.mm_wom_done => return waveDone(g, s),
        msg.noite.scene_started => {
            const bd = g.scene.?.backdrop.?;
            tick.play(g, obj(s.sassv), bd);
            tick.play(g, obj(s.saras), g.scene.?.backdrop.?);
            tick.play(g, obj(s.assassin), g.scene.?.backdrop.?);
            _ = sound.play(g, msg.main_window, obj(s.assassin).wave);
            s.intro = 1;
            return 0;
        },
        msg.noite.object_created => {
            switch (m.wparam) {
                0x2c => {
                    s.paper = g.newObject;
                    const p = obj(s.paper);
                    s.paperX = p.x;
                    s.paperY = p.y;
                    for (spots, 0..) |sp, i| {
                        s.targetRects[i] = .{
                            .left = s.paperX +% sp[0],
                            .top = sp[1],
                            .right = s.paperX +% sp[2],
                            .bottom = sp[3],
                        };
                    }
                },
                7 => s.assassin = g.newObject,
                8 => s.shotAnim = g.newObject,
                9 => s.sassv = g.newObject,
                0x24 => s.saras = g.newObject,
                else => {},
            }
            return 0;
        },
        else => return 0,
    }
}

/// The wave end after the intro speech asks the question; after the shot it
/// costs a life; in between it arms the answer deadline.
fn waveDone(g: *Game, s: *State) i16 {
    if (s.intro != 0) {
        const bd = g.scene.?.backdrop.?;
        animation.stopAndRedraw(g, obj(s.assassin), bd);
        animation.stopAndRedraw(g, obj(s.saras), g.scene.?.backdrop.?);
        g.setSystemTimer(@bitCast(obj(s.saras).anim.timerId), @bitCast(obj(s.saras).anim.timerPeriod));
        s.intro = 0;
        s.target = ini.randomBelow(&g.rand, g.plat, 10) +% 1;
        var buf: [256]u8 = undefined;
        const path = cstr.print(&buf, "{s}{s}{d}.wav", .{ cstr.slice(&g.driveCD), "fase2\\2fasspap\\assasp", s.target });
        _ = frames.setCurFrame(obj(s.paper), @bitCast(s.target));
        frames.resetRects(obj(s.paper));
        render.draw(g, obj(s.paper), g.scene.?.backdrop.?);
        _ = visibility.invalidate(g, obj(s.paper));
        s.cueWave = sound.open(g, path) catch null;
        _ = sound.play(g, msg.main_window, s.cueWave);
        s.awaitingClick = 1;
        return 1;
    }
    if (s.timedOut == 0) {
        if (s.awaitingClick == 0) return 0;
        g.setTimer(0x1f, 10000);
        return 1;
    }
    // Time-out or wrong answer: no game-over test (BUGS.md B1).
    g.lives -%= 1;
    s.timedOut = 0;
    s.intro = 0;
    s.awaitingClick = 0;
    update_list.discard(&g.updateList);
    _ = game_scenes.switchScene(g, "2fpontoc", 0xf0, 0xc8, 1, 1, 0, 0, 0);
    return 1;
}

fn rightButton(g: *Game, s: *State, m: Msg) i16 {
    if (s.intro != 0) return 1;
    const bd = g.scene.?.backdrop.?;
    const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 0x10, 0x10);
    s.hitObject = q.obj;
    s.hitResult = @truncate(q.result);
    if (s.hitResult < 1) return 1;
    const hit = s.hitObject orelse return 1;
    if (animation.isRunning(g, obj(s.assassin))) {
        animation.stopAndRedraw(g, obj(s.assassin), g.scene.?.backdrop.?);
        g.setSystemTimer(@bitCast(obj(s.assassin).anim.timerId), @bitCast(obj(s.assassin).anim.timerPeriod));
        sound.stop(&g.sound, g.plat, obj(s.assassin).wave);
        s.awaitingClick = 1;
    }
    if (hit.id != 0x2c and hit.id != 7 and hit.id != 8 and hit.id != 0x24) return 1;
    if (s.awaitingClick == 0) return 1;
    s.awaitingClick = 0;
    const x: i16 = @bitCast(m.lo());
    const y: i16 = @bitCast(m.hi());
    const t: u16 = @bitCast(s.target -% 1);
    const hitSpot = t < 10 and ptInRect(s.targetRects[t], x, y);
    sound.stop(&g.sound, g.plat, s.cueWave);
    if (!hitSpot) {
        g.setTimer(0x1e, 2000);
        return 1;
    }
    g.killTimer(0x1f);
    s.intro = 0;
    s.timedOut = 0;
    s.awaitingClick = 0;
    update_list.discard(&g.updateList);
    _ = game_scenes.switchScene(g, "2ffesta3", 700, 250, 1, 0, 0, 0, 0);
    return 1;
}
