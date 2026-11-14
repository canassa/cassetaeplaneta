//! SAUNA's engine data other than objects: scene, backdrop, occupancy
//! grid, draw and update lists, conditions. SAUNA's far layouts and
//! capacities (docs/sauna/DATA.md); data only (the functions are in the
//! units named).

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
/// SAUNA's update list holds 30 (NOITE's 100), as TIRO's.
pub const max_update = 30;
pub const grid_rows = 65;
pub const grid_cols = 81;
pub const ghost_count = 4;

/// The scene (Scene + SaunaScene flattened: only SaunaScene is
/// instantiated). Functions: units `scene` (the Scene methods and the
/// ctor), `maze` (its handler, createScreen and create), `ghost`
/// (sendGhostsHome).
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
    // @orig Scene+0x4e
    hasPlayer: i16 = 0,
    // @orig Scene+0x50
    hasStatusBar: i16 = 0,
    // @orig Scene+0x52
    hasControlPanel: i16 = 0,
    // @orig Scene+0x54
    is1Animation: i16 = 0,
    // @orig Scene+0x56
    isClickExit: i16 = 0,
    // @orig Scene+0x58
    animation: ?*Object = null,
    // @orig Scene+0x5c
    mayDropObject: i16 = 0,
    // @orig Scene+0x5e
    sceneNumber: i16 = 0,
    // @orig Scene+0x60 (set by scene_create; the handler returns 0 while 0)
    handlerEnabled: i16 = 0,

    // ---- SaunaScene ----
    // @orig SaunaScene+0x62 (four Ghosts built with the same arguments)
    ghosts: [ghost_count]?*Object = @splat(null),
    // @orig SaunaScene+0x72 (also g_peanut)
    peanut: ?*Object = null,
    // @orig SaunaScene+0x76 (also g_cork)
    cork: ?*Object = null,
};

/// The scene's offscreen view: Backdrop + GridBackdrop + SaunaBackdrop
/// flattened (only SaunaBackdrop is instantiated). Functions: unit
/// `backdrop` (SaunaBackdrop's `create` too: the maze walls).
///
/// SAUNA's backdrop has **two** WinG bitmaps, as ENCAIXE's: `pixels`
/// (+0x6, its DC +0x4) is the view the sprites are drawn into, `pixels2`
/// (+0x12, DC +0x10) the background with the dots, which `sauna_scene_create`
/// stamps and `pacman_restore_background` clears, and which
/// `restoreBackground` and `unk18` copy from. Both `bgWidth` × `bgHeight`,
/// 8 bpp, rows padded to 4, described by `bmiHeader`. The pixel contract is
/// NOITE's (docs/DESIGN.md "Backdrop, pixels and palette"): read and write
/// through `surface()`/`surface2()` or `dib.copy*`.
/// No counterpart: the DCs, `hpalette` (+0xa, = `bmiColors`), the old
/// bitmaps (+0xc, +0xe), `hwnd` (+0x16, written by the scene handler on
/// every message) and `hdcWindow` (+0x18): the port draws to the screen
/// through the platform.
pub const Backdrop = struct {
    // @orig Backdrop+0x6
    pixels: []u8 = &.{},
    // @orig Backdrop+0x12
    pixels2: []u8 = &.{},
    // @orig Backdrop+0x1a
    background: ?*Dib = null,
    // @orig Backdrop+0x1e
    bgWidth: i16 = 0,
    // @orig Backdrop+0x20
    bgHeight: i16 = 0,
    // @orig Backdrop+0x22
    originX: i16 = 0,
    // @orig Backdrop+0x24
    originY: i16 = 0,
    // @orig Backdrop+0x26
    viewWidth: i16 = 0,
    // @orig Backdrop+0x28
    viewHeight: i16 = 0,
    // @orig Backdrop+0x2a (unknown)
    unk2A: u16 = 0,
    // @orig Backdrop+0x2c (unknown)
    unk2C: u16 = 0,
    // @orig Backdrop+0x2e
    bmiHeader: BitmapInfoHeader = .{},
    // @orig Backdrop+0x56 (the same colours as the logical palette)
    bmiColors: [256]RgbQuad = @splat(.{}),
    // @orig Backdrop+0x456
    dibOrientation: i32 = 1,
    // @orig Backdrop+0x45a
    sceneList: ?*ObjectList = null,
    // @orig GridBackdrop+0x45e
    grid: ?*OccupancyGrid = null,

    /// The first WinG bitmap (+0x6) as the platform's `Surface`.
    pub fn surface(bd: *const Backdrop) Surface {
        return bd.surfaceOf(bd.pixels);
    }

    /// The second WinG bitmap (+0x12, the background with the dots) as a
    /// `Surface`.
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

/// The occupancy grid (struct `OccupancyGrid`, 0x10). The cells are the
/// DGROUP matrices `g_occupancyCount` / `g_occupancyObject` (`Occupancy`,
/// `Game.occupancy`). SaunaBackdrop's grid has 16-px cells (shift 4):
/// one per maze character.
pub const OccupancyGrid = struct {
    // @orig OccupancyGrid+0x0
    lastCellObject: ?*Object = null,
    // @orig OccupancyGrid+0x4
    firstObject: ?*Object = null,
    // @orig OccupancyGrid+0x8
    rowCount: i16 = 0,
    // @orig OccupancyGrid+0xa
    colCount: i16 = 0,
    // @orig OccupancyGrid+0xc
    rowShift: i16 = 0,
    // @orig OccupancyGrid+0xe
    colShift: i16 = 0,
};

/// The occupancy matrix (65 rows × 81 columns): count 0 free, > 0
/// occupants, -1 (0xff) blocked: the maze's `1` cells
/// (`sauna_backdrop_create`). Pacman's and the Ghosts' own occupy/vacate
/// set the count to 1 and 0 and the object to themselves and null
/// (BUGS.md P2).
pub const Occupancy = struct {
    // @orig g_occupancyCount
    count: [grid_rows][grid_cols]i8 = @splat(@splat(0)),
    // @orig g_occupancyObject
    object: [grid_rows][grid_cols]?*Object = @splat(@splat(null)),
};

/// Sorted draw list (struct `DrawList`, 100 nodes). Unit `lists`. (SAUNA
/// links a second, identical draw-list class that nothing uses: dead.)
pub const DrawList = struct {
    // @orig DrawList+0x0
    nodes: [max_draw_nodes]DrawListNode = @splat(.{}),
    // @orig DrawList+0x4b0
    freeHead: ?*DrawListNode = null,
    // @orig DrawList+0x4b4
    head: ?*DrawListNode = null,
};

pub const DrawListNode = struct {
    // @orig DrawListNode+0x0
    item: ?*Object = null,
    // @orig DrawListNode+0x4
    prev: ?*DrawListNode = null,
    // @orig DrawListNode+0x8
    next: ?*DrawListNode = null,
};

/// Objects to blit to the screen (struct `UpdateList`, 30 items), with
/// its own out-of-line functions (`/Od`): unit `lists`.
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

test "the maze grid fits the occupancy matrix" {
    // 30 rows × 40 columns of 16-px cells over the 640×480 window.
    try std.testing.expect(30 <= grid_rows and 40 <= grid_cols);
}
