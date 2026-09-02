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

The importer also **normalises every animation's feet onto `BASELINE_ROW`** by measuring
the alpha channel, which needs no configuration — see §7. That happens for every character
it imports, so bosses and enemies get it for free.

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

### Per-animation baseline drift — fixed at import

**The problem.** AutoSprite frames every clip independently, so the row the character
stands on drifts between animations. Measured across the player's fourteen, the lowest
opaque row ranged from **204 (`climb`) to 238 (`walk`)** — a 34 px spread in art that is
supposed to share one ground line. Wave Man had the same spread, 205 to 212.

`AnimatedSprite2D` has a single `offset` for the whole node and no per-animation
equivalent, so a scene can only ever compensate for one of them. `player.gd` compensates
for `SOURCE_ART_BASELINE` = 223, measured from `idle`; every other animation was off by
`(its baseline − 223) × 0.6102` world px. In the test room that was `walk` sinking 6 px
into the floor and `slide` hovering **39 px** above it.

Retuning `SOURCE_ART_BASELINE` cannot fix this — it is one number serving fourteen
animations with fourteen different baselines, so moving it to suit `slide` buries `idle`.

**The fix.** `AutoSpriteImporter` measures each animation's baseline from the alpha
channel and shifts the art onto `BASELINE_ROW` (223, which must equal the scene's
`SOURCE_ART_BASELINE` — a test asserts it). The shift is `AtlasTexture.margin.position.y`:

- verified on 4.7 — with `margin.size` left at zero, `get_size()` stays the region size
  and only the drawn pixels move, so centring is untouched;
- the `region` is unchanged, so a frame still samples only its own cell and cannot bleed
  in its neighbour;
- the baseline is the **median** of the per-frame lowest rows, not the mean, so a clip
  that leaves the ground for part of its length is aligned by the frames standing on it.

Drawn content **clips at the frame box**, so a shift larger than the transparent padding
would slice pixels off the character. The importer measures the available padding and
clamps, warning which animation was clamped and by how much. Nothing needed clamping for
the current 22 animations.

Result: every animation on both characters lands within 1 px of the ground line.

**Why no existing test caught it.** `Player.sprite_feet_offset()` derives its answer from
`SOURCE_ART_BASELINE` and from the `sprite.offset` that was *set* from
`SOURCE_ART_BASELINE`. The terms cancel algebraically and it returns 0 for any art at all,
so `test_sprite_feet_sit_on_the_origin` verifies the offset arithmetic against itself and
never reads a pixel. `test_every_animation_stands_on_the_same_baseline` measures the real
alpha instead; disabling the normalisation makes it fail on all 20 drifting animations.

### Checklist before generating the other seven bosses

- [x] Scale and art style settled (§7); one character regenerated and approved in-engine.
- [x] The six missing player animations exist (§4).
- [ ] Weapon colour approach settled (§3).
- [x] Frame count per animation agreed — 25 generated, then trimmed per §4a.
- [x] `godot --headless --script res://tools/autosprite_import.gd` runs clean.
- [x] `tests/test_sprite_frames.gd` passes.
- [x] Per-animation baseline drift (§7) — normalised at import onto `BASELINE_ROW`.

When the bosses are generated, budget for the wind-up problem up front: generate, look at
a 25-frame contact sheet per animation, and set `TRIM` before judging the art. Several
animations that look wrong in-engine are correct clips shown at the wrong frame.

---

## 8. PixelLab — tilesets and background art

A second art service, added 2026-09-02 for **backgrounds and tilesets**, where AutoSprite
only does characters. Declared in `.mcp.json` beside AutoSprite, key from the environment:

```json
{ "mcpServers": { "pixellab": {
    "type": "http",
    "url": "https://api.pixellab.ai/mcp",
    "headers": { "Authorization": "Bearer ${PIXELLAB_API_KEY}" } } } }
```

`api.pixellab.ai` is reachable from the web session — no network-policy change needed.
Copy `.env.example` to `.env` and fill both keys in; `.env` is gitignored, `.env.example`
is deliberately un-ignored and carries names with no values.

If the server does not register as `mcp__pixellab__*` tools after a session restart, drive
it directly the same way as AutoSprite (§6) — it is streamable-HTTP JSON-RPC answering in
SSE frames, and `tools/list` returns the authoritative schemas.

