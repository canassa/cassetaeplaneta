//! Port unit `handler_abert` (handler). scene handler 1018:c628.
//!
//! Handler of the opening scene. When the gift-wrapped package item (INI
//! Number 0x6b) is created it re-cuts the item's image into a four-frame
//! strip (92x116 each); everything else goes to the engine.

const Game = @import("../core/game.zig").Game;
const Msg = @import("../core/msg.zig").Msg;
const noite = @import("../core/msg.zig").noite;
const Object = @import("../core/object.zig").Object;
const frames = @import("../frames.zig");

pub const State = struct {
    // @orig g_abertGift
    abertGift: ?*Object = null,
};

// @orig 1018:c628 handler_abert
pub fn handle(g: *Game, m: Msg) i16 {
    if (m.id == noite.object_created and m.wparam == 0x6b) {
        const s = g.sceneState(State);
        // The original dereferences g_newObject unchecked.
        const obj = g.newObject.?;
        s.abertGift = obj;
        frames.frameInit(&obj.frames[0], frames.dib(obj), 4, 0x5c, 0x74, 0, 0, 0, 0);
        _ = frames.setCurFrame(obj, 0);
    }
    return 0;
}
