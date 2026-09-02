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
| **`slide`** | ✅ | n/a | Generated 2026-09-02. Trimmed to frames 18-24 |
| **`climb`** | ✅ | n/a | Generated 2026-09-02, rear view. Trimmed to 7-19 |
| `climb_top` | ❌ | n/a | Mount/dismount polish, deferred to M4 |
| `idle_shoot` | ✅ (`arm cannon attack`) | ✅ (`wave gun`) | |
| **`walk_shoot`** | ✅ | n/a | Generated 2026-09-02. Trimmed to 11-20 |
| **`jump_shoot`** | ✅ | n/a | Generated 2026-09-02. Trimmed to 12-14 |
| `climb_shoot` | ❌ | n/a | |
| `hurt` | ✅ (`Hit React`) | ✅ | |
| `death` | ✅ | ✅ | Enemies share one explosion effect instead |
| `teleport_in` / `teleport_out` | ✅ | ❌ | Generated 2026-09-02; `teleport_in` trimmed to 2-24 |
| `victory` | ✅ | n/a | |
| `attack` | ✅ | ✅ | Boss-specific |

**All six are now generated** (2026-09-02), as `custom` animations with explicit pose
descriptions, in one batch so the style matches — see §4a. The only player animations
still missing are `fall`, `land`, `climb_top` and `climb_shoot`, none of which block
anything: the controller falls back to a base animation for each.

### 4a. Generated animations have a wind-up — trim them

AutoSprite renders a clip as a small performance: a wind-up, the move, then a recovery.
That matters because **the controller owns state timing and never waits on the
animation**, so a short state only ever shows the animation's opening frames. A slide
lasts `slide_frames` = 26 physics frames = 0.43 s, which at these clips' ~12 fps is about
**five animation frames**. Untrimmed, `slide` spends those five frames standing up and
the character never visibly slides — the exact bug the animation was generated to fix.

`AutoSpriteImporter.TRIM` names the frame range each move actually lives in. Playback
speed is taken from the *source* frame count, so trimming changes which frames play,
never how fast. The atlases stay exactly as downloaded; the selection is reviewable code.

Two further things read off the real output:

- **The clips are 2.042 s, not 2.333 s** (the `turbo` video tier emits a 2 s clip), so the
  new animations run at 12.24 fps against the originals' 10.72. Both are well inside the
  1–60 fps the linter allows, and since the controller drives timing it changes nothing.
- **Vertical drift within a clip is real.** `slide`'s first usable frames bob 50 source px
  (30 world px) up and down; frames 18–24 are a settled band of 6 px. Prefer a stable band
  over a longer one — a bobbing sprite reads as floating, not sliding.

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

Three policy tables sit at the top of `autosprite_importer.gd` and are the only things
that normally need editing: `NAME_MAP` (directory name → animation name), `LOOPING`, and
`TRIM` (which frames of a clip to keep — see §4a). All three are plain data, so retuning
an animation is a one-line change with no scene edits.

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
2. **`www.autosprite.io` must be allowed by the environment's network policy.**

**Resolved 2026-09-02.** The domain is now reachable and the six missing player
animations were generated over it. Note the failure mode that remains: the MCP server
listed in `.mcp.json` did **not** load as `mcp__autosprite__*` tools even with the domain
allowed. Talking to the same endpoint directly works and is what was used:

```sh
curl -sS -X POST https://www.autosprite.io/api/mcp \
  -H "Authorization: Bearer $AUTOSPRITE_API_KEY" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
```

It speaks streamable-HTTP JSON-RPC and answers in SSE frames (`data: {...}`), so read the
last `data:` line. `tools/list` returns the authoritative tool schemas — use it instead of
guessing payload shapes.

### What generating an animation actually costs

`generate_spritesheet` takes `characterId` plus an `animations[]` array. For a move that
is not a stock kind, use `{"kind": "custom", "name": "<exact directory name>", "prompt":
"..."}` — `name` becomes the export directory, so naming it `slide` rather than
`Slide Move` means no `NAME_MAP` entry is needed. `prompt` is capped at **600 characters**.

| Option | Effect |
| --- | --- |
| `videoTier: "turbo"` (default) | 5 credits, a 2 s clip |
| `first_frame_quality: "pro"` | +3 credits, sharper and far more faithful opening pose |
| `spritesheet: {frameCount: 25, frameSize: 256}` | matches the existing exports |
| `loop: true` | for cycles; `custom` never auto-loops |

`first_frame_quality: "pro"` is worth it for unusual poses — the first frame is what the
video animates from, so a wrong first frame wastes the whole clip. The eight animations
generated on 2026-09-02 (six, plus `climb` and `jump_shoot` regenerated) cost 64 credits.

Jobs are async: the call returns `workflows[]` with a `jobId` each, and `get_job_status`
resolves to `spritesheetIds`. **Poll no faster than every 30 s.** Note that
`list_spritesheets` does not return the animation `name` and `latestOnly` collapses every
`custom` animation into one entry — map name → sheet through the `jobId` instead.

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

**Closed 2026-09-02:** the six missing player animations now exist (§4) and were verified
in-engine, not just in the atlas — `tools/screenshot.gd` drives the player into each state
and prints the state and animation it actually captured.

### Per-animation baseline drift

`SOURCE_ART_BASELINE` (223) and `SOURCE_ART_HEIGHT` (177) in `player.gd` are single
constants measured from `idle`, but **every animation lands its feet somewhere slightly
different inside the 256 px cell.** Measured against the collision box base, where
negative floats above the ground and positive sinks into it:

| | float/sink (world px) | | float/sink (world px) |
| --- | --- | --- | --- |
| `idle` | −0.6 | `walk` | **+8.5** |
| `slide` | −7.3 | `attack` | −9.2 |
| `climb` | −11.6 | `death` | +9.2 |
| `walk_shoot` | −5.5 | `jump` | −7.9 |
| `teleport_in` | −6.1 | `hurt` | +4.9 |

This spread is **pre-existing, not something the new art introduced** — `walk` already
sinks 8.5 px and `attack` already floats 9.2 px. The new animations sit inside roughly the
same band; `climb` is the worst at −11.6.

Do **not** try to fix this by retuning `SOURCE_ART_BASELINE`: it is one number shared by
every animation, so moving it to suit `slide` breaks `idle`, which is currently exact.
A real fix needs a per-animation baseline offset applied at import, which is a design
change worth making deliberately rather than as a side effect. Left open.

### Checklist before generating the other seven bosses

- [x] Scale and art style settled (§7); one character regenerated and approved in-engine.
- [x] The six missing player animations exist (§4).
- [ ] Weapon colour approach settled (§3).
- [x] Frame count per animation agreed — 25 generated, then trimmed per §4a.
- [x] `godot --headless --script res://tools/autosprite_import.gd` runs clean.
- [x] `tests/test_sprite_frames.gd` passes.
- [ ] Per-animation baseline drift (§7) decided — accept it, or offset at import.

When the bosses are generated, budget for the wind-up problem up front: generate, look at
a 25-frame contact sheet per animation, and set `TRIM` before judging the art. Several
animations that look wrong in-engine are correct clips shown at the wrong frame.
