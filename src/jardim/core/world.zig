//! JARDIM's engine data other than objects: the scene (LabyrinthScene and
//! the three phase scenes, with the phase's virtual table), the backdrop
//! (Backdrop + LabyrinthBackdrop: the raycaster's state), the sprite
//! queue, the draw and update lists, the conditions, the trigonometric
//! tables. JARDIM's layouts (large model, docs/jardim/DATA.md); data only
//! (the functions are in the units named).

const std = @import("std");
const msg = @import("../../core/msg.zig");
const Msg = msg.Msg;
const object = @import("object.zig");
const Object = object.Object;
const ObjectList = object.ObjectList;
const Dib = object.Dib;
const BitmapInfoHeader = object.BitmapInfoHeader;
const RgbQuad = object.RgbQuad;
const Surface = @import("../../platform/platform.zig").Surface;
const Game = @import("game.zig").Game;

pub const max_exits = 10;
pub const max_draw_nodes = 100;
/// The update list holds 30 (struct `UpdateList`, 0x7a).
pub const max_update = 30;
/// The map: 57 columns × 80 rows (labyrinth_load_map; a wall row is 58
/// bytes, an object row 57 far pointers).
pub const map_cols = 57;
pub const map_rows = 80;
/// The sprite queue's node pool (struct `SpriteQueue`, 0x7d6).
pub const max_sprites = 100;
/// The view's columns (480 px of 4) and `g_columnDepth`'s length.
pub const view_columns = 120;
/// Angle units per turn (8 per degree).
pub const full_turn = 2880;

/// Which LabyrinthScene subclass a scene is (its vtable: 834c, 91aa, 92da).
pub const Phase = enum(u8) { one = 1, two = 2, three = 3 };

/// The LabyrinthSceneVtbl slots a phase overrides (docs/jardim/DESIGN.md
/// "Scenes"): one instance per phase unit (`phase1.vtbl` …), set by the
/// phase's ctor (unit `labyrinth_scene`); the base slots (SceneVtbl 01-04,
/// 08-0F) are unit `scene`'s plain functions. Call through `Scene`'s
/// wrappers below. Signatures: hwnd dropped, arguments in source order.
pub const SceneVtbl = struct {
    /// 00 handleMessage: the phase's handler (it tail-calls
    /// `labyrinth_scene.handleMessage`); the engine default runs on 0.
    handleMessage: *const fn (g: *Game, s: *Scene, m: Msg) u16,
    /// 05 createScreen: the LabyrinthBackdrop on opcaoN.bmp.
    createScreen: *const fn (g: *Game, s: *Scene) ?*Backdrop,
    /// 06 createNewScene (from the 0x402 exit index): the next phase.
    createNewScene: *const fn (g: *Game, s: *Scene, exit_index: i16) ?*Scene,
    /// 07 create: the level (map, objects, waves, music).
    create: *const fn (g: *Game, s: *Scene) *Scene,
    /// 10 hit: a shot stopped in (col, row) on `obj` (null: a wall).
    hit: *const fn (g: *Game, s: *Scene, obj: ?*Object, col: i16, row: i16) void,
    /// 11 touch: a step into a cell holding `obj`; non-zero undoes the step.
    touch: *const fn (g: *Game, s: *Scene, obj: *Object) i16,
    /// 12 placeObjects: every map copy of every object.
    placeObjects: *const fn (g: *Game, s: *Scene) *Scene,
    /// 13 playEnemyAttackSound.
    playEnemyAttackSound: *const fn (g: *Game, s: *Scene, obj: *Object) void,
    /// 14 playEnemyStepSound.
    playEnemyStepSound: *const fn (g: *Game, s: *Scene, obj: *Object) void,
    /// 15 playFireSound.
    playFireSound: *const fn (g: *Game, s: *Scene) void,
    /// 16 playDoorSound.
    playDoorSound: *const fn (g: *Game, s: *Scene) void,
    /// 17 onLifeLost (the base table's 17 is labyrinth_scene_respawn).
    onLifeLost: *const fn (g: *Game, s: *Scene) void,
};