### The tools that matter here

| Tool | For |
| --- | --- |
| `create_sidescroller_tileset` | platform/ground tiles, side-view, transparent background |
| `create_tiles_pro`, `create_building_kit` | richer tile sets, walls/floors/stairs |
| `create_image_pixflux` / `_pixen` / `_pro` | freeform background plates, parallax layers |
| `create_map_object`, `create_1_direction_object` | props and set dressing |
| `create_ui_asset`, `create_font` | HUD panels and the stage-select font |

Generation is async everywhere: `create_*` returns an id, `get_*` polls it.

**Billing is in "generations", not credits.** The account is on a *trial* with **40
generations** and $0.00 credit fallback. `create_sidescroller_tileset` costs **2–3
generations, never 1** — so the trial is roughly 13–20 tilesets. Failed jobs are not
charged. Check with `get_balance`.

### Two things to settle before generating a stage

**1. Tile size lines up exactly, which is the good news.** PixelLab emits 16 px or 32 px
tiles. The project's tile is 72 px at `world_scale` 4.5, and **16 × 4.5 = 72 exactly**, so
a 16 px tileset lands on the tile grid at a clean integer 4.5× with no resampling error.
Use 16, not 32 — 32 would need 2.25× and would land off-grid.

**2. Filtering conflicts with the settled art direction, and needs a per-node override.**
§7 settled the game as smooth HD: linear filtering, snapping off, because the character is
177 px of anti-aliased art minified to 0.61×. **Linear filtering is wrong for a 16 px tile
blown up 4.5× — it will blur it into mush.** Do not change the project default; that
default is correct for the character and is asserted by `tests/test_project_settings.gd`.
Instead override per node on the tile layer, which is a `CanvasItem` property:

```gdscript
tilemap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
```

That gives crisp pixel tiles behind a smooth HD character in the same frame.

**The remaining question is aesthetic, not technical, and is not settled:** pixel-art
terrain behind a smooth anti-aliased character is a deliberate mixed style. It can look
intentional, and it can look like two games spliced together. Generate one stage's worth,
look at it next to the player in the test room, and decide before spending the trial on
eight stages.

### 8a. Stage 1 — "Dawn Boardwalk", ready to generate

Art direction agreed from a concept sketch: a post-apocalyptic dawn, the player walking a
weathered boardwalk over still floodwater, the ruins of a drowned city on the horizon and
a low sun just clear of it. Warm orange and pink sky grading to deep blue overhead, muted
desaturated palette, strong horizontal bands.

**The boardwalk is a tileset, not a background.** It is the surface the player stands on,
so it needs collision and must come from `create_sidescroller_tileset` at 16 px. Sky,
skyline, water and ruins are non-colliding parallax plates from `create_image_pixflux`.
Confusing the two is the easy mistake here — a painted boardwalk you cannot stand on.

| # | Asset | Tool | Cost | Parallax |
| --- | --- | --- | --- | --- |
| 1 | boardwalk planks + rail | `create_sidescroller_tileset`, 16 px | 2–3 | 1.0 (the TileMapLayer) |
| 2 | dawn sky + low sun | `create_image_pixflux` | 1 | ~0.05 |
| 3 | ruined city skyline, silhouette | `create_image_pixflux` | 1 | ~0.2 |
| 4 | floodwater + collapsed pier | `create_image_pixflux` | 1 | ~0.4 |
| 5 | foreground pilings / rail posts | `create_image_pixflux` | 1 | ~1.2, drawn in front |

**About 7 of the 40 trial generations.** Generate 1 and 2 first and look at them behind
the player before spending the rest — that is the cheapest point to settle the mixed-style
question, and it is still open.

Draft prompts, to refine rather than to trust:

1. *tileset* — `lower_description`: "weathered grey driftwood planks, rusted bolts, salt
   stained, gaps between boards"; `transition_description`: "pale sun-bleached plank
   surface with peeling paint"; `transition_size` 0.25; `outline` "selective outline";
   `shading` "basic shading".
2. *sky* — "Dawn sky over a drowned coast, low sun just above the horizon, warm orange and
   pink grading up into deep blue, thin banded cloud, drifting haze. Flat muted pixel art,
   no ground, no structures, seamless horizontally."
