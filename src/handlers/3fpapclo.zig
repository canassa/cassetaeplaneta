//! Port unit `handler_3fpapclo` (handler). scene handler 1020:8db8.
//!
//! The pope's closet. The player opens drawers (each its own scene) and
//! brings back three items picked with the right button
//! (`Game.pickedItems[3]`, `pickActive/pickArmed/pickRetry/pickAdded`, set
//! by the right-click hook in `game_hook`). Back in the closet the scene
//! start (0x401) lays the items out as icons; once three are placed the pope
//! judges how many are right (portable ids 0xac, 0xb4, 0xb9) with a verdict
//! wave. Three right: the pope's Sporl reacts and the player goes on to
//! `4finifes`. Otherwise the items go back to their drawers; the second
//! failure sends the player to `3fpapmal`.
//!
//! Timers: 0x14 (60 s after the intro) -> 0x15 (18 s) plays "papatime.wav"
//! (a bare file name in the CD root, as in the original) and the pope's
//! animation; 0x16 (35 s, armed after the first failure) sends 0x3bd, which
//! only acts while a verdict wave is pending, so there is no real time limit
//! (BUGS.md B6).
//!
//! `pickedCount` is only reset when a verdict is resolved (the three
//! resolution paths below), never bounded: the original `pickedItems[count]`
//! in the right-click hook would run past the three slots if a fourth item
//! were picked before the scene changes. Here the loops over the slots stop
//! at three.

const Game = @import("../core/game.zig").Game;
const Object = @import("../core/object.zig").Object;
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const backdrop = @import("../backdrop.zig");
const cstr = @import("../core/cstr.zig");
const game_scenes = @import("../game_scenes.zig");
const platform = @import("../platform/platform.zig");
const portable = @import("../portable.zig");
const sound = @import("../sound.zig");
const update_list = @import("../update_list.zig");
const animation = @import("../behaviour/animation.zig");
const render = @import("../behaviour/render.zig");
const space3d = @import("../behaviour/space3d.zig");
const tick = @import("../behaviour/tick.zig");
const visibility = @import("../behaviour/visibility.zig");

pub const State = struct {
    // @orig g_s3fpapcloSolved
    solved: i16 = 0,
    // @orig g_s3fpapcloIntro
    intro: i16 = 0,
    // @orig g_s3fpapcloAwaitingWave
    awaitingWave: i16 = 0,
    // @orig g_s3fpapcloHitObject
    hitObject: ?*Object = null,
    // @orig g_s3fpapcloPope
    pope: ?*Object = null,
    // @orig g_s3fpapcloSporl
    sporl: ?*Object = null,
    // @orig g_s3fpapcloItem
    item: ?*Object = null,
    // @orig g_s3fpapcloResultWave
    resultWave: ?platform.Wave = null,
};

fn obj(o: ?*Object) *Object {
    return o.?;
}

fn bdOf(g: *Game) *@import("../core/world.zig").Backdrop {
    return g.scene.?.backdrop.?;
}

/// Plays the pope's animation (`asAnimation`, slot 0xc0).
fn popePlay(g: *Game, s: *State) void {
    tick.play(g, obj(s.pope), bdOf(g));
}

/// Opens and plays a verdict wave under `fase3\3fpapclo\`.
fn playResult(g: *Game, s: *State, file: []const u8) void {
    var buf: [260]u8 = undefined;
    const path = cstr.print(&buf, "{s}{s}", .{ cstr.slice(&g.driveCD), file });
    s.resultWave = sound.open(g, path) catch null;
    _ = sound.play(g, msg.main_window, s.resultWave);
}

/// Sends every picked item back to the scene it came from (swapping its
/// scene names), moves it to its drawer position, and empties the slot.
fn returnItems(g: *Game, s: *State) void {
    const count: u8 = g.pickedCount;
    if (count == 0) return;
    var i: u8 = 0;
    while (true) {
        if (i < g.pickedItems.len) {
            const slot = &g.pickedItems[i];
            if (slot.object) |o| {
                const it = o.as(.portable).?;
                s.item = it;
                _ = portable.moveToScene(g, it, &it.portable.prevSceneName);
                space3d.moveToAndDrop(g, it, slot.x, slot.y, bdOf(g));
                slot.object = null;
                slot.placed = 0;
                slot.isRight = 0;
            }
        }
        i +%= 1;
        if (!(i < g.pickedCount)) break;
    }
}

/// How many of the three picked items are right.
fn rightCount(g: *Game) u8 {
    var n: u8 = 0;
    for (g.pickedItems) |p| {
        if (p.isRight != 0) n += 1;
    }
    return n;
}

// @orig 1020:8db8 handler_3fpapclo
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.rbuttondown => return rightButton(g, s, m),
        msg.wm.lbuttondown, msg.wm.lbuttonup, 0x203 => return if (m.id == msg.wm.lbuttondown) 1 else 0,
        msg.wm.timer => return timer(g, s, m.wparam),
        msg.wm.mm_wom_done => return waveDone(g, s),
        msg.noite.scene_started => return sceneStarted(g, s),
        msg.noite.object_created => {
            if (m.wparam == 0x91) s.pope = g.newObject;
            if (m.wparam == 0xa6) s.sporl = g.newObject;
            return 0;
        },
        else => return 0,
    }
}

fn timer(g: *Game, s: *State, id: u16) i16 {
    switch (id) {
        0x14 => {
            g.killTimer(0x14);
            g.setTimer(0x15, 18000);
        },
        0x15 => {
            g.killTimer(0x15);
            var buf: [260]u8 = undefined;
            // 1020:9db8 "papatime.wav": no folder, as in the original.
            const path = cstr.print(&buf, "{s}{s}", .{ cstr.slice(&g.driveCD), "papatime.wav" });
            const w = sound.open(g, path) catch null;
            _ = sound.play(g, msg.main_window, w);
            popePlay(g, s);
        },
        0x16 => {
            g.killTimer(0x16);
            _ = g.send(Msg.make(msg.wm.mm_wom_done, 0, 0, 0));
        },
        else => {},
    }
    return 0;
}

