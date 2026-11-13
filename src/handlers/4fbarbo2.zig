//! Port unit `handler_4fbarbo2` (handler). scene handler 1020:c632.
//!
//! The bar seen from the drunk's side. Right-clicking the drunk's pocket
//! (object 0xdc) starts a chain driven by WM_MM_WOM_DONE: the drunk speaks,
//! the front barman answers ("bumbeb.wav"), the barman behind the bar
//! speaks his INI wave, the front barman says "vaifundo.wav" and the scene
//! switches to 4FBOYDJ. `busy` starts at 1 in the EXE's data, so the chain
//! only starts after the first wave end (the scene-start wave of the front
//! barman, message 0x401, which runs the `busy = 0` tail).

const Game = @import("../core/game.zig").Game;
const Object = @import("../core/object.zig").Object;
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const cstr = @import("../core/cstr.zig");
const backdrop = @import("../backdrop.zig");
const frames = @import("../frames.zig");
const game_scenes = @import("../game_scenes.zig");
const sound = @import("../sound.zig");
const update_list = @import("../update_list.zig");
const animation = @import("../behaviour/animation.zig");
const render = @import("../behaviour/render.zig");
const tick = @import("../behaviour/tick.zig");

const wm = msg.wm;
const noite = msg.noite;

pub const State = struct {
    // @orig g_s4fbarbo2DrunkSpeaking
    drunkSpeaking: i16 = 0,
    // @orig g_s4fbarbo2BumbebSpeaking
    bumbebSpeaking: i16 = 0,
    // @orig g_s4fbarbo2Busy (initial value 1 in the EXE's data)
    busy: i16 = 1,
    // @orig g_s4fbarbo2BarmanDone
    barmanDone: i16 = 0,
    // @orig g_s4fbarbo2BarmanSpeaking
    barmanSpeaking: i16 = 0,
    // @orig g_s4fbarbo2GoAheadSpeaking
    goAheadSpeaking: i16 = 0,
    // @orig g_s4fbarbo2HitObject
    hitObject: ?*Object = null,
    // @orig g_s4fbarbo2Esoteric (INI Number 0xdd)
    esoteric: ?*Object = null,
    // @orig g_s4fbarbo2Pocket (0xdc; never read)
    pocket: ?*Object = null,
    // @orig g_s4fbarbo2Barman (0xda)
    barman: ?*Object = null,
    // @orig g_s4fbarbo2BarmanFront (0xe6)
    barmanFront: ?*Object = null,
    // @orig g_s4fbarbo2DrunkSpot (0xdb; never read)
    drunkSpot: ?*Object = null,
    // @orig g_s4fbarbo2Drunk (0xde)
    drunk: ?*Object = null,
};

const BARMAN_ID: u16 = 0xda;
const DRUNK_SPOT_ID: u16 = 0xdb;
const POCKET_ID: u16 = 0xdc;
const ESOTERIC_ID: u16 = 0xdd;
const DRUNK_ID: u16 = 0xde;
const BARMAN_FRONT_ID: u16 = 0xe6;

/// Plays `<CD>` + `name` (a wave in the CD root; `sound.open` falls back to
/// `pan\wav`).
fn playCdWave(g: *Game, name: []const u8) void {
    var buf: [256]u8 = undefined;
    // 1018:b784 "%s%s"
    const path = cstr.print(&buf, "{s}{s}", .{ cstr.slice(&g.driveCD), name });
    const wave = sound.open(g, path) catch null;
    _ = sound.play(g, msg.main_window, wave);
}

/// Redraws the esoteric object and the control panel into the backdrop.
fn redrawEsotericAndPanel(g: *Game, s: *State) void {
    const esoteric = s.esoteric.?;
    frames.resetRects(esoteric);
    render.draw(g, esoteric, g.scene.?.backdrop.?);
    render.draw(g, g.controlPanel.?, g.scene.?.backdrop.?);
}

/// Re-arms the object's animation timer (stop-and-redraw leaves it killed).
fn restartTimer(g: *Game, obj: *Object) void {
    g.setSystemTimer(@bitCast(obj.anim.timerId), @bitCast(obj.anim.timerPeriod));
}

