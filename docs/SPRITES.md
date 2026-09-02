# Sprite Pipeline — AutoSprite → Godot 4.7

> **Verified against real exports on 2026-09-02.** Everything in the pre-M0 draft of this
> document about the atlas format was a guess, and all of it was wrong. What follows is
> read off actual AutoSprite output (`MAIN-Character-spritesheet.zip`,
> `Wave-Man-spritesheet.zip`) and exercised by `tools/autosprite_importer.gd` and
> `tests/test_sprite_frames.gd`.

---

## 1. Export layout

AutoSprite emits **one directory per animation**, each with its own spritesheet — not one
sheet per character:

```
<Character>-spritesheet.zip
└── <Animation Name>/
    ├── atlas.json          frame rectangles + meta
    ├── spritesheet.png     grid of frames
    └── frames/0001.png…    the same frames again, individually
```

`frames/` is redundant with the sheet and is ~90% of the download (the two exports are
15 MB unpacked, 3 MB without it). **Commit only `spritesheet.png` and `atlas.json`.**

### atlas.json

```json
{
  "frames": {
    "0": { "x": 0,   "y": 0, "w": 256, "h": 256, "duration": 1 },
    "1": { "x": 256, "y": 0, "w": 256, "h": 256, "duration": 1 }
  },
  "meta": {
    "size":       { "w": 1280, "h": 1280 },
    "frame_size": { "w": 256,  "h": 256  },
    "duration_s": 2.333,
    "background_mode": "toonout_tensordock"
  }
}
```

Three things to know:

- **`frames` is an object keyed by stringified integers, not an array.** Sort the keys
  numerically. Sorted as text, frame `"10"` lands between `"1"` and `"2"` and the
  animation plays scrambled — which reads as bad art rather than a bug.
  `tests/test_sprite_frames.gd` asserts frame order advances left-to-right, top-to-bottom.
- **There is no `columns` or `frameCount` field.** Every frame carries its own rect, so
  the grid never has to be inferred.
- **Duration is total seconds, not fps.** Divide: 25 frames / 2.333 s ≈ 10.7 fps.

### Observed characteristics

| Property | Value |
| --- | --- |
| Frames per animation | 25 |
| Frame cell | 256 × 256 |
| Sheet | 1280 × 1280 (5 × 5) |
| Playback | 10.7 fps |
| Character within the cell | ~78 × 177 px (86% of the cell is transparent) |
| Distinct colours, one frame | ~230, with anti-aliased edges |

**This is smooth high-detail art, not upscaled pixel art.** 82% of horizontal colour runs
across the body are a single pixel long, so there is no upscale factor to reverse — it
cannot be losslessly reduced to a small pixel grid. Two consequences, both open (see §7):

1. A 177 px character does not fit a 256 × 224 viewport; it is 79% of the screen height
   where a Mega Man 3 sprite is 11%.
2. The two-tone palette-swap shader for weapon colours (§3) cannot work on 230 anti-aliased
   colours.

---

## 2. Conventions

| Convention | Value |
| --- | --- |
| Location | `assets/sprites/player/`, `assets/sprites/bosses/<name>/` |
| Committed files | `<Animation>/spritesheet.png` + `<Animation>/atlas.json` only |
| Facing | Right-facing only; mirror with `flip_h` |
| Generated output | `resources/sprite_frames/<character>.tres` |
| Animation names | `snake_case`, direction suffix stripped |

**Collision never derives from the sprite.** The cell is art; the hitbox is the 16 × 24
rect in ARCHITECTURE §3. Changing cell size or art scale must not change gameplay.

### Name normalisation

AutoSprite's directory names are inconsistent — `idle_right` next to `Hit React` next to
`arm cannon attack`. The importer maps known names through `NAME_MAP` and snake-cases the
rest, so a newly generated animation shows up under a usable name instead of being dropped.

| AutoSprite | Imported as |
| --- | --- |
| `idle_right`, `walk_right`, `run_right`, `jump_right` | `idle`, `walk`, `run`, `jump` |
| `attack_right` | `attack` |
| `arm cannon attack` | `idle_shoot` |
| `Hit React`, `Hurt` | `hurt` |
| `Death`, `Victory` | `death`, `victory` |
| `wave gun` | `attack_special` |

---

## 3. Palette swap — blocked

The plan was a `ShaderMaterial` remapping two authored body tones to the equipped weapon's
colours, the way the NES palette swap worked.

**This does not work on the current art.** An exact-match shader needs flat tones; one
frame has ~230 colours with anti-aliased edges and gradients. Options, in order of
preference:

1. **Regenerate as flat-shaded pixel art** — restores the original plan intact.
2. **Hue-rotate in the shader** instead of remapping exact colours. Works on any art, but
   the result is a tint rather than the crisp two-colour swap of the original, and dark
   outlines shift with it unless masked by luminance.
3. **Generate a colour variant per weapon in AutoSprite.** Highest fidelity, but it is
   8 × the art for one character and every regeneration multiplies.

Resolve alongside the art-direction decision in §7.

---

## 4. Animation coverage

What the two exports actually contain, against what the M1 controller needs:

