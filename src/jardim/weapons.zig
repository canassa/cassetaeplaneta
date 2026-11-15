//! Not in the original (`Fixes.jardim_weapon_inventory`, a Corrigida addition): Wolfenstein
//! 3D's weapons in JARDIM's labyrinth (docs/jardim/GAME.md "Weapons (Corrigida)").
//!
//! The original holds one weapon at a time: a pickup of the other kind swaps (the old one is
//! dropped in the cell), the ammunition is one counter, arrows and bombs are taken only with
//! the matching weapon in hand, and at 0 ammunition the hands go back to the fists. Here the
//! player owns the fists, the crossbow and the bra (phase 1) or the bazooka (phases 2 and 3),
//! each with its own ammunition:
//!
//! - **Pickups.** A weapon not owned is taken and taken into the hands (Wolf3D's), with its
//!   ammunition; an owned one only adds its ammunition (nothing is dropped or swapped, and the
//!   hands keep what they hold). Arrows and bombs are taken whenever the matching weapon is
//!   owned, held or not, and stay in the cell otherwise (the original's rule). A pickup is
//!   never lost to a shot in flight (BUGS.md J3).
//! - **Switching.** 1 the fists, 2 the crossbow, 3 the bra or the bazooka (only an owned one
//!   with ammunition; the fists always), Q the next of those (the web's mouse wheel sends Q).
//!   Allowed with a shot in flight: the shot is the weapon that fired it (`Game.shotWeapon`,
//!   its frame and its kills), whatever is in the hands when it lands.
//! - **No ammunition.** The shot that empties the weapon in the hands switches to the best
//!   other weapon with ammunition (the highest slot), else the fists. Fists reached this way
//!   (or by losing the bra) go back to a weapon as soon as one gains ammunition (Wolf3D's
//!   `GiveAmmo`); fists chosen by the key stay.
//! - **Phases.** The crossbow and every ammunition count carry over; phase 1's bra is left
//!   behind (the original turns it into the fists in phase 2).
//! - **A lost life.** The original puts the fists in the hands, empties the ammunition and
//!   places every pickup on the map again: the inventory is emptied the same way.
//!
//! `bd.ammo` stays the counter of the weapon in the hands (the shot and the HUD read it); the
//! others' are `State.ammo`.

const std = @import("std");
const Game = @import("core/game.zig").Game;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const object = @import("core/object.zig");
const Object = object.Object;

/// The hands' strips (`hands.curStrip`).
pub const fists: i16 = 0;
pub const crossbow: i16 = 1;
/// The bra in phase 1, the bazooka in phases 2 and 3.
pub const heavy: i16 = 2;
pub const count = 3;

/// What the player owns, carried across phases (`Game.weapons`).
pub const State = struct {
    have: [count]bool = .{ true, false, false },
    /// Ammunition by weapon; the one in the hands is `bd.ammo`, this entry is stale.
    ammo: [count]i16 = .{ 0, 0, 0 },
    /// The fists are in the hands because a weapon ran dry or was lost, not by the player's key.
    auto_fists: bool = false,
};

pub fn active(g: *const Game) bool {
    return g.fixes.jardim_weapon_inventory;
}

fn held(bd: *const Backdrop) usize {
    return @intCast(bd.hands.?.curStrip);
}

fn slot(k: i16) usize {
    return @intCast(k);
}

/// A weapon's ammunition, the one in the hands from the backdrop.
pub fn ammoOf(g: *const Game, bd: *const Backdrop, k: i16) i16 {
    return if (slot(k) == held(bd)) bd.ammo else g.weapons.ammo[slot(k)];
}

fn addAmmo(g: *Game, bd: *Backdrop, k: i16, n: i16) void {
    if (slot(k) == held(bd)) {
        bd.ammo +%= n;
    } else {
        g.weapons.ammo[slot(k)] +%= n;
    }
}

/// Puts weapon `k` in the hands (frame 0), the counter with it.
fn setHands(g: *Game, bd: *Backdrop, k: i16) void {
    const old = held(bd);
    if (old == slot(k)) return;
    g.weapons.ammo[old] = bd.ammo;
    bd.ammo = g.weapons.ammo[slot(k)];
    const hands = bd.hands.?;
    hands.curStrip = k;
    hands.curFrame = 0;
}

