//! INV's flattened object model (docs/inv/DESIGN.md "Object model").
//! INV's own layouts (TIRO's medium-model engine structs, field for
//! field); `@orig` cites INV's `Struct+offset` (Ghidra category `/inv`).
//!
//! Eight classes are instantiated: the Cannon (← Player2D ← Actor2D ←
//! Mover + Animation, the player `g_cannon`), the Saucer, the two Bombs
//! and the Shot (← Missile), the four InvaderColumns and the
//! InvaderExplosion (all ← Actor2D), the InvPanel (← ControlPanel ←
//! Animated3D ← Animation + Object3D) and the StatusBar. Mover,
//! Animation, Actor2D, Player2D, Missile, Animated3D, Moveable, Portable,
//! Actor, Player, Exit are never constructed on their own
//! (docs/inv/FUNCTIONS.md). Every object carries every part; `kind` says
//! which are live.
//!
//! Data only: the functions live in the units (src/inv/).

const std = @import("std");
const noite_object = @import("../../core/object.zig");

/// Win16 data types, shared with NOITE (memory-model independent).
pub const Dib = noite_object.Dib;
pub const BitmapInfoHeader = noite_object.BitmapInfoHeader;
pub const RgbQuad = noite_object.RgbQuad;
pub const Rect = noite_object.Rect;

pub const Kind = enum(u8) {
    /// Cannon (the player `g_cannon`; vtables 1876/187a/187e).
    cannon,
    /// Saucer (`g_saucer`; vtables 1dba/1dca/1dce).
    saucer,
    /// Bomb (`g_bombs[0..1]`; vtables 20c6/20d2/20d6).
    bomb,
    /// Shot (`g_shots[0]`; vtables 224a/2256/225a).
    shot,
    /// InvaderColumn (`g_invaderColumns[0..3]`; vtables 2552/255e/2562).
    invader_column,
    /// InvaderExplosion (`g_invaderExplosion`; vtables 23ce/23da/23de).
    invader_explosion,
    /// InvPanel (vtables 0fc4/0fe8/1154): created and attached, never shown.
    control_panel,
    /// StatusBar (vtable 170a): created and attached, never shown.
    status_bar,
};

/// What `Object.is`/`as` test for: SceneObject slots 3A–4B, 52/53 and the
/// INV tests 56 (isShot), 57 (isInvader: column and explosion), 58
/// (isSaucer), 59 (isCannon), 5A (isBomb), by the overrides of the eight
/// live tables. (`missile_can_step` classifies a blocker with them.)
pub const Class = enum { player, directional_player, animation, mover, actor2d, object3d, status_bar, control_panel, portable, exit, shot, invader, saucer, cannon, bomb };

/// One frame cell (struct `FrameCell`, 8 bytes): allocated and
/// constructed per strip (`frame_cell_ctor`), read by `frame_get_cell`,
/// `frame_cell_x/y`.
pub const FrameCell = struct {
    // @orig FrameCell+0x0
    raw: [8]u8 = @splat(0),
};

/// One bitmap strip (struct `Frame`, 0x16, with a vtable: `FrameVtbl.getCell`).
pub const Frame = struct {
    // @orig Frame+0x2
    cells: []FrameCell = &.{},
    // @orig Frame+0x4
    width: i16 = 0,
    // @orig Frame+0x6
    height: i16 = 0,
    // @orig Frame+0x8
    count: i16 = 0,
    // @orig Frame+0xa
    dib: ?*Dib = null,
    // @orig Frame+0xe
    hitX: i16 = 0,
    // @orig Frame+0x10
    hitY: i16 = 0,
    // @orig Frame+0x12
    hitW: i16 = 0,
    // @orig Frame+0x14
    hitH: i16 = 0,
};

/// Intrusive doubly linked list of objects (struct `ObjectList`, 6).
pub const ObjectList = struct {
    // @orig ObjectList+0x0
    head: ?*Object = null,
    // @orig ObjectList+0x2
    count: i16 = 0,
    // @orig ObjectList+0x4
    capacity: i16 = 0,
};

