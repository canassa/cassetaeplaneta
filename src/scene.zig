//! Port unit `scene` (module). the INI scene: lifetime, objects, exits, view forwarders, message dispatch to handlers and WM_SYSTIMER.
//!
//! The base class Scene and the INI scene class are flattened into
//! `world.Scene`; the scene is allocated by its creator (`g.gpa.create`)
//! and built with `iniSceneCtor`. The scene owns its backdrop (also from
//! `g.gpa`), its object list and its exit table: `dtor` deletes them.
//!
//! Slot 07 base (`create`, 1018:2834) is never reached: the INI scene
//! overrides it (`scene_loader.create`); it is ported for completeness.

const platform = @import("platform/platform.zig");
const ini = @import("ini.zig");
const cstr = @import("core/cstr.zig");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const Condition = world.Condition;
const msg_mod = @import("core/msg.zig");
const Msg = msg_mod.Msg;
const wm = msg_mod.wm;
const noite = msg_mod.noite;
const backdrop = @import("backdrop.zig");
const draw_list = @import("draw_list.zig");
const object_list = @import("object_list.zig");
const object_init = @import("object_init.zig");
const exit = @import("exit.zig");
const sound = @import("sound.zig");
const update_list = @import("update_list.zig");
const avi = @import("avi.zig");
const animation = @import("behaviour/animation.zig");
const movement = @import("behaviour/movement.zig");
const tick = @import("behaviour/tick.zig");
const game_input = @import("game_input.zig");

/// The scene's backdrop (the original dereferences it unchecked).
fn bdOf(scene: *Scene) *Backdrop {
    return scene.backdrop orelse @panic("scene: no backdrop");
}

// @orig 1018:697a scene_ctor
/// Constructor of the scene base class: copies the INI section name (19
/// chars max), stores the flags, starts an empty object list (capacity
/// 100) with no backdrop, exits or one-animation object. `sceneNumber` is
/// left alone (the loader sets it).
pub fn ctor(scene: *Scene, name: []const u8, has_player: i16, has_control_panel: i16, has_status_bar: i16, is_1animation: i16, is_click_exit: i16) *Scene {
    _ = object_list.ctor(&scene.objects, 100);
    var n: usize = 0;
    while (n < 19 and n < name.len and name[n] != 0) : (n += 1) scene.name[n] = name[n];
    @memset(scene.name[n..], 0); // strncpy pads with NULs; name[0x13] = 0
    scene.backdrop = null;
    scene.exitCount = 0;
    scene.hasPlayer = has_player;
    scene.hasStatusBar = has_status_bar;
    scene.hasControlPanel = has_control_panel;
    scene.is1Animation = is_1animation;
    scene.isClickExit = is_click_exit;
    scene.animation = null;
    scene.mayDropObject = 1;
    scene.handlerEnabled = 0;
    return scene;
}

// @orig 1018:6ad4 ini_scene_ctor
/// Constructor of the INI scene class (every game scene): the base
/// constructor (the vtable swap has no counterpart). `ini_file` is unused.
pub fn iniSceneCtor(scene: *Scene, ini_file: platform.File, name: []const u8, has_player: i16, has_control_panel: i16, has_status_bar: i16, is_1animation: i16, is_click_exit: i16) *Scene {
    _ = ini_file;
    return ctor(scene, name, has_player, has_control_panel, has_status_bar, is_1animation, is_click_exit);
}

// @orig 1018:2896 scene_dtor
/// Resets the game's sorted draw pool, deletes every object of the scene's
/// list (base scalar destructor) and the backdrop (allocated with
/// `g.gpa`; the pointer is cleared after the free). The Is_1Animation
/// scene's own Exit object (`animation`, not in the list) is never deleted
/// (BUGS.md B14): it is parked with `g.leakObject` unless the fix is on.
pub fn dtor(g: *Game, scene: *Scene) void {
    var cur = scene.objects.head;
    draw_list.reset(&g.drawList);
    while (cur) |o| {
        const next = o.next;
        object_init.sceneObjectScalarDtor(g, o, 1);
        cur = next;
    }
    scene.objects.head = null;
    scene.objects.count = 0;
    if (scene.backdrop) |bd| {
        _ = backdrop.scalarDtor(g, bd, 1);
        g.gpa.destroy(bd);
        scene.backdrop = null;
    }
    if (scene.animation) |a| {
        if (g.fixes.free_scene_animation) object_init.sceneObjectScalarDtor(g, a, 1) else g.leakObject(a);
        scene.animation = null;
    }
}

