//! INFERNO's flattened object model (docs/inferno/DESIGN.md "Object
//! model"). INFERNO's own layouts (large model: far `this`, far vptr and
//! vbptr, far data pointers, so every engine struct is wider than TIRO's);
//! `@orig` cites INFERNO's `Struct+offset` (Ghidra category `/inferno`,
//! docs/inferno/DATA.md §4). Offsets marked "measured" were read from the
//! accesses for this skeleton; a unit that finds one wrong fixes it here
//! in its own commit.
//!
//! Four classes are instantiated: the Hero (← Player2D ← Actor2D ← Mover +
//! Animation, the player `g_hero`), the four Platforms (← Actor2D), the
//! Props (← Actor2D: the drinks, the six rocks, the cross) and the six
//! Hazards (← Prop). Mover, Animation, Actor2D, Player2D, Object3D,
//! Animated3D, Moveable, Portable, Actor, Player, Exit, ControlPanel and
//! StatusBar are never constructed (docs/inferno/FUNCTIONS.md). Every
//! object carries every part; `kind` says which are live.
//!
//! Data only: the functions live in the units (src/inferno/).

const std = @import("std");
const noite_object = @import("../../core/object.zig");

/// Win16 data types, shared with NOITE (memory-model independent).
pub const Dib = noite_object.Dib;
pub const BitmapInfoHeader = noite_object.BitmapInfoHeader;
pub const RgbQuad = noite_object.RgbQuad;
pub const Rect = noite_object.Rect;

pub const Kind = enum(u8) {
    /// Hero (the player `g_hero`; vtables 7dc0/7dc4/7dc8).
    hero,
    /// Platform (`g_platforms[0..3]`; vtables 89c2/89ca/89ce).
    platform,
    /// Prop (the drinks `Platform.item`, `g_rocks[0..5]`, `g_cross`;
    /// vtables 8b42/8b52/8b56).
    prop,
    /// Hazard (`g_hazards[0..5]`; vtables 8cca/8cda/8cde).
    hazard,
};

/// What `Object.is`/`as` test for: SceneObject slots 3A–4B, 52/53 and
/// INFERNO's 57 (isPlatform), 58 (isProp), 59 (isHazard), by the overrides
/// of the four live tables.
pub const Class = enum { player, directional_player, animation, mover, actor2d, object3d, status_bar, control_panel, portable, exit, platform, prop, hazard };

/// One frame cell (struct `FrameCell`, 8 bytes): allocated and
/// constructed per strip (`frame_cell_ctor`), read by `frame_get_cell`,
/// `frame_cell_x/y`.
pub const FrameCell = struct {
    // @orig FrameCell+0x0
    raw: [8]u8 = @splat(0),
};

/// One bitmap strip (struct `Frame`, 0x12, with a vtable:
/// `FrameVtbl.getCell`). No hit box: INFERNO's is in the SceneObject.
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
};

/// Intrusive doubly linked list of objects (struct `ObjectList`, 4: the
/// far `head` only; TIRO's has a count and a capacity too).
pub const ObjectList = struct {
    // @orig ObjectList+0x0
    head: ?*Object = null,
};

/// Animation part (struct `Animation`, 0x12; Actor2D+0x36 in every live
/// class).
pub const AnimationPart = struct {
    // @orig Animation+0x8
    timerId: i16 = 0,
    // @orig Animation+0xa
    timerPeriod: i16 = 0,
    // @orig Animation+0xc
    framesLeft: i16 = 0,
    // @orig Animation+0xe
    playOnce: i16 = 0,
    // @orig Animation+0x10
    running: i16 = 0,
};

/// Mover part (struct `Mover`, 0x36; the first 0x36 bytes of Actor2D).
pub const MoverPart = struct {
    // @orig Mover+0x8..0xa (unknown)
    unk08: [2]u16 = @splat(0),
    // @orig Mover+0xc
    direction: i16 = 0,
    // @orig Mover+0xe..0x14 (unknown)
    unk0E: [4]u16 = @splat(0),
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
};

/// Player2D part (struct `Player2D` +0x48; the hero's).
pub const Player2dPart = struct {
    // @orig Player2D+0x48 (unused: the lives are `g_lives`)
    lives: i16 = 0,
    // @orig Player2D+0x4a (unused: the score is `g_score`)
    score: i32 = 0,
};

/// Hero part (struct `Hero`, own fields from 0x4e).
pub const HeroPart = struct {
    // @orig Hero+0x4e (unknown)
    unk4E: u16 = 0,
    // @orig Hero+0x50 (the big hero's countdown: 180 move ticks)
    powerTimer: i16 = 0,
    // @orig Hero+0x52 (rise ticks left: 18 or 12)
    jumpTicks: u16 = 0,
    // @orig Hero+0x54 (0 UP standing, 1 UP walking, 2 DOWN standing, 3 DOWN walking)
    jumpKind: i16 = 0,
    // @orig Hero+0x56 (1 left, 2 right)
    facing: i16 = 0,
    // @orig Hero+0x58 (4 rising, 8 falling)
    jumpPhase: u16 = 0,
    // @orig Hero+0x5a (in a jump: the arrows are ignored)
    busy: i16 = 0,
    // @orig Hero+0x5c
    walking: i16 = 0,
    // @orig Hero+0x5e (1: the big `marg*` strips 4-7 instead of 0-3)
    altStrips: i16 = 0,
};

