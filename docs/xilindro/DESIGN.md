# Native port of XILINDRO.EXE — design

XILINDRO.EXE ("Xilindro", the street fight that NOITE's `3fstreet` starts
after the prison escape) is ported with SALGIN.EXE under one design:
**`docs/salgin/DESIGN.md`** (decisions, object model, virtual slots,
state, fixes, integration, platform, tests, how to port a unit, owner
questions). This file holds what the tracker reads per program (the
SceneObject slot table below and `SLOTS.tsv`) and what differs from
SALGIN. `GAME.md`, `DATA.md`, `FUNCTIONS.md`, `QUALITY.md` and BUGS.md
X1–X11 describe the binary.

## What differs from SALGIN

- **Tree and names.** `src/xilindro/`, its own `@orig` addresses (DGROUP
  `1090` too, at XILINDRO's offsets), its Ghidra names: `Fighter.reacting`/
  `moveFrame`/`energy`/`contact`, `Opponent.reacting`/`moveFrame`/`energy`,
  `EnergyBar.leftX`/`rightX`/`fighterEnergy`/`opponentEnergy`,
  `XilindroScene.secondsLeft` (`Scene.secondsLeft`), `g_fighterMoveDamage`
  {1, 2, 1, 2} / `g_opponentMoveDamage` {4, 2, 2, 6}, `g_reactionTable
  [attacker 0-3][target strip 0-7][weak]`, `g_fighterBarMark`/
  `g_opponentBarMark`, `g_lastSecondTick`/`g_lastFrameTick`/
  `g_lastPumpTick`, `g_fightOver`, `g_lastFighterMove`/
  `g_lastOpponentMove`, the waves `soco2 soco dor3 dor1 chute3 vaias
  lutamal3` (+ `murmlut2` looped, no handle kept).
- **The fight's rules** (GAME.md): reach 100 (the opponent attacks from
  up to 130), the recoil after a hit, Down/Home trades, the clash, the
  opponent reacting whatever its strip, both outcomes closing after 31 end
  ticks, the score fighterEnergy × 150. These are all in `arena`
  (`xilindro_scene_handle_message`, 7.5 KB) and `fighters`.
- **Copy order.** Engine units start from TIRO's Zig, as SALGIN's; the
  fight units (`fighters`, `hud`, `arena`) and the fight's overrides in
  `animation`, `movement`, `occupancy`, `visibility`, `object_create`,
  `game` start from SALGIN's Zig once SALGIN's unit has landed.
- **Live code.** `wave_play_loop` is live (`murmlut2.WAV`), so `sound` has
  10 functions; `backdrop_autoscroll`'s dead tail is inside the function
  (port its `return 0`).
- **Fixes**: X1–X11 (`docs/salgin/DESIGN.md` "Fixes"); no flag is shared
  with SALGIN.
- **Launch**: `handler_3fstreet` when the street video ends; FindWindow
  ("Xilindro"); NOITE records `minigameWon[3]`, goes to `3fstree2` (won)
  or `3fstree1` (lost: a life, then `3fprisao` or `6fsaida`). In the
  Original, B21 sends NOITE to `3fhall` while the fight runs
  (`docs/salgin/DESIGN.md` "Integration").

### SceneObject slots (kinds: fighter, opponent, banner, energy_bar, panel = control_panel, status = status_bar)

The same slots, units and overrides as SALGIN's (`docs/salgin/DESIGN.md`);
generated from XILINDRO's vtables (thunks resolved). 0x58–0x5A have no
dispatcher.

