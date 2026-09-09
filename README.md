# Mega Man 3 Style Game (Godot 4.7.x)

An original action-platformer built in the style of *Mega Man 3* (NES, 1990): 8 selectable
stages, weapon-get progression, slide, robot-dog utility items, and boss-rush endgame.

**Status: all eight stages built, and the fortress has opened.** The player controller,
combat, enemies, eight bosses with weapon gets, eight stages of nineteen rooms each, and
the first of the four fortress stages behind the centre cell — all authored as room
tables against a shared `AuthoredStage`. Both weakness cycles close, no boss is weak to
the weapon it drops, and every one of the eight weapon archetypes is used exactly once.
Verified on Godot 4.7.stable, headless, in CI.

| # | Stage | Boss | Weapon | Gimmick |
| --- | --- | --- | --- | --- |
| 1 | Dawn Boardwalk | Tide | Tide Crawler | rising tide |
| 2 | Substation | Arc | Arc Lance | dark room |
| 3 | Breakers | Rust | Rust Bloom | crusher press |
| 4 | Mirror Field | Prism | Prism Ray | disappearing panels |
| 5 | Turbine Row | Gale | Gale Cutter | wind |
| 6 | Stack | Cinder | Cinder Spray | conveyors |
| 7 | Cold Store | Frost | Frost Lock | ice |
| 8 | Sinkhole | Quarry | Quarry Bore | water |

The four movement gimmicks are deliberately four different ideas rather than four
forces: **wind is a cycle you time, the belt is a constant you fight, ice moves nobody
and simply will not stop you, and water is the only one that helps.**

## The fortress

The centre cell of the stage select opens when the eighth Robot Master falls, and holds
four stages played **in order** rather than chosen from. The first is built:

| # | Stage | Boss | What it is |
| --- | --- | --- | --- |
| F1 | Outfall | Tide, rebuilt | the drain the sea comes back through |
| F2 | Caisson | — | the pressure chamber, and whoever is waiting in it |
| F3 | Switchgear | — | eight pads, and everything you already beat |
| F4 | Keep | — | the core |

**A fortress stage has no gimmick of its own, and that is the design.** Each master stage
contains exactly one idea and deliberately none of the others, because a stage that mixes
two teaches neither. The fortress can mix, because there is nothing left to teach — so
Outfall puts stage 8's pool and stage 1's tide in one stage, the two waters, one of which
is a floor and the other instant death. They never share a room: the tell is motion, and
*if the line is moving, it kills.*

Its boss is Tide again, faster. `Boss.aggression` shortens a boss's **recovery** and
nothing else — never the tell, which is the fairness contract, and never the act, which
is what the attack *is* — so a reprise is the same fight with fewer openings rather than
a different fight wearing the first one's sprite. It is Tide specifically because the
fortress is a chain with no stage select in between and therefore no refill, and Tide is
the boss the roster already names as the buster-only one.

**Stages 5–8 are greyboxed**: stage 3's tileset and enemy skins, and backdrops drawn in
code rather than loaded. The layouts were driven by the bot before any art was paid for,
which is PLAN.md's own rule — layout first, art second. Each stage's docstring names the
six enemies it actually wants.

Progress persists two ways, both writing the same struct: a **save slot** at
`user://save_0.json`, written when a stage is cleared and read at boot, and an
MM3-style **password grid** — five by five, one dot per cell, reachable with
**Pause** on the stage select. The slot carries your life count; the password
deliberately does not, because a password that restored lives would let you farm
one, write it down and come back topped up.

Three bosses drop a **utility item** as well as a weapon — Rust the **Rush Coil**,
Gale the **Rush Jet**, Quarry the **Rush Marine**. They ride the weapon system rather
than a menu of their own: they cost ammo, sit on the pause menu and the weapon cycle,
and are selected and fired like anything else, which is how MM3 does it. The Coil is a
spring you land on for a jump you cannot otherwise make; the Jet is a board that flies a
straight line until its fuel runs out; the Marine is the same board, underwater only.
Firing an item spawns the machine beside you rather than a projectile — see
`scenes/actors/items/item_courier.gd`, which is the one place the weapon system is told
that not every shot is a shot.

**Every stage wants a playtester.** The bot completes all eight from spawn to a dead
boss, but it is not a player: it dodges low projectiles better than a human and it never
gets bored, curious or greedy. Cold Store is the clearest case — the bot beats Frost
without taking a hit, because that fight's two answers happen to be the bot's two
strongest reflexes.