/// Platform part (struct `Platform`, own fields from 0x48).
pub const PlatformPart = struct {
    // @orig Platform+0x48 (the next respawn slot 0-3)
    slot: i16 = 0,
    // @orig Platform+0x4a (it carries the present: a small hero's hit opens it)
    presentReady: i16 = 0,
    // @orig Platform+0x4c (its drink, a Prop)
    item: ?*Object = null,
};

/// Prop part (struct `Prop`, own fields from 0x48; the Hazard's
/// `index`/`unk4A`/`active`/`unk4E` are at the same offsets).
pub const PropPart = struct {
    // @orig Prop+0x48 (the cross: the ticks before it drops)
    index: i16 = 0,
    // @orig Prop+0x4a (the cross: 2 launched right, 8 falling, 1 sliding left)
    state: i16 = 0,
    // @orig Prop+0x4c (on screen)
    active: i16 = 0,
    // @orig Prop+0x4e (1 for the cross: SceneObject slot 5A isPowerUp)
    powerUp: i16 = 0,
};

pub const Object = struct {
    kind: Kind,

    // ---- SceneObject (every kind) ----
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
    // @orig SceneObject+0x18..0x1a (unknown)
    unk18: [2]u16 = @splat(0),
    // @orig SceneObject+0x1c (+0x20 stripCount = frames.len)
    frames: []Frame = &.{},
    // @orig SceneObject+0x22
    curStrip: i16 = 0,
    // @orig SceneObject+0x24
    curFrame: i16 = 0,
    // @orig SceneObject+0x26
    bmiHeader: BitmapInfoHeader = .{},
    // @orig SceneObject+0x450 (measured: unknown word)
    unk450: u16 = 0,
    // @orig SceneObject+0x452 (measured)
    dibFormatOk: i32 = 0,
    // @orig SceneObject+0x456
    visible: i16 = 0,
    // @orig SceneObject+0x458 (measured)
    attached: i16 = 0,
    // @orig SceneObject+0x45a (the hit box: in the SceneObject, not the
    // Frame, in INFERNO; scene_object_init_state)
    hitX: i16 = 0,
    // @orig SceneObject+0x45c
    hitY: i16 = 0,
    // @orig SceneObject+0x45e
    hitW: i16 = 0,
    // @orig SceneObject+0x460
    hitH: i16 = 0,
    // @orig SceneObject+0x462 (measured: far)
    linked: ?*Object = null,
    // @orig SceneObject+0x466 (measured: unknown word)
    unk466: u16 = 0,
    // @orig SceneObject+0x468 (in the update list)
    queued: i16 = 0,
    // @orig SceneObject+0x46a (its index there)
    queueIndex: i16 = 0,
    // @orig SceneObject+0x46c (mover_step's next position)
    nextX: i16 = 0,
    // @orig SceneObject+0x46e
    nextY: i16 = 0,
    // @orig SceneObject+0x470 (x, y, w, h)
    dirty: Rect = .{},
    // @orig SceneObject+0x478 (x, y, w, h)
    clip: Rect = .{},
    // No counterpart: bmiColors (+0x4e) and hpalette (+0x44e), copied from
    // the backdrop by attach (the units decide whether a reader needs them).

    anim: AnimationPart = .{},
    mover: MoverPart = .{},
    player2d: Player2dPart = .{},
    hero: HeroPart = .{},
    platform: PlatformPart = .{},
    prop: PropPart = .{},

    /// The original's `asX` downcasts: the object if it is one, else null.
    pub fn as(obj: *Object, class: Class) ?*Object {
        return if (obj.is(class)) obj else null;
    }

    /// The original's `isX` type tests (the overrides in the four live
    /// SceneObject tables).
    pub fn is(obj: *const Object, class: Class) bool {
        const k = obj.kind;
        return switch (class) {
            .player => k == .hero,
            .animation, .mover, .actor2d => true,
            .platform => k == .platform,
            .prop => k == .prop or k == .hazard,
            .hazard => k == .hazard,
            .directional_player, .object3d, .status_bar, .control_panel, .portable, .exit => false,
        };
    }
};

test "type tests follow the live vtables" {
    var o: Object = .{ .kind = .hero };
    try std.testing.expect(o.is(.player) and o.is(.mover) and o.is(.animation) and !o.is(.prop));
    o.kind = .platform;
    try std.testing.expect(o.is(.platform) and o.is(.actor2d) and !o.is(.player) and !o.is(.prop));
    o.kind = .prop;
    try std.testing.expect(o.is(.prop) and !o.is(.hazard) and o.as(.object3d) == null);
    o.kind = .hazard;
    try std.testing.expect(o.is(.prop) and o.is(.hazard) and !o.is(.portable));
}