3. *skyline* — "Silhouette of a ruined city skyline on the horizon, collapsed towers and
   twisted girders, flat dark violet-grey shapes with no interior detail, transparent
   above the roofline. Muted pixel art, seamless horizontally."
4. *water* — "Still flooded water with soft horizontal reflection bands, a half-sunk
   collapsed pier and floating debris. Muted dawn palette, flat pixel art, seamless
   horizontally."
5. *foreground* — "Rusted boardwalk railing posts and barnacled pilings, close foreground,
   dark and low-contrast, transparent background. Muted pixel art."

**Layering in Godot 4.7.** Use `Parallax2D` (confirmed present in 4.7 — it supersedes
`ParallaxBackground`/`ParallaxLayer`, which are still there for older projects). Each plate
is one `Parallax2D` with `scroll_scale` from the table and `repeat_size.x` set to the
plate width so it tiles as the room scrolls.

**Filtering, again:** every one of these is pixel art and needs
`texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST` on the node. The project default is
Linear and must stay Linear for the character — see §8.

### 8b. Stage 1 — what was actually generated

Both are in. The boardwalk tileset needed a network-policy change first — see
"Tileset art comes from a different host" below, which is worth reading before
generating stage 2.

| # | Asset | State | Job / id |
| --- | --- | --- | --- |
| 1 | boardwalk planks + rail | **done** — `assets/tilesets/dawn_boardwalk/` | tileset `2e44791f-404c-4174-81fe-bc2f6a082215` |
| 2 | dawn sky + low sun | **done** — `assets/backgrounds/dawn_boardwalk/sky.png` | image `ceaaa4c7-f3a3-46ef-a24c-bf9107204ad2`, seed 10511 |
| 3–5 | skyline, water, foreground | not started | — |

Six of the 40 trial generations spent (3 on the tileset, 3 on the sky).

**The mixed-style question from §8 is settled: it works.** `art_preview.tscn`
lays a boardwalk from the tileset, puts the backdrop behind it and stands the
player on it. A smooth anti-aliased character against flat banded pixel terrain
reads as a deliberate choice, not as two games spliced together. Generate the
remaining plates.

The one thing to know about that preview: it offsets the camera to frame the
deck low. The tuning room centres the camera on the player, which puts the
walking surface across the middle of the screen — and because the sky plate is
locked vertically, that buries the sun behind the boardwalk. The backdrop is
composed for a stage camera that keeps the ground in the lower third, which is
what M4's camera limits will do.

#### The sky took three attempts, and the fix was not a better prompt

`create_image_pixflux` will not draw a sky. Asked for one it draws a *landscape*:
attempt 1 returned mountains and a lake, attempt 2 a hill ridge, attempt 3 hills
and a treeline. Negative phrasing ("no ground, no mountains, no horizon") did not
help and `text_guidance_scale` 15 did not help — a bare sky is not a picture, and
the model composes a picture.

What worked was to stop fighting it. Ask for a 400x400 sunrise over water, which
it draws happily and well, then take the sky out of it:

- crop source rows 72–311 to a 400x240 window;
- rows 72–241 are real generated sky and are untouched;
- the generated sea below the horizon is replaced with flat bands continuing the
  gradient, because **the horizon has to come from the water plate, not from the
  sky plate** — they scroll at 0.4 and 0.05 and a horizon baked into the sky
  would slide against the real one;
- the sun sits exactly on the source's horizon, so only its top half exists. It
  is a single flat colour (251, 234, 141) on a clean disc, so the bottom half is
  its top half mirrored about row 241.5.

The rebuilt band is the bottom 70 of 240 rows. All of it ends up behind the
skyline, water and foreground plates, which is why a flat fill is good enough
there and would not be anywhere higher up.

`tools/`-style reproduction is deliberately not committed for this: the crop
constants are specific to one seed, and re-running the prompt gives a different
picture that needs different constants. The numbers above are the record.

#### 400x240 is not an arbitrary size

At `world_scale` 4.5 it is exactly 1800x1080 — a full viewport height with no
resampling, the same reasoning as the 16 px tile in §8. A plate is scaled by
`world_scale` like everything else, so changing that constant still moves the
whole game together.

