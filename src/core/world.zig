//! Engine data structures other than objects: scene, backdrop, occupancy
//! grid, draw and update lists, conditions. Data only (functions are in
//! the units named in each doc comment). Capacities are the original's.

const std = @import("std");
const object = @import("object.zig");
const Object = object.Object;
const ObjectList = object.ObjectList;
const Dib = object.Dib;
const BitmapInfoHeader = object.BitmapInfoHeader;
const RgbQuad = object.RgbQuad;
const Surface = @import("../platform/platform.zig").Surface;

pub const max_exits = 25;
pub const max_draw_nodes = 100;
pub const max_update = 100;
pub const grid_rows = 65;
pub const grid_cols = 81;

/// An INI scene (classes Scene + the INI scene class flattened; only the
/// latter is instantiated). Functions: units `scene`, `scene_loader`.
pub const Scene = struct {
    // @orig Scene+0x4
    backdrop: ?*Backdrop = null,
    // @orig Scene+0x8
    exits: [max_exits]?*Object = @splat(null),
    // @orig Scene+0x6c
    exitCount: i16 = 0,
    // @orig Scene+0x6e (INI section name)
    name: [20]u8 = @splat(0),
    // @orig Scene+0x82
    objects: ObjectList = .{},
    // @orig Scene+0x8a
    hasPlayer: i16 = 0,
    // @orig Scene+0x8c
    hasStatusBar: i16 = 0,
    // @orig Scene+0x8e
    hasControlPanel: i16 = 0,
    // @orig Scene+0x90
    is1Animation: i16 = 0,
    // @orig Scene+0x92
    isClickExit: i16 = 0,
    // @orig Scene+0x94 (the Exit= object of an Is_1Animation scene)
    animation: ?*Object = null,
    // @orig Scene+0x98
    mayDropObject: i16 = 0,
    // @orig Scene+0x9a (Screen= Number: index into the handler table)
    sceneNumber: i16 = 0,
    // @orig Scene+0x9c
    handlerEnabled: i16 = 0,
};

