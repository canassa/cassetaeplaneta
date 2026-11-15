# Making XILINDRO (and SALGIN) fair: research and a minimal fix plan

> The research behind the Corrigida's fair fight (`Fixes.fight_fair`, `src/core/fight_fair.zig`). The
> owner approved it for the Corrigida (`--fix all`), so the note below about keeping it out of `all` no
> longer holds. Section 5, at the end, is what the port does, how it differs from this plan and the checks.
>
> The owner then found the fair fight "still too hard" for a beginner. The Corrigida's opponent is now this
> fair fight with a personality on top (`Fixes.fight_easy_ai`, `src/core/fight_easy.zig`): the research and
> its numbers are in `docs/fights/EASY_AI.md`. Everything below describes the fair fight alone, which is
> `--fix all,-fight_easy_ai`; section 5's last part has the player bots' win rates for it, before and after.

Scope: the shared fight engine of XILINDRO.EXE and SALGIN.EXE as described in `docs/xilindro/GAME.md`,
`docs/salgin/GAME.md` and `src/xilindro/arena.zig`/`fighters.zig`. Numbers are XILINDRO's unless noted.
Everything in section 4 is a design change, not a bug fix: it belongs behind its own flag (not in
`--fix all`/Corrigida) and needs the owner's OK.

---

## 1. Fairness fundamentals

