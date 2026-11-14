//! The flattened object model (docs/DESIGN.md "Object model").
//!
//! The original's class lattice (SceneObject, Object3D, Animation, Mover and
//! their virtual-inheritance combinations) becomes one `Object` with a
//! `kind` tag. Every kind carries every part; `kind` says which parts are
//! live (`Kind.hasObject3d` …). Virtual methods are functions in the
//! behaviour units that `switch (obj.kind)`; the original's type tests
//! (`isX`/`asX`) are the `Kind` predicates and `Object.as`.
//!
//! Data only: the functions live in the port units. Field names follow the
//! Ghidra struct members; `@orig` cites `Struct+offset`.

const std = @import("std");
pub const Condition = @import("world.zig").Condition;
const Wave = @import("../platform/platform.zig").Wave;

/// The instantiated classes. Mover, Animation and Player alone are never
/// instantiated; Actor2D/Player2D are dead (not ported).
pub const Kind = enum(u8) {
    /// Object3D (INI `Local=`).
    local,
    /// Animated3D (INI `Animated=` and `Static=`).
    animated,
    /// Moveable (INI `Moveable=`).
    moveable,
    /// Actor (INI `C_Actor=`; the loader supports it, the shipped INI has none).
    actor,
    /// DirectionalPlayer (the only player class instantiated).
    player,
    /// Exit (INI `Exit=`, `2Exit=`, and an Is_1Animation scene's animation).
    exit,
    /// Portable (INI `Portable=` and `ZoomPort=`).
    portable,
    /// ControlPanel (INI `Control=`).
    control_panel,
    /// StatusBar (INI `StatusBar=`).
    status_bar,

    /// SceneObject slots 50/51: isObject3D.
    pub fn hasObject3d(k: Kind) bool {
        return k != .status_bar;
    }
    /// Slots 48/49 (Animation) and 4A/4B (Animated3D): same set of kinds.
    pub fn isAnimation(k: Kind) bool {
        return switch (k) {
            .animated, .actor, .player, .exit, .control_panel => true,
            else => false,
        };
    }
    /// Slots 4C/4D: isMover.
    pub fn isMover(k: Kind) bool {
        return switch (k) {
            .moveable, .actor, .player, .portable => true,
            else => false,
        };
    }
    /// Actor's own part (the inventory list).
    pub fn isActor(k: Kind) bool {
        return k == .actor or k == .player;
    }
};

/// What `Object.as` tests for: the original's `asX` slots.
pub const Class = enum { object3d, animation, animated3d, mover, actor, player, directional_player, exit, portable, control_panel, status_bar };

/// Win16 RECT (all `int`).
pub const Rect = struct {
    left: i16 = 0,
    top: i16 = 0,
    right: i16 = 0,
    bottom: i16 = 0,
};

/// A device-independent bitmap as the original keeps it: BITMAPINFO
/// (header + colour table) and its pixel rows (bottom-up unless the
/// header height is negative). Loaded by the `dib` unit.
pub const Dib = struct {
    header: BitmapInfoHeader,
    colors: [256]RgbQuad,
    /// Row-padded (4-byte) pixels, 8 bits per pixel after loading.
    bits: []u8,
};

pub const BitmapInfoHeader = extern struct {
    biSize: u32 = 40,
    biWidth: i32 = 0,
    biHeight: i32 = 0,
    biPlanes: u16 = 1,
    biBitCount: u16 = 8,
    biCompression: u32 = 0,
    biSizeImage: u32 = 0,
    biXPelsPerMeter: i32 = 0,
    biYPelsPerMeter: i32 = 0,
    biClrUsed: u32 = 0,
    biClrImportant: u32 = 0,
};

/// Win16 RGBQUAD (the platform's type: `Surface.colors` takes the same tables).
pub const RgbQuad = @import("../platform/platform.zig").RgbQuad;

/// One bitmap strip of an object (struct `Frame`, 0x12): `count` frames of
/// `width`×`height` cut from one DIB, plus the hit box.
pub const Frame = struct {
    // @orig Frame+0x0
    width: i16 = 0,
    // @orig Frame+0x2
    height: i16 = 0,
    // @orig Frame+0x4
    count: i16 = 0,
    // @orig Frame+0x6
    dib: ?*Dib = null,
    // @orig Frame+0xa
    hitX: i16 = 0,
    // @orig Frame+0xc
    hitY: i16 = 0,
    // @orig Frame+0xe
    hitW: i16 = 0,
    // @orig Frame+0x10
    hitH: i16 = 0,
};

/// Intrusive doubly linked list of objects (struct `ObjectList`); the
/// links are `Object.next/prev/ownerList`.
pub const ObjectList = struct {
    // @orig ObjectList+0x0
    head: ?*Object = null,
    // @orig ObjectList+0x4
    count: i16 = 0,
    // @orig ObjectList+0x6
    capacity: i16 = 0,
};