`Parallax2D.repeat_size` alone is not enough to tile a plate: it only says how
wide a copy is. Without `repeat_times` the layer draws a single copy and leaves
bare viewport either side of it, which shows up the moment the camera moves off
the plate's origin. Both are set in `parallax_background.gd`.

Vertical scroll is 0 on every plate. A plate is sized to the viewport height
exactly, so any vertical drift walks its edge into frame.

#### Tileset art comes from a different host, and it has to be allowed

Raw images and tilesets are delivered differently, and only one of the two
survives a default web session's egress policy:

| Endpoint | Behaviour |
| --- | --- |
| `api.pixellab.ai/mcp/images/{job}/download` | 200, `image/png`, bytes served directly |
| `api.pixellab.ai/mcp/sidescroller-tilesets/{id}/image` | 302 to `backblaze.pixellab.ai` |

`api.pixellab.ai` is allowed by default; `backblaze.pixellab.ai` is not, and the
egress proxy answers 403 to the CONNECT. So `create_image_pixflux` output comes
back fine and tileset output does not, which is exactly the wrong way round for
a stage whose terrain is the part that needs collision.

There is no proxied or base64 tileset endpoint — confirmed against PixelLab's
own docs agent, and by probing `/v1/tilesets/{id}`, `?format=base64`,
`/download` and `/spritesheet`, all of which 404 or redirect. The *metadata* is
served from the allowed host and downloads fine; it is only the spritesheet PNG
that moves.

**Add `backblaze.pixellab.ai` to the environment's allowed domains before
generating a tileset.** A tileset already generated stays on the server, so
opening the host later costs nothing to recover it — this one was downloaded
after the fact, not regenerated.

Do not work around it by handing the storage URL back to the API as an
`init_image_url` so the service fetches its own file. That routes around the
policy rather than asking for it to be changed, costs a generation, and puts the
sheet through a diffusion pass that can smear the very tile seams the Wang set
depends on.

`inpaint_image` is worth knowing about for a different reason: it costs **20–40
generations**, billed by image size, against a trial of 40. It is not a cheap
repair tool here.

#### The tileset importer

`tools/pixellab_tileset_import.gd` builds a `TileSet` with collision from an
export, the same shape as the AutoSprite importer and for the same reason: the
logic is a plain `RefCounted` because `EditorScript` cannot run headless.

    assets/tilesets/<stage>/tileset.png    4x4 grid of 16 px tiles
    assets/tilesets/<stage>/tileset.json   the /metadata response, verbatim
      -> resources/tilesets/<stage>.tres

The layout is `tileset15_4x4`, a Wang **corner** set. Each tile is named
`wang_N`, and N's bits say which corners are *background*:

    1 = SE   2 = SW   4 = NE   8 = NW      bit set == background

`wang_0` is fully solid interior and `wang_15` is fully empty — which is why the
layout is tileset15 and not tileset16. Fifteen tiles carry terrain; the
sixteenth is the "no tile" case and is deliberately never created.

**Corner terrain offsets the terrain grid half a tile from the visual grid.**
`wang_12` (both north corners background) is a top-surface tile whose solid half
is its *bottom* half, with the plank surface drawn across the middle. Collision
therefore follows the art, not the tile bounds, and a deck painted from row R
has its walking surface at R + 0.5. Get this backwards and the player stands
half a tile above the planks.

Before trusting any of that for collision, the corner metadata was checked
against the art's own alpha channel across all sixteen tiles. It agreed exactly,
which is what makes the mapping safe to rely on rather than merely plausible.
`tests/test_tilesets.gd` keeps it honest: it re-derives every shipped tile's
mask from its name, and asserts the generated collision polygons cover exactly
the quadrants the metadata calls solid.

Stages paint with `set_cells_terrain_connect` rather than naming tiles, which is
also the check on the importer — wrong corner data shows up immediately as wrong
edges.

#### What the tileset actually looks like

Prompted for "weathered grey driftwood planks", it returned mauve-purple
blockwork with pale sun-bleached tops: closer to weathered concrete than to
driftwood, and not grey. It is kept anyway, because the mauve happens to sit in
the sky's own palette and the deck reads correctly at 4.5x. Worth knowing that
`lower_description` steers material far less than it steers colour — if stage 2
needs a specific material, expect to iterate, and remember a tileset is 2–3
generations a try.