/// Object3D part (struct `Object3D`, 0x16; the InvPanel's).
pub const Object3dPart = struct {
    // @orig Object3D+0x4
    worldX: i16 = 0,
    // @orig Object3D+0x6
    worldDepth: i16 = 0,
    // @orig Object3D+0x8
    worldElev: i16 = 0,
    // @orig Object3D+0xa
    sizeW: i16 = 0,
    // @orig Object3D+0xc
    sizeH: i16 = 0,
    // @orig Object3D+0xe
    sizeD: i16 = 0,
    // @orig Object3D+0x10
    anchorX: i16 = 0,
    // @orig Object3D+0x12
    anchorY: i16 = 0,
    // @orig Object3D+0x14
    support: ?*Object = null,
};

/// Animation part (struct `Animation`, 0xe; Actor2D+0x32 in every INV
/// class).
pub const AnimationPart = struct {
    // @orig Animation+0x4
    timerId: i16 = 0,
    // @orig Animation+0x6
    timerPeriod: i16 = 0,
    // @orig Animation+0x8
    framesLeft: i16 = 0,
    // @orig Animation+0xa
    playOnce: i16 = 0,
    // @orig Animation+0xc
    running: i16 = 0,
};

/// Mover part (struct `Mover`, 0x32; Actor2D+0 in every INV class).
pub const MoverPart = struct {
    // @orig Mover+0x4..0x6 (unknown)
    unk04: [2]u16 = @splat(0),
    // @orig Mover+0x8
    direction: i16 = 0,
    // @orig Mover+0xa..0x10 (unknown)
    unk0A: [4]u16 = @splat(0),
    // @orig Mover+0x12
    prevX: i16 = 0,
    // @orig Mover+0x14
    prevY: i16 = 0,
    // @orig Mover+0x16
    targetX: i16 = 0,
    // @orig Mover+0x18
    targetY: i16 = 0,
    // @orig Mover+0x1a
    stepX: i16 = 0,
    // @orig Mover+0x1c
    stepY: i16 = 0,
    // @orig Mover+0x1e
    lineDx: i16 = 0,
    // @orig Mover+0x20
    lineDy: i16 = 0,
    // @orig Mover+0x22
    lineErr: i16 = 0,
    // @orig Mover+0x24 (unknown)
    unk24: u16 = 0,
    // @orig Mover+0x26
    errIncDiag: i16 = 0,
    // @orig Mover+0x28
    errIncX: i16 = 0,
    // @orig Mover+0x2a
    errIncY: i16 = 0,
    // @orig Mover+0x2c
    timerId: i16 = 0,
    // @orig Mover+0x2e
    timerPeriod: i16 = 0,
    // @orig Mover+0x30
    moving: i16 = 0,
};

/// Player2D part (struct `Player2D` +0x40; the cannon's).
pub const Player2dPart = struct {
    // @orig Player2D+0x40 (4 from createPlayer; cannon_lose_life: 0 loses)
    lives: i16 = 0,
    // @orig Player2D+0x42 (+10 per invader, +50 per saucer; never read:
    // NOITE gets `g_score`)
    score: i32 = 0,
};

/// Cannon part (struct `Cannon`, own fields from 0x46).
pub const CannonPart = struct {
    // @orig Cannon+0x46 (-1 idle, else the explosion's frame count;
    // BUGS.md I2)
    hitFrame: i16 = 0,
    // @orig Cannon+0x48 (no access found)
    unk48: u16 = 0,
};

/// Saucer part (struct `Saucer`, own fields from 0x40).
pub const SaucerPart = struct {
    // @orig Saucer+0x40 (1 from the ctor, cleared when the saucer leaves;
    // read only by saucer_check_edge's dead left-edge branch)
    unk40: i16 = 0,
    // @orig Saucer+0x42..0x4a (no access found)
    unk42: [5]u16 = @splat(0),
    // @orig Saucer+0x4c (the launch timer, 0xe)
    timer2Id: i16 = 0,
    // @orig Saucer+0x4e (-1 idle, else the explosion's frame count)
    hitFrame: i16 = 0,
};

