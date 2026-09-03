# Mega Man 3 Style Game (Godot 4.7.x)

An original action-platformer built in the style of *Mega Man 3* (NES, 1990): 8 selectable
stages, weapon-get progression, slide, robot-dog utility items, and boss-rush endgame.

**Status: M5a complete** — the player controller, combat, enemies, a boss with a weapon
get, and stage 1 built from eight rooms and eight level elements. Verified on Godot
4.7.stable with 273 tests (7442 assertions) passing headless in CI. Next up is M6, the
remaining seven stages.

```sh
GODOT=/path/to/godot ./tools/check.sh     # import + boot check + tests, same as CI

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
| `scenes/stages/test_room/` | M1 tuning room — run the game and it drops you here |
| `tests/` | Headless suite, including integration tests driving the real `CharacterBody2D` |

## Controls

Arrows/WASD move, **Z or Space** jump, **X** shoot, **Q/E** cycle weapons, **F3** debug
overlay. **Slide is down + jump**, as in Mega Man 3 — not its own binding.

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
