//! SAUNA's flattened object model (docs/sauna/DESIGN.md "Object model").
//! SAUNA is TIRO's engine built large model: far data, so the layouts are
//! NOITE's far ones (`SceneObject.x` at +0x12); `@orig` cites SAUNA's
//! `Struct+offset` (Ghidra category `/sauna`, docs/sauna/DATA.md).
//!
//! Four kinds are instantiated: Pacman (← Player2D ← Actor2D ← Mover +
//! Animation, the player `g_pacman`), the four Ghosts (← Actor2D), the two
//! dot pictures (plain SceneObjects: `g_peanut`, `g_cork`) and the
//! ControlPanel (← Animated3D ← Animation + Object3D, concrete: SAUNA has no
//! panel subclass). Mover, Animation, Actor2D, Player2D, Animated3D,
//! Moveable, Portable, Actor, Player, Exit, DirectionalPlayer and StatusBar
//! are never constructed on their own (docs/sauna/FUNCTIONS.md). Every
//! object carries every part; `kind` says which are live.
//!
//! Data only: the functions live in the units (src/sauna/).

const std = @import("std");
const noite_object = @import("../../core/object.zig");

/// Win16 data types, shared with NOITE (memory-model independent).
pub const Dib = noite_object.Dib;
pub const BitmapInfoHeader = noite_object.BitmapInfoHeader;
pub const RgbQuad = noite_object.RgbQuad;
pub const Rect = noite_object.Rect;

pub const Kind = enum(u8) {
    /// Pacman (the player `g_pacman`; vtables 80f6/80fe/8116).
    pacman,
    /// Ghost (`SaunaScene.ghosts[0..3]`; vtables 9a90/9a9c/9ab4).
    ghost,
    /// A plain SceneObject (vtable 41fc): the peanut and cork pictures
    /// (`g_peanut`, `g_cork`), stamped into the backdrop, never attached.
    dot,
    /// ControlPanel (vtables 7f0c/7f44/80cc): built at y 592, below the
    /// window, never seen.
    control_panel,
};

/// What `Object.is`/`as` test for: SceneObject slots 40–53 and 59/5A, by
/// the overrides of the four live tables. `scroll_target` is
/// `isScrollTarget`/`slot43` (Player2D's, so Pacman's). Pacman is **not**
/// a `player` (Player2D keeps SceneObject's `isPlayer`).
pub const Class = enum { scroll_target, player, directional_player, animation, mover, actor2d, object3d, status_bar, control_panel, portable, exit };

/// One frame cell (struct `FrameCell`, 8 bytes): allocated and
/// constructed per strip (`frame_cell_ctor`), read by `frame_get_cell`,
/// `frame_cell_x/y`.
pub const FrameCell = struct {
    // @orig FrameCell+0x0
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

/// Object3D part (struct `Object3D`, 0x1e; the ControlPanel's).
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

/// Animation part (struct `Animation`, 0x16; Actor2D+0x36 in Pacman and
/// the Ghosts, the ControlPanel's first part).
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
    // @orig Animation+0x12 (unknown)
    unk12: u16 = 0,
    // @orig Animation+0x14 (set by `animation_set_avi`; never called on a
    // live object, so 0)
    isAvi: i16 = 0,
};

/// Mover part (struct `Mover`, 0x36; Pacman's and the Ghosts').
pub const MoverPart = struct {
    // @orig Mover+0x8..0xa (unknown)
    unk08: [2]u16 = @splat(0),
    // @orig Mover+0xc (the edge code of moveToEdge: 1 left, 2 right, 4 up, 8 down)
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
    // @orig Mover+0x30 (Pacman 0x10, every Ghost 0x11)
    timerId: i16 = 0,
    // @orig Mover+0x32 (55 ms)
    timerPeriod: i16 = 0,
    // @orig Mover+0x34
    moving: i16 = 0,
};

/// Player2D part (struct `Player2D` +0x4c; Pacman's). Unused: the game
/// keeps `g_lives` and `g_score`.
pub const Player2dPart = struct {
    // @orig Player2D+0x4c
    lives: i16 = 0,
    // @orig Player2D+0x4e
    score: i32 = 0,
};