| Needed | Player | Wave Man | Note |
| --- | --- | --- | --- |
| `idle` | ✅ | ✅ | |
| `walk` | ✅ | ✅ | |
| `run` | — | ✅ | Not needed; MM3 has one ground speed |
| `jump` | ✅ | ✅ | Single pose; no separate `fall` |
| `fall` | ❌ | ❌ | Can reuse `jump` |
| `land` | ❌ | ❌ | Cosmetic, droppable |
| **`slide`** | ❌ | n/a | **The MM3 signature move. Blocks M1.** |
| **`climb`**, `climb_top` | ❌ | n/a | **Blocks ladders in M1.** |
| `idle_shoot` | ✅ (`arm cannon attack`) | ✅ (`wave gun`) | |
| **`walk_shoot`**, **`jump_shoot`** | ❌ | n/a | **Blocks "fire while moving", §1 of PLAN.** |
| `climb_shoot` | ❌ | n/a | |
| `hurt` | ✅ (`Hit React`) | ✅ | |
| `death` | ✅ | ✅ | Enemies share one explosion effect instead |
| `teleport_in` / `teleport_out` | ❌ | ❌ | Stage start/clear |
| `victory` | ✅ | n/a | |
| `attack` | ✅ | ✅ | Boss-specific |

Five player animations block M1: **`slide`, `climb`, `walk_shoot`, `jump_shoot`,
`teleport_in`/`teleport_out`**. None are AutoSprite stock types, so they need Custom
Animations with explicit pose descriptions — and they should be generated **in the same
session as the base character** so the style matches.

25 frames at 10.7 fps is also far more than a NES cycle (walk is 3 frames). Extra frames
are harmless — the controller owns timing, the animation is cosmetic — but they cost
texture memory: one character is currently 1.4 MB across 8 animations.

---

## 5. The importer

```
tools/autosprite_importer.gd         AutoSpriteImporter — all the logic
tools/autosprite_import.gd           SceneTree wrapper, for CLI and CI
tools/autosprite_import_editor.gd    EditorScript wrapper, for File > Run
```

```sh
godot --headless --script res://tools/autosprite_import.gd
```

The split exists because **`EditorScript` cannot run headless** — `godot --script` rejects
anything that is not a `SceneTree` or `MainLoop`, so the documented "add an EditorScript
and use File > Run" approach cannot be used from CI. The logic lives in a plain
`RefCounted` and both wrappers are three lines.

It finds characters by shape, not by a fixed depth — any directory whose children contain
an `atlas.json` — so `assets/sprites/player/` and `assets/sprites/bosses/wave_man/` both
work. Frame rects come straight from the atlas, fps from `frame_count / duration_s`, and
looping from a policy list (`idle`, `walk`, `run`, `climb`, `hurt` loop; everything else
plays once).

Actor scenes reference `resources/sprite_frames/<character>.tres` by path, so regenerating
art never requires touching a scene.

### Manual fallback

The documented route still works to unblock: `AnimatedSprite2D` → new `SpriteFrames` → grid
icon → set Horizontal/Vertical → select frames → Add Frames. Use it once, then go back to
the script; at 25 frames × 17 animations × 9 characters, hand-clicking is not a pipeline.

---

## 6. Generating new sprites via MCP

`.mcp.json` declares the AutoSprite MCP server. The key is **not** committed — it comes
from `AUTOSPRITE_API_KEY` in the environment (see `.env.example`):

```json
{ "mcpServers": { "autosprite": {
    "type": "http",
    "url": "https://www.autosprite.io/api/mcp",
    "headers": { "Authorization": "Bearer ${AUTOSPRITE_API_KEY}" } } } }
```

Two things must be true before it can be used from a Claude Code web session:

1. **The session must be restarted** for `.mcp.json` to load.
2. **`www.autosprite.io` must be allowed by the environment's network policy.** It is
   currently denied — the proxy answers `403` to `CONNECT www.autosprite.io:443` — so the
   server is unreachable from the container regardless of the key. Add the domain to the
   environment's allowed hosts.

---

## 7. Art direction — settled

**Decision: keep the art, go HD.** The game is not pixel art.

| | |
| --- | --- |
| Viewport | 1920 × 1080 |
| `world_scale` | 4.5 |
| Tile | 72 px |
| Character | 108 px (1.5 tiles, as in the original) |
| Sprite draw scale | 0.61× from the 177 px source |
| Filtering | **Linear**, snapping off, no integer scaling |

The frame holds 26.7 × 15 tiles against the original's 16 × 14: vertical view is nearly
identical so vertical platforming transfers directly, horizontal view is wider.

Two knock-on effects, both already applied:

- Nearest filtering, pixel snapping and integer scaling were all correct for the pixel-art
  plan and are wrong here. Reversed, with the settings tests rewritten to match.
- The two-tone palette swap (§3) is not viable. Hue rotation is the fallback; decide at M5
  when weapons land.

Still open: the five missing player animations in §4 block nothing structurally — the
controller falls back to a base animation and `tests/test_player_movement.gd` covers the
behaviour — but `slide` and `climb` look wrong until they exist.

### Checklist before generating the other seven bosses

- [ ] Scale and art style settled (§7); one character regenerated and approved in-engine.
- [ ] The five missing player animations exist (§4).
- [ ] Weapon colour approach settled (§3).
- [ ] Frame count per animation agreed — 25 is generous for a NES-style cycle.
- [ ] `godot --headless --script res://tools/autosprite_import.gd` runs clean.
- [ ] `tests/test_sprite_frames.gd` passes.