/// Wolf3D's `GiveAmmo`: ammunition gained while the fists are in the hands only because the
/// weapon ran dry brings the weapon back.
fn backToWeapon(g: *Game, bd: *Backdrop, k: i16) void {
    if (g.weapons.auto_fists and held(bd) == slot(fists)) setHands(g, bd, k);
    g.weapons.auto_fists = false;
}

/// A weapon touched: a new one is owned, loaded with `n` and taken into the hands; an owned
/// one only gets `n` more (and takes the hands back from fists a lack of ammunition left).
pub fn pickWeapon(g: *Game, bd: *Backdrop, k: i16, n: i16) void {
    const w = &g.weapons;
    if (!w.have[slot(k)]) {
        w.have[slot(k)] = true;
        w.ammo[slot(k)] = 0;
        if (held(bd) == slot(k)) bd.ammo = 0;
        addAmmo(g, bd, k, n);
        w.auto_fists = false;
        setHands(g, bd, k);
    } else {
        addAmmo(g, bd, k, n);
        backToWeapon(g, bd, k);
    }
}

/// Arrows or bombs touched: false (they stay in the cell) unless the weapon is owned.
pub fn pickAmmo(g: *Game, bd: *Backdrop, k: i16, n: i16) bool {
    if (!g.weapons.have[slot(k)]) return false;
    addAmmo(g, bd, k, n);
    backToWeapon(g, bd, k);
    return true;
}

/// Whether the player can switch to `k`: the fists always, a weapon if owned with ammunition.
fn usable(g: *const Game, bd: *const Backdrop, k: usize) bool {
    return k == slot(fists) or (g.weapons.have[k] and ammoOf(g, bd, @intCast(k)) > 0);
}

/// The key `n` (1, 2 or 3): that weapon if usable. True if the hands changed.
pub fn select(g: *Game, bd: *Backdrop, n: u16) bool {
    if (!active(g) or n < 1 or n > count) return false;
    const k: usize = n - 1;
    if (!usable(g, bd, k) or k == held(bd)) return false;
    g.weapons.auto_fists = false;
    setHands(g, bd, @intCast(k));
    return true;
}

/// Q: the next usable weapon after the one in the hands, the fists after the last.
pub fn cycle(g: *Game, bd: *Backdrop) bool {
    if (!active(g)) return false;
    var i: usize = 1;
    while (i < count) : (i += 1) {
        const k = (held(bd) + i) % count;
        if (usable(g, bd, k)) {
            g.weapons.auto_fists = false;
            setHands(g, bd, @intCast(k));
            return true;
        }
    }
    return false;
}

/// The best weapon (the highest slot) other than the one in the hands with ammunition, else
/// the fists.
fn best(g: *const Game, bd: *const Backdrop) i16 {
    var k: usize = count - 1;
    while (k > 0) : (k -= 1) {
        if (k != held(bd) and usable(g, bd, k)) return @intCast(k);
    }
    return fists;
}

/// A shot has landed (`from_tick`: on a game tick, not on the key press): the hands go back
/// to the rest pose unless something else is in them, and the weapon in the hands that has
/// run dry gives way to the best one with ammunition, else the fists.
pub fn afterShot(g: *Game, bd: *Backdrop, from_tick: bool) void {
    const hands = bd.hands.?;
    if (held(bd) != slot(fists) and bd.ammo == 0) {
        const next = best(g, bd);
        setHands(g, bd, next);
        g.weapons.auto_fists = next == fists;
    } else if (from_tick and held(bd) != slot(fists)) {
        // The firing pose back (the original's `nextFrame` from frame 1); a weapon switched
        // to in flight is at frame 0 already.
        hands.curFrame = 0;
    }
}

/// WM_USER+2 (the exit door): what is carried to the next phase (`g.curWeapon`, `g.carryAmmo`;
/// the phase builds its hands and counter from them). Phase 1's bra stays behind.
pub fn carry(g: *Game, bd: *Backdrop) void {
    if (bd.level +% 1 == 2 and g.weapons.have[slot(heavy)]) {
        if (held(bd) == slot(heavy)) {
            setHands(g, bd, fists);
            g.weapons.auto_fists = true;
        }
        g.weapons.have[slot(heavy)] = false;
        g.weapons.ammo[slot(heavy)] = 0;
    }
    g.curWeapon = bd.hands.?.curStrip;
    g.carryAmmo = bd.ammo;
}

/// A life lost: the original's respawn (fists, ammunition 0, every pickup on the map again).
pub fn reset(g: *Game) void {
    g.weapons = .{};
}