| slot | behaviour | unit | default | overrides (impl: kinds) |
|---|---|---|---|---|
| 00 | getWorldX | space3d | scene_object_get_world_x_default | object3d_get_world_x: panel |
| 01 | getWorldDepth | space3d | scene_object_get_world_depth_default | object3d_get_world_depth: panel |
| 02 | getWorldElev | space3d | scene_object_get_world_elev_default | object3d_get_world_elev: panel |
| 03 | getSizeW | space3d | scene_object_get_size_w_default | object3d_get_size_w: panel |
| 04 | getSizeH | space3d | scene_object_get_size_h_default | object3d_get_size_h: panel |
| 05 | getSizeD | space3d | scene_object_get_size_d_default | object3d_get_size_d: panel |
| 06 | getAnchorX | space3d | scene_object_get_anchor_x_default | object3d_get_anchor_x: panel |
| 07 | getAnchorY | space3d | scene_object_get_anchor_y_default | object3d_get_anchor_y: panel |
| 08 | getX | position | scene_object_get_x | mover_get_x: fighter opponent banner energy_bar |
| 09 | getY | position | scene_object_get_y | mover_get_y: fighter opponent banner energy_bar |
| 0A | getStepX | position | scene_object_get_step_x_default | mover_get_step_x: fighter opponent banner energy_bar |
| 0B | getStepY | position | scene_object_get_step_y_default | mover_get_step_y: fighter opponent banner energy_bar |
| 0C | slot11 | position | scene_object_slot11_default |  |
| 0D | setElevation | space3d | scene_object_set_elevation_default | object3d_set_elevation: panel |
| 0E | setAnchor | space3d | scene_object_set_anchor_default | object3d_set_anchor: panel |
| 0F | setSize | space3d | scene_object_set_size_default | object3d_set_size: panel |
| 10 | setWorldElev | space3d | scene_object_set_world_elev_default |  |
| 11 | drawBounds | space3d | scene_object_draw_bounds_default | object3d_draw_bounds: panel |
| 12 | addDirtyRect | render | scene_object_add_dirty_rect |  |
| 13 | computeOverlap | render | scene_object_compute_overlap |  |
| 14 | restoreBackground | render | scene_object_restore_background | mover_restore_background: fighter opponent banner energy_bar |
| 15 | drawDirtyTo | render | scene_object_draw_dirty_to | mover_draw_dirty_to: fighter opponent banner energy_bar |
| 16 | draw | render | scene_object_draw | player2d_draw: fighter; animation_draw: opponent banner energy_bar; control_panel_draw: panel |
| 17 | drawClipTo | render | scene_object_draw_clip_to |  |
| 18 | drawClip | render | scene_object_draw_clip |  |
| 19 | erase | render | scene_object_erase | animation_erase: fighter opponent banner energy_bar panel |
| 1A | slot1F | render | scene_object_slot1f_default | animation_slot1f: fighter opponent banner energy_bar panel |
| 1B | redraw | visibility | scene_object_redraw | actor2d_redraw: fighter opponent banner energy_bar; animated3d_redraw: panel |
| 1C | hideAndInvalidate | visibility | scene_object_hide_and_invalidate |  |
| 1D | blitToDc | visibility | scene_object_blit_to_dc | actor2d_blit_to_dc: fighter opponent banner energy_bar |
| 1E | invalidate | visibility | scene_object_invalidate | fighter_invalidate: fighter; opponent_invalidate: opponent; mover_invalidate: banner energy_bar |
| 1F | slot24 | visibility | scene_object_slot24 | mover_slot24: fighter opponent banner energy_bar |
| 20 | hide | visibility | scene_object_hide | mover_hide: fighter opponent banner energy_bar |
| 21 | show | visibility | scene_object_show | actor2d_show: fighter opponent banner energy_bar; animated3d_show: panel |
| 22 | occupy | occupancy | scene_object_occupy | control_panel_occupy: panel; status_bar_occupy: status |
| 23 | vacate | occupancy | scene_object_vacate | control_panel_vacate: panel; status_bar_vacate: status |
| 24 | attach | occupancy | scene_object_attach | actor2d_attach: fighter opponent banner energy_bar; control_panel_attach: panel; status_bar_attach: status |
| 25 | canStep | occupancy | scene_object_can_step_default | fighter_can_step: fighter; opponent_can_step: opponent; actor2d_can_step: banner energy_bar |
| 26 | isStepBlocked | occupancy | scene_object_is_step_blocked |  |
| 27 | nextFrame | animation | scene_object_next_frame_default | actor2d_next_frame: fighter opponent banner energy_bar; animated3d_next_frame: panel |
| 28 | prevFrame | animation | scene_object_prev_frame_default | actor2d_prev_frame: fighter opponent banner energy_bar; animated3d_prev_frame: panel |
| 29 | play | animation | scene_object_play_default | animation_play: fighter opponent banner energy_bar; animated3d_play: panel |
| 2A | playIdle | animation | scene_object_play_idle_default |  |
| 2B | stopAndRedrawDc | animation | scene_object_stop_and_redraw_dc_default | actor2d_stop_and_redraw_dc: fighter opponent banner energy_bar; animated3d_stop_and_redraw_dc: panel |
| 2C | stopAndRedraw | animation | scene_object_stop_and_redraw_default | actor2d_stop_and_redraw: fighter opponent banner energy_bar; animated3d_stop_and_redraw: panel |
| 2D | tick | animation | scene_object_tick_default | fighter_tick: fighter; opponent_tick: opponent; animation_tick: banner energy_bar; control_panel_tick: panel |
| 2E | stop | animation | scene_object_stop_default | actor2d_stop: fighter opponent banner energy_bar; animated3d_stop: panel |
| 2F | moveTo | movement | scene_object_move_to_default | mover_move_to: fighter opponent banner energy_bar |
| 30 | moveToEdgeH | movement | scene_object_move_to_edge_h_default | mover_move_to_edge_h: fighter opponent banner energy_bar |
| 31 | moveToEdgeV | movement | scene_object_move_to_edge_v_default | mover_move_to_edge_v: fighter opponent banner energy_bar |
| 32 | stopMovingDc | movement | scene_object_stop_moving_dc_default | fighter_stop_moving_dc: fighter; opponent_stop_moving_dc: opponent; actor2d_stop_moving_dc: banner energy_bar |
| 33 | stopMoving | movement | scene_object_stop_moving_default | fighter_stop_moving: fighter; opponent_stop_moving: opponent; actor2d_stop_moving: banner energy_bar |
| 34 | moveTick | movement | scene_object_move_tick_default | fighter_move_tick: fighter; opponent_move_tick: opponent; actor2d_move_tick: banner energy_bar |
| 35 | getTimerId | animation | scene_object_get_timer_id_default | actor2d_get_timer_id: fighter opponent banner energy_bar; animated3d_get_timer_id: panel |
| 36 | isMoving | movement | scene_object_is_moving_default | actor2d_is_moving: fighter opponent banner energy_bar |
| 37 | isRunning | animation | scene_object_is_running_default | animation_is_running: fighter opponent banner energy_bar panel |
| 38 | moveToAndDrop | space3d | scene_object_move_to_and_drop_default | object3d_move_to_and_drop: panel |
| 39 | setPosition | position | scene_object_set_position | actor2d_set_position: fighter opponent banner energy_bar |
| 4C | unk4E | position | scene_object_unk4e |  |
| 4D | redrawOverlapping | visibility | scene_object_redraw_overlapping | fighter_redraw_overlapping: fighter; opponent_redraw_overlapping: opponent; object3d_redraw_overlapping: panel |
| 4E | hitboxOverlaps | position | scene_object_hitbox_overlaps |  |
| 4F | boundsOverlap | position | scene_object_bounds_overlap |  |
| 50 | slot5B | position | scene_object_slot5b_default |  |
| 51 | slot5C | position | scene_object_slot5c_default |  |
| 54 | isEnabled | position | scene_object_is_enabled_default |  |
| 55 | getExitIndex | position | scene_object_get_exit_index_default |  |
| 3A–4B, 52/53, 56/57 | type tests | (Object.is/as) | | |

