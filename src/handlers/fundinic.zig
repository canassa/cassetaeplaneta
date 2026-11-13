//! Port unit `handler_fundinic` (handler). scene handler 1018:c688.
//!
//! Title menu. The quit, configuration and play hotspots open their panels
//! and highlight the pressed option (button down); on release quit-now goes
//! to the credits, configuration shows a joke error picture, new game loads
//! slot 0 and load game opens the slot screen. Also re-cuts the gift item's
//! strip like the opening scene.

const Game = @import("../core/game.zig").Game;
const Object = @import("../core/object.zig").Object;
const msgs = @import("../core/msg.zig");
const Msg = msgs.Msg;
const backdrop = @import("../backdrop.zig");
const frames = @import("../frames.zig");
const update_list = @import("../update_list.zig");
const visibility = @import("../behaviour/visibility.zig");
const game_scenes = @import("../game_scenes.zig");
const save = @import("../save.zig");

pub const State = struct {
    // @orig g_fundinicHitObject
    hitObject: ?*Object = null,
    // @orig g_fundinicQuitPanel
    quitPanel: ?*Object = null,
    // @orig g_fundinicPlayPanel
    playPanel: ?*Object = null,
    // @orig g_fundinicConfigPanel
    configPanel: ?*Object = null,
    // @orig g_fundinicQuitNowLit
    quitNowLit: ?*Object = null,
    // @orig g_fundinicQuitLaterLit
    quitLaterLit: ?*Object = null,
    // @orig g_fundinicNewGameLit
    newGameLit: ?*Object = null,
    // @orig g_fundinicLoadGameLit
    loadGameLit: ?*Object = null,
    // @orig g_fundinicConfigText
    configText: ?*Object = null,
    // @orig g_fundinicMotherError
    motherError: ?*Object = null,
    // @orig g_fundinicQuitNowHotspot
    quitNowHotspot: ?*Object = null,
    // @orig g_fundinicQuitLaterHotspot
    quitLaterHotspot: ?*Object = null,
    // @orig g_fundinicNewGameHotspot
    newGameHotspot: ?*Object = null,
    // @orig g_fundinicLoadGameHotspot
    loadGameHotspot: ?*Object = null,
    // @orig g_fundinicConfigHotspotA
    configHotspotA: ?*Object = null,
    // @orig g_fundinicConfigHotspotB
    configHotspotB: ?*Object = null,
    // @orig g_fundinicConfigHotspot
    configHotspot: ?*Object = null,
    // @orig g_fundinicPlayHotspot
    playHotspot: ?*Object = null,
    // @orig g_fundinicQuitHotspot
    quitHotspot: ?*Object = null,
};

// The original dereferences every one of these globals unchecked.
fn get(o: ?*Object) *Object {
    return o.?;
}

/// GetDC/ReleaseDC dropped (one window, no hdc).
fn hideWithDc(g: *Game, obj: *Object) void {
    frames.resetRects(obj);
    visibility.hideAndInvalidate(g, obj, 0, g.scene.?.backdrop.?);
}

fn showObj(g: *Game, obj: *Object) void {
    visibility.show(g, obj, g.scene.?.backdrop.?);
}

/// show + invalidate.
fn showInvalidate(g: *Game, obj: *Object) void {
    showObj(g, obj);
    _ = visibility.invalidate(g, obj);
}

fn showMenuHotspots(g: *Game, s: *State) void {
    showObj(g, get(s.quitNowHotspot));
    showObj(g, get(s.quitLaterHotspot));
    showObj(g, get(s.quitHotspot));
    showObj(g, get(s.configHotspotA));
    showObj(g, get(s.configHotspot));
    showObj(g, get(s.newGameHotspot));
    showObj(g, get(s.loadGameHotspot));
    showObj(g, get(s.configHotspotB));
    showObj(g, get(s.playHotspot));
}

// @orig 1018:c688 handler_fundinic
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msgs.wm.lbuttondown, msgs.wm.rbuttondown => return buttonDown(g, s, m),
        msgs.wm.lbuttonup, msgs.wm.rbuttonup => return buttonUp(g, s, m),
        msgs.noite.scene_started => {
            showMenuHotspots(g, s);
            return 0;
        },
        msgs.noite.object_created => return objectCreated(g, s, m),
        else => return 0,
    }
}

fn pick(g: *Game, s: *State, m: Msg) ?*Object {
    const bd = g.scene.?.backdrop.?;
    const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 16, 16);
    s.hitObject = q.obj;
    if (q.result <= 0) return null;
    return s.hitObject;
}