**Startup, active, recovery.** Every attack in a modern fighting game has three phases: *startup*,
"the windup period" before the attack can make contact; *active*, the frames when it has a hitbox and
can do damage; and *recovery*, when the attacker "is finishing the follow-through and usually left wide
open if you whiffed" ([Infil: Startup](https://glossary.infil.net/?t=Startup),
[Active](https://glossary.infil.net/?t=Active), [Recovery](https://glossary.infil.net/?t=Recovery)).
Startup is the telegraph: the time the defender has to read the move. Recovery is the reward: the
*whiff punish* window, when a missed attack can be hit back ([Infil: Whiff Punish](https://glossary.infil.net/?t=Whiff%20Punish),
[Punish](https://glossary.infil.net/?t=Punish)). Action-game designers break enemy attacks down the
same way. Jerry Zhang's analysis of Dark Souls 3 splits an attack into opening pose (the readable tell),
attack signal (the wind-up, no hitbox yet), attack, end pose and return. The return, the recovery, is
"generally the longest" phase and is the player's window of opportunity. He gives a floor of **340 ms**
for signal plus attack, and calls attacks under that "nearly impossible to dodge"
([Game Developer: Anatomy of an Enemy Attack in Dark Souls 3](https://www.gamedeveloper.com/game-platforms/anatomy-of-an-enemy-attack-in-dark-souls-3)).

**Reaction windows.** Simple visual reaction time is about 190 ms for college-age subjects, and
"usually on the order of 200 ms" ([Wikipedia: Mental chronometry](https://en.wikipedia.org/wiki/Mental_chronometry)).
Gaming write-ups put it at about 200 ms, with 150 ms near the human limit
([Blur Busters: Human reflex](https://www.blurbusters.com/human-reflex-input-lag-and-the-limits-of-human-reaction-time/2/)).
That figure covers one known response to one stimulus. A fight is a *choice* reaction: which attack is
coming, and which answer fits it. Hick's law adds time for each extra alternative (RT = a + b·log₂(n+1),
same source). Zhang's Model Human Processor budget is perceive about 100 ms, think about 70 ms, act about
70 ms. Fighting-game players report the same limits in practice: "if you can reliably react to moves
that have around 20 frames of startup [333 ms], you're doing a super great job", and good players
still get hit by 20-frame moves ([Infil: Reactable](https://glossary.infil.net/?t=Reactable),
[Reaction](https://glossary.infil.net/?t=Reaction)). The practical rule is that **under about 250 ms
is a guess, about 330 to 350 ms is reactable for a practiced player, and 400 ms or more is reactable
for a casual one**.

**Spacing, footsies, range parity.** *Footsies* is "the battle for controlling the space in front of
you": each fighter tries to reach a range it likes and to keep the other out of a range the other likes
([Infil: Footsies](https://glossary.infil.net/?t=Footsies); [SuperCombo: Footsies](https://srk.shib.live/w/Footsies)).
That only works when ranges are knowable and comparable. Hitboxes "try to cover the area where the
strike is causing impact, so it 'makes sense' to players", and hurtboxes "match your character's model
pretty closely" ([Infil: Hitbox](https://glossary.infil.net/?t=Hitbox), [Hurtbox](https://glossary.infil.net/?t=Hurtbox)).
An enemy that hits from farther away than its sprite reaches, or than the player can ever reach, breaks
that contract.

**Block, chip, stun.** A block works because it *holds*: blocked normals usually do no damage, and
chip damage (damage taken through a block) is mostly for special moves, at "usually between 10–25% of
the move's regular damage" ([Infil: Chip Damage](https://glossary.infil.net/?t=Chip%20Damage)).
*Hitstun* and *blockstun* are the periods in which the defender cannot act after being hit or after
blocking ([Hit Stun](https://glossary.infil.net/?t=Hit%20Stun), [Block Stun](https://glossary.infil.net/?t=Block%20Stun)).
A knocked-down character is in most games "invincible to all attacks" until it wakes up
([Infil: Knockdown](https://glossary.infil.net/?t=Knockdown), [Wakeup](https://glossary.infil.net/?t=Wakeup)).
*Pushback* separates the fighters after a hit or block. It is "very important to fighting game balance",
because without it a move that leaves the attacker ahead can be repeated forever
([Infil: Pushback](https://glossary.infil.net/?t=Pushback)).

**Rock, paper, scissors.** Sirlin builds his design on the triangle "attack (rock), block (paper), and
throw (scissors)": every option has a counter, so the game is about reading the opponent rather than
executing one dominant move ([Sirlin: Designing Yomi](https://sirlin.net/articles/designing-yomi);
[Critical Points: The Importance of Rock Paper Scissors](https://critpoints.net/2017/02/08/the-importance-of-rock-paper-scissors/)).
For a simple minigame, the question is whether each enemy action has at least one player answer that
the player can choose *after seeing it*.

## 2. Fair CPU opponents

**The "cheap" CPU is the one that skips the telegraph.** Street Fighter II's AI is a set of small
bytecode scripts. It waits for conditions ("until my opponent is attackable", "until opponent is within
M pixels"), picks scripts at random while idle and by time left in the round while attacking, and reacts
to incoming moves through a per-frame "yoke" value. It cheats by reading that yoke "as soon as you have
input it", a frame before the move appears. Its charge moves cannot fail, and one instruction can switch
off its collisions ([sf2platinum: The AI engine](https://sf2platinum.wordpress.com/2017/01/20/the-ai-engine/);
summary at [Game Developer](https://www.gamedeveloper.com/programming/have-a-peek-inside-the-ai-code-of-i-street-fighter-ii-i-)).
Players remember MKII's and SF2's CPUs for the same reasons: they react faster than a human, and they
input specials faster than a human can ([Set Side B on MKII's CPU](https://setsideb.com/tag/mk2/)).
The lesson is that input-reading and zero-delay reactions are what make a CPU feel unfair. Raw damage
and aggression matter less.

**Punch-Out!! is the model for a one-opponent minigame.** Every attack is telegraphed: "a wind up, a
crouch, or something else entirely to let you know that the punch is coming"
([Vice: What Punch-Out taught us about fighting](https://www.vice.com/en/article/pg5jyy/what-39mike-tyson39s-punch-out39-taught-us-about-fighting-uk-translation)).
After the tell "you have a split second to try and interrupt it with your own attack or get out of the
way" ([Critical Video Game Studies](https://criticalvideogamestudies.com/?p=3291)). Tells are learnable
and sometimes subtle, such as Bald Bull's rematch charge cued by a nodding spectator
([StrategyWiki: Major Circuit](https://strategywiki.org/wiki/Mike_Tyson%27s_Punch-Out!!/Major_Circuit)).
The internals are three layers of script. A match script picks behaviours on fight events and *changes
difficulty values at fixed round-timer markers*. Those values include "how long the opponent stays
vulnerable after a missed punch". A behaviour script sequences punches with explicit pauses ("throw a
right jab, pause for 28 frames, randomly throw either a left or right uppercut"). An animation script
opens windows in which the opponent is vulnerable
([Tomorrow Corporation: Punch-Out overview](https://tomorrowcorporation.com/posts/retro-game-internals-punch-out-overview),
[match script](https://tomorrowcorporation.com/posts/retro-game-internals-punch-out-match-script)).
This maps directly onto the techniques a fair CPU needs:

- **Reaction delay and decision cadence.** The CPU decides on a schedule (scripted pauses), not on
  every frame, and never on the player's raw input.
- **Deliberate openings.** Every attack ends in a vulnerable recovery, and its length is a difficulty
  knob.
- **Difficulty scaling.** Tighten timings at time markers or by fight number. Do not raise damage.
- **No infinite pressure.** Behaviours alternate with idle and pauses. Pushback and knockdown
  invincibility stop lock-downs.
- **Readable randomness.** Random choice among *telegraphed* options is fine, because the tell resolves
  the randomness before the hit.

Karate Champ (1984) used single decisive hits judged as half or full points, with a pause after each
landed hit that resets neutral ([arcade-history: Karate Dou](https://www.arcade-history.com/game/1261/)).
That reset is the same job XILINDRO's 100-px recoil does. I found no primary source on the CPU logic of
Yie Ar Kung-Fu or IK+ (the [IK+ article](https://en.wikipedia.org/wiki/International_Karate_%2B) cites
an Edge making-of that I could not open), so this report makes no claims about them.

## 3. Implementation patterns for a small state-machine fighter

1. **A move is a timeline.** Each move carries `startup`, `active` and `recovery` counted in the
   engine's tick (here a 200 ms beat), plus `reach` and `damage`. The fighter state is
   `idle | walking | startup(move, t) | active(move) | recovery(move, t) | hitstun(t) | blockstun(t) | knockdown(t)`.
2. **Confirm the hit on the active tick, not on the press.** At the active tick, test the *current*
   distance against the move's reach and the defender's *current* state (blocking the right height,
   airborne, in knockdown). This single rule creates spacing, whiffs, blocks and punishes.
3. **Per-move reach.** One number per move is enough for a 1D game: a punch is short, a sweep and a high
   kick are longer. The hurtbox is the sprite's near edge, so reach should match what the frame shows.
4. **Input buffering.** Remember the last move key pressed during the final part of a move and start it
   on the first free tick ([Infil: Buffer Window](https://glossary.infil.net/?t=Buffer%20Window);
   Smash Ultimate buffers 9 frames, [SmashWiki: Buffer](https://www.ssbwiki.com/Buffer)). Without a
   buffer, presses made while the keys are locked are lost, and the controls feel unresponsive. Mick
   West's point is that responsiveness is about the game answering input in time, not about the player
   reacting faster ([Game Developer: Programming Responsiveness](https://gamedeveloper.com/programming/feature-programming-responsiveness-)).
5. **An AI cooldown.** After its recovery, the AI waits `cooldown + rand(0..jitter)` ticks before the
   next decision. That gives a cadence the player can learn, with enough jitter that it isn't a metronome.
6. **Knockback and pushback.** After a hit, push the *defender* (or both) out to a fixed gap that is
   outside the attacker's reach. Make the knocked-down or reeling side invulnerable until it can act.
   Clamp to the screen edges, and if the pushed side is cornered, push the attacker instead.

## 4. Applied to this engine

### What the code does now (XILINDRO)

- Beat = first message ≥ 200 ms after the last beat, so a beat lasts **200–250 ms** in practice (50 ms
  timer). Key presses are handled at once, between beats.
- **Player:** the blow lands on the key press (startup 0) when the gap is ≤ 100. Damage is
  `{1, 2, 1, 2}` (average 1.5). The fighter then recoils 100 px, and all keys stay locked for the
  3-frame move (**600 ms of recovery**). A whiff costs the same 600 ms.
- **Opponent:** it walks 32 px a beat while the gap is > 130. On the first beat with the gap ≤ 130
  (99–130 px), it picks `rand() % 4` and **its damage `{4, 2, 2, 6}` (average 3.5) applies on that same
  beat**. It then plays 2–3 frames and jumps 100 px back to the walk. One cycle is 6–7 beats
  (about 1.3 s).
- The attack beat comes one beat after the last walk step. The walk pose does not change, so nothing
  says "this was the last step". In practice there is **no tell at all**.
- **Clash:** a fighter in any strip other than 4–7 when the attack lands takes full damage and deals
  `g_fighterMoveDamage[strip]`. That includes a whiffing fighter, and a fighter still reeling (strips 8
  and 9 deal 0) **with no reaction and no protection**. Down and Home also *trade*.
- **Block** (with the X1 fix) stops only the high kick. **Jump** stops nothing, and the AI turns a
  sweep into a high kick against a jumping fighter.
- **Opening:** the opponent starts at 200 px, so it attacks within about 4 beats (0.6–0.8 s), while the
  PORRADA banner (X9 fix) is still showing.

### Flaws, the principle each one breaks, and the minimal fix

| # | Flaw | Principle broken | Minimal fix (engine terms) |
|---|---|---|---|
| A | The opponent's damage lands on the beat its attack starts, with no tell | startup/telegraph, reaction window | New AI state **WINDUP**: on arrival, show attack frame 0 for `WINDUP_BEATS = 2`, then resolve on the next beat |
| B | Damage is decided when the attack starts, not when it strikes | hit at active frame | Resolve at the end of WINDUP: re-test the gap ≤ `OPP_REACH` and the fighter's state; otherwise it whiffs |
| C | Opponent reach 130 > player reach 100, and it stops at 99–130, so it can never be hit first | range parity, footsies | `APPROACH_STOP = 100` (walk while gap > 100; it stops at 69–100), `OPP_REACH = 100`. SALGIN already stops at 69–100 against a 120 reach |
| D | A player hit on an attacking opponent leaves its attack running ("keeps its strip") | interrupt / RPS (Punch-Out) | A player blow that lands while the opponent is in WINDUP cancels the attack, and the opponent reacts (existing `g_reactionTable`) |
| E | Block holds only against the high kick; jump avoids nothing | RPS: every attack needs an answer | Block holds against punch, middle kick and high kick (0 damage; optional chip `damage/4`); jump avoids the sweep; a sweep beats block. Leave the AI's sweep-to-high-kick swap, now readable because it is chosen at WINDUP start |
| F | A reeling or falling fighter takes full damage again; whiffing or recovering counts as a "clash" | hitstun / knockdown invulnerability | Fighter in strip 8 or 9: the opponent's hit whiffs. Fighter in strips 0–3: an ordinary hit (reaction + damage), no double damage. Remove the Down/Home trade (`trade = false`) |
| G | The opponent jumps 100 px back the moment its move ends, so a dodge earns nothing | recovery = punish window | `OPP_RECOVERY_BEATS = 1` (2 for easy): stay in place, in range, before the jump back |
| H | The attack comes 0.6–0.8 s after start | opening / readiness | `START_DELAY_BEATS = 10` (2 s, the banner's time): no AI until then |
| I | Damage 1.5 per player hit vs 3.5 per opponent hit, both from 91 energy | pacing / balance | `FIGHTER_DAMAGE = {2, 4, 2, 4}` (×2). The tie-on-time win and the ×150 score are unchanged |
| J | Presses during the 600 ms key lock are dropped | input buffering | Remember the last move key pressed in the move's final beat and start it on the beat the latches clear (`BUFFER_BEATS = 1`) |
| K | The 600 ms lock after every press, even a whiff | recovery length | Optional: make the punch 2 frames (`fighterStripFrames[0] = 2`, 400 ms), so it is the fast, safe poke |

How the fixed cycle plays: the opponent walks in to 69–100 px, so both fighters are now in range of each
other. It shows the wind-up pose (frame 0 of its attack strip) for 2 beats. During those 400–500 ms the
player can:

- hit first (D): the attack is cancelled and the 100-px recoil resets neutral;
- block the punch or a kick (E);
- jump the sweep (E);
- step back with Left (32 px puts the gap at 101–132, out of reach, B).

If the player dodged or blocked, the opponent stands in range for 1 beat (G) and can be punished, then
jumps back. Doing nothing, or guessing wrong, costs the attack's damage, as now. That is a complete rock,
paper, scissors built on a readable tell, the Punch-Out!! structure, using only the strips and tables the
game already has.

### The 200 ms beat: is 1 beat of wind-up enough?

The wind-up appears on beat N's redraw, presses are processed immediately, and the hit resolves on beat
N+W. The reaction window is therefore exactly **W beat periods**, 200–250 ms each. It is *not* 200–400 ms:
a press must arrive before beat N+W runs, so W = 1 gives 200–250 ms. That is at or below the median
*simple* reaction time (about 190–250 ms, section 1), and this is a *choice* reaction among four attacks
and four answers. With W = 1 a casual player wins roughly half the reads by luck and the rest by guessing.
It is too short.

- **W = 2: 400–500 ms.** Above Zhang's 340 ms floor and above Infil's "great job" 333 ms. Reactable for
  a casual player once the tells are learned. **Recommended default.**
- **W = 3: 600–750 ms.** Generous. Use it for an easy setting, or for the first 30 s of the round in the
  Punch-Out style: drop to W = 2 at the 60 s mark, a time-marker escalation.
- W = 1 only as a late-round or hard variant, combined with a predictable pattern (Punch-Out!!'s fast
  jabs work because they are learnable patterns, not because they are reactable).

The tell must also be *distinguishable*: frame 0 of each attack strip should differ visibly by height.
If two attacks share a wind-up pose, play a different sound on the wind-up beat (`soco` vs `chute3`) and
keep `dor3` for the hit. Sound cues are a valid tell (see Reaction above). The other fixes stay
beat-granular and need no sub-beat timing.

### Ranking: impact per effort

**Minimal "fair" set** (one AI state, a few constants, no new art):

1. **A + B, wind-up and resolve-at-active** (`WINDUP_BEATS = 2`, `OPP_REACH`): the biggest single change.
   One new opponent state in `arena.zig` (`counterAttack` splits into start and resolve).
2. **C, range parity** (`APPROACH_STOP = 100`, `OPP_REACH = 100`): two constants in the `0x83` test and
   the resolve test. Without it the player cannot hit during the wind-up.
3. **D, interrupt**: a few lines in `landHit` (if the opponent is in WINDUP, cancel and react).
4. **H, start delay** (`START_DELAY_BEATS = 10`): trivial, ties to the banner fix.
5. **F, no hit on a reeling fighter, no clash double damage, no trade**: a few lines.
6. **E, block and jump answers**: replaces the X1 rule with a per-attack `blockable[4] = {1, 1, 0, 1}`
   and `jumpable[4] = {0, 0, 1, 0}`.
7. **I, damage ×2 for the player**: one table.
8. **G, a 1-beat recovery in range**: delays the jump back in `opponentStep` by one beat.

**Deeper changes** (more feel, more effort):

9. **J, input buffer.** Small, but it touches the latch logic (X4 and X5).
10. **K, per-move recovery and per-move reach** (punch 80, middle kick 100, high kick 110, sweep 110),
    with startup on the heavy kicks (1 beat) so they carry risk.
11. **AI cadence:** `OPP_COOLDOWN_BEATS = 1` plus `rand() % 3` jitter after the walk-in, and occasional
    feints (walk in, walk out).
12. **Time-marker difficulty** (W = 3 → 2 at 60 s, recovery 2 → 1 at 30 s) and held-block semantics
    for the new Down key.
13. **A faster beat** (100 ms) for smoother animation, with the beat counts doubled. Only if the strips
    look too choppy, since every frame count changes.

### Tuning by playing

Put the numbers in one `Tuning` struct, enabled by a single design flag (for example `--fix
xilindro_fair`, kept out of `all` until the owner agrees). Allow overrides through an environment
variable or command-line flag (`--tune windup=3,reach=100`) so the owner can play variants without
rebuilding. Add a debug overlay that shows the gap in px and the AI state. In order of importance:

1. `WINDUP_BEATS` (2): the fairness dial; 3 is easy, 1 is hard.
2. `APPROACH_STOP` / `OPP_REACH` (100 / 100): whether the player can interrupt and whether a step back
   dodges.
3. `FIGHTER_DAMAGE` scale (×2): round length. Target: a player who reads about 70% of the tells wins by
   KO at around 60 s.
4. `OPP_RECOVERY_BEATS` (1): how rewarding a dodge is.
5. `START_DELAY_BEATS` (10), `OPP_COOLDOWN_BEATS` / jitter (0 / 0 for minimal).
6. `OPP_DAMAGE` (`{4, 2, 2, 6}`): leave it alone at first. The high kick at 6 makes reading the tell
   worth it.

Back the owner's play with the headless harness. Three scripted players bound the tuning:

- a do-nothing script must lose (as `tools/play/xilindro-alone-lose.input` does now);
- a masher that presses PgUp every beat must lose or scrape by on time;
- a "reactor" that answers each tell 300 ms after the wind-up must win clearly.

If the reactor loses, the window is too short or the damage too low. If the masher wins, the interrupt
is too strong; fix that by giving the punch less reach than `APPROACH_STOP`, or 1 beat of startup.

The same plan applies to SALGIN with its own constants (reach 120, approach 100, opponent damage
`{1, 2, 1, 2}`). There, steps C and I matter less, and A, B, E and H matter most.

## 5. What the port does (`fight_fair`, in the Corrigida)

One flag for both fights, `Fixes.fight_fair`, in `Fixes.all()`. The Original is unchanged: every
change sits behind the flag in each program's `arena.zig` (`fairBeat`, `fairLandHit`, `fairStrike`);
the shared part is `src/core/fight_fair.zig`: the numbers (`Tuning`, one set per fight), the AI's state
(`Ai`), the strike's rules (`strikeOutcome`) and the debug overlay.

### The cycle

On each beat, after the fighter's own frame step, the opponent runs one phase:

| Phase | What it does | Next |
|---|---|---|
| approach | walks in, 32 px a beat; one step out of reach (gap 101-132, *the edge*) it stands `edge_beats` + 0..`jitter_beats` beats | in range (gap <= `approach_stop`): wind-up, or a feint (1 in `feint_one_in`) |
| windup | the tell: frame 0 of the attack it chose now (`rand() % 4`, the Original's choice, sweep to high kick against a jumping fighter) and the attack's own wave; `windup_beats` beats | strike |
| strike | the outcome (below), then the attack's other frames, one a beat | recovery |
| recovery | stands in range, frozen in its follow-through, `recovery_beats` beats: the punish window | jumps back `retreat_px`, then pause |
| pause | stands `pause_beats` + 0..`jitter_beats` beats | approach |
| feint | came in, stands `feint_beats` beats in its stance | jumps back, pause |
| reel | hit by the fighter: its reaction (the table's, as a walking opponent: the reel, the fall when weak) plays; it cannot be hit | jumps back if in range, pause |

Without the controls screen (`--fix fight_fair` alone) it first stands `start_delay_beats` (10, the
banner's 2 s); with it, PORRADA's frozen intro (`fight_controls.start_delay_ms`) already holds the
round, so the AI starts with the round (checked: the opponent stands through the intro).

Its choices use only the game's own `rand()` (deterministic in the harness) and what the screen shows:
the gap, and whether the fighter has just started a blow (below). It never reads a key.

**The strike** (`strikeOutcome`) resolves when it lands, on the current gap and the fighter's current
pose: gap > `opp_reach` dodged; fighter reeling (strips 8, 9) or in its win pose untouched; blocking
(strip 7) a punch or a kick (`blockable`) holds (0 damage, `block_chip`); jumping (strip 5) the sweep
(`jumpable`) clears it; anything else, a whiffing or recovering fighter included, is an ordinary hit:
the Original's waves, its reaction (a 7 the table gives a non-blocking fighter becomes the reel 9), the
keys locked, `g_opponentMoveDamage` (XILINDRO) / the Corrigida's table (SALGIN) taken. No clash, no
double damage.

**The fighter's blows** land at a gap <= `fighter_reach` (100 in both fights: SALGIN's was 120) for
`fighter_damage` {2, 4, 2, 4} (the Original's x 2), with XILINDRO's recoil as before. No trade. A
reeling opponent cannot be hit (the blow whiffs, no wave, no recoil). Any other opponent reacts by the
table; a blow in the wind-up cuts the attack (*interrupt*).

### Changes from the plan of section 4

- **The edge and the whiff punish** (new, `edge_beats`, `whiff_punish`). With only A-H the masher won:
  pressing a punch every beat, its 3-beat lock and the 2-beat wind-up line up so that 2 tells in 3 find
  it free, and every one of those is an interrupt. So the opponent plays footsies: it stops one step
  out of reach for a beat or two, and if the fighter starts a blow there (a whiff it can see), it steps
  in at once. The strike then lands on the beat the fighter's 3-beat move ends, before a new key can
  start: a whiff is punished. A player who waits for the tell is never caught by it.
- **SALGIN's reach is 100**, not 120 (range parity): at 120 the fighter hits the opponent standing at
  the edge, and a held key won untouched.
- **The tell's sound.** Frame 0 of the attacks is not distinct (the strips, dumped): in XILINDRO the
  punch and the middle kick start from the stance (the guard and walk pose too), only the sweep (low)
  and the high kick (leaning in) differ; in SALGIN all four start from the stance. So the wind-up also
  plays the attack's own wave, without the pain cry the hit adds: XILINDRO `soco` (punch), `chute3`
  (kicks), `soco2` (sweep); SALGIN `soco`, `chute3`, `soco2` likewise. A held block answers all but the
  sweep, so the one read that matters, *sweep or not*, is both seen (the low pose) and heard (`soco2`).
  A blocked attack plays `soco`.
- Not done (section 4's deeper list): the input buffer (J), per-move recovery and reach (K, 10), the
  held-block semantics, a faster beat. The time-marker ramp is there but off (`opening_s` 0).

### Tuning (both fights)

| Knob | Value | Turn it |
|---|---|---|
| `windup_beats` | 2 (400-500 ms) | 3 easier, 1 a guess |
| `opening_windup_beats` / `opening_s` | 3 / 0 (off) | e.g. 3 for the first 30 s |
| `approach_stop`, `opp_reach`, `fighter_reach` | 100, 100, 100 | a step back (32 px) from where it stops dodges |
| `recovery_beats` | 1 | 2 rewards a dodge more |
| `edge_beats`, `whiff_punish` | 1, on | `whiff_punish` off makes mashing pay again |
| `pause_beats`, `jitter_beats` | 1, 1 | the cadence between attacks |
| `feint_one_in`, `feint_beats` | 6, 1 | 0: no feints |
| `retreat_px` | 100 | |
| `start_delay_beats` | 10 | only without the controls screen |
| `fighter_damage` | {2, 4, 2, 4} | round length |
| `block_chip` | 0 | e.g. 1 for chip damage |
| `blockable`, `jumpable` | punch and kicks; sweep | |

The opponent's damage is the Original's (XILINDRO {4, 2, 2, 6}; SALGIN the Corrigida's {1, 2, 1, 2}).

### The easy opponent on top (`fight_easy_ai`)

The fair fight's opponent is a metronome: approach, tell, strike, hop back, pause, a cycle of 6-7 beats whatever
the player does. `fight_easy_ai` keeps the moves, the tells and `strikeOutcome` and changes what the opponent
decides whenever it is free (`docs/fights/EASY_AI.md` "The easy opponent"): it dithers, waits, guards (strip 7:
the punch and the kicks, not the sweep), backs off, starts a blow from too far now and then, counters a blocked
blow, shrugs some hits off and eases off when it leads. The fair fight's `windup_beats` stays 2 (a quarter of the
easy opponent's wind-ups, half in SALGIN, are a lazy 3), so every tell is still readable; the tuning knobs below
are the fair fight's and still apply.

### The debug overlay

F9 in a fight, in a Debug build with `fight_fair` on (SDL window or a script's `key f9`), toggles a box
above the arena: the gap, the AI's phase and beats left, the attack, the beat count, the last strike's
outcome, both x, both strips, both energies, the tells and the interrupts. While it is on, each beat
also prints one line to stderr (`[ms] fair gap ...`), which `tools/fight_plan.py` reads. The web build
(ReleaseSmall) has neither.

### Checks

Three scripted players bound the tuning (`--fix all,-fight_easy_ai`, 2026-11 values; with the easy opponent
the scripts are the `expert` bot's recordings instead, `docs/fights/EASY_AI.md`):

| Player | XILINDRO | SALGIN |
|---|---|---|
| (a) no input: `*-alone-lose.input` | KO'd, window closes at 78.0 s (`lost -1000`) | the clock ends it 27 to 91 (`lost -1000`) |
| (b) A (punch) every beat: `*-fair-mash.input` | 11 interrupts in 41 tells, KO'd at ~79 s, the opponent at 67 | 12 in 47, the clock ends it 38 to 63 |
| (c) the reactor: `*-alone-win.input` | KO at 60.5 s, the fighter untouched (91, +13650) | KO at ~60 s, untouched (91, +9100) |

Every masher variant tried (A, S, D or F every beat, at two beat phases) loses in both fights.

The reactor and the masher are `tools/fight_plan.py`: it probes the port with the script so far plus
F9, reads the beat log, adds the next action and probes again (the run is deterministic). The reactor
answers each tell 300 ms after it shows: with room behind it, a step back (the strike whiffs) and, as
the strike comes, a step in and a kick (S) in the follow-through; against the wall a block (Down) or a
jump (Insert) against the sweep, then a kick while the opponent still stands in range. It never throws
a blow out of reach. `--player fast` answers a tell in reach with a kick in the wind-up instead (an
interrupt; the playthroughs use it, KO about 10 s sooner), and `--ko-at MS` holds the last kick back so
the KO falls on a given beat: then everything after the fight plays as in the held-key fight it
replaces (the SERIAL after XILINDRO in `xilindro-serial-hall.input`, the disco after XILINDRO in
`onebutton.input`).

### The fair fight against the player bots

`tools/fight_bots.py` (`core/fight_bot.zig`, 100 seeds a cell, `--fix all,-fight_easy_ai`) measures the fair fight
with players that see only the screen (docs/fights/EASY_AI.md "Measuring"). A beginner, who reacts to a tell
400-700 ms late and walks into the opponent, wins XILINDRO's fair fight 22% of the time (and is knocked out in
about half of the rounds); a button masher 0%, a decent player (250-350 ms) 100%, SALGIN's novice 100% (it
lands about 31 hits and knocks the opponent out before the clock) and its masher 35%. That is the owner's
"still too hard", measured, and the reason for the easy opponent.