/// Object3D part (struct `Object3D`, own fields).
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

/// Animation part (struct `Animation`, own fields).
pub const AnimationPart = struct {
    // @orig Animation+0x8
    timerId: i16 = 0,
    // @orig Animation+0xa
    timerPeriod: i16 = 0,
    // @orig Animation+0xc
    playOnce: i16 = 0,
    // @orig Animation+0xe
    running: i16 = 0,
    // @orig Animation+0x10
    isAvi: i16 = 0,
    // @orig Animation+0x12
    aviDevice: u16 = 0,
    // @orig Animation+0x14
    aviName: [256]u8 = @splat(0),
};

/// Mover part (struct `Mover`, own fields).
pub const MoverPart = struct {
    // @orig Mover+0x8..0x14 (never accessed)
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
    // @orig Mover+0x28
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
    // @orig Mover+0x36
    allowOffscreen: i16 = 0,
};

/// Actor + Player parts.
pub const ActorPart = struct {
    // @orig Actor+0x14c
    inventory: ObjectList = .{},
    // @orig Player+0x154 (only written; the live counter is Game.lives)
    lives: i16 = 0,
    // @orig Player+0x156
    score: i32 = 0,
};

/// Exit part (struct `Exit`, own fields from 0x114).
pub const ExitPart = struct {
    // @orig Exit+0x114
    sceneName: [20]u8 = @splat(0),
    // @orig Exit+0x128
    playerX: i16 = 0,
    // @orig Exit+0x12a
    playerY: i16 = 0,
    // @orig Exit+0x12c
    hasPlayer: i16 = 0,
    // @orig Exit+0x12e
    hasControlPanel: i16 = 0,
    // @orig Exit+0x130
    hasStatusBar: i16 = 0,
    // @orig Exit+0x132
    condition: ?*Condition = null,
    // @orig Exit+0x136
    exitIndex: i16 = 0,
    // @orig Exit+0x138
    framesLeft: i16 = 0,
    // @orig Exit+0x13a
    playing: i16 = 0,
    // @orig Exit+0x13c
    keyObject: i16 = 0,
    // @orig Exit+0x13e
    altExitIndex: i16 = 0,
    // @orig Exit+0x140
    altSceneName: [20]u8 = @splat(0),
    // @orig Exit+0x154
    altPlayerX: i16 = 0,
    // @orig Exit+0x156
    altPlayerY: i16 = 0,
};

/// Portable part (struct `Portable`, own fields from 0x38).
pub const PortablePart = struct {
    // @orig Portable+0x38 (the carrier; its inventory holds this item)
    owner: ?*Object = null,
    // @orig Portable+0x3c
    icon: ?*Dib = null,
    // @orig Portable+0x40
    iconPath: [256]u8 = @splat(0),
    // @orig Portable+0x44
    iconW: i16 = 0,
    // @orig Portable+0x46
    iconH: i16 = 0,
    // @orig Portable+0x48
    scoreTake: i16 = 0,
    // @orig Portable+0x4a
    scoreUse: i16 = 0,
    // @orig Portable+0x4c
    scoreMisuse: i16 = 0,
    // @orig Portable+0x4e
    prevSceneName: [21]u8 = @splat(0),
    // @orig Portable+0x63
    homeSceneName: [21]u8 = @splat(0),
    // @orig Portable+0x78
    homeX: i16 = 0,
    // @orig Portable+0x7a
    homeY: i16 = 0,
    /// Not in the original (B30's fix): the height the item rests at when
    /// the fall started by its drop ends (its support's top, 0 on the
    /// floor); null when no such fall is under way.
    restElev: ?i16 = null,
    /// Not in the original (`Fixes.smooth_item_fall`): the time of the
    /// last step of its walk (or of the drop that started it).
    stepAt: u32 = 0,
};

/// ControlPanel part (struct `ControlPanel`, own fields from 0x114).
pub const ControlPanelPart = struct {
    // @orig ControlPanel+0x114
    isOpen: i16 = 0,
    // @orig ControlPanel+0x116 (4 = up/open, 8 = down/close)
    slideDir: i16 = 0,
    // @orig ControlPanel+0x118
    slideStepsLeft: i16 = 0,
    // @orig ControlPanel+0x11a (COLORREF)
    textColor: u32 = 0,
    // @orig ControlPanel+0x11e
    message: [256]u8 = @splat(0),
    // @orig ControlPanel+0x21e
    scoreText: [256]u8 = @splat(0),
    // @orig ControlPanel+0x31e
    livesText: [256]u8 = @splat(0),
    // @orig ControlPanel+0x41e
    messageX: i16 = 0,
};

