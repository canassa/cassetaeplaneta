# Easy fighting-game CPU opponents: research note

Purpose: tune the CPU opponent of the 1-D, 200 ms-beat fighting minigame into an
EASY, early-ladder opponent ("Mortal Kombat 1-2 tier"): it takes hits without
blocking, sometimes counters, idles, retreats and makes mistakes.

## Overview

Sections 0-7 are the research: what is known, with sources, about how early-ladder and easy CPU opponents are
built. Sections 8-13 are what the port did with it for XILINDRO and SALGIN: the player bots that measure a fight
(8), the fair fight measured (9), the easy opponent (10), its results (11), the choices the owner has (12) and
what was not done (13). What the research gives, short:

- The only Mortal Kombat AI source found is the leaked Ultimate Mortal Kombat 3 (3DO) code, not MK1 (1992),
  which has no primary documentation. Its CPU is table-driven: one `diff` (0-9) indexes every probability. At
  the first rungs (`diff` 0-2) it reacts to only 15, 17.5 and 30% of the player's attacks, counters 10, 35 and
  55% of those reactions and avoids the rest, may stand idle (20% a decision, twice a round, `diff` <= 4) and
  has no reaction delay at all: its easy feel is dice, not slowness. [verified: MKDRONE.C, MKMAIN.C]
- Street Fighter II's CPU is bytecode scripts: random small walks forward and back while it waits, scripts chosen
  by the time left in the round, and it reads the player's input one frame early. The "cheap" feel of both
  games' hard rungs is that: input reading and zero reaction time. [verified: sf2platinum]
- Beatable-AI practice: reaction budgets of 15 frames (FightingICE) to 230 ms (a pro-level agent) are the
  *minimum*; block frequency and block/counter accuracy are the standard difficulty knobs; difficulty ramps with
  the player's wins and resets after a loss (UMK3's `diff_adjust`). [verified / verified*]
- Not found: any MK1 AI write-up, Ed Boon or John Tobias on how the CPU works, SF2's per-difficulty numbers,
  SNK or Killer Instinct arcade CPU documentation (section 7).


Status key used throughout:

- **[verified]** primary or near-primary: source code, disassembly, a developer's
  own statement, an official rules page, a peer-reviewed measurement.
- **[verified*]** secondary documentation of game data or industry practice by an
  expert or a curated wiki (no code shown), or a self-report by a reverse
  engineer who did not publish data. Stronger than lore, weaker than code.
- **[lore]** forum posts, YouTube-derived blog summaries, player experience.

Every source below was opened (fetched or downloaded and read) unless section 7 lists it
as "snippet only". Access date: 2026-11-15.

Caveat that matters for the whole note: the only AI **source code** found for the
Mortal Kombat family is the leaked **Ultimate Mortal Kombat 3 (3DO)** code
(Midway, Feb-Oct 1995). It is not MK1 (1992) and not the arcade build, but it is
the same team's later work and its `drone` AI is the best primary evidence of how
Midway tied difficulty to the ladder. MK1 itself has almost no primary
documentation (section 1.3).

## 0. Summary table