// @orig 1018:1954 scene_scalar_dtor
/// Deleting destructor: `dtor`, then frees the scene when `flags & 1`.
pub fn scalarDtor(g: *Game, scene: *Scene, flags: u16) *Scene {
    dtor(g, scene);
    if (flags & 1 != 0) g.gpa.destroy(scene);
    return scene;
}

// @orig 1018:2834 scene_create
/// Scene slot 07 of the base class (overridden by the INI scene, so never
/// called): builds the backdrop through slot 05 (`createScreen`), creates
/// its view, points it at the scene's object list and enables the handler.
pub fn create(g: *Game, scene: *Scene) *Scene {
    scene.backdrop = createScreen(g, scene);
    const bd = bdOf(scene);
    _ = backdrop.create(g, bd);
    bd.sceneList = &scene.objects;
    scene.handlerEnabled = 1;
    return scene;
}

// @orig 1018:6a1c scene_set_is_1animation
pub fn setIs1Animation(scene: *Scene) void {
    scene.is1Animation = 1;
}

// @orig 1018:6a34 scene_set_is_click_exit
pub fn setIsClickExit(scene: *Scene) void {
    scene.isClickExit = 1;
}

// @orig 1018:6a4c scene_clear_may_drop_object
pub fn clearMayDropObject(scene: *Scene) *Scene {
    scene.mayDropObject = 0;
    return scene;
}

/// Scene slot 01.
// @orig 1010:439a scene_get_has_player
pub fn getHasPlayer(g: *Game, scene: *Scene) bool {
    _ = g;
    return scene.hasPlayer != 0;
}

/// Scene slot 02.
// @orig 1010:43b0 scene_get_has_control_panel
pub fn getHasControlPanel(g: *Game, scene: *Scene) bool {
    _ = g;
    return scene.hasControlPanel != 0;
}

/// Scene slot 03.
// @orig 1010:43c6 scene_get_has_status_bar
pub fn getHasStatusBar(g: *Game, scene: *Scene) bool {
    _ = g;
    return scene.hasStatusBar != 0;
}

/// Scene slot 04: links the object into the scene's list and inserts its
/// Object3D part (null for a non-3D object) into the sorted draw pool.
// @orig 1018:292e scene_add_object
pub fn addObject(g: *Game, scene: *Scene, obj: *Object) void {
    _ = object_list.add(g, &scene.objects, obj);
    _ = draw_list.insert(g, bdOf(scene), obj.as(.object3d));
}

/// Scene slot 05: the INI scene does not override the base stub, which
/// only warns (caption: the scene name) and returns the scene's backdrop.
// @orig 1010:43dc scene_create_screen_default (absorbed)
pub fn createScreen(g: *Game, scene: *Scene) ?*Backdrop {
    ini.messageBoxPrintf(g.plat, &g.messageBuf, cstr.slice(&scene.name), "Faltou redefinir o m\xe9todo CreateScreen", 0);
    return scene.backdrop;
}

