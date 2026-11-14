//! ENCAIXE's engine data other than objects: scene, backdrop, occupancy
//! grid, draw and update lists, conditions. ENCAIXE's layouts and
//! capacities; data only (the functions are in the units named).

const std = @import("std");
const object = @import("object.zig");
const Object = object.Object;
const ObjectList = object.ObjectList;
const Dib = object.Dib;
const BitmapInfoHeader = object.BitmapInfoHeader;
const RgbQuad = object.RgbQuad;
const Surface = @import("../../platform/platform.zig").Surface;

pub const max_exits = 10;
pub const max_draw_nodes = 100;
/// ENCAIXE's update list holds 30 (NOITE's 100).
pub const max_update = 30;
pub const grid_rows = 65;
pub const grid_cols = 81;

/// The scene (Scene + TetrisScene flattened: only TetrisScene is
/// instantiated). Functions: units `scene`, `tetris` (its handler,
/// createScreen and create).
pub const Scene = struct {
    // @orig Scene+0x2
    backdrop: ?*Backdrop = null,
    // @orig Scene+0x4
    exits: [max_exits]?*Object = @splat(null),
    // @orig Scene+0x18
    exitCount: i16 = 0,
    // @orig Scene+0x1a
    name: [20]u8 = @splat(0),
    // @orig Scene+0x2e
    objects: ObjectList = .{},
    // @orig Scene+0x34
    hasPlayer: i16 = 0,
    // @orig Scene+0x36
    hasStatusBar: i16 = 0,
    // @orig Scene+0x38
    hasControlPanel: i16 = 0,
    // @orig Scene+0x3a
    is1Animation: i16 = 0,
    // @orig Scene+0x3c
    isClickExit: i16 = 0,
    // @orig Scene+0x3e
    animation: ?*Object = null,
    // @orig Scene+0x40
    mayDropObject: i16 = 0,
    // @orig Scene+0x42
    sceneNumber: i16 = 0,
};

/// The scene's offscreen view: Backdrop + GridBackdrop + TetrisBackdrop
/// flattened (only TetrisBackdrop is instantiated). Functions: unit
/// `backdrop` (and `tetris` for TetrisBackdrop's `create`).
///
/// ENCAIXE's backdrop has **two** WinG bitmaps (NOITE's has one): `pixels`
/// (+0x4, its DC +0x2) and `pixels2` (+0x10, DC +0xe). Both are the whole
/// background, `bgWidth` × `bgHeight`, 8 bpp, rows padded to 4, described
/// by `bmiHeader`; the score and the row clear draw on both. The pixel
/// contract is NOITE's (docs/DESIGN.md "Backdrop, pixels and palette"):
/// read and write them through `surface()` / `surface2()` or `dib.copy*`.
/// No counterpart: the DCs, `hpalette` (+0x8, = `bmiColors`), the old
/// bitmaps (+0xa, +0xc).
pub const Backdrop = struct {
    // @orig Backdrop+0x4
    pixels: []u8 = &.{},
    // @orig Backdrop+0x10
    pixels2: []u8 = &.{},
    // @orig Backdrop+0x14
    background: ?*Dib = null,
    // @orig Backdrop+0x18
    bgWidth: i16 = 0,
    // @orig Backdrop+0x1a
    bgHeight: i16 = 0,
    // @orig Backdrop+0x1c
    originX: i16 = 0,
    // @orig Backdrop+0x1e
    originY: i16 = 0,
    // @orig Backdrop+0x20
    viewWidth: i16 = 0,
    // @orig Backdrop+0x22
    viewHeight: i16 = 0,
    // @orig Backdrop+0x24 (unknown)
    unk24: u16 = 0,
    // @orig Backdrop+0x26 (unknown)
    unk26: u16 = 0,
    // @orig Backdrop+0x28
    bmiHeader: BitmapInfoHeader = .{},
    // @orig Backdrop+0x50 (the same colours as the logical palette)
    bmiColors: [256]RgbQuad = @splat(.{}),
    // @orig Backdrop+0x450
    dibOrientation: i32 = 1,
    // @orig Backdrop+0x454
    sceneList: ?*ObjectList = null,
    // @orig GridBackdrop+0x456
    grid: ?*OccupancyGrid = null,

    /// The first WinG bitmap as the platform's `Surface`.
    pub fn surface(bd: *const Backdrop) Surface {
        return bd.surfaceOf(bd.pixels);
    }

    /// The second WinG bitmap (+0x10) as a `Surface`.
    pub fn surface2(bd: *const Backdrop) Surface {
        return bd.surfaceOf(bd.pixels2);
    }

    fn surfaceOf(bd: *const Backdrop, px: []u8) Surface {
        return .{
            .pixels = px,
            .width = @bitCast(bd.bgWidth),
            .height = @bitCast(bd.bgHeight),
            .bottom_up = bd.dibOrientation > 0,
            .colors = &bd.bmiColors,
        };
    }
};