| Claim | Status | Source |
|---|---|---|
| UMK3 CPU has one global `diff` (0..9) and every AI decision is a table lookup `table[diff]` | [verified] | [MKDRONE.C](https://raw.githubusercontent.com/ArchivesML/UMK3-3DO-src/master/MKDRONE.C), `ask_mr_diff` |
| `diff` starts at 0 each new game, rises +1..+3 per match the human wins, falls back to 0 (or by 1) when the CPU wins | [verified] | [MKMAIN.C](https://raw.githubusercontent.com/ArchivesML/UMK3-3DO-src/master/MKMAIN.C) `diff_adjust` |
| At diff 0-2 the CPU only reacts to 15 / 17.5 / 30 % of the player's attacks (`d_randpers`) | [verified] | [MKDRONE.C](https://raw.githubusercontent.com/ArchivesML/UMK3-3DO-src/master/MKDRONE.C) `react_jump_table` |
| When it does react at diff 0-2, it counters 10 / 35 / 55 % of the time and avoids (block/duck/evade) the rest | [verified] | same, `rpt_counter` |
| Anti-spam: once the same player action is among the CPU's last 6 hits 3 times (diff 0-2), it counters every time | [verified] | same, `repeat_table`, `count_q_repeats` |
| At diff <= 4 the CPU may "hang out" (stand in stance) with 20 % chance per decision, max 2 per round; none at diff >= 5 | [verified] | same, `hangout_check`, `d_hang_out`, `d_init` |
| The CPU polls the player's current action every game tick; there is no explicit reaction delay | [verified] | same, `d_beware`, `d_stance_pause` |
| MK1 arcade Rev 3.0 (31 Aug 1992) note: "Computer intelligence increased" | [verified*] | [Arcade-History](https://www.arcade-history.com/game/1674/) |
| Arcade MK CPU "reads inputs", blocks instantly, is unfair after the first few opponents | [lore] | [Arbiter's Judgement](https://arbitersjudgement.blogspot.com/2012/02/mortal-kombat-arcade-kollection.html?m=1), [Atrocious Gameplay](https://atrociousgameplay.miraheze.org/wiki/Mortal_Kombat_2_CPU) |
| MKII CPU exploitable by jump-back / uppercut / sweep spam on early opponents | [lore] | [MKO thread](https://www.mortalkombatonline.com/t/classic/the-cpu-behavior-in-mkii/L5JH1Zn6YA), [Atrocious Gameplay](https://atrociousgameplay.miraheze.org/wiki/Mortal_Kombat_2_CPU) |
| SF2 AI is bytecode scripts; 3 modes; 8 script levels picked by time left in the round | [verified] | [sf2platinum: The AI Engine](https://sf2platinum.wordpress.com/2017/01/20/the-ai-engine/) |
| SF2 AI reads the player's input one frame before the animation shows (the "yoke") | [verified] | same |
| SF2 board has jumpers for 8 difficulty levels; "the computer lets plenty of attacks through unguarded" depending on difficulty | [verified] | same |
| SF2 difficulty "rises steadily during rounds"; loser of round 1 gets a 2P advantage | [verified*] (self-report, no data) | [Sonic Retro, Dr. Ivo](https://forums.sonicretro.org/goto/post?id=619398) |
| Smash CPU level mainly sets "how likely a CPU is to act and how fast it reacts"; level 1 "almost never" acts quickly | [verified*] | [SmashWiki: Artificial intelligence](https://www.ssbwiki.com/Artificial_intelligence) |
| Smash (Brawl+ and later) level-to-value scale 0, 15, 21, 31, 42, 48, 60, 75, 100 | [verified*] | same |
| FightingICE gives its AIs state delayed by 15 frames (250 ms) "to simulate human response time" | [verified] | [FightingICE rules](https://ice.ci.ritsumei.ac.jp/~ftgaic/index-3.html) |
| A pro-level fighting AI was given an average 230 ms delay "so that the AI does not have an advantage" | [verified] | [Oh et al., arXiv 1904.03821](https://arxiv.org/abs/1904.03821) (PDF text) |
| Mean simple reaction time 231 ms (213 ms hardware-corrected), n = 1469 | [verified] | [Woods et al. 2015](https://www.frontiersin.org/journals/human-neuroscience/articles/10.3389/fnhum.2015.00131/full) |
| Fighting-game AI difficulty is commonly tuned by block frequency, block/counter accuracy and action timing | [verified*] | [Game Developer (T. Thompson)](https://gamedeveloper.com/programming/the-killer-groove-the-shadow-ai-of-killer-instinct) |

## 1. Mortal Kombat

### 1.1 What is verified: the UMK3 `drone` AI (leaked source)

Provenance. The repository
[ArchivesML/UMK3-3DO-src](https://github.com/ArchivesML/UMK3-3DO-src) is described
as "The source code for Ultimate Mortal Kombat 3 for the 3DO console". Files carry
Midway headers ("By: David Schwartz", dates Oct 1994 to May 1995) and the C is a
literal port of 34010-style assembly (`current_proc->a0`, `pa8`, `ta1`
pseudo-registers). It is an unofficial leak, so treat it as near-primary, not as an
official release. I downloaded and read `MKDRONE.C` (7816 lines), `MKMAIN.C`,
`MKLADDER.C`, `MKUTIL.C`, `MKOPT.C`, `MKDRONE.H` from
`raw.githubusercontent.com/ArchivesML/UMK3-3DO-src/master/`. "Drone" is the code's
name for the CPU player (`drone_begin`, `drone_proc`).

**One difficulty variable.** `short diff;  /* current game difficulty */`
([MKGAME.H](https://raw.githubusercontent.com/ArchivesML/UMK3-3DO-src/master/MKGAME.H)).
`ask_mr_diff()` is documented as "table of 10 randper values which are used based
on the magical variable called diff" and does `randper(*(pa0+diff))`, with
`if (diff>9) ... // diff is fucked up use 7`. `randper(prob)` is "probability of
event (0-1000)" ([MKUTIL.C](https://raw.githubusercontent.com/ArchivesML/UMK3-3DO-src/master/MKUTIL.C)),
so a table entry of 150 means 15 %. [verified]

**How `diff` moves** ([MKMAIN.C](https://raw.githubusercontent.com/ArchivesML/UMK3-3DO-src/master/MKMAIN.C),
`diff_adjust`, "end of round adjustment of the variable @diff", David Schwartz,
Oct 1994): [verified]

- `game_over()` sets `diff=0`; a fresh game therefore starts at 0.
- Called at the end of every match (`end_of_match_chores`).
- Not adjusted in a two-human game.
- Human won the match: `diff += ladder_diff_slopes[ladderorder_a1()]` with
  `ladder_diff_slopes[]={1,2,2,3}`, i.e. +1 to +3 per match won. (The global
  `ladder` selecting the slope is not defined in the files I read; its meaning is
  not confirmed.)
- CPU won the match: `--perform; if (perform>3) diff--; else diff=0;`. `perform`
  counts the human's net match wins (`++perform` on a human win). So losing early
  (fewer than 4 net wins) snaps `diff` back to 0, a late loss only drops it by 1.
- A floor `ladder_diff_minimums[]={0,1,2,3}` is applied, then `diff` is clamped to
  0..9. The attract-mode demo game runs at `diff=5`.
- The operator setting `cmos_diff` (default 2, menu values "Very Easy, Easy,
  Medium, Hard, Very Hard" from `opt_diff` in
  [MKOPT.C](https://raw.githubusercontent.com/ArchivesML/UMK3-3DO-src/master/MKOPT.C))
  is read by `get_adj_diff()` and a set of `diff_min_1..5[]` tables, but in the files
  I read `diff_min_tables` is declared and never used by `diff_adjust`, so I could
  not confirm that the dip/menu setting feeds `diff` here. Not verified.

**The probability tables** (all in `MKDRONE.C`; index = `diff` 0..9; value =
per-mille):

| Table | Meaning (from the code around it) | diff 0..9 |
|---|---|---|
| `d_randpers` | chance the CPU reacts at all to a player action | 150,175,300,400,550,600,650,700,750,750 |
| `rpt_counter` | given it reacts: counter (else "avoid") | 100,350,550,600,700,750,800,800,800,900 |
| `repeat_table` | how many repeats of one action it will keep ignoring randomly | 3,3,3,2,2,2,2,1,1,1 |
| `rpt_promoves` | "should I promove" (chain/pro moves) | 100,500,680,700,750,775,785,795,800,850 |
| `rpt_cornered` | cornered: run in vs stalk | 100,100,100,600,650,700,750,800,800,850 |
| `rpt_counter_airborns` | counter an airborne opponent | 100,100,100,250,333,550,600,700,750,750 |
| `rpt_angle` | respond to an angled jump | 100,100,100,150,200,400,450,600,700,750 |
| `rpt_anti_kano` | anti-charge reaction | 100,100,350,500,600,650,750,750,750,750 |
| `rpt_elbow_knee` | elbow/knee counter | 100,300,450,550,650,700,700,750,800,850 |

(`repeat_table` is a count, not per-mille.)

**The reaction function** (`react_jump_table`, "react to given move"): [verified]

1. `count_q_repeats(action)` scans the CPU's own **hit queue** (the last six hits it
   took) and counts how many equal the incoming action.
2. If that count is below `repeat_table[diff]`: with probability
   `1 - d_randpers[diff]` it does nothing (`return_to_beware`); otherwise it picks
   "avoid" with probability `1 - rpt_counter[diff]`, else "counter".
3. If the count has reached `repeat_table[diff]` (the same move already hit it 3
   times at diff 0-2), it skips the dice and always counters.

Derived rates for the easy diffs (arithmetic on the tables above): at diff 0 the
CPU ignores 85 % of the player's attacks, avoids 13.5 % and counters 1.5 %; at
diff 1: 82.5 % / 11.4 % / 6.1 %; at diff 2: 70 % / 13.5 % / 16.5 %; at diff 9 it
ignores 25 %, avoids 7.5 % and counters 67.5 %. Spamming one move is punished: in
this code that is the designed answer to "you abuse me I abuse you" (the comment
on `c_angle_jump`, which also fires when `f_aabuse>10`).

**Idle.** `hangout_check()`: `if (diff>4 || dv_hangout==0) return; chance_do(&c_hc);`
with `DCHANCE c_hc = {200,d_hang_out}` and `chance_do` = `randper(prop)`, i.e. a
20 % chance each time the main loop reaches the decision point, at most
`dv_hangout=2` times per round (set in `d_init`). `d_hang_out` holds the stance for
`randu_minimum(0x40*2,0x30)` ticks while still calling `d_beware()` and facing the
player (`d_stance_pause`). "hard no hangouts" is the comment for diff > 4. Tick
length was not established. [verified]

**Reaction timing.** `drone_entry` -> `d_beware()` reads the opponent's current
action id every tick (`d_get_his_action`); no action means "no act --> no react";
the same action as last tick is ignored. There is no frame delay anywhere; the
human-like slowness at low diff comes only from the dice above. [verified]

**Other diff gates** (all `MKDRONE.C`): [verified] `run_in_close` with `diff<2` goes
to a flip kick only; `is_throwing_allowed` with `diff<2` disallows zaps
(projectiles); `d_propell_attack` with `diff<3` calls `diff_no_propell()`;
`diff>4` selects the harder kick table, `diff>=5` the `run_in_close_hard` table
(elbow, knee, slam), `diff>=6` removes the zap option when the player jumps.
Attack choice is a uniform `random_do(table)` per distance band (very close < 0x45,
close < 0x78, far < 0xf0 scaled units). After a block it waits
`d_wait_nonattack(0x40*2)` before acting again.


### 1.2 What is lore about MK2/MK3 arcade CPUs

- "The A.I. reacts to your inputs, not what happens on screen", "skips the startup
  delay that limits human blocking" and "the AI doesn't block the first three
  bicycle kicks each round": opinion page, no sources or test data
  ([Atrocious Gameplay: MK2 CPU](https://atrociousgameplay.miraheze.org/wiki/Mortal_Kombat_2_CPU)). [lore]
- MK2 exploits: sweep spam "on earlier opponents only", ice puddle spam, uppercut
  then slide ([same](https://atrociousgameplay.miraheze.org/wiki/Mortal_Kombat_2_CPU)).
  Forum version: jump back and the CPU jump-kicks or throws a projectile, "The
  computer stands still for a second" after you jump back, the jump-back trick stops
  working at Kintaro ([MKO: The CPU behavior in MKII](https://www.mortalkombatonline.com/t/classic/the-cpu-behavior-in-mkii/L5JH1Zn6YA)),
  Kintaro "will always stomp or toss a fireball when he knows he's getting whooped"
  ([MKO: Impossible AI](https://www.mortalkombatonline.com/t/classic/gawd-help-me-impossible-ai-in-mortal-kombat-ii-mat2/ZP2QTr3L0ja), 2005,
  Midway Arcade Treasures 2). Several posters there mix MKII, MKT and UMK3. [lore]
- UMK3 flaws as listed on Wikipedia: after a backflip jump-kick "the AI character
  will always throw a projectile"; walking back and forth in a range makes "the
  opponent mimic the player's walking movements for the whole round and never
  attack"; a cornered CPU lets the player punch repeatedly "without the AI character
  stumbling back" ([Wikipedia: UMK3](https://en.wikipedia.org/wiki/Ultimate_Mortal_Kombat_3)).
  Wikipedia gives no code reference for these. [lore]
- "Dynamic difficulty": commenters say the MK arcade "gets easier after a loss,
  until you win" ([Nintendo Life comments](https://www.nintendolife.com/news/2019/09/video_how_the_cpu_used_to_cheat_in_street_fighter_ii)). [lore]
  Note that the UMK3 `diff_adjust` code above (reset to 0 after an early loss) is
  exactly this behaviour, so the lore is corroborated for UMK3 by section 1.1.
- Modern Vintage Gamer's MK2 video argues the CPU cheats; per its summaries it used
  the UMK3 PlayStation code, which "uses a dynamic difficulty variable called diff",
  because MK2's code was not public at the time
  ([Set Side B](https://setsideb.com/?p=11644),
  [EventHubs](https://www.eventhubs.com/news/2022/apr/14/mortal-kombat-2-literally-cheated/)).
  I did not open the video itself; the blogs give no numbers. The `diff` claim is
  confirmed independently by section 1.1. [verified*]

### 1.3 MK1 (1992) specifically

- Arcade revision history: Rev 3.0, 31 Aug 1992: "Computer intelligence increased"
  ([Arcade-History](https://www.arcade-history.com/game/1674/)). This shows the
  CPU was retuned by the developers after release; it says nothing about how. [verified*]
- Arcade-museum's community DIP list for MK has coinage, blood, violence, no
  difficulty switch, and warns it "has not been tested or verified"
  ([Arcade Museum](https://arcade-museum.com/dipswitch-settings/mortal-kombat)). So
  I found no verified MK1 difficulty dip. (The MK3-era menu-driven setting is in
  section 1.1.) [lore]
- Reviewer's recollection: MK1's CPU would "instantly counter you pretty much no
  matter what you did" after the first few opponents, "depending on the cabinet's
  difficulty dip switch", not tested in the article
  ([Arbiter's Judgement](https://arbitersjudgement.blogspot.com/2012/02/mortal-kombat-arcade-kollection.html?m=1)). [lore]
- Ed Boon: no interview was found that describes CPU logic. The only AI anecdote is
  that a Kung Lao teleport crashed the game when the CPU used it and was left
  unfixed for a while because few people played the CPU, per EventHubs' write-up of
  a 2022 recollection (search result, see section 7). Not about difficulty.

Net for MK1: it is not documented. The credible, code-backed description of the
Midway approach is the UMK3 table-driven `diff` ladder in 1.1, and the first
opponents in that scheme (diff 0-2) ignore most attacks.

## 2. Street Fighter II

### 2.1 sf2platinum "The AI Engine" (primary, from the ROM)

Source: [sf2platinum, "The AI Engine", 2017-01-20](https://sf2platinum.wordpress.com/2017/01/20/the-ai-engine/)
(the blog is a reverse-engineering project of SF2 World Warrior's code; a
Portuguese summary is on [TabNews](https://www.tabnews.com.br/rafael/a-inteligencia-artificial-do-street-fighter-ii)
and the post was shared in the [NESdev thread](https://nesdev.nes.science/f5/t15825.xhtml)).
All [verified] unless noted.

- Not learning: "isn't very sophisticated"; computer fighters run small bytecode
  scripts, one set per opponent and per circumstance (e.g. a nearby fireball).
- Attack opcode 0x10 takes attack type, strength (low/mid/high = 0/2/4) and a repeat
  count; wait opcode 0x00 waits 0x00-0x7F frames, or until a fireball can be thrown
  (0x80), the opponent is within M pixels (0x81), is attackable (0x82), or a jump
  reaches height M (0xC0). Example: Ryu's easy script is three fireballs, then a
  throw if the player is dizzy.
- Three modes: (1) waiting for an attack, "random scripts, mostly small forward or
  backward walks"; (2) actively attacking; (3) reacting to an attack, scripts chosen
  by the attack's **yoke** value stored in each animation frame's metadata.
  Reacting happens "Sometimes".
- Modes 1 and 2 use **8 script levels chosen by the time remaining in the round**;
  thresholds are not given.
- Reaction advantage: the AI reads the yoke "as soon as the player inputs a move",
  "one more frame of advantage on top of your reaction time".
- Difficulty: the board has jumpers for 8 levels; the author tested mainly the
  easiest; "Depending on the AI difficulty setting the computer lets plenty of
  attacks through unguarded."
- Built-in advantages: charge moves "are simply executed as instructions, so they
  cannot fail"; one instruction can disable collisions against the computer for N
  frames.
- Not given: script-selection probabilities, reaction delays beyond the one frame,
  how difficulty changes with player performance, per-difficulty block rates. The
  promised post on higher difficulties is not on the blog index
  ([blog home](https://sf2platinum.wordpress.com/)).

### 2.2 Other SF2 sources

- Dr. Ivo, Sonic Retro, 2011-09-14: "reverse engineered the AI (and difficulty)
  system"; the game "gets steadily harder during rounds", in 2P the first-round
  loser gets an edge, damage is metered near the end of a match, and he holds "the
  exact statistics for all of the randomness" but publishes none
  ([Sonic Retro](https://forums.sonicretro.org/goto/post?id=619398)). [verified*]
- A Nintendo Life comment thread repeats: input reading ("uses the player inputs to
  trigger CPU attacks"), charge moves with no charge, and that Hyper Fighting is
  "the fairest" ([Nintendo Life](https://www.nintendolife.com/news/2019/09/video_how_the_cpu_used_to_cheat_in_street_fighter_ii)).
  The SF2 cheating videos (YouTuber "desk", Modern Vintage Gamer) are only known to
  me through blog summaries, e.g. [Set Side B](https://setsideb.com/?p=11644). The
  yoke/one-frame-early finding is the code-backed version of "input reading". [lore]
  "rank" dynamic difficulty with numbers (section 7).

## 3. Other fighters

### 3.1 Super Smash Bros. CPU levels (SmashWiki)

Source: [SmashWiki, Artificial intelligence](https://www.ssbwiki.com/Artificial_intelligence)
and [AI flaws list](https://www.ssbwiki.com/Flaws_in_artificial_intelligence),
[Melee AI flaws](https://www.ssbwiki.com/AI_flaws_(SSBM)). [verified*]

- "The level mainly sets how likely a CPU is to act and how fast it reacts": level 1
  "will almost never do so, waiting for a long time before eventually doing it";
  level 9 "almost always will instantly".
- Brawl+, Smash 4 and Ultimate use an internal 0-100 scale per level: 1 = 0, 2 = 15,
  3 = 21, 4 = 31, 5 = 42, 6 = 48, 7 = 60, 8 = 75, 9 = 100. Level 1 "rarely acts,
  shields almost never, mashes buttons at a very slow speed, often stands next to
  opponents using weak attacks".
- Default Versus level is 3 (1 in Melee); level 0 events exist where CPUs "don't
  attack at all".
- Level 9 reaction is one frame from Brawl on (Toomai 2013, cited by the wiki), "can
  defend against almost any attack with one-frame reactions". Low levels "almost
  never" shield, or shield at random times in Brawl.
- Melee flaws: CPUs "almost never shield or dodge other oncoming attacks, even at
  level nine"; after a KO "CPUs usually taunt"; some situations make them "cease all
  movement and action". Predictability is "the most common complaint": "if-then"
  logic gives "the exact same response to certain actions".

### 3.2 Killer Instinct

- Shadow AI is not tuned by difficulty sliders: it replays the player's recorded
  behaviour (about 400-700 patterns per match, 40 matches per opponent). The article
  contrasts it with traditional AI, where "Block frequencies, block and counter
  accuracy and time to execute specific actions or action macros are parameterised"
  and lowering block and accuracy values yields "easy" AI; and expert AI is "a
  subject of frustration given their perfect blocking and counter reflexes". It also
  states human reaction as "around 12-19 frames in a 60 frames-per-second game"
  ([Game Developer, T. Thompson, 2017-10-13](https://gamedeveloper.com/programming/the-killer-groove-the-shadow-ai-of-killer-instinct)). [verified*]
- The Rare/Midway arcade KI (1994) CPU: no documentation found. The GDC talk page
  (Neal and Hayles, Iron Galaxy, Shadow system only) says nothing about difficulty
  ([Game Developer](https://gamedeveloper.com/design/video-designing-competitive-game-ai-the-i-killer-instinct-i-way)).

### 3.3 SNK, Samurai Shodown, Tekken, Virtua Fighter

- SNK: only lore found ("SNK boss syndrome": counters immediately after the player
  acts, takes less damage). I found no source stating that SNK CPUs scale with
  consecutive wins. Search snippets only (section 7). [lore]
- Tekken 3, speedrun community guide by Shirdel: on Medium "stages 1-3: the AI will
  very rarely block, if ever ... won't react to strings, 10 hit combos and won't
  break throws ... isn't especially aggressive"; "stages 4-5: will now block more".
  The page returned 403 when fetched; quotes are from the search snippet of
  [speedrun.com guide](https://speedrun.com/tekken3/guides/m0r8j). [lore]
- Virtua Fighter: nothing found.
- Skullgirls: developer post (Ian Cox, 2011-05-02), via search summary only (the page
  loaded as a landing page): easy AIs are specialised teachers, e.g. "an easy
  rushdown AI meant to teach blocking" with jump-ins, ground chains and late sweeps
  ([post](https://skullgirls.com/?p=122)). [lore until read directly]

## 4. General game-AI design for beatable fighters

### 4.1 Reaction time budgets

- Human simple visual reaction: mean 231 ms, 213 ms after correcting for hardware
  delay, n = 1469 adults, +0.55 ms per year of age, motor output is the age-sensitive
  part ([Woods et al., Front. Hum. Neurosci. 2015](https://www.frontiersin.org/journals/human-neuroscience/articles/10.3389/fnhum.2015.00131/full)). [verified]
- FightingICE (the standard academic fighting-game AI competition): "the information
  sent to AIs will have a delay of 15 frames"; "There are 60 frames per second"
  ([rules](https://ice.ci.ritsumei.ac.jp/~ftgaic/index-3.html)). 15 frames = 250 ms. [verified]
- NCSOFT's pro-level DRL agent: "We applied an average of 230 ms of delay for the
  decision of an AI to be reflected in the game, so that the AI does not have an
  advantage. This amount of delay corresponds to the average reaction time of
  professional players" in their game; "the most important factor that affects the
  result is the reaction time" ([Oh et al., 2019, arXiv 1904.03821](https://arxiv.org/abs/1904.03821); text read from the PDF). [verified]
- NESdev thread: "what if the AI can only react to things that were 10 or more
  frames back?" (JRoatch) and "even the best AI shouldn't be frame perfect;
  otherwise, they'd be untouchable" (Drew Sebastino)
  ([thread](https://nesdev.nes.science/f5/t14855.xhtml)). [lore]
- Therefore: SF2 and UMK3 CPUs have effectively zero delay (they read inputs/actions
  directly), and the "easy" feel in UMK3 comes from the 15-30 % chance to react at
  all, not from slowness.

### 4.2 Block probability and "knobs"

- Block frequency, block/counter accuracy and timing are the standard tuning knobs
  ([Game Developer](https://gamedeveloper.com/programming/the-killer-groove-the-shadow-ai-of-killer-instinct)). [verified*]
- Concrete numbers exist only in the UMK3 tables (section 1.1) and the Smash 0-100
  scale (section 3.1).
- Error injection: an old C64 fighter's "table with the exact way to block every
  possible attack", with the AI "sometimes read the wrong entry, with more errors on
  easier difficulties" ([NESdev, "Punch"](https://nesdev.nes.science/f5/t14855.xhtml)). [lore]

### 4.3 Aggression, patience, idling, taunts

- UMK3: idle ("hang out") 20 % per decision, only at diff <= 4, max 2 per round
  (section 1.1). [verified]
- SF2: the "waiting" mode is random short forward/backward walks (section 2.1). [verified]
- Smash level 1: stands near the player using weak attacks, mashes slowly; CPUs
  taunt after KOs and sometimes stand still when nothing is in range
  (section 3.1). [verified*]

### 4.4 Telegraphing and punishable moves

- Punch-Out!! (NES) per the community behaviour guide: Glass Joe starts dodging star
  punches after about seven and a reset allows five more; Von Kaiser dodges after
  roughly five. Only seen in a search snippet of mPap's guide (PDF not opened).
  [lore]
- On Glass Joe the TASVideos strategy page says he gets up on a 1 count and "backs
  up" after certain blocked punches, giving a KO window
  ([TASVideos](https://tasvideos.org/GameResources/NES/MikeTysonsPunchout/GlassJoeStrats)). [verified*]

### 4.5 Dynamic difficulty and rubber banding

- UMK3: win-driven ramp and loss-driven reset, with a floor by ladder position
  (section 1.1). [verified]
- SF2: "gets steadily harder during rounds" per Dr. Ivo, and time-based script
  levels per sf2platinum (section 2). [verified*]
- A recent review of learning-based fighter AI notes that rule-based AIs "tend to
  produce imbalanced difficulty levels, with enemies appearing either trivially easy
  or frustratingly challenging" and that the primary challenge is responding within
  16.6 ms ([Matera and Basile, CEUR Vol-4097](https://ceur-ws.org/Vol-4097/paper2.pdf)). [lore]

## 5. What this suggests for a 1-D, 200 ms-beat minigame

Everything here is **inference** from the evidence above. Units: 1 beat = 200 ms
= 12 frames at 60 fps. Numbers are for an early-ladder opponent (UMK3 diff 0-2
equivalent); a later ladder rung should interpolate toward the diff 5-9 rows.

| Parameter | Proposal (easy tier) | Evidence behind the number |
|---|---|---|
| Respond to a player attack at all | 15 % (first opponent), 30 % (third) | `d_randpers[0..2]` = 150, 175, 300 per-mille (section 1.1) |
| If it responds: block/evade vs counter | counter 10 % / 35 % / 55 %, rest block-or-evade (opponent 1 / 2 / 3) | `rpt_counter[0..2]` |
| Net outcome per player attack | opponent 1: ignore ~85 %, block ~13 %, counter ~2 %; opponent 3: ignore ~70 %, block ~13 %, counter ~16 % | arithmetic on the two rows above |
| Anti-spam rule | once the same player attack has landed 3 times in the CPU's last 6 hits, always answer it | `repeat_table[0..2]` = 3 and `count_q_repeats` (hit-queue of 6); makes sweep/punch spam stop working without raising the base block rate |
| Reaction delay | at least 2 beats (400 ms, 24 frames) between the start of the player's action and any response; fast attacks (punch) are effectively unreadable, long ones (jump, sweep) are readable | 12-19 frames for human reaction ([KI article](https://gamedeveloper.com/programming/the-killer-groove-the-shadow-ai-of-killer-instinct)), 231 ms mean SRT (Woods), 15 frames in FightingICE, 230 ms in NCSOFT; easy should sit above all of them. UMK3 itself has no delay (its slowness is the dice), so the delay is an additional design choice, not an MK fact |
| Idle ("hang out") | 20 % chance at each decision point, at most 2 per round, no idling in later rungs; hold a guarded stance for about 4-10 beats while still tracking the player | `c_hc = {200,...}`, `dv_hangout = 2`, `diff > 4` = none, duration `randu_minimum(0x80,0x30)` ticks. The beat conversion assumes a tick is about one 60 Hz frame (48-128 ticks = 0.8-2.1 s), which is not verified |
| Retreat | include a back-step in the random walk pool with equal weight to a forward step; no separate "retreat after hit" probability is supported | SF2 waiting mode = "mostly small forward or backward walks"; UMK3 `dz_backup` re-evaluates distance each tick. No source gives a retreat-after-hit percentage |
| Cornered behaviour | at opponents 1-3 stay passive: choose "run in" only 10 % of the time | `rpt_cornered[0..2]` = 100 |
| Move variety on easy | no projectile or special-move option below diff 2-3; basic jump-in or one close-range attack | `is_throwing_allowed` (diff < 2), `d_propell_attack` (diff < 3), `run_in_close` (diff < 2 = flip kick only) |
| Aggression ramp | +1 diff step per round the player wins (up to +3 on a faster ladder), reset to the floor when the player loses an early match, drop 1 step when the player loses after several wins | `diff_adjust`, slopes {1,2,2,3}, floors {0,1,2,3}; reset to 0 when `perform <= 3` |
| Whiff/mistake behaviour | after a blocked or missed move wait about 2 beats before the next action | UMK3 `d_wait_nonattack(0x40*2)` after blocks; SF2 scripts use waits between attacks; the beats figure again assumes ticks = frames |
| Telegraph | keep the 2-beat wind-up on the CPU's own strikes | Punch-Out and SF2 scripted waits (lore/verified*); not a number from MK |

Two points from the evidence on what NOT to copy:

- Do not give the CPU "free" input reading or perfect block on the first
  opponents. Every source that calls MK2/SF2 CPUs unfair names exactly that
  (lore, but consistent with the one-frame yoke advantage verified in SF2 and with
  UMK3 `d_beware` polling). The UMK3 easy tier avoids it by reacting only 15-30 % of
  the time.
- Do not add a "mimic the player" idle: UMK3's accidental mimicry loop (never
  attacks) is listed as a flaw.

## 6. Sources opened (all links appear inline above)

32 pages or files were opened: sf2platinum (AI Engine and blog index), TabNews,
NESdev (two threads), Sonic Retro, Nintendo Life, Set Side B (two
posts), MKO (two threads), Atrocious Gameplay, EventHubs, Arbiter's Judgement,
Wikipedia UMK3, the UMK3-3DO-src repository plus seven of its files (MKDRONE.C/.H,
MKMAIN.C, MKLADDER.C, MKUTIL.C, MKOPT.C, MKGAME.H, under
`https://raw.githubusercontent.com/ArchivesML/UMK3-3DO-src/master/`), Arcade-History,
Arcade Museum, three SmashWiki pages, two Game Developer articles, the FightingICE
rules, arXiv 1904.03821 and the CEUR Vol-4097 paper (PDF text read locally),
arXiv 2108.03599 (abstract, no numbers used), Woods et al. 2015, TASVideos Glass Joe,
and the Ritsumeikan DDA page.

Opened but useless: TCRF MK pages, nicole.express, skullgirls.com landing page,
Human Benchmark. Answered 403: TechSpot, GameFAQs, speedrun.com Tekken guide,
Smashboards, srk.shib.live, TVTropes, Medium, Game Developer SF2 piece, NeoGAF.

## 7. Not found, and search-snippet-only items

Not found (searched, nothing usable):

- Any Ed Boon / John Tobias interview describing how the CPU opponents work.
- Any MK1 (1992) disassembly, MAME-driver note or write-up of its AI; the MK2 and MK3
  arcade source leaks have TCRF pages but no AI analysis I could find.
- A verified MK1 arcade difficulty dip/menu list and the ramp over its 12-opponent
  ladder, including how endurance rounds differ.
- A verified MK throw rate for the CPU.
- sf2platinum posts on difficulty levels, the "yoke" detail beyond the AI Engine
  post, "rating", or per-level scripts (the blog index has none).
- Numeric reaction delay, block probability per difficulty, or dynamic "rank" for SF2.
- SNK (Fatal Fury / KOF / Art of Fighting / Samurai Shodown) or Virtua Fighter CPU
  documentation; the "gets stronger the more you win" claim has no source.
- Killer Instinct arcade CPU documentation (only the Shadow system is documented).
- A Millington "AI for Games" fighting-game chapter, a Game AI Pro fighting chapter,
  or a GDC talk by Midway on MK AI.
- Per-level Smash CPU reaction frames from game code for Melee (the wiki gives only
  the 0-100 scale from Brawl onward).
- Tomorrow Corporation / Nintendo posts on the Punch-Out AI; mPap's Punch-Out
  behaviour guide percentages.

Seen only in search results, not opened, so used for no number: Techspot's "CPU
recovers from stuns in 12 frames", the EventHubs Boon/Kung Lao crash anecdote,
Smashboards per-level offsets, mPap's Punch-Out guide, UTS/RMIT MCTS DDA papers.

## 8. Measuring: the player bots

To tune an opponent for a kind of player, the port needs players. `src/core/fight_bot.zig` is a player bot for
both fights (`--fight-bot PROFILE[,SEED][,log][,after=MS]`, a test tool: no original code, not a fix). It sees
what a player sees (`View`: the gap, both poses and frames, both energies, the clock; never the opponent's AI
state), sends the 1995 key codes through the arena's key handler on every WM_TIMER (after the timer's own turn,
translated to A/S/D/F when `fight_keys_asdf` is on), and models a human's reaction time by looking at the screen
as it was `reaction` ms ago. A run is deterministic: it varies with the bot's seed and `--epoch` (the headless
`time()`, which seeds the games' `rand()`). `tools/fight_bots.py` runs a profile over many seeds in parallel.

| Profile | Plays |
|---|---|
| `idle` | no key |
| `masher` | a random blow (72%) or step (28%) every 100-250 ms, whatever is on the screen; never blocks or jumps |
| `novice` | a first-time player: decides every 300-700 ms; walks in to 100 px; attacks 62% of the decisions in reach with a random blow, 72% when the opponent is open; sees a tell (the opponent's first attack frame) 400-700 ms after it shows, answers 75% of those it can (60% of the answers right: block, jump the sweep, else a wrong one or a step back) |
| `decent` | answers 92% of the tells 250-350 ms after they show (96% right: block a punch or kick, jump the sweep, sometimes step back), kicks while the opponent is open (75%), seldom starts a blow itself (10%) |
| `expert` | answers every tell 220-300 ms after it shows, always right, and goes after the opponent; the scripted playthroughs record it |

The bot definitions are mine and the win rates depend on them (the novice's aggression alone swings its win rate by
tens of points); they are fixed by the profile table, not tuned per result. 100 seeds a cell is +-5 points.
The tables use `--fix all,-fight_easy_ai` for "fair" (the Corrigida before this work), `--fix all` for "easy" and
no fix for "orig". An earlier measurement of the fair fight was wrong because the bots' kicks and sweeps were
re-translated by the A/S/D/F layer (a bug in the tool, fixed: `fight_controls.untranslate`); every number here is
from the fixed tool.

## 9. The fair fight, measured (before)

Win rate over 100 seeds, `--fix all,-fight_easy_ai` (win = the 0x40a result is a win: a KO, or at least the
opponent's energy when the clock ends):

| Bot | XILINDRO win % | SALGIN win % |
|---|---:|---:|
| idle | 0 | 0 |
| masher | 0 | 35 |
| novice | 22 | 100 |
| decent | 100 | 100 |
| expert | 100 | 100 |

XILINDRO's beginner loses three rounds in four, and half of all novice rounds end by the opponent's KO: the
fair opponent starts a wind-up every 2 s (45 per 90-s round), 24 of them hit a novice (the novice cuts 18 with
a blow of its own and answers 6 of about 50 tells), for 3.5 energy each (24 x 3.5 = 84 of the novice's 91). Its time
goes 36% walking in, 30% in an attack (wind-up 15, strike 9, recovery 6), 19% pausing, 15% reeling. It never
stands and takes a hit without a reaction, never blocks, never retreats other than the fixed 100-px hop, and
never attacks less because the player is losing: a metronome, as the owner felt. SALGIN is the opposite: its
opponent hits for 1.5, the fighter has no recoil, and a novice lands about 31 hits and knocks it out at 44 s.

## 10. The easy opponent

`Fixes.fight_easy_ai` (in `Fixes.all()`, needs `fight_fair`), `src/core/fight_easy.zig` (decisions, pure,
tested), carried out by each program's `arena.zig` (`easyDecide`, `fairWindup`, `hopBack`, the `wait` and `guard`
phases). The fair fight's moves, tells and rules are unchanged; the opponent *decides*, whenever it is free
(arrived in range, or a pause, a wait or a guard is over), on a personality table (`Style`) rolled with the
game's own `rand()`:

```
approach --(walking in: 20% a beat it stands 1-2 beats)--> edge --(12%: a blow from too far)--> windup
   |                                                          \--> in reach: decide
   v                                                                  |
 decide (in reach): attack 58 | wait 15 | guard 10 | back off 10 | feint 7   (open fighter: 35% attack first)
   attack -> windup 2 beats (25% a lazy 3) -> strike -> recovery -> hop back -> pause (+1 beat after a hit it landed) -> decide
   wait   -> stance 1-4 beats -> decide          guard -> strip 7, 2-4 beats -> (counter 25%: windup 3 beats) | decide
   hit by the fighter: reel -> (15% guard, else 25% back off, else the usual hop back) ;  or shrugged: no reel (10%, SALGIN 60%), not in a wind-up/strike/guard
```

| Parameter (`Style`) | XILINDRO | SALGIN | Why |
|---|---|---|---|
| `w_attack` / `w_wait` / `w_guard` / `w_retreat` / `w_feint` | 58 / 15 / 10 / 10 / 7 | same | the owner's list (idles, blocks sometimes, retreats, feints); calibrated, section 11 |
| `hesitate`, `hesitate_beats` | 20%, 1-2 | same | "does not just keep going forward": the walk in stops (SF2's waiting mode is random small walks forward and back [verified]) |
| `whiff` | 12% | same | a punishable mistake: a wind-up from one step out of reach, which misses unless the fighter walks in |
| `opportunist` | 35% | same | an open fighter (in a blow of its own) is attacked at once only a third of the time: slow reactions |
| `punish` | 50% | same | the fair fight stepped in on every whiffed blow; the easy one sees half |
| guard (strip 7, 2-4 beats) | holds punch, kicks; not the sweep | same | the opponent's block is the fighter's: `blockable`; UMK3 diff 0-2 avoids 11-14% of the player's attacks [verified] |
| `counter` | 25%, windup 3 | same | UMK3 counters 10-55% of the attacks it reacts to; a slower tell than the usual one |
| `windup_beats`, `slow` | 2, 25% lazy 3 | 2, 50% | the fair fight's tell; a lazy one is a beginner's chance |
| `shrug` | 10% | 60% | UMK3 ignores 85% of the attacks it sees at diff 0; SALGIN's opponent would otherwise live in its reel |
| `guard_after_hurt` / `back_off_after_hurt` / `back_off_px` | 15% / 25% / 100 | same | retreat after a hit (no source gives a number: SF2/UMK3 back-step in the waiting mode) |
| `mercy_beats` | 1 | same | a beat's pause after it lands a hit: no long strings (the fair fight already hops back after each blow) |
| rubber band | -18 / +25 energy: attack weight x0.5 / x1.5 | same | UMK3's win-driven `diff` ramp, in small: it presses when it trails, eases off when it leads [inference] |
| `damage_pct`, `fighter_damage_pct` | 100, 100 | 250, 50 | SALGIN's fighter has no recoil: the table's {1, 2, 1, 2} x 2.5 against the Original's {1, 2, 1, 2} |

Verified facts behind these (section 1.1): the probability-table structure, the reaction share at the first rungs,
the counter share, idling at low difficulty, the win-driven ramp. Inference (not from any source): every number in
the table above; the sources fix the shape (decisions by dice, a low block rate, counters now and then, idling,
back-steps), the calibration is by the bots. Not copied: UMK3's absence of any reaction delay (the fair fight's
tells and the 2-beat wind-up stay, the research's rule that an easy CPU must not read inputs or block
instantly), its "same move three times and the CPU always counters" rule (`repeat_table`: a spammed blow is
answered; a next step if masher-proofing is wanted) and its idle limit (two a round).

## 11. Results

Win rate % (and, in the notes, the energies) over 100 seeds. "orig" is the Original (no fix), "fair" the
Corrigida before (`all,-fight_easy_ai`), "easy" the Corrigida now (`all`). `tools/fight_bots.py --seeds 100
--bots idle,masher,novice,decent,expert --fixes orig=orig fair=all,-fight_easy_ai easy=all,-fight_mk3`
(`zig-out/reports/fight-easy-ai/win-rates.tsv`).

| Bot | Target | XILINDRO orig | fair | easy | SALGIN orig | fair | easy |
|---|---|---:|---:|---:|---:|---:|---:|
| idle | loses | 0 | 0 | 0 | 0 | 0 | 0 |
| masher | about half | 0 | 0 | 51 | 96 | 35 | 17 |
| novice | 70-80 | 0 | 22 | 73 | 0 | 100 | 81 |
| decent | about 95 | 0 | 100 | 100 | 0 | 100 | 93 |
| expert | wins | 0 | 100 | 100 | 34 | 100 | 100 |

XILINDRO hits the targets except the decent player, which is a clean 100% (a deterministic reactor never loses the
damage race: it takes 3 hits a round; a human's 95% is errors the bot does not make). SALGIN hits the novice
(81) and the decent player (93) but its masher wins 17%, not half: SALGIN's fighter has no recoil, so a player who
walks in and answers a little (the novice) lands 58 hits a round while a masher, who cannot walk in on purpose,
lands 26, and the opponent's damage cannot be chosen to put both near the target (damage 200%: novice 87, masher
15; 260%: 36 and 2). The Original's SALGIN is a masher's game (96%: it lands 56 hits, the opponent 38) and its
fair version already took that away.

What the XILINDRO beginner's round looks like now (60 seeds, novice bot): the opponent starts 36 wind-ups
(45 before), 17 hit (24 before), the novice cuts 15 of them with a blow, and the round ends on the clock with the
novice ahead, 34 to 22 on average. Its time: 31% walking in, 12% in
a wind-up, 7% striking, 4% recovering, 19% pausing, 14% reeling, 6% waiting, 5% guarding. Per round it decides
about 60 times: 36 attacks (2-3 of them from too far), 8 waits, 6 guards, 6 back-offs, 4 feints; the novice's blows
meet a guard 3 times. The idle bot is knocked out in 9% of the rounds and loses the rest on the clock; the masher
wins half.

A few seconds of it: `zig-out/reports/fight-easy-ai/xilindro-easy-opponent.gif` (the novice bot, seed 2, with the
F9 overlay: a wind-up cut by a blow, a guard, a wait, a wind-up that strikes and the recovery, a guard before the
next wind-up).

Scripts: `tools/play/{xilindro,salgin}-easy-{novice,masher,decent}.input` let a bot play a round (deterministic
results); the Corrigida's alone wins, the street and gym integrations, `xilindro-serial-hall.input`,
`onebutton.input` and `full.input` are re-planned: the `expert` bot's keys, recorded with `tools/fight_plan.py
--player bot` (the bot runs the script with its keys logged, the log becomes the `?fight_easy_ai` block, and the
replay is the same run). The Original's scripts are unchanged; `*-fair-mash.input` now run with
`--fix all,-fight_easy_ai` (the fair fight alone).

## 12. Choices for the owner

1. **Win-rate targets.** XILINDRO: novice 73, masher 51, decent 100, idle 0. SALGIN: novice 81, masher 17, decent
   93, idle 0. The SALGIN masher cannot be brought to half without the novice winning ~every round (section 11):
   say if you would rather have SALGIN's novice at 60 and its masher at 30.
2. **SALGIN's damage** is the Original's {1, 2, 1, 2} for the fighter and 2.5 times that for the opponent. The
   alternative is the fair fight's {2, 4, 2, 4} for the fighter and a higher opponent damage with the same
   win rates; the numbers on the energy bar get bigger, nothing else changes.
3. **The wind-up** stays at the fair fight's 2 beats (400-500 ms) with a quarter (SALGIN: half) lazy 3-beat ones.
   Every lazy one is an easy dodge for a beginner; setting `slow` to 100 makes the masher win ~everything.
4. **Guard.** A held block of the punch and the kicks costs a blow its damage; the sweep (F) goes under it.
   Blows into a guard do not recoil the XILINDRO fighter.
5. **Aggression ramp.** Only the small rubber band (-18 / +25 energy) exists; a per-round ramp (UMK3's `diff_adjust`)
   needs a ladder, which the minigames do not have.
6. **The beginner's round ends on the clock**, not by a KO (XILINDRO's novice lands 23 hits, about 70 damage, in
   90 s): only the expert knocks the opponent out, at about a minute. Say if a beginner should be able to KO.

## 13. Not done, and limits

- UMK3's anti-spam rule (the same blow thrice among the last six hits and the CPU always answers it) is not built;
  a player who throws the same kick every time still wins in SALGIN (the Original's masher wins 96%).
- No taunts or idle animations: the "wait" is the stance (the art has none).
- The bots are mine; real players differ. A first-time human on the web build is the real test, and the knobs
  are `--fight-tune key=value,...` (headless/SDL) on `fight_easy.Style`.
- The Corrigida's `fight_fair` alone (`--fix all,-fight_easy_ai`) keeps its old tuning and checks
  (`docs/fights/FAIRNESS.md`).