/// Missile part (struct `Missile`, own fields from 0x40; the Bombs' and
/// the Shot's: Bomb and Shot add only their vtordisp).
pub const MissilePart = struct {
    // @orig Missile+0x40 (no access found)
    unk40: u16 = 0,
    // @orig Missile+0x42 (never written nor read: the creators' writes go
    // through the still-null object pointers, BUGS.md INV Harmless)
    unk42: i16 = 0,
    // @orig Missile+0x44 (bomb 0's drop timer, 8)
    timer2Id: i16 = 0,
    // @orig Missile+0x46 (bomb 1's drop timer, 9)
    timer2IdB: i16 = 0,
    // @orig Missile+0x48
    hitFrame: i16 = 0,
    // @orig Missile+0x4a (the class of what blocked the last step: '1'
    // shot, '2' invader, '3' saucer, '4' cannon, '5' bomb, 0 none; never
    // initialised: LocalAlloc does not clear, the port starts it at 0)
    hitState: u8 = 0,
};

/// One invader of a column (struct `InvaderCell`, 6).
pub const InvaderCell = struct {
    // @orig InvaderCell+0x0
    x: i16 = 0,
    // @orig InvaderCell+0x2
    y: i16 = 0,
    // @orig InvaderCell+0x4
    alive: i16 = 0,
};

/// InvaderColumn / InvaderExplosion part (structs `InvaderColumn`,
/// `InvaderExplosion`, own fields from 0x40; the explosion shares the
/// column's slot overrides, so it carries the column's fields, unused).
pub const InvaderPart = struct {
    // @orig InvaderColumn+0x40 (1 once it reached the cannon row)
    landed: i16 = 0,
    // @orig InvaderColumn+0x42 (1 until the formation's first reversal:
    // the left-edge test is off)
    firstPass: i16 = 0,
    // @orig InvaderColumn+0x44 (read and cleared by the formation step)
    atEdge: i16 = 0,
    // @orig InvaderColumn+0x46 (the bottom live cell, -1 when empty)
    lowestAlive: i16 = 0,
    // @orig InvaderColumn+0x48 (2 right, 1 left)
    direction: i16 = 0,
    // @orig InvaderColumn+0x4a (no access found)
    unk4A: u16 = 0,
    // @orig InvaderColumn+0x4c (invader_column_can_step's blocker class,
    // never read)
    hitState: u8 = 0,
    // @orig InvaderColumn+0x52 (the column's five invaders, 44 px apart)
    cells: [5]InvaderCell = @splat(.{}),
    // @orig InvaderExplosion+0x4e
    frameCounter: i16 = 0,
};

/// Portable part (struct `Portable`, own fields from 0x32). No Portable is
/// ever constructed; `game_input`'s pick-up and drop paths take it.
pub const PortablePart = struct {
    // @orig Portable+0x32
    owner: ?*Object = null,
    // @orig Portable+0x34 (the ctor strncpy's 0x13 bytes, NUL at +0x47)
    prevSceneName: [20]u8 = @splat(0),
    // @orig Portable+0x4a
    icon: ?*Dib = null,
    // @orig Portable+0x50
    iconW: i16 = 0,
    // @orig Portable+0x52
    iconH: i16 = 0,
};

/// ControlPanel part (struct `ControlPanel`, own fields from 0xe).
pub const ControlPanelPart = struct {
    // @orig ControlPanel+0xe
    isOpen: i16 = 0,
    // @orig ControlPanel+0x10
    slideDir: i16 = 0,
    // @orig ControlPanel+0x12
    slideStepsLeft: i16 = 0,
    // @orig ControlPanel+0x14
    textColor: u32 = 0,
    // @orig ControlPanel+0x18
    text: [200]u8 = @splat(0),
    // @orig ControlPanel+0xe0
    textX: i16 = 0,
};

/// StatusBar part (struct `StatusBar`, own fields from 0x46c).
pub const StatusBarPart = struct {
    // @orig StatusBar+0x46c
    textColor: u32 = 0,
    // @orig StatusBar+0x470
    text: [200]u8 = @splat(0),
    // @orig StatusBar+0x538
    textX: i16 = 0,
};

