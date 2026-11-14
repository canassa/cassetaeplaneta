//! XILINDRO's flattened object model (docs/salgin/DESIGN.md "Object
//! model"). XILINDRO's own layouts (TIRO's medium-model build: the engine structs are
//! TIRO's, offset for offset); `@orig` cites XILINDRO's `Struct+offset`
//! (Ghidra category `/xilindro`).
//!
//! Six classes are instantiated: the Fighter (← Player2D ← Actor2D ← Mover
//! + Animation, the player `g_fighter`), the Opponent, the Banner and the
//! EnergyBar (← Actor2D), the XilindroPanel (← ControlPanel ← Animated3D ←
//! Animation + Object3D) and the StatusBar. Mover, Animation, Actor2D,
//! Player2D, Animated3D, Moveable, Portable, Actor, Player, Exit are never
//! constructed on their own (docs/xilindro/FUNCTIONS.md). Every object
//! carries every part; `kind` says which are live.
//!
//! Data only: the functions live in the units (src/xilindro/).

const std = @import("std");
const noite_object = @import("../../core/object.zig");

/// Win16 data types, shared with NOITE (memory-model independent).
pub const Dib = noite_object.Dib;
pub const BitmapInfoHeader = noite_object.BitmapInfoHeader;
pub const RgbQuad = noite_object.RgbQuad;
pub const Rect = noite_object.Rect;

pub const Kind = enum(u8) {
    /// Fighter (the player `g_fighter`; vtables 18a4/18b0/18b4).
    fighter,
    /// Opponent (`g_opponent`; vtables 1fe0/1fe8/1fec).
    opponent,
    /// Banner (`g_banner`, the PORRADA picture; vtables 2160/2164/2168).
    banner,
    /// EnergyBar (`g_energyBar`, the two energies and the tiles; vtables
    /// 22dc/22e0/22e4).
    energy_bar,
    /// XilindroPanel (vtables 11e2/1206/1372): created and attached, never shown.
    control_panel,
    /// StatusBar (vtable 1aac): created and attached, never shown.
    status_bar,
};

/// What `Object.is`/`as` test for: SceneObject slots 3A–4B, 52/53 and the
/// XILINDRO tests 56 (isFighter, asked by `opponent_can_step`) and 57
/// (isOpponent, asked by `fighter_can_step`), by the overrides of the six
/// live tables.
pub const Class = enum { player, directional_player, animation, mover, actor2d, object3d, status_bar, control_panel, portable, exit, fighter, opponent };

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

/// Object3D part (struct `Object3D`, 0x16; the XilindroPanel's).
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

/// Animation part (struct `Animation`, 0xe; Actor2D+0x32 in the Fighter,
/// the Opponent, the Banner and the EnergyBar). `framesLeft` is the frame
/// count of the current move.
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

/// Mover part (struct `Mover`, 0x32; also the first 0x32 bytes of the
/// flattened Opponent, Banner and EnergyBar). `direction` is the walk's:
/// 1 left, 2 right.
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

/// Player2D part (struct `Player2D` +0x40; the Fighter's).
pub const Player2dPart = struct {
    // @orig Player2D+0x40
    lives: i16 = 0,
    // @orig Player2D+0x42
    score: i32 = 0,
};

/// Fighter part (struct `Fighter`, own fields from 0x46).
pub const FighterPart = struct {
    // @orig Fighter+0x46 (no access found)
    unk46: i16 = 0,
    // @orig Fighter+0x48 (1 while playing a reaction strip from g_reactionTable)
    reacting: i16 = 0,
    // @orig Fighter+0x4a (frames played of the current move)
    moveFrame: i16 = 0,
    // @orig Fighter+0x4c (no access found)
    unk4C: i16 = 0,
    // @orig Fighter+0x4e (fighter_start_timer: 10)
    timerId: i16 = 0,
    // @orig Fighter+0x50 (91 from createPlayer, never written again:
    // BUGS.md X2)
    energy: i16 = 0,
    // @orig Fighter+0x52 ('0', '2' when blocked by the opponent; never read)
    contact: u8 = 0,
};

/// Opponent part (struct `Opponent`, own fields from 0x40).
pub const OpponentPart = struct {
    // @orig Opponent+0x40 (1 from the ctor)
    unk40: i16 = 0,
    // @orig Opponent+0x42
    reacting: i16 = 0,
    // @orig Opponent+0x44
    moveFrame: i16 = 0,
    // @orig Opponent+0x46 (91; lowered by PgUp, Up and Home hits; never read)
    energy: i16 = 0,
    // @orig Opponent+0x48 ('0', '1'; never read)
    contact: u8 = 0,
};

/// EnergyBar part (struct `EnergyBar`, own fields from 0x40): the two
/// energies that decide the round.
pub const EnergyBarPart = struct {
    // @orig EnergyBar+0x40 (0x122: the fighter's tiles grow left from 290)
    leftX: i16 = 0,
    // @orig EnergyBar+0x42 (0x14d: the opponent's grow right from 333)
    rightX: i16 = 0,
    // @orig EnergyBar+0x44
    fighterEnergy: i16 = 0,
    // @orig EnergyBar+0x46
    opponentEnergy: i16 = 0,
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
    // @orig SceneObject+0x18 (a fighter's move: docs/xilindro/GAME.md "The fight")
    curStrip: i16 = 0,
    // @orig SceneObject+0x1a
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
    fighter: FighterPart = .{},
    opponent: OpponentPart = .{},
    energyBar: EnergyBarPart = .{},
    portable: PortablePart = .{},
    panel: ControlPanelPart = .{},
    status: StatusBarPart = .{},

    /// The original's `asX` downcasts: the object if it is one, else null.
    pub fn as(obj: *Object, class: Class) ?*Object {
        return if (obj.is(class)) obj else null;
    }

    /// The original's `isX` type tests (the overrides in the six live
    /// SceneObject tables).
    pub fn is(obj: *const Object, class: Class) bool {
        const k = obj.kind;
        return switch (class) {
            .player, .fighter => k == .fighter,
            .mover, .actor2d => k == .fighter or k == .opponent or k == .banner or k == .energy_bar,
            .animation => k != .status_bar,
            .object3d, .control_panel => k == .control_panel,
            .status_bar => k == .status_bar,
            .opponent => k == .opponent,
            .directional_player, .portable, .exit => false,
        };
    }
};

test "type tests follow the live vtables" {
    var o: Object = .{ .kind = .fighter };
    try std.testing.expect(o.is(.player) and o.is(.fighter) and o.is(.mover) and o.is(.animation) and !o.is(.opponent));
    o.kind = .opponent;
    try std.testing.expect(o.is(.opponent) and o.is(.actor2d) and !o.is(.player) and !o.is(.fighter));
    o.kind = .energy_bar;
    try std.testing.expect(o.is(.mover) and !o.is(.opponent) and !o.is(.player));
    o.kind = .control_panel;
    try std.testing.expect(o.as(.object3d) != null and o.as(.mover) == null and o.is(.animation));
    o.kind = .status_bar;
    try std.testing.expect(!o.is(.animation) and o.is(.status_bar));
}