/// Scene slot 06 (INI scene): allocates and constructs the scene an exit
/// leads to from its target name (the alternative one when the exit's
/// alternative index is this index) and flags. Past the exit table it
/// falls back to the base method (warning box, returns `scene`). The
/// original tests `exitCount < exitIndex`, so index == exitCount reads an
/// unset exit (a NULL dereference there).
// @orig 1018:6b16 ini_scene_create_new_scene
pub fn createNewScene(g: *Game, scene: *Scene, exit_index: i16) ?*Scene {
    if (scene.exitCount < exit_index) return createNewSceneDefault(g, scene);
    const ex = scene.exits[@intCast(exit_index)] orelse @panic("scene.createNewScene: no exit");
    const new = g.gpa.create(Scene) catch return null;
    new.* = .{};
    const name = if (ex.exit.altExitIndex == exit_index) &ex.exit.altSceneName else &ex.exit.sceneName;
    return iniSceneCtor(new, g.iniFile, cstr.slice(name), ex.exit.hasPlayer, ex.exit.hasControlPanel, ex.exit.hasStatusBar, 0, 0);
}

/// The base Scene's CreateNewScene warning (its caption is the scene name);
/// `game.createExitScene` shows it too.
pub const create_new_scene_missing = "Faltou redefinir o m\xe9todo CreateNewScene";

// @orig 1010:441a scene_create_new_scene_default (absorbed)
fn createNewSceneDefault(g: *Game, scene: *Scene) *Scene {
    ini.messageBoxPrintf(g.plat, &g.messageBuf, cstr.slice(&scene.name), create_new_scene_missing, 0);
    return scene;
}

/// Scene slot 08: blits the backdrop's view to the window.
// @orig 1010:4454 scene_blit_to_dc
pub fn blitToDc(g: *Game, scene: *Scene) *Scene {
    backdrop.blitToDc(g, bdOf(scene));
    return scene;
}

/// Scene slot 09: blanks the backdrop's bitmap.
// @orig 1010:4480 scene_clear_view
pub fn clearView(g: *Game, scene: *Scene) *Scene {
    _ = g;
    backdrop.clear(bdOf(scene));
    return scene;
}

/// Scene slot 0A: copies the background picture into the backdrop's
/// bitmap. The original ignores the copy's result; `backdrop.drawBackground`
/// reports only `LimitExceeded`/`Fatal` (the original would have corrupted
/// memory or died), which this signature cannot carry, so they panic.
// @orig 1010:44a8 scene_draw_background
pub fn drawBackground(g: *Game, scene: *Scene) *Scene {
    backdrop.drawBackground(g, bdOf(scene)) catch |e| @panic(@errorName(e));
    return scene;
}

/// Appends `ex` to the exit table; returns its index (the unchecked
/// original overflows the 25-entry table into `exitCount`).
fn appendExit(scene: *Scene, ex: *Object) i16 {
    const idx = scene.exitCount;
    if (idx < 0 or idx >= world.max_exits) @panic("scene: exit table overflow");
    scene.exits[@intCast(idx)] = ex;
    scene.exitCount += 1;
    return idx;
}

/// Scene slot 0B: appends an exit whose target is already set; stores its
/// index in it.
// @orig 1018:2a44 scene_add_exit
pub fn addExit(g: *Game, scene: *Scene, ex: *Object) i16 {
    _ = g;
    _ = exit.setExitIndex(ex, scene.exitCount);
    return appendExit(scene, ex);
}

/// Scene slot 0C: sets the exit's target scene, player position and
/// condition, then appends it.
// @orig 1018:29e6 scene_add_exit_to_scene
pub fn addExitToScene(g: *Game, scene: *Scene, ex: *Object, scene_name: []const u8, player_x: i16, player_y: i16, condition: ?*Condition) i16 {
    _ = g;
    _ = exit.setLinkToScene(ex, scene_name, player_x, player_y, condition, scene.exitCount);
    return appendExit(scene, ex);
}

/// Scene slot 0D: sets the exit's player position and condition, then
/// appends it.
// @orig 1018:298c scene_add_exit_at
pub fn addExitAt(g: *Game, scene: *Scene, ex: *Object, player_x: i16, player_y: i16, condition: ?*Condition) i16 {
    _ = g;
    _ = exit.setLink(ex, player_x, player_y, condition, scene.exitCount);
    return appendExit(scene, ex);
}

