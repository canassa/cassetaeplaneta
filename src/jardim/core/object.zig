//! JARDIM's flattened object model (docs/jardim/DESIGN.md "Object model").
//! JARDIM is a large-model build: its engine structs have NOITE's layouts
//! (far pointers, 4 bytes; the SceneObject is NOITE's 0x49e), not TIRO's;
//! `@orig` cites JARDIM's `Struct+offset` (Ghidra category `/jardim`,
//! docs/jardim/DATA.md "Classes").
//!
//! Six classes are instantiated as the most derived class: the plain
//! SceneObject (the face, the hands, the shot), the WallStrip (the wall
//! textures, vtable 8e60), the Portable (every pickup and enemy type: one
//! object stored in many map cells), the Exit (portainv.bmp: only its exit
//! index is used), the Player (createPlayer's hidden dummy) and the
//! ControlPanel (labinter.bmp). Mover, Moveable, Animation, Animated3D,
//! Object3D and Actor are bases only; the StatusBar is never built
//! (createStatusBar returns NULL). Every object carries every part; `kind`
//! says which are live.
//!
//! Data only: the functions live in the units (src/jardim/). The parts
//! DATA.md lists as skeletons (Portable, Exit, ControlPanel, Moveable,
//! Animated3D, Frame) carry what the engine's twins (NOITE's, TIRO's) use;
//! a unit that finds another field adds it here with its `@orig` offset.

const std = @import("std");
const noite_object = @import("../../core/object.zig");

/// Win16 data types, shared with NOITE (memory-model independent).
pub const Dib = noite_object.Dib;
pub const BitmapInfoHeader = noite_object.BitmapInfoHeader;
pub const RgbQuad = noite_object.RgbQuad;
pub const Rect = noite_object.Rect;

pub const Kind = enum(u8) {
    /// A plain SceneObject (g_sceneObjectVtbl 3f0e): the face (rostoN),
    /// the hands (maosN strips), the shot (shotN).
    scene_object,
    /// WallStrip (8e60: SceneObject + attach): paredesN.bmp, 6 textures.
    wall_strip,
    /// Portable (59d4/59d8/5b5c): every pickup and enemy.
    portable,
    /// Exit (8fe4/8ffc/9180): phases 1-2, never drawn.
    exit,
    /// Player (7d6a/7d6e/7d86/7f0a): built by createPlayer, never shown.
    player,
    /// ControlPanel (7b84/7bbc/7d40): labinter.bmp.
    control_panel,
};

/// What `Object.is`/`as` test for: SceneObject slots 41-52, 58, 59 by the
/// overrides of the six live tables.
pub const Class = enum { player, directional_player, animation, mover, actor2d, object3d, status_bar, control_panel, portable, exit };

/// One frame cell (struct `FrameCell`).
pub const FrameCell = struct {
    raw: [8]u8 = @splat(0),
};

/// One bitmap strip (struct `Frame`, 0x1a, with a vtable: `FrameVtbl.getCell`).
pub const Frame = struct {
    // @orig Frame+0x4
    cells: []FrameCell = &.{},
    // @orig Frame+0x8
    width: i16 = 0,
    // @orig Frame+0xa
    height: i16 = 0,
    // @orig Frame+0xc
    count: i16 = 0,
    // @orig Frame+0xe
    dib: ?*Dib = null,
    // @orig Frame+0x12
    hitX: i16 = 0,
    // @orig Frame+0x14
    hitY: i16 = 0,
    // @orig Frame+0x16
    hitW: i16 = 0,
    // @orig Frame+0x18
    hitH: i16 = 0,
};

/// Intrusive doubly linked list of objects (struct `ObjectList`, 8).
pub const ObjectList = struct {
    // @orig ObjectList+0x0
    head: ?*Object = null,
    // @orig ObjectList+0x4
    count: i16 = 0,
    // @orig ObjectList+0x6
    capacity: i16 = 0,
};

/// Object3D part (struct `Object3D`, 0x1e).
pub const Object3dPart = struct {
    // @orig Object3D+0x8
    worldX: i16 = 0,
    // @orig Object3D+0xa
    worldDepth: i16 = 0,
    // @orig Object3D+0xc
    worldElev: i16 = 0,
    // @orig Object3D+0xe
    sizeW: i16 = 0,
    // @orig Object3D+0x10
    sizeH: i16 = 0,
    // @orig Object3D+0x12
    sizeD: i16 = 0,
    // @orig Object3D+0x14
    anchorX: i16 = 0,
    // @orig Object3D+0x16
    anchorY: i16 = 0,
    // @orig Object3D+0x18
    support: ?*Object = null,
};