**Stage 1 wants one most, and M7b sharpened why.** Its difficulty is the one open
question in the plan (docs/PLAN.md M5b), and building the fortress produced the clearest
measurement of it yet: **the bot loses the Tide fight about as often as it wins it.** The
unseeded run that has been quoted for milestones — "TIDE DOWN, player hp=6" — is one
sample of a coin flip; asked for seeds 1 and 2 it died in the arena both times, and it
does the same in Outfall at every reprise speed from 1.0 to 1.6. Its death frame moves 4%
across a 60% change in the boss's aggression, which is what a measurement with no
headroom looks like. Two things follow: stage 1's boss is much closer to the edge than
anyone thought, and **the bot cannot be used to tune Tide or anything built on it.**

Run the game (a windowed run drops straight into stage 1), press **F3** for the running
ledger, and play it through; the same breakdown prints to the console on a game over or a
stage clear.

**The tide was inert until M7b, in every build that has ever existed.** `RisingTide` has
been complete and unit-tested since M5a — it climbs in steps, stops at its ceiling,
recedes when told, kills through i-frames — and `running` defaults to false, correctly,
because water that climbed from the moment the stage loaded would top out before the
player arrived. Nothing was ever written to turn it on. Every one of its nine unit tests
calls `begin()` itself, which is the exact shape of a test that cannot see this: it checks
that a thing works when switched on and never asks who switches it on. Stage 1's headline
gimmick was a blue rectangle sitting still. It now starts when the player enters the room
and resets when they re-enter it — including when "re-entering" means respawning after
drowning in it — and `tests/test_gimmicks_in_play.gd` builds the real stage and watches
the real water. **Stage 1 is harder than it was**: the bot now drowns there once a run.

```sh
GODOT=/path/to/godot ./tools/check.sh     # import + boot check + tests, same as CI

# The bot: a stage from spawn to the boss door, then the fight. Prints a ledger of
# what the run cost, per room and per cause. Headless, and repeatable -- it advances
# on physics frames, so a loaded machine gets the same answer as an idle one.
godot --headless --script res://tools/playthrough.gd
godot --headless --script res://tools/playthrough.gd -- stage=substation
godot --headless --script res://tools/playthrough.gd -- stage=mirror_field

# Bosses randomise their pattern order, so an unseeded run is a sample and not a
# result -- Breakers came back 18 HP / 0 deaths and then 28 / 1 on identical code.
# `seed=` pins the fight, for comparing two builds that should behave the same.
# It stays off by default, because hiding that spread is worse than knowing it.
godot --headless --script res://tools/playthrough.gd -- stage=breakers seed=7

# A plain run lands on the stage select. To skip it and open one stage directly:
godot scenes/stages/dawn_boardwalk/dawn_boardwalk.tscn
godot scenes/stages/substation/substation.tscn
godot scenes/stages/breakers/breakers.tscn
godot scenes/stages/mirror_field/mirror_field.tscn

# A shot of every room, for looking at a whole stage at once. Paste them onto the
# (col, band) grid the room table declares and the sheet is the stage's shape.
xvfb-run -a godot --script res://tools/stage_map.gd -- /tmp/out stage=substation

# A contact sheet of one character's animations, frame by frame. The default is the
# imported art with the ground line drawn on it -- what the game will show. `raw=true`
# is every source frame untrimmed, which is what you need before setting a TRIM range.
godot --headless --script res://tools/contact_sheet.gd -- /tmp/out
godot --headless --script res://tools/contact_sheet.gd -- /tmp/out character=arc raw=true

# The player in each of its states, in the engine rather than in the atlas. This is
# what catches art that floats, sinks, or shows the wrong part of a move.
xvfb-run -a godot --script res://tools/screenshot.gd -- /tmp/out

# The full suite is about five minutes, nearly all of it spent waiting on
# real physics frames. While working on one thing, narrow it — arguments after `--` are
# substrings matched against file and method names, and this takes a second or two:
godot --headless --script res://tests/run_tests.gd -- backdrop
godot --headless --script res://tests/run_tests.gd -- rising_tide crest_wave
```

| Document | What's in it |
| --- | --- |
| [docs/PLAN.md](docs/PLAN.md) | Scope, milestones M0–M8, acceptance criteria, risks |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Project settings, folder layout, node/scene design, physics constants, collision layers |
| [docs/SPRITES.md](docs/SPRITES.md) | AutoSprite generation workflow, animation manifest, automated `SpriteFrames` import |