const testing = std.testing;

const Fixture = struct {
    t: @import("core/game.zig").TestGame,
    bd: Backdrop = .{},
    hands: Object = .{ .kind = .scene_object },

    fn init(f: *Fixture) !void {
        f.t = try @import("core/game.zig").TestGame.init(testing.allocator);
        f.t.game.fixes.jardim_weapon_inventory = true;
        f.bd = .{};
        f.hands = .{ .kind = .scene_object };
        f.bd.hands = &f.hands;
        f.bd.level = 1;
    }

    fn deinit(f: *Fixture) void {
        f.t.deinit();
    }

    fn g(f: *Fixture) *Game {
        return f.t.game;
    }
};

test "a new weapon goes into the hands with its ammunition; an owned one only adds" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const g = f.g();
    const bd = &f.bd;
    pickWeapon(g, bd, crossbow, 6);
    try testing.expectEqual(crossbow, bd.hands.?.curStrip);
    try testing.expectEqual(@as(i16, 6), bd.ammo);
    // The heavy weapon is new: it takes the hands, the crossbow keeps its 6.
    pickWeapon(g, bd, heavy, 3);
    try testing.expectEqual(heavy, bd.hands.?.curStrip);
    try testing.expectEqual(@as(i16, 3), bd.ammo);
    try testing.expectEqual(@as(i16, 6), ammoOf(g, bd, crossbow));
    // The crossbow again: ammunition only, the hands stay (no swap, nothing dropped).
    pickWeapon(g, bd, crossbow, 6);
    try testing.expectEqual(heavy, bd.hands.?.curStrip);
    try testing.expectEqual(@as(i16, 12), ammoOf(g, bd, crossbow));
    try testing.expectEqual(@as(i16, 3), bd.ammo);
}

test "arrows and bombs go to the owned weapon, held or not, else stay" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const g = f.g();
    const bd = &f.bd;
    try testing.expect(!pickAmmo(g, bd, crossbow, 3));
    try testing.expect(!pickAmmo(g, bd, heavy, 1));
    pickWeapon(g, bd, crossbow, 6);
    try testing.expect(pickAmmo(g, bd, crossbow, 3));
    try testing.expectEqual(@as(i16, 9), bd.ammo);
    pickWeapon(g, bd, heavy, 1);
    // The bazooka in the hands: the arrows still go to the crossbow's own counter.
    try testing.expect(pickAmmo(g, bd, crossbow, 3));
    try testing.expectEqual(@as(i16, 12), ammoOf(g, bd, crossbow));
    try testing.expectEqual(@as(i16, 1), bd.ammo);
    try testing.expect(pickAmmo(g, bd, heavy, 1));
    try testing.expectEqual(@as(i16, 2), bd.ammo);
}

test "the keys select an owned weapon with ammunition; Q cycles; the fists are always there" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const g = f.g();
    const bd = &f.bd;
    try testing.expect(!select(g, bd, 2));
    try testing.expect(!select(g, bd, 3));
    try testing.expect(!cycle(g, bd));
    pickWeapon(g, bd, crossbow, 6);
    pickWeapon(g, bd, heavy, 2);
    try testing.expect(select(g, bd, 1));
    try testing.expectEqual(fists, bd.hands.?.curStrip);
    try testing.expectEqual(@as(i16, 0), bd.ammo);
    try testing.expect(select(g, bd, 2));
    try testing.expectEqual(@as(i16, 6), bd.ammo);
    try testing.expect(select(g, bd, 3));
    try testing.expectEqual(@as(i16, 2), bd.ammo);
    try testing.expect(!select(g, bd, 3));
    // Q: heavy -> fists -> crossbow -> heavy.
    try testing.expect(cycle(g, bd));
    try testing.expectEqual(fists, bd.hands.?.curStrip);
    try testing.expect(cycle(g, bd));
    try testing.expectEqual(crossbow, bd.hands.?.curStrip);
    try testing.expect(cycle(g, bd));
    try testing.expectEqual(heavy, bd.hands.?.curStrip);
    // A weapon without ammunition is skipped and refused.
    g.weapons.ammo[@intCast(crossbow)] = 0;
    try testing.expect(!select(g, bd, 2));
    try testing.expect(cycle(g, bd));
    try testing.expectEqual(fists, bd.hands.?.curStrip);
    try testing.expect(cycle(g, bd));
    try testing.expectEqual(heavy, bd.hands.?.curStrip);
}

