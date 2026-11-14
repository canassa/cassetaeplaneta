//! TIRO's engine data other than objects: scene, backdrop, occupancy
//! grid, draw and update lists, conditions. TIRO's layouts and
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
/// TIRO's update list holds 30 (NOITE's 100), as ENCAIXE's.
pub const max_update = 30;
pub const grid_rows = 65;
pub const grid_cols = 81;

/// The scene (Scene + TiroScene flattened: only TiroScene is
/// instantiated). Functions: units `scene`, `gallery` (its handler,
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

/// The scene's offscreen view: Backdrop + GridBackdrop + TiroBackdrop
/// flattened (only TiroBackdrop is instantiated). Functions: unit
/// `backdrop` (TiroBackdrop's `create` too: the wall cells).
///
/// TIRO's backdrop has **one** WinG bitmap, as NOITE's (ENCAIXE's has
/// two), so its fields sit 8 bytes lower than ENCAIXE's from +0xc on:
/// `pixels` (+0x4, its DC +0x2), the whole background, `bgWidth` ×
/// `bgHeight`, 8 bpp, rows padded to 4, described by `bmiHeader`. The
/// pixel contract is NOITE's (docs/DESIGN.md "Backdrop, pixels and
/// palette"): read and write it through `surface()` or `dib.copy*`.
/// No counterpart: the DC, `hpalette` (+0x8, = `bmiColors`), the old
/// bitmap (+0xa).
pub const Backdrop = struct {
    // @orig Backdrop+0x4
    pixels: []u8 = &.{},
    // @orig Backdrop+0xc
    background: ?*Dib = null,
    // @orig Backdrop+0x10
    bgWidth: i16 = 0,
    // @orig Backdrop+0x12
    bgHeight: i16 = 0,
    // @orig Backdrop+0x14
    originX: i16 = 0,
    // @orig Backdrop+0x16
    originY: i16 = 0,
    // @orig Backdrop+0x18
    viewWidth: i16 = 0,
    // @orig Backdrop+0x1a
    viewHeight: i16 = 0,
    // @orig Backdrop+0x1c (unknown)
    unk1C: u16 = 0,
    // @orig Backdrop+0x1e (unknown)
    unk1E: u16 = 0,
    // @orig Backdrop+0x20
    bmiHeader: BitmapInfoHeader = .{},
    // @orig Backdrop+0x48 (the same colours as the logical palette)
    bmiColors: [256]RgbQuad = @splat(.{}),
    // @orig Backdrop+0x448
    dibOrientation: i32 = 1,
    // @orig Backdrop+0x44c
    sceneList: ?*ObjectList = null,
    // @orig GridBackdrop+0x44e
    grid: ?*OccupancyGrid = null,

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

/// The backdrop's rectangle queries' result (as NOITE's `world.RectQuery`).
pub const RectQuery = struct {
    result: i8 = 0,
    flag: i8 = 0,
    obj: ?*Object = null,
    first: ?*Object = null,
};

/// The occupancy grid (struct `OccupancyGrid`, 0xc). The cells are the
/// DGROUP matrices `g_occupancyCount` / `g_occupancyObject` (`Occupancy`,
/// `Game.occupancy`). TiroBackdrop's grid has 32-px cells (20 × 15).
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
/// occupants, -1 (0xff) blocked: TIRO's wall cells, columns 0 and 19 for
/// rows 5-13 and row 13 for columns 0-18 (`tiro_backdrop_create`).
pub const Occupancy = struct {
    // @orig g_occupancyCount
    count: [grid_rows][grid_cols]i8 = @splat(@splat(0)),
    // @orig g_occupancyObject
    object: [grid_rows][grid_cols]?*Object = @splat(@splat(null)),
};

/// Sorted draw list (struct `DrawList`, 100 nodes). Unit `lists`. (TIRO
/// links a second, identical draw-list class that nothing uses: dead.)
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

/// Objects to blit to the screen (struct `UpdateList`, 30 items). Unlike
/// ENCAIXE's, TIRO's update list has its own functions (`/Od` keeps them
/// out of line): unit `lists`.
pub const UpdateList = struct {
    // @orig UpdateList+0x0
    items: [max_update]?*Object = @splat(null),
    // @orig UpdateList+0x3c
    count: i16 = 0,
};

/// Exit conditions: FlagCondition (CompoundCondition is never built: its
/// two factories have no caller). Functions: unit `game`.
pub const Condition = struct {
    kind: enum { base, flag } = .base,
    // @orig FlagCondition+0x2
    value: i16 = 0,
};
