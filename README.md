# Mega Man 3 Style Game (Godot 4.7.x)

An original action-platformer built in the style of *Mega Man 3* (NES, 1990): 8 selectable
stages, weapon-get progression, slide, robot-dog utility items, and boss-rush endgame.

**Status: planning.** No engine code has been written yet. The design lives in `docs/`.

| Document | What's in it |
| --- | --- |
| [docs/PLAN.md](docs/PLAN.md) | Scope, milestones M0–M8, acceptance criteria, risks |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Project settings, folder layout, node/scene design, physics constants, collision layers |
| [docs/SPRITES.md](docs/SPRITES.md) | AutoSprite generation workflow, animation manifest, automated `SpriteFrames` import |

## Ground rules

- **Engine:** Godot 4.7.x, GDScript, Compatibility renderer.
- **Internal resolution:** 256×224, integer-scaled, nearest-neighbour filtering.
- **Fixed 60 Hz physics tick.** All movement constants are authored in NES units
  (pixels *per frame*) and converted once, so the feel matches the reference hardware.
- **Original IP.** Mechanics and feel are modelled on Mega Man 3; character names, art,
  music, and level layouts are original work. Canonical MM3 tables appear in these docs
  only as design references to be renamed before shipping.