/// The scene: Scene + LabyrinthScene + Phase1/2/3Scene flattened (one
/// struct; `phase` and `vtbl` say which). Base fields: TIRO's Scene with
/// far pointers (LabyrinthScene's `handlerEnabled` at +0x60 confirms the
/// sum); functions: units `scene`, `labyrinth_scene`, `phase1..3`.
pub const Scene = struct {
    phase: Phase = .one,
    vtbl: *const SceneVtbl,

    // ---- Scene ----
    // @orig LabyrinthScene+0x4 (the screen = `backdrop` below)
    screen: ?*Backdrop = null,
    // @orig Scene+0x8 (far pointers)
    exits: [max_exits]?*Object = @splat(null),
    // @orig Scene+0x30
    exitCount: i16 = 0,
    // @orig Scene+0x32
    name: [20]u8 = @splat(0),
    // @orig Scene+0x46
    objects: ObjectList = .{},
    // @orig Scene+0x4e
    hasPlayer: i16 = 0,
    // @orig Scene+0x50
    hasStatusBar: i16 = 0,
    // @orig Scene+0x52
    hasControlPanel: i16 = 0,
    // @orig Scene+0x54
    is1Animation: i16 = 0,
    // @orig Scene+0x56
    isClickExit: i16 = 0,
    // @orig Scene+0x58
    animation: ?*Object = null,
    // @orig Scene+0x5c
    mayDropObject: i16 = 0,
    // @orig Scene+0x5e
    sceneNumber: i16 = 0,

    // ---- LabyrinthScene ----
    // @orig LabyrinthScene+0x60
    handlerEnabled: i16 = 0,
    // @orig LabyrinthScene+0x62
    backdrop: ?*Backdrop = null,
    // @orig LabyrinthScene+0x66 ("raymapN.dat")
    mapFile: []const u8 = "",

    // ---- Phase1/2/3Scene: one Portable per object type ----
    // @orig Phase1Scene+0x6a
    crossbow: ?*Object = null,
    // @orig Phase1Scene+0x6e (phase 1 the bra, phases 2-3 the bazooka)
    secondWeapon: ?*Object = null,
    // @orig Phase1Scene+0x72 (Bussuf, Alemão, Chato: health -5)
    enemyA: ?*Object = null,
    // @orig Phase1Scene+0x76 (Seios, Siri, Bicho: a life)
    enemyB: ?*Object = null,
    // @orig Phase1Scene+0x7a
    medkit: ?*Object = null,
    // @orig Phase1Scene+0x7e
    beer: ?*Object = null,
    // @orig Phase1Scene+0x82 (phase 1 the açaí, phases 2-3 the shrimp)
    snack: ?*Object = null,
    // @orig Phase1Scene+0x86
    arrows: ?*Object = null,
    // @orig Phase2Scene+0x8a (phases 2-3)
    bombs: ?*Object = null,
    // @orig Phase1Scene+0x8a / Phase2Scene+0x8e (phases 1-2)
    exit: ?*Object = null,
    // @orig Phase1Scene+0x8e / Phase2Scene+0x92 (phases 1-2)
    exitIndex: i16 = 0,
    // @orig Phase3Scene+0x8e (espanf with variant 1, vamanf with 0)
    goal: ?*Object = null,

    pub fn handleMessage(s: *Scene, g: *Game, m: Msg) u16 {
        return s.vtbl.handleMessage(g, s, m);
    }
    pub fn createScreen(s: *Scene, g: *Game) ?*Backdrop {
        return s.vtbl.createScreen(g, s);
    }
    pub fn createNewScene(s: *Scene, g: *Game, exit_index: i16) ?*Scene {
        return s.vtbl.createNewScene(g, s, exit_index);
    }
    pub fn create(s: *Scene, g: *Game) *Scene {
        return s.vtbl.create(g, s);
    }
    pub fn hit(s: *Scene, g: *Game, obj: ?*Object, col: i16, row: i16) void {
        s.vtbl.hit(g, s, obj, col, row);
    }
    pub fn touch(s: *Scene, g: *Game, obj: *Object) i16 {
        return s.vtbl.touch(g, s, obj);
    }
    pub fn placeObjects(s: *Scene, g: *Game) *Scene {
        return s.vtbl.placeObjects(g, s);
    }
    pub fn playEnemyAttackSound(s: *Scene, g: *Game, obj: *Object) void {
        s.vtbl.playEnemyAttackSound(g, s, obj);
    }
    pub fn playEnemyStepSound(s: *Scene, g: *Game, obj: *Object) void {
        s.vtbl.playEnemyStepSound(g, s, obj);
    }
    pub fn playFireSound(s: *Scene, g: *Game) void {
        s.vtbl.playFireSound(g, s);
    }
    pub fn playDoorSound(s: *Scene, g: *Game) void {
        s.vtbl.playDoorSound(g, s);
    }
    pub fn onLifeLost(s: *Scene, g: *Game) void {
        s.vtbl.onLifeLost(g, s);
    }
};

