# Mega Man 3 Style Game (Godot 4.7.x)

An original action-platformer built in the style of *Mega Man 3* (NES, 1990): 8 selectable
stages, weapon-get progression, slide, robot-dog utility items, and boss-rush endgame.

**Status: M0 complete** — the project boots, the pixel-perfect settings are verified on
Godot 4.7.stable, and 31 tests pass headless in CI. Next up is M1, the player controller.

```sh
GODOT=/path/to/godot ./tools/check.sh     # import + boot check + tests, same as CI
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
| `tests/` | Headless suite: tuning simulations, project settings, input map, progression |

## Ground rules

- **Engine:** Godot 4.7.x, GDScript, Compatibility renderer.
- **Internal resolution:** 256×224, integer-scaled, nearest-neighbour filtering.
- **Fixed 60 Hz physics tick.** All movement constants are authored in NES units
  (pixels *per frame*) and converted once, so the feel matches the reference hardware.
- **Design against the discrete jump apex of 46.3 px**, not the 48.8 px that v²/2g gives.
  The engine integrates frame by frame and loses ~v/2. See ARCHITECTURE §3.
- **Original IP.** Mechanics and feel are modelled on Mega Man 3; character names, art,
  music, and level layouts are original work. Canonical MM3 tables appear in these docs
  only as design references to be renamed before shipping.
