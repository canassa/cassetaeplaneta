//! INFERNO's engine data other than objects: scene, backdrop, occupancy
//! grid, update list, conditions. INFERNO's layouts (large model,
//! docs/inferno/DATA.md §4) and capacities; data only (the functions are in
//! the units named). There is no draw list: INFERNO links no draw-list
//! module.

const std = @import("std");
const object = @import("object.zig");
const Object = object.Object;
const ObjectList = object.ObjectList;
const Dib = object.Dib;
const BitmapInfoHeader = object.BitmapInfoHeader;
const RgbQuad = object.RgbQuad;
const Surface = @import("../../platform/platform.zig").Surface;

pub const max_exits = 10;
/// The update list holds 30 (NOITE's 100), as TIRO's.
pub const max_update = 30;
pub const grid_rows = 65;
pub const grid_cols = 81;

/// The scene (struct `Scene`, 0x50; Scene + InfernoScene flattened: only
/// InfernoScene is instantiated, with hasPlayer 1, hasStatusBar 0,
/// hasControlPanel 0). Functions: units `scene`, `hell` (its handler,
/// createScreen and create).
pub const Scene = struct {
    // @orig Scene+0x4
    backdrop: ?*Backdrop = null,
    // @orig Scene+0x8
    exits: [max_exits]?*Object = @splat(null),
    // @orig Scene+0x30
    exitCount: i16 = 0,
    // @orig Scene+0x32
    name: [20]u8 = @splat(0),
    // @orig Scene+0x46
    objects: ObjectList = .{},
    // @orig Scene+0x4a
    hasPlayer: i16 = 0,
    // @orig Scene+0x4c
    hasStatusBar: i16 = 0,
    // @orig Scene+0x4e
    hasControlPanel: i16 = 0,
};

/// The scene's offscreen view: Backdrop + GridBackdrop + InfernoBackdrop
/// flattened (only InfernoBackdrop is instantiated). Functions: unit
/// `backdrop` (InfernoBackdrop's `create` too: the floor wall).
///
/// One WinG bitmap, as TIRO's and NOITE's: `pixels` (+0x6, its DC +0x4),
/// the whole background, `bgWidth` × `bgHeight`, 8 bpp, rows padded to 4,
/// described by `bmiHeader`. The pixel contract is NOITE's
/// (docs/DESIGN.md "Backdrop, pixels and palette"): read and write it
/// through `surface()` or `dib.copy*`. No counterpart: the DC, `hpalette`
/// (+0xa, = `bmiColors`), the old bitmap (+0xc).
pub const Backdrop = struct {
    // @orig Backdrop+0x6
    pixels: []u8 = &.{},
    // @orig Backdrop+0xe
    background: ?*Dib = null,
    // @orig Backdrop+0x12
    bgWidth: i16 = 0,
    // @orig Backdrop+0x14
    bgHeight: i16 = 0,
    // @orig Backdrop+0x16
    originX: i16 = 0,
    // @orig Backdrop+0x18
    originY: i16 = 0,
    // @orig Backdrop+0x1a
    viewWidth: i16 = 0,
    // @orig Backdrop+0x1c
    viewHeight: i16 = 0,
    // @orig Backdrop+0x1e (unknown)
    unk1E: u16 = 0,
    // @orig Backdrop+0x20 (unknown)
    unk20: u16 = 0,
    // @orig Backdrop+0x22
    bmiHeader: BitmapInfoHeader = .{},
    // @orig Backdrop+0x4a (the same colours as the logical palette)
    bmiColors: [256]RgbQuad = @splat(.{}),
    // @orig Backdrop+0x44a
    dibOrientation: i32 = 1,
    // @orig Backdrop+0x44e
    sceneList: ?*ObjectList = null,
    // @orig GridBackdrop+0x452
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

/// The backdrop's rectangle query's result (as NOITE's `world.RectQuery`;
/// INFERNO has no queryRectFirst, so `first` stays null).
pub const RectQuery = struct {
    result: i8 = 0,
    flag: i8 = 0,
    obj: ?*Object = null,
    first: ?*Object = null,
};

/// The occupancy grid (struct `OccupancyGrid`, 0x10). The cells are the
/// DGROUP matrices `g_occupancyCount` / `g_occupancyObject` (`Occupancy`,
/// `Game.occupancy`).
pub const OccupancyGrid = struct {
    // @orig OccupancyGrid+0x0
    lastCellObject: ?*Object = null,
    // @orig OccupancyGrid+0x4
    firstObject: ?*Object = null,
    // @orig OccupancyGrid+0x8
    rowCount: i16 = 0,
    // @orig OccupancyGrid+0xa
    colCount: i16 = 0,
    // @orig OccupancyGrid+0xc (a byte)
    rowShift: i16 = 0,
    // @orig OccupancyGrid+0xe (a byte)
    colShift: i16 = 0,
};

/// The occupancy matrix (65 rows × 81 columns): count 0 free, > 0
/// occupants, -1 (0xff) blocked: INFERNO's floor wall, row 23 written for
/// columns 0-89 (the last 9 land on row 24: BUGS.md "Harmless (INFERNO)").
pub const Occupancy = struct {
    // @orig g_occupancyCount
    count: [grid_rows][grid_cols]i8 = @splat(@splat(0)),
    // @orig g_occupancyObject
    object: [grid_rows][grid_cols]?*Object = @splat(@splat(null)),
};

/// Objects to blit to the screen (struct `UpdateList`, 30 items, count at
/// +0x78). Unit `lists`.
pub const UpdateList = struct {
    // @orig UpdateList+0x0
    items: [max_update]?*Object = @splat(null),
    // @orig UpdateList+0x78
    count: i16 = 0,
};

/// Exit conditions: FlagCondition (CompoundCondition is never built: its
/// two factories have no caller). Functions: unit `game`.
pub const Condition = struct {
    kind: enum { base, flag } = .base,
    // @orig FlagCondition+0x4
    value: i16 = 0,
};