## Layout

| Path | |
| --- | --- |
| `scripts/core/player_tuning.gd` | Every movement constant, in px/frame. The feel of the game lives here. |
| `scripts/autoload/` | `GameState`, `WeaponManager`, `Tuning`, `AudioManager`, `SceneRouter` |
| `tools/` | `bootstrap_input_map.gd` (regenerates the input map), `check.sh` |
| `scenes/actors/player/` | `Player` plus one script per state under `states/` |
| `scripts/core/playtest_log.gd` | What a run cost, per room and per cause. Attached to stage 1 and to the bot, so the two reports compare. |
| `scenes/level/authored_stage.gd` | Everything a stage shares. A stage is a room table plus its differences. |
| `scenes/stages/dawn_boardwalk/` | Stage 1, Dawn Boardwalk — where a windowed run drops you |
| `scenes/stages/substation/` | Stage 2, Substation — Arc, and the dark-room gimmick |
| `scenes/stages/breakers/` | Stage 3, Breakers — Rust, and the crusher press |
| `scenes/stages/mirror_field/` | Stage 4, Mirror Field — Prism, and the disappearing panels |
| `scenes/actors/items/` | The dog. Coil, Jet and Marine, spawned by a courier so they can be bodies rather than shots. |
| `scenes/level/phase_block.gd` | The panel. A block is solid for two beats, and a beat is one jump. |
| `scenes/stages/test_room/` | M1 tuning room, opened directly when reading movement numbers off F3 |
| `tests/` | Headless suite, including integration tests driving the real `CharacterBody2D` |

## Controls

| | Keyboard | Gamepad |
| --- | --- | --- |
| Move | ← → , A D | D-pad, left stick |
| Aim up / climb | ↑ ↓ , W S | D-pad, left stick |
| Jump | **Z** or **Space** | A (bottom face) |
| Shoot | **X** | X (west face) |
| Sword | **C** | Y (north face) |
| Cycle weapon | **Q** / **E** | LB / RB |
| Pause / weapon menu | **Enter** or **Esc** | Start |
| Debug overlay + playtest ledger | **F3** | — |

**Slide is down + jump**, as in Mega Man 3 — not its own binding.

**Three attacks, and two of them are not discoverable**, so they are written down here
rather than left to be found:

- **Tap X** — the buster pellet. 1 damage, 3 live shots at once. Tap-firing is still the
  best damage per second in the game.
- **Hold X** — charges. 40 frames (~0.7 s) for a mid blast at 2 damage, 85 (~1.4 s) for a
  full one at 3. Deliberately *worse* per frame than tapping: it trades rate for a single
  big hit. Taking a hit cancels it.
- **C** — the sword. 3 damage and no ammo, in exchange for standing still inside an
  enemy's reach for the whole 20-frame swing with no cancel.

The pause menu lists this table itself, and there is a **MENU** button in the top-right
corner of the screen — so the way in is on screen rather than only in this file. That
list is generated from the live `InputMap`, so it says what the game actually responds to
rather than what someone last wrote down.

In the pause menu, ↑/↓ moves and **Z or X** confirms; the rows are the weapons, then
E-Tank, Restart and Resume. On the game-over screen, **Z or X** continues.

## Ground rules

- **Engine:** Godot 4.7.x, GDScript, Compatibility renderer.
- **Resolution:** 1920×1080, `world_scale` 4.5 — 72 px tiles, a 108 px character, and a
  frame holding 26.7 × 15 tiles against the original's 16 × 14. Linear filtering: the art
  is smooth HD, not pixel art.
- **Fixed 60 Hz physics tick.** All movement constants are authored in NES units
  (pixels *per frame*) and converted once, so the feel matches the reference hardware.
- **Reason in tiles, not pixels.** A jump clears 2.89 tiles and a slide covers 4.06 at any
  scale; the pixel figures change when `world_scale` does. And design against the
  *discrete* apex — the engine integrates frame by frame and loses ~v/2 against v²/2g,
  which is a quarter-tile and decides whether a ledge is clearable. ARCHITECTURE §3.
- **Original IP.** Mechanics and feel are modelled on Mega Man 3; character names, art,
  music, and level layouts are original work. Canonical MM3 tables appear in these docs
  only as design references to be renamed before shipping.