/// The scene's offscreen view: Backdrop + GridBackdrop + PerspectiveBackdrop
/// flattened (only PerspectiveBackdrop is instantiated). Functions: units
/// `backdrop`, `grid`, `projection`.
///
/// Pixel contract (docs/DESIGN.md "Backdrop"): `pixels` is the WinG bitmap
/// of the *whole background* — `bgWidth` × `bgHeight`, 8 bpp, rows padded
/// to 4 bytes, described by `bmiHeader` (biWidth = bgWidth, biHeight =
/// bgHeight × dibOrientation). `wingRecommendDibFormat` always says
/// top-down, so `dibOrientation` is -1 and row 0 is the top. Coordinates
/// into it are scene coordinates; the window shows the `viewWidth` ×
/// `viewHeight` block at (`originX`, `originY`). Read and write it only
/// through `surface()` (`plat.wingBitBlt`, `plat.textOut`) or `dib.copy*`
/// with `&bmiHeader` (which honour the orientation).
///
/// No counterpart: `hdc` (+0x4, the WinG DC: the bitmap is `pixels`),
/// `hpalette` (+0xa: its colours are `bmiColors`; SelectPalette +
/// RealizePalette = `plat.realizePalette(&bd.bmiColors)`), `oldBitmap`
/// (+0xc).
pub const Backdrop = struct {
    // @orig Backdrop+0x6 (WinG DIB bits; bgWidth × bgHeight, 8 bpp)
    pixels: []u8 = &.{},
    // @orig Backdrop+0xe (the pristine background picture)
    background: ?*Dib = null,
    // @orig Backdrop+0x12
    bgWidth: i16 = 0,
    // @orig Backdrop+0x14
    bgHeight: i16 = 0,
    // @orig Backdrop+0x16 (scroll position)
    originX: i16 = 0,
    // @orig Backdrop+0x18
    originY: i16 = 0,
    // @orig Backdrop+0x1a
    viewWidth: i16 = 0,
    // @orig Backdrop+0x1c
    viewHeight: i16 = 0,
    // @orig Backdrop+0x1e
    unk1E: u16 = 0,
    // @orig Backdrop+0x20
    unk20: u16 = 0,
    // @orig Backdrop+0x22
    bmiHeader: BitmapInfoHeader = .{},
    // @orig Backdrop+0x4a (statics 0-9/246-255 + background colours 10-245;
    // the same colours as the logical palette)
    bmiColors: [256]RgbQuad = @splat(.{}),
    // @orig Backdrop+0x44a (1 bottom-up / -1 top-down; always -1 here)
    dibOrientation: i32 = 1,
    // @orig Backdrop+0x44e (&Scene.objects)
    sceneList: ?*ObjectList = null,
    // @orig GridBackdrop+0x452
    grid: ?*Grid = null,
    // @orig PerspectiveBackdrop+0x456
    vanishX: i16 = 0,
    // @orig PerspectiveBackdrop+0x458 (stored as viewHeight - VanishY)
    vanishY: i16 = 0,
    // @orig PerspectiveBackdrop+0x45a
    eyeDistance: i16 = 0,
    // @orig PerspectiveBackdrop+0x45c
    axisX: i16 = 0,
    // @orig PerspectiveBackdrop+0x45e
    view3dX: i16 = 0,
    // @orig PerspectiveBackdrop+0x460 (stored negated)
    view3dY: i16 = 0,
    // @orig PerspectiveBackdrop+0x462
    view3dZ: i16 = 0,

    /// The WinG bitmap as the platform's `Surface` (for `wingBitBlt` and
    /// `textOut`).
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

/// Result of the backdrop's rectangle queries: Backdrop slot 03
/// `queryRectFirst(x, y, w, h, &outObj, &outFirst, &outFlag)` and slot 04
/// `queryRect(x, y, w, h, &outObj, &outFlag)` (source order; callers push
/// them left to right). The grid query (`occupancy_grid_query_rect`)
/// clears `*outObj`/`*outFlag` on entry, so every field is always written,
/// whatever `result` is — callers may store them unconditionally, as the
/// original does.
pub const RectQuery = struct {
    /// The return value (char): 0 all cells free, > 0 the first occupied
    /// cell's count, -1 a negative position or (via `flag`) only blocked
    /// cells.
    result: i8 = 0,
    /// `*outFlag`: -1 if a blocked cell was seen, else 0.
    flag: i8 = 0,
    /// `*outObj`: the last object met up to the first occupied cell (null
    /// if none).
    obj: ?*Object = null,
    /// `*outFirst` (queryRectFirst only; null from queryRect): the first
    /// object met (`Grid.firstObject`).
    first: ?*Object = null,
};

/// The occupancy grid (struct `OccupancyGrid` + the cell globals). Cell
/// count: 0 free, >0 occupants, -1 blocked, < -1 blocked and occupied.
/// Functions: unit `grid`.
pub const Grid = struct {
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
    // @orig g_occupancyCount
    count: [grid_rows][grid_cols]i8 = @splat(@splat(0)),
    // @orig g_occupancyObject
    object: [grid_rows][grid_cols]?*Object = @splat(@splat(null)),
};

/// Sorted draw list (struct `DrawList`): back-to-front Object3D items in
/// a 100-node pool. Functions: unit `draw_list`.
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

/// Objects to blit to the screen ("lista de atualização", struct
/// `UpdateList`). Functions: unit `update_list`.
pub const UpdateList = struct {
    // @orig UpdateList+0x0
    items: [max_update]?*Object = @splat(null),
    // @orig UpdateList+0x190
    count: i16 = 0,
};

/// Exit conditions (Condition / FlagCondition; CompoundCondition is dead).
/// Functions: unit `condition`.
pub const Condition = struct {
    kind: enum { base, flag } = .base,
    // @orig FlagCondition+0x4
    value: i16 = 0,
};

pub const PickedItem = struct {
    // @orig PickedItem+0x0
    object: ?*Object = null,
    // @orig PickedItem+0x4
    x: i16 = 0,
    // @orig PickedItem+0x6
    y: i16 = 0,
    // @orig PickedItem+0x8
    isRight: u16 = 0,
    // @orig PickedItem+0xa
    placed: u16 = 0,
};

/// Recorded when the options screen opens (struct `SavedPosition`).
pub const SavedPosition = struct {
    // @orig SavedPosition+0x0
    scene: [256]u8 = @splat(0),
    // @orig SavedPosition+0x100
    playerX: i16 = 0,
    // @orig SavedPosition+0x102
    playerY: i16 = 0,
    // @orig SavedPosition+0x104
    hasPlayer: i16 = 0,
    // @orig SavedPosition+0x106
    hasControlPanel: i16 = 0,
    // @orig SavedPosition+0x108
    hasStatusBar: i16 = 0,
    // @orig SavedPosition+0x10a
    is1Animation: i16 = 0,
    // @orig SavedPosition+0x10c
    isClickExit: i16 = 0,
};