/// The view: Backdrop + LabyrinthBackdrop flattened (only the
/// LabyrinthBackdrop is built, one per phase scene). Functions: units
/// `backdrop` (the Backdrop base and its defaults), `labyrinth` (slot 00
/// create, paint, a frame), `labyrinth_input` (slot 17 handleMessage),
/// `labmap`, `hud`, `raycast`, `sprites`.
///
/// Pixel contract: NOITE's (docs/DESIGN.md "Backdrop, pixels and
/// palette"), one top-down 640×480 WinG bitmap, `surface()`. No
/// counterpart: the DC (+0x4), `hpalette` (+0xa).
pub const Backdrop = struct {
    // ---- Backdrop (NOITE's layout, 0x452) ----
    // @orig LabyrinthBackdrop+0x6
    pixels: []u8 = &.{},
    // @orig LabyrinthBackdrop+0xe (opcaoN.bmp)
    background: ?*Dib = null,
    // @orig Backdrop+0x12
    bgWidth: i16 = 0,
    // @orig Backdrop+0x14
    bgHeight: i16 = 0,
    // @orig LabyrinthBackdrop+0x16
    originX: i16 = 0,
    // @orig LabyrinthBackdrop+0x18
    originY: i16 = 0,
    // @orig LabyrinthBackdrop+0x1a
    viewWidth: i16 = 0,
    // @orig LabyrinthBackdrop+0x1c
    viewHeight: i16 = 0,
    // @orig Backdrop+0x22
    bmiHeader: BitmapInfoHeader = .{},
    // @orig Backdrop+0x4a
    bmiColors: [256]RgbQuad = @splat(.{}),
    // @orig Backdrop+0x44a (1 bottom-up / -1 top-down)
    dibOrientation: i32 = 1,
    // @orig Backdrop+0x44e (&Scene.objects)
    sceneList: ?*ObjectList = null,

    // ---- LabyrinthBackdrop (0x73c) ----
    // @orig LabyrinthBackdrop+0x452 (1/32 cell)
    playerX: i32 = 0,
    // @orig LabyrinthBackdrop+0x456
    playerY: i32 = 0,
    // @orig LabyrinthBackdrop+0x45a (0-2879; 480 = 60° at the start)
    viewAngle: i32 = 0,
    // @orig LabyrinthBackdrop+0x45e (the respawn point)
    startX: i32 = 0,
    // @orig LabyrinthBackdrop+0x462
    startY: i32 = 0,
    // @orig LabyrinthBackdrop+0x466
    skyScrollX: i16 = 0,
    // @orig LabyrinthBackdrop+0x468
    floorScrollX: i16 = 0,
    // @orig LabyrinthBackdrop+0x46a
    floorScrollY: i16 = 0,
    // @orig LabyrinthBackdrop+0x46c
    velX: i32 = 0,
    // @orig LabyrinthBackdrop+0x470
    velY: i32 = 0,
    // @orig LabyrinthBackdrop+0x474
    viewX: i16 = 0,
    // @orig LabyrinthBackdrop+0x476
    viewY: i16 = 0,
    // @orig LabyrinthBackdrop+0x478
    viewW: i16 = 0,
    // @orig LabyrinthBackdrop+0x47a
    viewH: i16 = 0,
    // @orig LabyrinthBackdrop+0x47c
    viewRight: i16 = 0,
    // @orig LabyrinthBackdrop+0x47e
    viewBottom: i16 = 0,
    // @orig LabyrinthBackdrop+0x480
    viewHalfH: i16 = 0,
    // @orig LabyrinthBackdrop+0x482
    horizonY: i16 = 0,
    // @orig LabyrinthBackdrop+0x484 (the speed's fraction, always 0)
    moveRamp: i16 = 0,
    // @orig LabyrinthBackdrop+0x486 (units per step)
    moveSpeed: i16 = 0,
    // @orig LabyrinthBackdrop+0x488 (index into tables[5] at viewAngle)
    secAt: u16 = 0,
    // @orig LabyrinthBackdrop+0x48c (index into tables[6] at viewAngle)
    cscAt: u16 = 0,
    // @orig LabyrinthBackdrop+0x490 (58-byte rows: 0 floor, 1-6 walls,
    // 7-8 exit doors, 9-12 doors; row 0 is the file's last line)
    wallRows: [map_rows][map_cols + 1]i8 = @splat(@splat(0)),
    // @orig LabyrinthBackdrop+0x5d0
    objectRows: [map_rows][map_cols]?*Object = @splat(@splat(null)),
    // @orig LabyrinthBackdrop+0x710
    health: i16 = 0,
    // @orig LabyrinthBackdrop+0x712
    lives: i16 = 0,
    // @orig LabyrinthBackdrop+0x714
    ammo: i16 = 0,
    // @orig LabyrinthBackdrop+0x716
    level: i16 = 0,
    // @orig LabyrinthBackdrop+0x718 (16-bit, the score NOITE gets)
    score: i16 = 0,
    // @orig LabyrinthBackdrop+0x71a
    wallStrip: ?*Object = null,
    // @orig LabyrinthBackdrop+0x71e
    spriteQueue: ?*SpriteQueue = null,
    // @orig LabyrinthBackdrop+0x722 (curStrip = the weapon)
    hands: ?*Object = null,
    // @orig LabyrinthBackdrop+0x726
    shot: ?*Object = null,
    // @orig LabyrinthBackdrop+0x72a
    face: ?*Object = null,
    // @orig LabyrinthBackdrop+0x72e
    scene: ?*Scene = null,
    // @orig LabyrinthBackdrop+0x734
    active: i16 = 0,
    // @orig LabyrinthBackdrop+0x736
    moveFlag: i16 = 0,
    // @orig LabyrinthBackdrop+0x738
    shotInFlight: i16 = 0,
    // No counterpart: hwnd (+0x732).

    /// The WinG bitmap as the platform's `Surface`.
    pub fn surface(bd: *const Backdrop) Surface {
        return .{
            .pixels = bd.pixels,
            .width = @bitCast(bd.bgWidth),
            .height = @bitCast(bd.bgHeight),
            .bottom_up = bd.dibOrientation > 0,
            .colors = &bd.bmiColors,
        };
    }
};