/// Scene slot 0E: sets the exit's alternative target (its alternative
/// index is the new index), then appends it.
// @orig 1018:2a8c scene_add_exit_alt
pub fn addExitAlt(g: *Game, scene: *Scene, ex: *Object, alt_scene_name: []const u8, alt_x: i16, alt_y: i16) i16 {
    _ = g;
    _ = exit.setAltLink(ex, alt_scene_name, alt_x, alt_y, scene.exitCount);
    return appendExit(scene, ex);
}

/// Scene slot 0F: the exit at `index`, null when `index >= exitCount`
/// (signed compare, so a negative index reads before the table).
// @orig 1010:44d0 scene_get_exit
pub fn getExit(g: *Game, scene: *Scene, index: i16) ?*Object {
    _ = g;
    if (scene.exitCount <= index) return null;
    return scene.exits[@intCast(index)];
}

/// Click on a scene whose `isClickExit` is set: finishes through the
/// one-animation exit.
fn clickExit(g: *Game, scene: *Scene) i16 {
    if (scene.isClickExit == 0) return 0;
    g.exitPending = 1;
    const anim = scene.animation orelse @panic("scene: no animation");
    _ = g.post(Msg.make(noite.exit_finished, @bitCast(anim.exit.exitIndex), 0, 0));
    return 1;
}

/// Scene slot 00 (INI scene): window-message handler. Swallows input while
/// it is locked, offers the message to the scene's registered handler
/// (always for 0x406, otherwise once the scene is enabled), then does the
/// default handling of object clicks, object timers (WM_SYSTIMER), MCI
/// notifications and 0x401. Non-zero = handled.
// @orig 1018:915e ini_scene_handle_message
pub fn handleMessage(g: *Game, scene: *Scene, m: Msg) i16 {
    if (g.inputLocked != 0) {
        switch (m.id) {
            wm.keydown, wm.keyup, wm.rbuttondown, wm.rbuttonup, wm.lbuttondown, wm.lbuttonup => return 1,
            noite.unlock_input => {
                g.inputLocked = 0;
                return 1;
            },
            else => {},
        }
    }
    if (scene.handlerEnabled != 0 or m.id == noite.object_created) {
        if (g.handlers[@intCast(scene.sceneNumber)]) |h| {
            if (h(g, m) != 0) return 1;
        }
    }
    g.unk097C = null;
    switch (m.id) {
        wm.rbuttondown => {
            const bd = bdOf((g.scene orelse @panic("scene: no current scene")));
            const x: i16 = @as(i16, @bitCast(m.lo())) +% bd.originX;
            const y: i16 = @as(i16, @bitCast(m.hi())) +% bd.originY;
            const q = backdrop.queryRect(g, bd, x, y, 16, 16);
            g.hitObject = q.obj;
            if (q.result > 0) {
                if (g.hitObject) |hit| {
                    if (animation.isAvi(g, hit)) _ = g.plat.mciString("stop musica");
                    // B28: the wave plays before the game tests the
                    // exit's reach; with the fix an exit the click will
                    // not take stays silent.
                    const silent = g.fixes.exit_sound_needs_reach and hit.is(.exit) and !game_input.exitTakesClick(g, hit);
                    if (!hit.is(.portable) and !silent) _ = sound.play(g, msg_mod.main_window, hit.wave);
                }
            }
            return clickExit(g, scene);
        },
        wm.lbuttondown => return clickExit(g, scene),
        wm.systimer => return systimer(g, scene, m),
        wm.mm_mcinotify => return mciNotify(g, scene, m),
        wm.mm_wom_done => return 1,
        noite.scene_started => return sceneStarted(g, scene),
        else => return 0,
    }
}