fn rightButton(g: *Game, s: *State, m: Msg) i16 {
    if (s.awaitingWave != 0) return 1;
    s.hitObject = null;
    const bd = bdOf(g);
    const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 0x10, 0x10);
    s.hitObject = q.obj;
    if (q.result < 1) return 0;
    const hit = s.hitObject orelse return 0;
    if (hit.id == 0x91) return 1;
    if (hit.is(.portable)) return 1;
    return if (hit.id == 0xa6) 1 else 0;
}

fn sceneStarted(g: *Game, s: *State) i16 {
    if (g.pickActive == 0) {
        if (s.intro == 0) return 0;
        popePlay(g, s);
        _ = sound.play(g, msg.main_window, obj(s.pope).wave);
        s.awaitingWave = 1;
        g.pickActive = 1;
        g.setTimer(0x14, 60000);
        return 0;
    }

    // Back from a drawer: lay out the picked items as icons.
    var allPlaced = false;
    var i: u8 = 0;
    while (i < 3) : (i += 1) {
        const slot = &g.pickedItems[i];
        const o = slot.object orelse continue;
        const it = o.as(.portable).?;
        s.item = it;
        if (@as(i16, g.pickedCount) -% @as(i16, i) == 1) {
            _ = portable.drop(g, it, g.scene.?);
            space3d.moveToAndDrop(g, it, 0x280, 0x1e0, bdOf(g));
            it.portable.iconW = 0x50;
            it.portable.iconH = 0x50;
            slot.placed = 1;
            g.pickAdded = 0;
        }
        portable.drawIcon(g, it, bdOf(g), 0x15e, @as(i16, i) *% 0x50 +% 0xb4) catch {};
        if (it.id == 0xac or it.id == 0xb4 or it.id == 0xb9) slot.isRight = 1;
        if (g.pickedItems[0].placed != 0 and g.pickedItems[1].placed != 0 and g.pickedItems[2].placed != 0) {
            allPlaced = true;
            break;
        }
    }
    if (!allPlaced) return 0;

    s.intro = 0;
    sound.pump(&g.sound);
    const right = rightCount(g);
    if (right == 3) {
        popePlay(g, s);
        animation.playOnce(g, obj(s.sporl), bdOf(g));
        playResult(g, s, "fase3\\3fpapclo\\papar02.wav");
        s.solved = 1;
        s.awaitingWave = 1;
        return 0;
    }
    popePlay(g, s);
    const file = if (g.pickRetry == 0) switch (right) {
        0 => "fase3\\3fpapclo\\papar05.wav",
        1 => "fase3\\3fpapclo\\papar03.wav",
        else => "fase3\\3fpapclo\\papar04.wav",
    } else switch (right) {
        0 => "fase3\\3fpapclo\\papar08.wav",
        1 => "fase3\\3fpapclo\\papar06.wav",
        else => "fase3\\3fpapclo\\papar07.wav",
    };
    playResult(g, s, file);
    s.awaitingWave = 1;
    return 0;
}

/// A wave ended (or timer 0x16 sent the message): the intro speech, then a
/// verdict wave.
fn waveDone(g: *Game, s: *State) i16 {
    if (s.awaitingWave == 0) return 1;
    s.awaitingWave = 0;
    if (s.intro != 0) {
        s.intro = 0;
        animation.stopAndRedraw(g, obj(s.pope), bdOf(g));
        return 0;
    }
    if (s.resultWave == null) {
        s.awaitingWave = 0;
        return 1;
    }
    s.resultWave = null;

    if (s.solved != 0) {
        s.solved = 0;
        g.killTimer(0x14);
        g.killTimer(0x15);
        g.killTimer(0x16);
        g.pickRetry = 0;
        returnItems(g, s);
        g.pickActive = 0;
        g.pickArmed = 0;
        g.pickedCount = 0;
        s.intro = 1;
        update_list.discard(&g.updateList);
        // 1020:9c1c "4finifes"; no player, panel, status bar, 1animation.
        _ = game_scenes.switchScene(g, "4finifes", 0, 0, 0, 0, 0, 0, 0);
        return 0;
    }

    if (g.pickRetry == 0) {
        // First failure: the always-true `&g.pickedItems != NULL` test.
        g.killTimer(0x14);
        g.killTimer(0x15);
        g.setTimer(0x16, 35000);
        g.pickRetry = 1;
        returnItems(g, s);
        backdrop.restoreBackground(g, bdOf(g)) catch {};
        backdrop.blitToDc(g, bdOf(g));
        render.draw(g, obj(s.sporl), bdOf(g));
        _ = visibility.invalidate(g, obj(s.sporl));
        g.pickedCount = 0;
        animation.stopAndRedraw(g, obj(s.pope), bdOf(g));
        return 1;
    }

    // Second failure: the pope's punishment (the dead `pickRetry == 0` test
    // of the original is dropped).
    g.killTimer(0x16);
    returnItems(g, s);
    g.pickActive = 0;
    g.pickRetry = 0;
    s.intro = 1;
    g.pickArmed = 0;
    g.pickedCount = 0;
    update_list.discard(&g.updateList);
    // 1020:9c12 "3fpapmal"; is1animation 1.
    _ = game_scenes.switchScene(g, "3fpapmal", 0, 0, 0, 0, 0, 1, 0);
    return 1;
}