// @orig 1020:c632 handler_4fbarbo2
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        wm.mousemove => return if (m.hi() < 0x169) 0 else 1,
        wm.rbuttondown => {
            const bd = g.scene.?.backdrop.?;
            const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 0x10, 0x10);
            s.hitObject = q.obj;
            if (q.result < 1) return 0;
            const hit = s.hitObject orelse return 0;
            switch (@as(u16, @bitCast(hit.id))) {
                BARMAN_ID, DRUNK_SPOT_ID, ESOTERIC_ID, DRUNK_ID, BARMAN_FRONT_ID => return 1,
                POCKET_ID => {
                    if (s.drunkSpeaking != 0) return 1;
                    if (s.busy != 0) return 1;
                    s.drunkSpeaking = 1;
                    const drunk = s.drunk.?;
                    animation.playOnce(g, drunk, g.scene.?.backdrop.?);
                    _ = sound.play(g, msg.main_window, drunk.wave);
                    return 1;
                },
                else => return 0,
            }
        },
        wm.mm_wom_done => return womDone(g, s),
        noite.scene_started => {
            const front = s.barmanFront.?;
            tick.play(g, front, g.scene.?.backdrop.?);
            _ = sound.play(g, msg.main_window, front.wave);
            redrawEsotericAndPanel(g, s);
            return 0;
        },
        noite.object_created => {
            switch (m.wparam) {
                BARMAN_ID => {
                    s.barman = g.newObject;
                    s.barman.?.playOnceRewinds = 0;
                },
                DRUNK_SPOT_ID => s.drunkSpot = g.newObject,
                POCKET_ID => s.pocket = g.newObject,
                ESOTERIC_ID => s.esoteric = g.newObject,
                DRUNK_ID => {
                    s.drunk = g.newObject;
                    s.drunk.?.playOnceRewinds = 0;
                },
                BARMAN_FRONT_ID => s.barmanFront = g.newObject,
                else => {},
            }
            return 0;
        },
        else => return 0,
    }
}

/// One wave of the chain ended; the flags say which one it was.
fn womDone(g: *Game, s: *State) i16 {
    const front = s.barmanFront.?;
    if (s.drunkSpeaking != 0 and s.busy == 0) {
        // The drunk is done: the front barman answers.
        s.drunkSpeaking = 0;
        s.busy = 1;
        tick.play(g, front, g.scene.?.backdrop.?);
        playCdWave(g, "bumbeb.wav");
        s.bumbebSpeaking = 1;
        return 0;
    }
    if (s.bumbebSpeaking != 0 and s.barmanDone == 0) {
        // The front barman is done: the barman behind the bar speaks.
        s.bumbebSpeaking = 0;
        s.barmanDone = 1;
        animation.stopAndRedraw(g, front, g.scene.?.backdrop.?);
        restartTimer(g, front);
        const barman = s.barman.?;
        animation.playOnce(g, barman, g.scene.?.backdrop.?);
        _ = sound.play(g, msg.main_window, barman.wave);
        s.barmanSpeaking = 1;
        return 0;
    }
    if (s.barmanSpeaking != 0) {
        // The barman is done: back to his first frame, the front barman
        // says "go ahead" (vaifundo).
        s.barmanSpeaking = 0;
        const barman = s.barman.?;
        animation.stopAndRedraw(g, barman, g.scene.?.backdrop.?);
        restartTimer(g, barman);
        _ = frames.setCurFrame(barman, 0);
        frames.resetRects(barman);
        render.draw(g, barman, g.scene.?.backdrop.?);
        redrawEsotericAndPanel(g, s);
        backdrop.blitToDc(g, g.scene.?.backdrop.?);
        update_list.discard(&g.updateList);
        tick.play(g, front, g.scene.?.backdrop.?);
        playCdWave(g, "vaifundo.wav");
        s.goAheadSpeaking = 1;
        return 0;
    }
    if (s.goAheadSpeaking != 0) {
        // "Go ahead" ended: on to the DJ's room.
        animation.stopAndRedraw(g, front, g.scene.?.backdrop.?);
        s.busy = 1;
        s.drunkSpeaking = 0;
        s.bumbebSpeaking = 0;
        s.barmanDone = 0;
        s.barmanSpeaking = 0;
        s.goAheadSpeaking = 0;
        update_list.discard(&g.updateList);
        // x, y, player 0, control panel 1, status bar 0, is1animation 0, click-exit 0.
        _ = game_scenes.switchScene(g, "4FBOYDJ", 0, 0, 0, 1, 0, 0, 0);
        return 0;
    }
    // The scene-start wave ended: the pocket can be clicked now.
    animation.stopAndRedraw(g, front, g.scene.?.backdrop.?);
    s.busy = 0;
    redrawEsotericAndPanel(g, s);
    backdrop.blitToDc(g, g.scene.?.backdrop.?);
    update_list.discard(&g.updateList);
    return 0;
}