/// WM_SYSTIMER: the one-animation's timer, or the movement/animation
/// timers (ids 5-10) of every object of the scene list, then the global
/// objects.
fn systimer(g: *Game, scene: *Scene, m: Msg) i16 {
    if (scene.handlerEnabled == 0) return 1;
    if (scene.is1Animation != 0) {
        const anim = scene.animation orelse @panic("scene: no animation");
        // B21: `g_iniIsAVI` is cleared when any video closes, so a stale
        // timer with the id of a video exit ticks (and takes) the exit.
        const video = g.fixes.avi_exit_ignores_timer and animation.isAvi(g, anim);
        if (@as(u16, @bitCast(animation.getTimerId(g, anim))) == m.wparam and g.ini.rec.isAvi == 0 and !video) {
            sound.pump(&g.sound);
            tick.tick(g, anim, bdOf(scene));
            return 0;
        }
    }
    if (m.wparam < 5 or m.wparam > 10) return 0;
    const bd = bdOf(scene);
    var passes: u16 = 0;
    if (bd.sceneList) |list| {
        g.unk097C = list.head;
        passes = 1;
    } else {
        g.unk097C = g.globalObjects.head;
    }
    while (true) {
        if (g.unk097C != null) {
            while (true) {
                const cur = g.unk097C.?;
                if (animation.isRunning(g, cur)) {
                    const cur_bd = bdOf(g.scene orelse @panic("scene: no current scene"));
                    tick.tick(g, cur, cur_bd);
                    sound.pump(&g.sound);
                    if (!update_list.isEmpty(&g.updateList)) {
                        // GetDC / ReleaseDC: the screen is the platform's
                        update_list.flush(&g.updateList, g.plat, bdOf(g.scene.?));
                    }
                } else if (movement.isMoving(g, cur)) {
                    movement.moveTick(g, cur, bd);
                }
                const here = g.unk097C orelse break;
                g.unk097C = here.next;
                if (g.unk097C == null) break;
            }
        }
        g.unk097C = g.globalObjects.head;
        const more = passes != 0;
        passes -%= 1;
        if (!more) break;
    }
    return 0;
}

/// MM_MCINOTIFY: the playing AVI finished (successful or aborted).
fn mciNotify(g: *Game, scene: *Scene, m: Msg) i16 {
    const playing = g.aviPlaying orelse return 0;
    if (playing.anim.aviDevice != m.lo()) return 1;
    if (m.wparam != 1 and m.wparam != 8) return 1;
    avi.closeAvi(g, playing, playing.anim.aviDevice);
    g.aviPlaying = null;
    g.inputLocked = 1;
    _ = g.post(Msg.make(noite.unlock_input, 0, 0, 0));
    _ = sound.mixInit(g);
    if (scene.isClickExit != 0) return 1;
    const anim = scene.animation orelse @panic("scene: no animation");
    if (exit.hasKeyObject(g, anim, true, null)) {
        _ = g.post(Msg.make(noite.exit_finished, @bitCast(anim.exit.exitIndex), 0, 0));
        return 1;
    }
    const alt = anim.exit.altExitIndex;
    if (alt == -1) return 1;
    _ = g.post(Msg.make(noite.exit_finished, @bitCast(alt), 0, 0));
    return 1;
}

/// 0x401 (scene started): starts the engine tick and the music, and for a
/// one-animation scene its animation (or its wave).
fn sceneStarted(g: *Game, scene: *Scene) i16 {
    g.setSystemTimer(1, 50);
    if (g.skipMusicReplay == 0) {
        _ = g.plat.mciString("play musica notify");
    } else {
        g.skipMusicReplay = 0;
    }
    if (scene.is1Animation == 0) return 1;
    const anim = scene.animation orelse @panic("scene: no animation");
    if (animation.isAvi(g, anim)) {
        _ = g.plat.mciString("pause musica");
        sound.stopAll(&g.sound, g.plat);
        sound.freeAll(&g.sound, g.plat);
        sound.pump(&g.sound);
        sound.mixClose(&g.sound, g.plat);
    } else {
        _ = sound.play(g, msg_mod.main_window, anim.wave);
    }
    tick.play(g, anim, bdOf(scene));
    g.exitPending = if (scene.isClickExit == 0) 1 else 0;
    return 1;
}
