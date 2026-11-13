//! Port unit `handler_4fboydj` (handler). scene handler 1020:cd36.
//!
//! The DJ's mixing desk: three buttons, one of them right. The scene starts
//! by picking a random rotation of three button rectangles; a right click
//! inside rectangle 0 plays the boo button (boos, then the lights go out),
//! inside rectangle 1 the globe button, inside rectangle 2 the right one
//! (timer 0x15 after 5 s leads to the dance floor). When a boo or globe
//! animation ends, timer 0x14 (3 s) costs a life and returns to the bar
//! (4fbarbo2).
//!
//! Original bugs reproduced: the life lost on timer 0x14 has no game-over
//! test (B1, fix `lives_game_over`); rotation 2 maps the rectangles to
//! table entries 2, 1, 0 (not a rotation of 0, 1, 2).

const Game = @import("../core/game.zig").Game;
const Object = @import("../core/object.zig").Object;
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const backdrop = @import("../backdrop.zig");
const cstr = @import("../core/cstr.zig");
const game_scenes = @import("../game_scenes.zig");
const ini = @import("../ini.zig");
const sound = @import("../sound.zig");
const update_list = @import("../update_list.zig");
const animation = @import("../behaviour/animation.zig");
const space3d = @import("../behaviour/space3d.zig");
const tick = @import("../behaviour/tick.zig");

const Rect = struct { left: i16 = 0, top: i16 = 0, right: i16 = 0, bottom: i16 = 0 };

pub const State = struct {
    // @orig g_s4fboydjBooPending (1050:0c38)
    booPending: i16 = 0,
    // @orig g_s4fboydjGlobePending (1050:0c3a)
    globePending: i16 = 0,
    // @orig g_s4fboydjUnk0C3C (1050:0c3c; only ever cleared)
    unk0C3C: i16 = 0,
    // @orig g_s4fboydjButtonRectTable (1050:0c3e), initial values from the EXE
    buttonRectTable: [3]Rect = .{
        .{ .left = 0xfb, .top = 0x170, .right = 0x111, .bottom = 0x180 },
        .{ .left = 0x10e, .top = 0x186, .right = 0x127, .bottom = 0x19a },
        .{ .left = 0x122, .top = 0x1a0, .right = 0x13b, .bottom = 0x1b3 },
    },
    // @orig 1040:002c (the click point; ES:[0x2c] after MOV ES,[0x1240])
    clickX: i16 = 0,
    clickY: i16 = 0,
    // @orig g_s4fboydjButtonRects (1040:0030)
    buttonRects: [3]Rect = @splat(.{}),
    // @orig g_s4fboydjHitObject
    hitObject: ?*Object = null,
    // @orig g_s4fboydjButton1 (INI Number 0xe8)
    button1: ?*Object = null,
    // @orig g_s4fboydjButton2 (0xe9)
    button2: ?*Object = null,
    // @orig g_s4fboydjButton3 (0xea)
    button3: ?*Object = null,
    // @orig g_s4fboydjLights (0xe7)
    lights: ?*Object = null,
    // @orig g_s4fboydjGlobe (0x117)
    globe: ?*Object = null,
    // @orig g_s4fboydjButtonRotation
    buttonRotation: i16 = 0,
};

fn must(o: ?*Object) *Object {
    return o.?;
}

fn ptInRect(r: Rect, x: i16, y: i16) bool {
    return x >= r.left and x < r.right and y >= r.top and y < r.bottom;
}

fn bdOf(g: *Game) *@import("../core/world.zig").Backdrop {
    return g.scene.?.backdrop.?;
}

/// `asAnimation()->playOnce(bd)` (Animation slot 07).
fn playOnce(g: *Game, o: ?*Object) void {
    animation.playOnce(g, must(must(o).as(.animation)), bdOf(g));
}

/// wave_play of the object's own wave.
fn playOwnWave(g: *Game, o: ?*Object) void {
    _ = sound.play(g, msg.main_window, must(o).wave);
}

/// `<CD>` + `name`, opened and played.
fn playBundled(g: *Game, name: []const u8) void {
    var buf: [257]u8 = undefined;
    // 1018:b784 "%s%s"
    const path = cstr.print(&buf, "{s}{s}", .{ cstr.slice(&g.driveCD), name });
    const w = sound.open(g, path) catch null;
    _ = sound.play(g, msg.main_window, w);
}