test "a switch resets the pose and keeps each counter" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const g = f.g();
    const bd = &f.bd;
    pickWeapon(g, bd, crossbow, 6);
    pickWeapon(g, bd, heavy, 3);
    bd.hands.?.curFrame = 1;
    bd.ammo -= 1;
    try testing.expect(select(g, bd, 2));
    try testing.expectEqual(@as(i16, 0), bd.hands.?.curFrame);
    try testing.expectEqual(@as(i16, 6), bd.ammo);
    try testing.expectEqual(@as(i16, 2), ammoOf(g, bd, heavy));
}

test "an emptied weapon gives way to the best other one, else the fists, and comes back with ammunition" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const g = f.g();
    const bd = &f.bd;
    pickWeapon(g, bd, crossbow, 6);
    pickWeapon(g, bd, heavy, 1);
    // The bra's last shot lands: the crossbow is the best other one.
    bd.ammo = 0;
    afterShot(g, bd, true);
    try testing.expectEqual(crossbow, bd.hands.?.curStrip);
    try testing.expectEqual(@as(i16, 6), bd.ammo);
    try testing.expect(!g.weapons.auto_fists);
    // The crossbow's last: the bra has none, so the fists.
    bd.ammo = 0;
    afterShot(g, bd, true);
    try testing.expectEqual(fists, bd.hands.?.curStrip);
    try testing.expect(g.weapons.auto_fists);
    // Arrows bring the crossbow back into the hands; ammunition of a weapon not owned does not.
    try testing.expect(pickAmmo(g, bd, crossbow, 3));
    try testing.expectEqual(crossbow, bd.hands.?.curStrip);
    try testing.expectEqual(@as(i16, 3), bd.ammo);
    // Fists chosen by the key stay when ammunition comes.
    try testing.expect(select(g, bd, 1));
    try testing.expect(pickAmmo(g, bd, crossbow, 3));
    try testing.expectEqual(fists, bd.hands.?.curStrip);
    try testing.expectEqual(@as(i16, 6), ammoOf(g, bd, crossbow));
}

test "a shot that does not empty the weapon only rests the pose" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const g = f.g();
    const bd = &f.bd;
    pickWeapon(g, bd, crossbow, 6);
    bd.hands.?.curFrame = 1;
    bd.ammo = 5;
    afterShot(g, bd, false);
    try testing.expectEqual(@as(i16, 1), bd.hands.?.curFrame);
    afterShot(g, bd, true);
    try testing.expectEqual(@as(i16, 0), bd.hands.?.curFrame);
    try testing.expectEqual(crossbow, bd.hands.?.curStrip);
}

test "phase 2 leaves the bra behind, the crossbow and its ammunition go on" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const g = f.g();
    const bd = &f.bd;
    pickWeapon(g, bd, crossbow, 6);
    pickWeapon(g, bd, heavy, 2);
    carry(g, bd);
    // The bra was in the hands: the original's bra -> fists.
    try testing.expectEqual(fists, g.curWeapon);
    try testing.expectEqual(@as(i16, 0), g.carryAmmo);
    try testing.expect(!g.weapons.have[@intCast(heavy)]);
    try testing.expectEqual(@as(i16, 6), g.weapons.ammo[@intCast(crossbow)]);
    // The next phase's backdrop is built from the carry; the crossbow still selects.
    var bd2: Backdrop = .{};
    var hands2: Object = .{ .kind = .scene_object };
    hands2.curStrip = g.curWeapon;
    bd2.hands = &hands2;
    bd2.ammo = g.carryAmmo;
    bd2.level = 2;
    try testing.expect(select(g, &bd2, 2));
    try testing.expectEqual(@as(i16, 6), bd2.ammo);
    // Phase 3 keeps what phase 2 held, the bazooka included.
    pickWeapon(g, &bd2, heavy, 3);
    carry(g, &bd2);
    try testing.expectEqual(heavy, g.curWeapon);
    try testing.expectEqual(@as(i16, 3), g.carryAmmo);
    try testing.expect(g.weapons.have[@intCast(heavy)]);
}

test "a lost life empties the inventory" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const g = f.g();
    pickWeapon(g, &f.bd, crossbow, 6);
    reset(g);
    try testing.expect(!g.weapons.have[@intCast(crossbow)]);
    try testing.expect(g.weapons.have[@intCast(fists)]);
}