/// One node of the sprite queue (struct `SpriteQueueEntry`, 0x14).
pub const SpriteQueueEntry = struct {
    // @orig SpriteQueueEntry+0x0
    object: ?*Object = null,
    // @orig SpriteQueueEntry+0x4
    dist: i16 = 0,
    // @orig SpriteQueueEntry+0x6
    angle: i16 = 0,
    // @orig SpriteQueueEntry+0x8
    col: i16 = 0,
    // @orig SpriteQueueEntry+0xa
    row: i16 = 0,
    // @orig SpriteQueueEntry+0xc (nearer)
    left: ?*SpriteQueueEntry = null,
    // @orig SpriteQueueEntry+0x10 (farther or equal)
    right: ?*SpriteQueueEntry = null,
};

/// The sprites of a frame: a binary tree keyed by depth, one node per
/// cell, drawn farthest first (struct `SpriteQueue`, 0x7d6). Unit `sprites`.
/// The original has no capacity check (BUGS.md JARDIM latent): a 101st
/// node is a panic naming it.
pub const SpriteQueue = struct {
    // @orig SpriteQueue+0x0
    entries: [max_sprites]SpriteQueueEntry = @splat(.{}),
    // @orig SpriteQueue+0x7d0
    root: ?*SpriteQueueEntry = null,
    // @orig SpriteQueue+0x7d4
    nextFree: i16 = 0,
};

/// The seven 16.16 tables of `raycast_build_tables` (`g_labyrinthTables`,
/// unit `tables`): [0] tan, [1] cot, [2] ±32·|tan|, [3] ±32·|cot|,
/// [5] 1/cos, [6] 1/sin, 2881 entries each (index 2880 = 0); [4] 481
/// entries, 22500/cos for −30°..+30°.
pub const Tables = struct {
    trig: [7][]const i32 = @splat(&.{}),
};

/// Sorted draw list (struct `DrawList`, 100 nodes). Unit `lists`.
pub const DrawList = struct {
    nodes: [max_draw_nodes]DrawListNode = @splat(.{}),
    freeHead: ?*DrawListNode = null,
    head: ?*DrawListNode = null,
};

pub const DrawListNode = struct {
    item: ?*Object = null,
    prev: ?*DrawListNode = null,
    next: ?*DrawListNode = null,
};

/// Objects to blit to the screen (struct `UpdateList`, 30 items). Unit `lists`.
pub const UpdateList = struct {
    // @orig UpdateList+0x0
    items: [max_update]?*Object = @splat(null),
    // @orig UpdateList+0x78
    count: i16 = 0,
};

/// Exit conditions: FlagCondition (CompoundCondition is never built).
/// Functions: unit `game`.
pub const Condition = struct {
    kind: enum { base, flag } = .base,
    // @orig FlagCondition+0x4
    value: i16 = 0,
};