/// The backdrop's rectangle queries' result (as NOITE's `world.RectQuery`).
pub const RectQuery = struct {
    result: i8 = 0,
    flag: i8 = 0,
    obj: ?*Object = null,
    first: ?*Object = null,
};

/// The occupancy grid (struct `OccupancyGrid`, 0xc). The cells are the
/// DGROUP matrices `g_occupancyCount` / `g_occupancyObject` (`Occupancy`,
/// `Game.occupancy`). TetrisBackdrop's grid has 32-px cells (shift 5).
pub const OccupancyGrid = struct {
    // @orig OccupancyGrid+0x0
    lastCellObject: ?*Object = null,
    // @orig OccupancyGrid+0x2
    firstObject: ?*Object = null,
    // @orig OccupancyGrid+0x4
    rowCount: i16 = 0,
    // @orig OccupancyGrid+0x6
    colCount: i16 = 0,
    // @orig OccupancyGrid+0x8
    rowShift: i16 = 0,
    // @orig OccupancyGrid+0xa
    colShift: i16 = 0,
};

/// The occupancy matrix (65 rows × 81 columns): count 0 free, > 0
/// occupants, -1 blocked (the wall cells, BUGS.md E9).
pub const Occupancy = struct {
    // @orig g_occupancyCount
    count: [grid_rows][grid_cols]i8 = @splat(@splat(0)),
    // @orig g_occupancyObject
    object: [grid_rows][grid_cols]?*Object = @splat(@splat(null)),
};

/// Sorted draw list (struct `DrawList`, 100 nodes). Unit `lists`.
pub const DrawList = struct {
    // @orig DrawList+0x0
    nodes: [max_draw_nodes]DrawListNode = @splat(.{}),
    // @orig DrawList+0x258
    freeHead: ?*DrawListNode = null,
    // @orig DrawList+0x25a
    head: ?*DrawListNode = null,
};

pub const DrawListNode = struct {
    // @orig DrawListNode+0x0
    item: ?*Object = null,
    // @orig DrawListNode+0x2
    prev: ?*DrawListNode = null,
    // @orig DrawListNode+0x4
    next: ?*DrawListNode = null,
};

/// Objects to blit to the screen (struct `UpdateList`, 30 items). ENCAIXE
/// has no update-list functions: the code that adds and flushes is
/// inlined at its callers (each unit ports its own copy).
pub const UpdateList = struct {
    // @orig UpdateList+0x0
    items: [max_update]?*Object = @splat(null),
    // @orig UpdateList+0x3c
    count: i16 = 0,
};

/// Exit conditions: FlagCondition (CompoundCondition is never built).
/// Functions: unit `game`.
pub const Condition = struct {
    kind: enum { base, flag } = .base,
    // @orig FlagCondition+0x2
    value: i16 = 0,
};
