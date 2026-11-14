//! ENCAIXE's flattened object model (docs/encaixe/DESIGN.md "Object
//! model"). ENCAIXE's own layouts (small model: near 2-byte pointers, so
//! every offset differs from NOITE's); `@orig` cites ENCAIXE's
//! `Struct+offset` (Ghidra category `/encaixe`).
//!
//! Three classes are instantiated: the falling piece (Piece ← Player2D ←
//! Actor2D ← Mover + Animation, no Object3D), the TetrisPanel (←
//! ControlPanel ← Animated3D ← Animation + Object3D) and the StatusBar.
//! Mover, Animation, Animated3D, Moveable, Portable, Actor, Player, Exit
//! are never constructed (BUGS.md E-section, docs/encaixe/FUNCTIONS.md).
//! Every object carries every part; `kind` says which are live.
//!
//! Data only: the functions live in the units (src/encaixe/).

const std = @import("std");
const noite_object = @import("../../core/object.zig");

/// Win16 data types, shared with NOITE (memory-model independent).
pub const Dib = noite_object.Dib;
pub const BitmapInfoHeader = noite_object.BitmapInfoHeader;
pub const RgbQuad = noite_object.RgbQuad;
pub const Rect = noite_object.Rect;

pub const Kind = enum(u8) {
    /// Piece (the player object `g_piece`; vtables 0f8a/0f90/0f92).
    piece,
    /// TetrisPanel (vtables 0b0e/0b20/0bda): created and attached, never shown.
    control_panel,
    /// StatusBar (vtable 0dc2): created and attached, never shown.
    status_bar,
};

/// What `Object.is`/`as` test for: SceneObject slots 3C–4D (and 54/55),
/// by the overrides of the three live tables.
pub const Class = enum { player, directional_player, animation, mover, actor2d, object3d, status_bar, control_panel, portable, exit };

/// One frame cell (struct `FrameCell`, 8 bytes): allocated and
/// constructed per strip, read only by `frame_get_cell`; layout unknown.
pub const FrameCell = struct {
    // @orig FrameCell+0x0
    raw: [8]u8 = @splat(0),
};

/// One bitmap strip (struct `Frame`, 0x16; ENCAIXE's has a vtable,
/// `FrameVtbl.getCell`, unlike NOITE's).
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

/// Object3D part (struct `Object3D`, 0x16; the TetrisPanel's).
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

/// Animation part (struct `Animation`, 0xe).
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

/// Mover part (struct `Mover`, 0x32; `allowOffscreen` is gone).
pub const MoverPart = struct {
    // @orig Mover+0x4..0x6 (unknown)
    unk04: [2]u16 = @splat(0),
    // @orig Mover+0x8 (1 left, 2 right, 4 rotate, 8 down for the piece)
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

/// Player2D part (struct `Player2D` +0x40).
pub const Player2dPart = struct {
    // @orig Player2D+0x40
    lives: i16 = 0,
    // @orig Player2D+0x42
    score: i32 = 0,
};

/// Piece part (struct `Piece`, own fields from 0x48): the board lives in
/// the player object. `board[col][row]`, 11 columns × 14 rows, cells
/// `'0'`/`'1'` (docs/encaixe/GAME.md "Board"). +0xf2–0x108 are written only
/// by the dead `te_piece_calc_shape_rects` (no field).
pub const PiecePart = struct {
    pub const columns = 11;
    pub const rows = 14;
    // @orig Piece+0x48 (written, never tested)
    unk48: u16 = 0,
    // @orig Piece+0x4a
    canFall: u16 = 0,
    // @orig Piece+0x4c (unknown)
    unk4C: u16 = 0,
    // @orig Piece+0x4e (written, never tested)
    unk4E: u16 = 0,
    // @orig Piece+0x50
    linesCleared: u16 = 0,
    // @orig Piece+0x52 (column-major; reach it through `cell`)
    board: [columns][rows]u8 = @splat(@splat('0')),
    // @orig Piece+0xec
    column: i16 = 0,
    // @orig Piece+0xee
    row: i16 = 0,
    // @orig Piece+0xf0
    rightCol: i16 = 0,

    /// `board[col][row]` the way the original addresses it: one flat
    /// `col * 14 + row` byte, so row 14 is the next column's row 0 (BUGS.md
    /// E2). Past the board's 154 bytes would be `column`, which no valid
    /// position reaches: a panic naming E2.
    pub fn cell(p: *PiecePart, col: i16, row: i16) *u8 {
        const i = @as(i32, col) * rows + row;
        if (i < 0 or i >= columns * rows) @panic("E2: a board write outside Piece.board");
        const flat: *[columns * rows]u8 = @ptrCast(&p.board);
        return &flat[@intCast(i)];
    }
};

/// Portable part (struct `Portable`, own fields from 0x32). No Portable is
/// ever constructed; `game_input`'s pick-up and drop paths take it.
pub const PortablePart = struct {
    // @orig Portable+0x32
    owner: ?*Object = null,
    // @orig Portable+0x34
    prevSceneName: [19]u8 = @splat(0),
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
    // @orig SceneObject+0x18 (the piece's kind, 0-5)
    curStrip: i16 = 0,
    // @orig SceneObject+0x1a (the piece's rotation, 0-3)
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
    piece: PiecePart = .{},
    portable: PortablePart = .{},
    panel: ControlPanelPart = .{},
    status: StatusBarPart = .{},

    /// The original's `asX` downcasts: the object if it is one, else null.
    pub fn as(obj: *Object, class: Class) ?*Object {
        return if (obj.is(class)) obj else null;
    }

    /// The original's `isX` type tests (the overrides in the three live
    /// SceneObject tables).
    pub fn is(obj: *const Object, class: Class) bool {
        const k = obj.kind;
        return switch (class) {
            .player, .mover, .actor2d => k == .piece,
            .animation => k == .piece or k == .control_panel,
            .object3d, .control_panel => k == .control_panel,
            .status_bar => k == .status_bar,
            .directional_player, .portable, .exit => false,
        };
    }
};

test "type tests follow the live vtables" {
    var o: Object = .{ .kind = .piece };
    try std.testing.expect(o.is(.player) and o.is(.mover) and o.is(.animation) and !o.is(.object3d));
    o.kind = .control_panel;
    try std.testing.expect(o.as(.object3d) != null and o.as(.mover) == null and o.is(.animation));
    o.kind = .status_bar;
    try std.testing.expect(!o.is(.animation) and o.is(.status_bar));
}