fn objectCreated(g: *Game, s: *State, m: Msg) i16 {
    const obj = g.newObject;
    switch (m.wparam) {
        0x6b => {
            s.hitObject = obj;
            const o = get(obj);
            frames.frameInit(&o.frames[0], frames.dib(o), 4, 0x5c, 0x74, 0, 0, 0, 0);
            _ = frames.setCurFrame(o, 0);
        },
        0x133 => s.quitNowHotspot = obj,
        0x134 => s.quitLaterHotspot = obj,
        0x135 => s.configHotspotA = obj,
        0x136 => s.configHotspotB = obj,
        0x137 => s.quitHotspot = obj,
        0x138 => s.configHotspot = obj,
        0x139 => s.playHotspot = obj,
        0x13a => s.newGameHotspot = obj,
        0x13b => s.loadGameHotspot = obj,
        // Panels and highlights: hidden as soon as they are created.
        0x12e, 0x12b, 0x12c, 0x12d, 0x12f, 0x130, 0x131, 0x132, 0x13e => {
            const slot: *?*Object = switch (m.wparam) {
                0x12e => &s.configPanel,
                0x12b => &s.quitPanel,
                0x12c => &s.quitNowLit,
                0x12d => &s.quitLaterLit,
                0x12f => &s.configText,
                0x130 => &s.playPanel,
                0x131 => &s.newGameLit,
                0x132 => &s.loadGameLit,
                else => &s.motherError,
            };
            slot.* = obj;
            hideWithDc(g, get(obj));
        },
        else => {},
    }
    return 0;
}

fn buttonDown(g: *Game, s: *State, m: Msg) i16 {
    const hit = pick(g, s, m) orelse return 0;
    switch (hit.id) {
        0x133 => {
            if (get(s.quitPanel).visible == 0) return 0;
            if (get(s.quitLaterLit).visible != 0) hideWithDc(g, get(s.quitLaterLit));
            showInvalidate(g, get(s.quitNowLit));
            return 1;
        },
        0x134 => {
            if (get(s.quitPanel).visible == 0) return 0;
            if (get(s.quitNowLit).visible != 0) hideWithDc(g, get(s.quitNowLit));
            showInvalidate(g, get(s.quitLaterLit));
            return 1;
        },
        0x135 => {
            if (get(s.configPanel).visible == 0) return 0;
            showObj(g, get(s.configHotspotB));
            return 1;
        },
        0x136 => {
            if (get(s.configPanel).visible == 0) return 0;
            showObj(g, get(s.configHotspotA));
            return 1;
        },
        0x137 => {
            showInvalidate(g, get(s.quitPanel));
            showObj(g, get(s.quitNowHotspot));
            showObj(g, get(s.quitLaterHotspot));
            return 1;
        },
        0x138 => {
            if (get(s.motherError).visible != 0) return 1;
            showInvalidate(g, get(s.configPanel));
            showObj(g, get(s.configHotspotA));
            showObj(g, get(s.configHotspotB));
            return 1;
        },
        0x139 => {
            showInvalidate(g, get(s.playPanel));
            showObj(g, get(s.newGameHotspot));
            showObj(g, get(s.loadGameHotspot));
            return 1;
        },
        0x13a => {
            if (get(s.playPanel).visible == 0) return 0;
            if (get(s.loadGameLit).visible != 0) hideWithDc(g, get(s.loadGameLit));
            showInvalidate(g, get(s.newGameLit));
            showObj(g, get(s.loadGameHotspot));
            return 1;
        },
        0x13b => {
            if (get(s.playPanel).visible == 0) return 0;
            if (get(s.newGameLit).visible != 0) hideWithDc(g, get(s.newGameLit));
            showInvalidate(g, get(s.loadGameLit));
            showObj(g, get(s.newGameHotspot));
            return 1;
        },
        0x13e => {
            if (get(s.motherError).visible == 0) return 0;
            hideWithDc(g, get(s.motherError));
            showMenuHotspots(g, s);
            return 1;
        },
        else => return 0,
    }
}

fn buttonUp(g: *Game, s: *State, m: Msg) i16 {
    const hit = pick(g, s, m) orelse return 0;
    switch (hit.id) {
        0x12c, 0x133 => {
            if (get(s.quitPanel).visible == 0) return 0;
            update_list.discard(&g.updateList);
            _ = game_scenes.switchScene(g, "creditos", 0, 0, 0, 0, 0, 0, 0);
            return 1;
        },
        0x12d, 0x134 => {
            if (get(s.quitPanel).visible == 0) return 0;
            hideWithDc(g, get(s.quitPanel));
            hideWithDc(g, get(s.quitLaterLit));
            showObj(g, get(s.quitHotspot));
            return 1;
        },
        0x12f, 0x135, 0x136 => {
            if (get(s.motherError).visible != 0) return 0;
            hideWithDc(g, get(s.configPanel));
            hideWithDc(g, get(s.configText));
            frames.resetRects(get(s.motherError));
            showObj(g, get(s.motherError));
            _ = visibility.invalidate(g, get(s.motherError));
            return 1;
        },
        0x131, 0x13a => {
            if (get(s.playPanel).visible == 0) return 0;
            update_list.discard(&g.updateList);
            _ = save.loadGame(g, "jogo0");
            return 1;
        },
        0x132, 0x13b => {
            if (get(s.playPanel).visible == 0) return 0;
            g.slotScreenSaves = 0;
            update_list.discard(&g.updateList);
            _ = game_scenes.switchScene(g, "salvar2", 0, 0, 0, 0, 0, 0, 0);
            return 1;
        },
        else => return 0,
    }
}