/// StatusBar part (struct `StatusBar`, own fields from 0x49e).
pub const StatusBarPart = struct {
    // @orig StatusBar+0x49e
    textColor: u32 = 0,
    // @orig StatusBar+0x4a2
    text: [200]u8 = @splat(0),
    // @orig StatusBar+0x56a
    textX: i16 = 0,
};

pub const Object = struct {
    kind: Kind,

    // SceneObject (every kind)
    // @orig SceneObject+0x4
    next: ?*Object = null,
    // @orig SceneObject+0x8
    prev: ?*Object = null,
    // @orig SceneObject+0xc
    ownerList: ?*ObjectList = null,
    // @orig SceneObject+0x10 (ctor argument, meaning unknown)
    unk10: u16 = 0,
    // @orig SceneObject+0x12
    x: i16 = 0,
    // @orig SceneObject+0x14
    y: i16 = 0,
    // @orig SceneObject+0x16 (serial, or the INI Number)
    id: i16 = 0,
    // @orig SceneObject+0x1c / +0x20 (stripCount = frames.len)
    frames: []Frame = &.{},
    // @orig SceneObject+0x22
    curStrip: i16 = 0,
    // @orig SceneObject+0x24
    curFrame: i16 = 0,
    // @orig SceneObject+0x26: the backdrop's BITMAPINFOHEADER patched to the
    // strip (biWidth = frame width, biHeight = count × height, positive).
    // Not kept: bmiColors (+0x4e) and hpalette (+0x44e), copied from the
    // backdrop by attach/reattach but never read (drawing goes through the
    // backdrop's header and the strip's own DIB).
    bmiHeader: BitmapInfoHeader = .{},
    // @orig SceneObject+0x452 (WinGRecommendDIBFormat result, always 1
    // here; multiplies draw height)
    dibFormatOk: i32 = 0,
    // @orig SceneObject+0x456
    visible: i16 = 0,
    // @orig SceneObject+0x458
    attached: i16 = 0,
    // @orig SceneObject+0x45a (Mover: the object that blocked the last step)
    linked: ?*Object = null,
    // @orig SceneObject+0x45e
    unk45E: u16 = 0,
    // @orig SceneObject+0x460
    queued: i16 = 0,
    // @orig SceneObject+0x462
    queueIndex: i16 = 0,
    // @orig SceneObject+0x464 (Mover: Bresenham next point)
    nextX: i16 = 0,
    // @orig SceneObject+0x466
    nextY: i16 = 0,
    // @orig SceneObject+0x468..0x46e
    dirty: Rect = .{},
    // @orig SceneObject+0x470..0x476
    clip: Rect = .{},
    // @orig SceneObject+0x478 (scene a persistent object belongs to)
    sceneName: [22]u8 = @splat(0),
    // @orig SceneObject+0x48e (NomeWAVE: the WaveMix handle `sound.open`
    // returned, NULL = none; pass it to `sound.play/stop` as is)
    wave: ?Wave = null,
    // @orig SceneObject+0x492 (slots 00/01: "used/touched" mark)
    unk492: u16 = 0,
    // @orig SceneObject+0x494 (never set by the shipped game)
    rleMode: u16 = 0,
    // @orig SceneObject+0x496
    rleBits: ?[]u8 = null,
    // @orig SceneObject+0x49a
    playOnceRewinds: u16 = 0,
    // @orig SceneObject+0x49c
    framesLeft: i16 = 0,

    o3d: Object3dPart = .{},
    anim: AnimationPart = .{},
    mover: MoverPart = .{},
    actor: ActorPart = .{},
    exit: ExitPart = .{},
    portable: PortablePart = .{},
    panel: ControlPanelPart = .{},
    status: StatusBarPart = .{},

    /// The original's `asX` downcasts: the object itself if it is one,
    /// else null (the original returns NULL).
    pub fn as(obj: *Object, class: Class) ?*Object {
        return if (obj.is(class)) obj else null;
    }

    /// The original's `isX` type tests.
    pub fn is(obj: *const Object, class: Class) bool {
        const k = obj.kind;
        return switch (class) {
            .object3d => k.hasObject3d(),
            .animation, .animated3d => k.isAnimation(),
            .mover => k.isMover(),
            .actor => k.isActor(),
            .player, .directional_player => k == .player,
            .exit => k == .exit,
            .portable => k == .portable,
            .control_panel => k == .control_panel,
            .status_bar => k == .status_bar,
        };
    }
};

test "type tests match the original's vtables" {
    var o: Object = .{ .kind = .portable };
    try std.testing.expect(o.is(.mover) and o.is(.object3d) and !o.is(.animation));
    o.kind = .exit;
    try std.testing.expect(o.as(.animated3d) != null and o.as(.mover) == null);
    o.kind = .status_bar;
    try std.testing.expect(!o.is(.object3d));
}
