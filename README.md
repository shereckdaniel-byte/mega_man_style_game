# Mega Man 3 Style Game (Godot 4.7.x)

An original action-platformer built in the style of *Mega Man 3* (NES, 1990): 8 selectable
stages, weapon-get progression, slide, robot-dog utility items, and boss-rush endgame.

**Status: M6c complete** — the player controller, combat, enemies, two bosses with weapon
gets, and **two stages**: Dawn Boardwalk and Substation, both authored as room tables
against a shared `AuthoredStage`. Verified on Godot 4.7.stable, headless, in CI. Next up
is the rest of M6, stages 3–8.

**Stage 1 wants a playtester.** Its difficulty is the one open question in the plan, and
it is not one more bot run away — see docs/PLAN.md M5b. Run the game (a windowed run drops
straight into stage 1), press **F3** for the running ledger, and play it through; the same
breakdown prints to the console on a game over or a stage clear.

```sh
GODOT=/path/to/godot ./tools/check.sh     # import + boot check + tests, same as CI

# The bot: a stage from spawn to the boss door, then the fight. Prints a ledger of
# what the run cost, per room and per cause. Headless, and repeatable -- it advances
# on physics frames, so a loaded machine gets the same answer as an idle one.
godot --headless --script res://tools/playthrough.gd
godot --headless --script res://tools/playthrough.gd -- stage=substation

# Play a stage directly (a plain run drops into stage 1):
godot scenes/stages/substation/substation.tscn

# A shot of every room, for looking at a whole stage at once. Paste them onto the
# (col, band) grid the room table declares and the sheet is the stage's shape.
xvfb-run -a godot --script res://tools/stage_map.gd -- /tmp/out stage=substation

# The full suite is about three and a half minutes, nearly all of it spent waiting on
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

In the pause menu, ↑/↓ moves and **Z or X** confirms; the rows are the weapons, then
E-Tank, then Restart. On the game-over screen, **Z or X** continues.

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