pub const Object = struct {
    kind: Kind,

    // ---- SceneObject (every kind) ----
    // @orig SceneObject+0x2
    next: ?*Object = null,
    // @orig SceneObject+0x4
    prev: ?*Object = null,
    // @orig SceneObject+0x6
    ownerList: ?*ObjectList = null,
    // @orig SceneObject+0x8
    unk08: u16 = 0,
    // @orig SceneObject+0xa
    x: i16 = 0,
    // @orig SceneObject+0xc
    y: i16 = 0,
    // @orig SceneObject+0xe
    id: i16 = 0,
    // @orig SceneObject+0x10..0x12 (unknown)
    unk10: [2]u16 = @splat(0),
    // @orig SceneObject+0x14 (+0x16 stripCount = frames.len)
    frames: []Frame = &.{},
    // @orig SceneObject+0x18 (1: the cannon's, the saucer's or a bomb's
    // explosion strip)
    curStrip: i16 = 0,
    // @orig SceneObject+0x1a (the shot's 1 is its blank frame)
    curFrame: i16 = 0,
    // @orig SceneObject+0x1c
    bmiHeader: BitmapInfoHeader = .{},
    // @orig SceneObject+0x448
    dibFormatOk: i32 = 0,
    // @orig SceneObject+0x44c
    visible: i16 = 0,
    // @orig SceneObject+0x44e
    attached: i16 = 0,
    // @orig SceneObject+0x450
    linked: ?*Object = null,
    // @orig SceneObject+0x452
    unk452: u16 = 0,
    // @orig SceneObject+0x454
    queued: i16 = 0,
    // @orig SceneObject+0x456
    queueIndex: i16 = 0,
    // @orig SceneObject+0x458
    nextX: i16 = 0,
    // @orig SceneObject+0x45a
    nextY: i16 = 0,
    // @orig SceneObject+0x45c (x, y, w, h)
    dirty: Rect = .{},
    // @orig SceneObject+0x464 (x, y, w, h)
    clip: Rect = .{},
    // No counterpart: bmiColors (+0x44) and hpalette (+0x444), copied from
    // the backdrop by attach (the units decide whether a reader needs them).

    o3d: Object3dPart = .{},
    anim: AnimationPart = .{},
    mover: MoverPart = .{},
    player2d: Player2dPart = .{},
    cannon: CannonPart = .{},
    saucer: SaucerPart = .{},
    missile: MissilePart = .{},
    invader: InvaderPart = .{},
    portable: PortablePart = .{},
    panel: ControlPanelPart = .{},
    status: StatusBarPart = .{},

    /// The original's `asX` downcasts: the object if it is one, else null.
    pub fn as(obj: *Object, class: Class) ?*Object {
        return if (obj.is(class)) obj else null;
    }

    /// The original's `isX` type tests (the overrides in the eight live
    /// SceneObject tables).
    pub fn is(obj: *const Object, class: Class) bool {
        const k = obj.kind;
        return switch (class) {
            .player, .cannon => k == .cannon,
            .mover, .actor2d => k != .control_panel and k != .status_bar,
            .animation => k != .status_bar,
            .object3d, .control_panel => k == .control_panel,
            .status_bar => k == .status_bar,
            .shot => k == .shot,
            .invader => k == .invader_column or k == .invader_explosion,
            .saucer => k == .saucer,
            .bomb => k == .bomb,
            .directional_player, .portable, .exit => false,
        };
    }
};

test "type tests follow the live vtables" {
    var o: Object = .{ .kind = .cannon };
    try std.testing.expect(o.is(.player) and o.is(.cannon) and o.is(.mover) and o.is(.animation) and !o.is(.saucer));
    o.kind = .saucer;
    try std.testing.expect(o.is(.saucer) and o.is(.actor2d) and !o.is(.player) and !o.is(.bomb));
    o.kind = .bomb;
    try std.testing.expect(o.is(.bomb) and o.is(.mover) and !o.is(.shot));
    o.kind = .invader_explosion;
    try std.testing.expect(o.is(.invader) and o.is(.actor2d) and !o.is(.player));
    o.kind = .control_panel;
    try std.testing.expect(o.as(.object3d) != null and o.as(.mover) == null and o.is(.animation));
    o.kind = .status_bar;
    try std.testing.expect(!o.is(.animation) and o.is(.status_bar));
}