/// Portable part (struct `Portable`, own fields from 0x36). No Portable is
/// ever constructed; `game_input`'s pick-up and drop paths take it.
pub const PortablePart = struct {
    // @orig Portable+0x36
    owner: ?*Object = null,
    // @orig Portable+0x3a
    icon: ?*Dib = null,
    // @orig Portable+0x3e
    iconPath: []const u8 = "",
    // @orig Portable+0x42
    iconW: i16 = 0,
    // @orig Portable+0x44
    iconH: i16 = 0,
};

/// ControlPanel part (struct `ControlPanel`, own fields from 0x16).
pub const ControlPanelPart = struct {
    // @orig ControlPanel+0x16
    isOpen: i16 = 0,
    // @orig ControlPanel+0x18
    slideDir: i16 = 0,
    // @orig ControlPanel+0x1a
    slideStepsLeft: i16 = 0,
    // @orig ControlPanel+0x1c
    textColor: u32 = 0,
    // @orig ControlPanel+0x20
    text: [200]u8 = @splat(0),
    // @orig ControlPanel+0xe8
    textX: i16 = 0,
};

pub const Object = struct {
    kind: Kind,

    // ---- SceneObject (every kind; NOITE's far layout) ----
    // @orig SceneObject+0x4
    next: ?*Object = null,
    // @orig SceneObject+0x8
    prev: ?*Object = null,
    // @orig SceneObject+0xc
    ownerList: ?*ObjectList = null,
    // @orig SceneObject+0x10 (unknown)
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
    // @orig SceneObject+0x22 (Pacman: direction strip 0-3 + g_powerStrip,
    // 8 the death; a Ghost: direction strip 0-3 + g_powerStrip)
    curStrip: i16 = 0,
    // @orig SceneObject+0x24
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
    // @orig SceneObject+0x45e (unknown)
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
    // @orig SceneObject+0x478 (char[22])
    sceneName: [22]u8 = @splat(0),
    // @orig SceneObject+0x48e
    wave: ?*anyopaque = null,
    // @orig SceneObject+0x492 (unknown)
    unk492: u16 = 0,
    // @orig SceneObject+0x494 (`enableRle` is never called: always 0, the
    // RLE path is dead)
    rleMode: u16 = 0,
    // @orig SceneObject+0x49a
    playOnceRewinds: u16 = 0,
    // No counterpart: bmiColors (+0x4e) and hpalette (+0x44e), copied from
    // the backdrop by attach (the units decide whether a reader needs
    // them); rleBits (+0x496, the dead RLE path).

    o3d: Object3dPart = .{},
    anim: AnimationPart = .{},
    mover: MoverPart = .{},
    player2d: Player2dPart = .{},
    portable: PortablePart = .{},
    panel: ControlPanelPart = .{},

    /// The original's `asX` downcasts: the object if it is one, else null.
    pub fn as(obj: *Object, class: Class) ?*Object {
        return if (obj.is(class)) obj else null;
    }

    /// The original's `isX` type tests (the overrides in the four live
    /// SceneObject tables).
    pub fn is(obj: *const Object, class: Class) bool {
        const k = obj.kind;
        return switch (class) {
            .scroll_target => k == .pacman,
            .mover, .actor2d => k == .pacman or k == .ghost,
            .animation => k != .dot,
            .object3d, .control_panel => k == .control_panel,
            .player, .directional_player, .status_bar, .portable, .exit => false,
        };
    }
};

test "type tests follow the live vtables" {
    var o: Object = .{ .kind = .pacman };
    try std.testing.expect(o.is(.scroll_target) and o.is(.mover) and o.is(.animation) and !o.is(.player));
    o.kind = .ghost;
    try std.testing.expect(o.is(.actor2d) and !o.is(.scroll_target) and !o.is(.object3d));
    o.kind = .dot;
    try std.testing.expect(!o.is(.animation) and o.as(.mover) == null);
    o.kind = .control_panel;
    try std.testing.expect(o.as(.object3d) != null and o.as(.mover) == null and o.is(.animation));
}