/// Animation part (struct `Animation`, 0x18; NOITE's without the AVI).
pub const AnimationPart = struct {
    // @orig Animation+0x8
    timerId: i16 = 0,
    // @orig Animation+0xa
    timerPeriod: i16 = 0,
    // @orig Animation+0xc (play-once frame countdown; animation_play_once sets it)
    framesLeft: i16 = 0,
    // @orig Animation+0xe (play-once flag: animation_play_once 1, animation_stop 0)
    playOnce: i16 = 0,
    // @orig Animation+0x10 (play-once rewind flag; nothing in JARDIM sets it)
    rewinds: i16 = 0,
    // @orig Animation+0x12 (animation_is_running)
    running: i16 = 0,
    // @orig Animation+0x14 (AnimationVtbl lock / isLocked)
    locked: i16 = 0,
};

/// Mover part (struct `Mover`, 0x38).
pub const MoverPart = struct {
    // @orig Mover+0x8..0x14 (unknown)
    unk08: [7]u16 = @splat(0),
    // @orig Mover+0x16
    prevX: i16 = 0,
    // @orig Mover+0x18
    prevY: i16 = 0,
    // @orig Mover+0x1a
    targetX: i16 = 0,
    // @orig Mover+0x1c
    targetY: i16 = 0,
    // @orig Mover+0x1e
    stepX: i16 = 0,
    // @orig Mover+0x20
    stepY: i16 = 0,
    // @orig Mover+0x22
    lineDx: i16 = 0,
    // @orig Mover+0x24
    lineDy: i16 = 0,
    // @orig Mover+0x26
    lineErr: i16 = 0,
    // @orig Mover+0x28 (unknown)
    unk28: u16 = 0,
    // @orig Mover+0x2a
    errIncDiag: i16 = 0,
    // @orig Mover+0x2c
    errIncX: i16 = 0,
    // @orig Mover+0x2e
    errIncY: i16 = 0,
    // @orig Mover+0x30
    timerId: i16 = 0,
    // @orig Mover+0x32
    timerPeriod: i16 = 0,
    // @orig Mover+0x34
    moving: i16 = 0,
    // @orig Mover+0x36 (only `portable_ctor_zoom` writes it, 0)
    unk36: i16 = 0,
};

/// Actor and Player parts (structs `Actor` 0x56, `Player` 0x5c): the
/// Player's tail. JARDIM's lives, health and score are the backdrop's
/// (`Backdrop.lives` …), not these.
pub const ActorPart = struct {
    // @orig Actor+0x4e
    inventory: ObjectList = .{},
    // @orig Player+0x56
    lives: i16 = 0,
    // @orig Player+0x58
    score: i32 = 0,
};

/// Portable part (struct `Portable`, 0x48; a skeleton in Ghidra: the
/// fields are the engine's, to be confirmed by `object_create`).
pub const PortablePart = struct {
    // @orig Portable+0x38 (`portable_ctor_zoom` zeroes it; nothing reads it)
    unk38: i16 = 0,
    // @orig Portable+0x3a (far pointer: the current strip's DIB at construction)
    icon: ?*Dib = null,
    // @orig Portable+0x42 (the icon width; control_panel_draw_inventory_item reads it)
    iconW: i16 = 0,
    // @orig Portable+0x44 (the icon height)
    iconH: i16 = 0,
};

/// Exit part (struct `Exit`, 0x60; a skeleton in Ghidra). Phases 1-2 build
/// one (portainv.bmp) for its exit index only (`scene_add_exit_at`).
pub const ExitPart = struct {
    // @orig Exit+0x3c (the index the SPACE door posts with 0x402)
    exitIndex: i16 = 0,
    sceneName: [20]u8 = @splat(0),
    playerX: i16 = 0,
    playerY: i16 = 0,
    hasPlayer: i16 = 0,
    hasControlPanel: i16 = 0,
    hasStatusBar: i16 = 0,
    // @orig Exit+0x34 (zeroed by `exit_ctor`; nothing reads it)
    unk34: [2]u16 = @splat(0),
    condition: ?*anyopaque = null,
    framesLeft: i16 = 0,
    playing: i16 = 0,
    keyObject: i16 = 0,
    altExitIndex: i16 = 0,
    altSceneName: [20]u8 = @splat(0),
    altPlayerX: i16 = 0,
    altPlayerY: i16 = 0,
};

/// ControlPanel part (struct `ControlPanel`, 0xec; a skeleton in Ghidra).
pub const ControlPanelPart = struct {
    isOpen: i16 = 0,
    slideDir: i16 = 0,
    slideStepsLeft: i16 = 0,
    textColor: u32 = 0,
    text: [200]u8 = @splat(0),
    textX: i16 = 0,
};

/// StatusBar part: never built in JARDIM (createStatusBar returns NULL);
/// the live code that tests for one reads it.
pub const StatusBarPart = struct {
    textColor: u32 = 0,
    text: [200]u8 = @splat(0),
    textX: i16 = 0,
};

