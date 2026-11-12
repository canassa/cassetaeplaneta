//! State of the leaf modules that the original keeps in DGROUP globals:
//! the INI reader and the WaveMix sound table. `Game` embeds one of each;
//! the module units take a pointer to theirs (not the whole `Game`).

const SectionTable = @import("../ini_sections.zig").SectionTable;
const platform = @import("../platform/platform.zig");

/// The INI module (1018:98d0..aeaa): open file, section index, and the
/// values the last reader parsed (the `g_ini*` globals; readers write them
/// and `ini_scene_create` / `ini_game_init` read them).
pub const Ini = struct {
    // @orig g_iniFile
    file: ?platform.File = null,
    // @orig g_iniPath
    path: [256]u8 = @splat(0),
    sections: SectionTable = .{},
    // @orig g_iniSectionBuild (never reset by the original)
    sectionBuild: i16 = 0,
    // @orig g_iniSectionEnd
    sectionEnd: u16 = 0,
    // @orig g_iniKeySearch
    keySearch: u16 = 0,
    // @orig g_iniLastChar
    lastChar: u8 = 0,
    // @orig g_lastAssetPath / g_assetPath
    assetPath: [256]u8 = @splat(0),
    rec: Record = .{},

    /// The fields one INI line can carry (`g_iniNumber` … `g_iniKeyObject`).
    pub const Record = struct {
        number: i16 = 0, // g_iniNumber
        x: i16 = 0, // g_iniX
        y: i16 = 0, // g_iniY
        numSprites: i16 = 0, // g_iniNumSprites
        originX3d: i16 = 0, // g_ini3DOriginX
        originY3d: i16 = 0, // g_ini3DOriginY
        w3d: i16 = 0, // g_ini3Dw
        h3d: i16 = 0, // g_ini3Dh
        d3d: i16 = 0, // g_ini3Dd
        numTimer: i16 = 0, // g_iniNumTimer
        perTimer: i16 = 0, // g_iniPerTimer
        deltaX: i16 = 0, // g_iniDeltaX
        deltaY: i16 = 0, // g_iniDeltaY
        numFrames: i16 = 0, // g_iniNumFrames
        frameW: i16 = 0, // g_iniFrameW
        frameH: i16 = 0, // g_iniFrameH
        boundX: i16 = 0, // g_iniBoundX
        boundY: i16 = 0, // g_iniBoundY
        boundW: i16 = 0, // g_iniBoundW
        boundH: i16 = 0, // g_iniBoundH
        arg816C: i16 = 0, // g_iniArg816C
        elevation: i16 = 0, // g_iniElevation
        exitPlayerX: i16 = 0, // g_iniExitPlayerX
        exitPlayerY: i16 = 0, // g_iniExitPlayerY
        screenX: i16 = 0, // g_iniScreenX
        screenY: i16 = 0, // g_iniScreenY
        screenW: i16 = 0, // g_iniScreenW
        screenH: i16 = 0, // g_iniScreenH
        vanishX: i16 = 0, // g_iniVanishX
        vanishY: i16 = 0, // g_iniVanishY
        viewX: i16 = 0, // g_iniViewX
        viewY: i16 = 0, // g_iniViewY
        view3dX: i16 = 0, // g_iniView3Dx
        view3dY: i16 = 0, // g_iniView3Dy
        view3dZ: i16 = 0, // g_iniView3Dz
        axisX: i16 = 0, // g_iniAxisX
        axisY: i16 = 0, // g_iniAxisY
        limits: [8]i16 = @splat(0), // g_iniLimits1..8
        bmpName: [50]u8 = @splat(0), // g_iniBmpName
        smallBmpName: [50]u8 = @splat(0), // g_iniSmallBmpName
        portScene: [50]u8 = @splat(0), // g_iniPortScene
        screenBmp: [50]u8 = @splat(0), // g_iniScreenBmp
        firstScene: [50]u8 = @splat(0), // g_iniFirstScene
        sceneInName: [50]u8 = @splat(0), // g_iniSceneInName
        hasPlayer: i16 = 0, // g_iniHasPlayer
        hasControlPanel: i16 = 0, // g_iniHasControlPanel
        hasStatusBar: i16 = 0, // g_iniHasStatusBar
        is1Animation: i16 = 0, // g_iniIs1Animation
        isClickExit: i16 = 0, // g_iniIsClickExit
        mayDropObject: i16 = 0, // g_iniMayDropObject
        /// Also "an AVI is playing" after loading (cleared by closeAvi).
        isAvi: i16 = 0, // g_iniIsAVI
        exit2Str: [50]u8 = @splat(0), // g_ini2ExitStr
        nomeWave: [50]u8 = @splat(0), // g_iniNomeWAVE
        exit2F27: i16 = 0, // g_ini2ExitF27
        exit2F28: i16 = 0, // g_ini2ExitF28
        waveObject: i16 = 0, // g_iniWaveObject
        scoreTake: i16 = 0, // g_iniScoreTake
        scoreUse: i16 = 0, // g_iniScoreUse
        scoreMisuse: i16 = 0, // g_iniScoreMisuse
        smallNumFrames: i16 = 0, // g_iniSmallNumFrames
        smallFrameW: i16 = 0, // g_iniSmallFrameW
        smallFrameH: i16 = 0, // g_iniSmallFrameH
        keyObject: i16 = 0, // g_iniKeyObject
    };
};

pub const max_waves = 30;

/// The WaveMix wave table (unit `sound`).
pub const Sound = struct {
    // @orig g_waves
    waves: [max_waves]?platform.Wave = @splat(null),
    // @orig g_waveCount
    count: i16 = 0,
    // @orig g_waveMixSession
    session: u16 = 0,
    // @orig g_waveMixOpenResult (last WaveMix result)
    openResult: u32 = 0,
    // @orig g_waveCacheA/B/C
    cache: [3]u16 = @splat(0),
};
