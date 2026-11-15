//! SAUNA's maze as the EXE starts with it (DGROUP 10b0:031a), apart from the game: the arcade
//! planner (`plan.zig`) reads it without the rest of the port.

/// The maze: 30 rows of 40 cells of 16×16 px, one NUL-terminated row of
/// 41 bytes each (`s_mazeRow00…29`): '1' wall, '2' peanut, '3' cork, ' '.
pub const maze_rows = 30;
pub const maze_cols = 40;
pub const Maze = [maze_rows][maze_cols + 1]u8;

/// The maze as SAUNA.EXE starts with it (DGROUP 10b0:031a): 96 peanuts,
/// 4 corks. Rows 27-29 lie below the 460-px background.
pub const initial_maze: Maze = blk: {
    const rows = [maze_rows]*const [maze_cols:0]u8{
        "1111111111111111111111111111111111111111",
        "13 2 2 1     12 2 2 2 2 2 1     12 2 3 1",
        "1      1     1            1     1      1",
        "1  11  1111111  11111111  1111111  11  1",
        "12 2 2 2 2 2 2  1      1 2 2 2 2 2 2 2 1",
        "1               1      1               1",
        "12 11111111111  11111111  111111111112 1",
        "1  2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2   1",
        "12                                   2 1",
        "1  1  1111  1111111  1111111  1111  1  1",
        "12 1  1  1  1              1  1  1  12 1",
        "1  1  1  1  1              1  1  1  1  1",
        "12 1  1111  1  1        1  1  1111  12 1",
        "1              1        1              1",
        "12             1        1            2 1",
        "1  1  1111  1  1        1  1  1111  1  1",
        "12 1  1  1  1  1        1  1  1  1  12 1",
        "1  1  1  1  1  1        1  1  1  1  1  1",
        "12 1  1111  1  1111111111  1  1111  12 1",
        "1  1 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2  1  1",
        "12 1                                12 1",
        "1  11111111111  11111111  11111111111  1",
        "12 2 2 2 2 2 2  1      1 2 2 2 2 2 2 2 1",
        "1               1      1               1",
        "1  11  1111111  11111111  1111111  11  1",
        "13 2 2 1     12 2 2 2 2 2 1     12 2 3 1",
        "1      1     1            1     1      1",
        "1111111111111111111111111111111111111111",
        "1111111111111111111111111111111111111111",
        "1111111111111111111111111111111111111111",
    };
    var m: Maze = undefined;
    for (rows, 0..) |r, i| m[i] = r.* ++ [1]u8{0};
    break :blk m;
};