// @orig 1020:cd36 handler_4fboydj
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.timer => {
            if (m.wparam == 0x14) {
                g.killTimer(0x14);
                backdrop.blitToDc(g, bdOf(g));
                // B1: no game-over test.
                g.lives -%= 1;
                s.booPending = 0;
                s.globePending = 0;
                s.unk0C3C = 0;
                update_list.discard(&g.updateList);
                if (g.fixes.lives_game_over and g.lives <= 0) {
                    _ = game_scenes.switchScene(g, "6fsaida", 0, 0, 0, 0, 0, 1, 0);
                } else {
                    // 1020:d4fc
                    _ = game_scenes.switchScene(g, "4FBARBO2", 0, 0, 0, 1, 0, 0, 0);
                }
            }
            if (m.wparam == 0x15) {
                g.killTimer(0x15);
                s.booPending = 0;
                s.globePending = 0;
                s.unk0C3C = 0;
                update_list.discard(&g.updateList);
                // 1020:d506
                _ = game_scenes.switchScene(g, "4FPISTAV", 0, 0, 0, 0, 0, 0, 0);
            }
            return 0;
        },
        msg.wm.mousemove => {
            if (m.hi() > 0x1b8) return 1;
            return 0;
        },
        msg.wm.rbuttondown => return rightButton(g, s, m),
        msg.noite.scene_started => return sceneStarted(g, s),
        msg.noite.animation_finished => return animationFinished(g, s),
        msg.noite.object_created => {
            switch (m.wparam) {
                0xe7 => s.lights = g.newObject,
                0xe8 => s.button1 = g.newObject,
                0xe9 => s.button2 = g.newObject,
                0xea => s.button3 = g.newObject,
                0x117 => s.globe = g.newObject,
                else => {},
            }
            return 0;
        },
        else => return 0,
    }
}

fn rightButton(g: *Game, s: *State, m: Msg) i16 {
    const bd = bdOf(g);
    const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 0x10, 0x10);
    s.hitObject = q.obj;
    const hitFlag: i8 = @truncate(q.result);
    if (hitFlag <= 0) return 0;
    const hit = s.hitObject orelse return 0;
    switch (hit.id) {
        0xe7, 0xe8, 0xe9, 0xea, 0x117 => return 1,
        else => {},
    }
    s.clickX = @bitCast(m.lo());
    s.clickY = @bitCast(m.hi());
    if (ptInRect(s.buttonRects[0], s.clickX, s.clickY)) {
        s.booPending = 1;
        playOnce(g, s.button1);
        playOwnWave(g, s.button1);
    }
    if (ptInRect(s.buttonRects[1], s.clickX, s.clickY)) {
        s.globePending = 1;
        playOnce(g, s.button2);
        playOwnWave(g, s.button2);
    }
    if (ptInRect(s.buttonRects[2], s.clickX, s.clickY)) {
        g.setTimer(0x15, 5000);
        playOnce(g, s.button3);
        // 1020:d5d8 (BUGS.md B2 family: resolved by wave_open's fallback)
        playBundled(g, "maeemae.wav");
    }
    return 0;
}

fn sceneStarted(g: *Game, s: *State) i16 {
    s.buttonRotation = ini.randomBelow(&g.rand, g.plat, 3);
    tick.play(g, must(must(s.lights).as(.animation)), bdOf(g));
    const t = &s.buttonRectTable;
    // Table entries for rectangles 0, 1, 2 (rotation 2 is 2, 1, 0 in the EXE).
    const idx: [3]usize = switch (s.buttonRotation) {
        0 => .{ 0, 1, 2 },
        1 => .{ 1, 2, 0 },
        2 => .{ 2, 1, 0 },
        else => return 0,
    };
    for (idx, 0..) |i, k| s.buttonRects[k] = t[i];
    return 0;
}

fn animationFinished(g: *Game, s: *State) i16 {
    if (s.booPending != 0) {
        playBundled(g, "vaias.wav");
        const lights = must(s.lights);
        animation.stopAndRedraw(g, lights, bdOf(g));
        const a = must(lights.as(.animation));
        g.setSystemTimer(@bitCast(a.anim.timerId), @bitCast(a.anim.timerPeriod));
        space3d.moveToAndDrop(g, lights, 0x280, 0x1e0, bdOf(g));
        s.booPending = 0;
        // PatBlt(BLACKNESS, 640x480) on the window.
        @memset(&g.plat.screen().pixels, 0);
    } else {
        if (s.globePending == 0) return 1;
        s.globePending = 0;
        playOnce(g, s.globe);
        playOwnWave(g, s.globe);
    }
    g.setTimer(0x14, 3000);
    return 0;
}