### Other vtables

`SLOTS.tsv` (the same owners as SALGIN's): Object3DVtbl → `space3d`;
AnimationVtbl → `animation`; Mover/Fighter/OpponentVtbl 00 → `movement`;
FighterVtbl 01–02 and OpponentVtbl 01 → `fighters`; ControlPanelVtbl 00
→ `animation`, 01–08 → `panels`; GameVtbl 00 → `game_input`, 01–06 →
`game`; SceneVtbl 00, 05, 07 → `arena`, the rest `scene`;
Backdrop/GridBackdropVtbl → `backdrop`; ConditionVtbl → `game`;
FrameVtbl → `object_create`.

## Units

20 units, 328 functions to port; 109 dead, 468 absorbed (357 thunks, 69
defaults, 42 type tests), 185 replaced (91 CRT, 94 imports). Levels and
hard deps as SALGIN's.

| Level | Unit | Fns | Size | Calls into |
|---|---|---|---|---|
| 0 | `dib` | 8 | 3.7 KB | — |
| 0 | `position` | 27 | 1.2 KB | — |
| 0 | `sound` | 10 | 1.1 KB | — |
| 1 | `backdrop` | 28 | 3.6 KB | dib, position |
| 1 | `object_create` | 27 | 3.0 KB | dib, position |
| 1 | `render` | 17 | 2.3 KB | dib, position |
| 1 | `space3d` | 24 | 4.0 KB | position |
| 2 | `animation` | 26 | 1.7 KB | position, render |
| 2 | `lists` | 17 | 2.0 KB | object_create, position, render |
| 2 | `occupancy` | 18 | 1.7 KB | position, render |
| 3 | `movement` | 20 | 2.9 KB | animation, backdrop, occupancy, position, render |
| 3 | `panels` | 17 | 1.6 KB | animation, dib, lists, object_create, position, render |
| 3 | `scene` | 15 | 0.8 KB | backdrop, lists, object_create |
| 3 | `visibility` | 22 | 1.5 KB | lists, position, render |
| 4 | `fighters` | 14 | 1.5 KB | animation, movement, object_create, occupancy, sound |
| 4 | `hud` | 6 | 1.3 KB | dib, object_create, occupancy, render, visibility |
| 5 | `arena` | 3 | 7.6 KB | animation, backdrop, fighters, hud, movement, scene, sound |
| 5 | `game` | 18 | 2.2 KB | animation, fighters, hud, lists, movement, object_create, occupancy, panels, scene |
| 6 | `app` | 8 | 1.3 KB | backdrop, dib, game |
| 6 | `game_input` | 3 | 4.2 KB | game, lists, position, render, space3d |

## Tracker

`noite -p xilindro …`: DB `db/xilindro.sqlite`, plan
`db/xilindro-plan.tsv`, tree `src/xilindro/`, worktrees
`work/xilindro-<unit>/` on branches `port/xilindro-<unit>`; the commands
and the porting steps are SALGIN's with `-p xilindro`.
