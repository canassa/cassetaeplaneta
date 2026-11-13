//! Scene handler of the credits: each right click turns both credit columns
//! to the next page; after the last page it closes the main window.

const Game = @import("../core/game.zig").Game;
const Object = @import("../core/object.zig").Object;
const Msg = @import("../core/msg.zig").Msg;
const msgs = @import("../core/msg.zig");
const frames = @import("../frames.zig");
const render = @import("../behaviour/render.zig");
const visibility = @import("../behaviour/visibility.zig");

/// Number of credit pages.
const page_count: i16 = 5;
/// INI object numbers of the two columns (`Animated=355` creddir, `356` credesq).
const right_id: u16 = 0x163;
const left_id: u16 = 0x164;

pub const State = struct {
    // @orig g_creditosPage
    page: i16 = 1,
    // @orig g_creditosRight
    right: ?*Object = null,
    // @orig g_creditosLeft
    left: ?*Object = null,
};

// @orig 1028:10da handler_creditos
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    if (m.id == msgs.wm.rbuttondown) {
        if (s.page < page_count) {
            // The original dereferences g_creditosRight/Left unchecked.
            const right = s.right.?;
            const left = s.left.?;
            _ = frames.setCurFrame(right, @bitCast(s.page));
            _ = frames.setCurFrame(left, @bitCast(s.page));
            // GetDC/ReleaseDC dropped (one window, no hdc).
            frames.resetRects(right);
            frames.resetRects(left);
            render.draw(g, right, g.scene.?.backdrop.?);
            render.draw(g, left, g.scene.?.backdrop.?);
            _ = visibility.invalidate(g, right);
            _ = visibility.invalidate(g, left);
            s.page +%= 1;
        } else {
            _ = g.send(.{ .id = msgs.wm.destroy });
        }
    } else {
        if (m.id != msgs.noite.object_created) return 0;
        if (m.wparam == right_id) s.right = g.newObject;
        if (m.wparam == left_id) s.left = g.newObject;
    }
    return 1;
}