pub const Object = struct {
    kind: Kind,

    // ---- SceneObject (every kind; struct `SceneObject`, 0x49e) ----
    // @orig SceneObject+0x4
    next: ?*Object = null,
    // @orig SceneObject+0x8
    prev: ?*Object = null,
    // @orig SceneObject+0xc
    ownerList: ?*ObjectList = null,
    // @orig SceneObject+0x10
    unk10: u16 = 0,
    // @orig SceneObject+0x12
    x: i16 = 0,
    // @orig SceneObject+0x14
    y: i16 = 0,
    // @orig SceneObject+0x16
    id: i16 = 0,
    // @orig SceneObject+0x1c (+0x20 stripCount = frames.len)
    frames: []Frame = &.{},
    // @orig SceneObject+0x22 (the hands: the weapon, 0 fists, 1 crossbow,
    // 2 bra/bazooka; the shot: 0 arrow, 1 bra/bazooka)
    curStrip: i16 = 0,
    // @orig SceneObject+0x24 (the hands: 1 the firing pose)
    curFrame: i16 = 0,
    // @orig SceneObject+0x26
    bmiHeader: BitmapInfoHeader = .{},
    // @orig SceneObject+0x452
    dibFormatOk: i32 = 0,
    // @orig SceneObject+0x456
    visible: i16 = 0,
    // @orig SceneObject+0x458
    attached: i16 = 0,
    // @orig SceneObject+0x45a
    linked: ?*Object = null,
    // @orig SceneObject+0x45e
    unk45E: u16 = 0,
    // @orig SceneObject+0x460
    queued: i16 = 0,
    // @orig SceneObject+0x462
    queueIndex: i16 = 0,
    // @orig SceneObject+0x464
    nextX: i16 = 0,
    // @orig SceneObject+0x466
    nextY: i16 = 0,
    // @orig SceneObject+0x468 (x, y, w, h)
    dirty: Rect = .{},
    // @orig SceneObject+0x470 (x, y, w, h)
    clip: Rect = .{},
    // @orig SceneObject+0x478
    sceneName: [22]u8 = @splat(0),
    // @orig SceneObject+0x48e (set and read by the slot00/01 defaults)
    slot00Flag: i16 = 0,
    // @orig SceneObject+0x490 (enableRle sets it; isRle reads it)
    rleFlag: i16 = 0,
    // @orig SceneObject+0x492 (far pointer: the RLE data, past the colour table)
    rleBits: ?[]u8 = null,
    // @orig SceneObject+0x496 (the labyrinth world position, 1/32 cell)
    worldX: i16 = 0,
    // @orig SceneObject+0x498
    worldY: i16 = 0,
    // @orig SceneObject+0x49a (set on the enemies only; NOITE's playOnceRewinds)
    isEnemy: i16 = 0,
    // @orig SceneObject+0x49c (the wall strip: one texture's height, 300)
    framesLeft: i16 = 0,
    // @orig WallStrip+0x49e (the texture count, 6)
    textureCount: i16 = 0,
    // No counterpart: bmiColors (+0x4e) and hpalette (+0x44e), copied from
    // the backdrop by attach (the units decide whether a reader needs them).

    o3d: Object3dPart = .{},
    anim: AnimationPart = .{},
    mover: MoverPart = .{},
    actor: ActorPart = .{},
    portable: PortablePart = .{},
    exit: ExitPart = .{},
    panel: ControlPanelPart = .{},
    status: StatusBarPart = .{},

    /// The original's `asX` downcasts: the object if it is one, else null.
    pub fn as(obj: *Object, class: Class) ?*Object {
        return if (obj.is(class)) obj else null;
    }

    /// The original's `isX` type tests (the overrides in the six live
    /// SceneObject tables, docs/jardim/DESIGN.md "SceneObject slots").
    pub fn is(obj: *const Object, class: Class) bool {
        const k = obj.kind;
        return switch (class) {
            .player => k == .player,
            .mover => k == .portable or k == .player,
            .animation => k == .exit or k == .player or k == .control_panel,
            .object3d => k == .portable or k == .exit or k == .player or k == .control_panel,
            .control_panel => k == .control_panel,
            .portable => k == .portable,
            .exit => k == .exit,
            .directional_player, .actor2d, .status_bar => false,
        };
    }
};

test "type tests follow the live vtables" {
    var o: Object = .{ .kind = .portable };
    try std.testing.expect(o.is(.portable) and o.is(.mover) and o.is(.object3d) and !o.is(.animation) and !o.is(.player));
    o.kind = .player;
    try std.testing.expect(o.is(.player) and o.is(.mover) and o.is(.animation) and o.is(.object3d));
    o.kind = .exit;
    try std.testing.expect(o.is(.exit) and o.is(.animation) and !o.is(.mover));
    o.kind = .control_panel;
    try std.testing.expect(o.as(.control_panel) != null and o.as(.mover) == null);
    o.kind = .wall_strip;
    try std.testing.expect(!o.is(.object3d) and !o.is(.animation));
    o.kind = .scene_object;
    try std.testing.expect(!o.is(.portable));
}
