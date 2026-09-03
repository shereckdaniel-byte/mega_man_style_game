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

## 3. Palette swap — resolved at M5: hue rotation

The plan was a `ShaderMaterial` remapping two authored body tones to the equipped weapon's
colours, the way the NES palette swap worked.

**That does not work on this art.** An exact-match shader needs flat tones; one frame has
~230 colours with anti-aliased edges and gradients. The options were:

1. **Regenerate as flat-shaded pixel art** — restores the original plan intact.
2. **Hue-rotate in the shader** instead of remapping exact colours. Works on any art, but
   the result is a tint rather than the crisp two-colour swap of the original, and dark
   outlines shift with it unless masked by luminance.
3. **Generate a colour variant per weapon in AutoSprite.** Highest fidelity, but it is
   8 × the art for one character and every regeneration multiplies.

**Option 2 shipped** (`scenes/actors/player/weapon_palette.gdshader`). Option 1 was
rejected with the art direction in §7 — the smooth HD character is the decision, and
regenerating it flat to enable a shader would be the tail wagging the dog. Option 3 is
eight regenerations of a fourteen-animation character to change one colour.

The outline problem named above is handled rather than lived with: **the shift is weighted
by saturation, and luminance is untouched.** Near-grey pixels — the outline, the white
highlights — barely move, so the character stays the same character between weapons while
the coloured body tones carry the weapon. `grey_floor` is the dial: 0 freezes greys
completely, and the player uses 0.12 so the outline warms very slightly rather than
looking pasted on.

The shift itself is measured from the buster's own palette to the equipped weapon's, both
read from the `.tres` — so a weapon resource says what colour the weapon *is*, and nothing
has to separately state what colour it is relative to. The buster is therefore exactly
0, and the default sprite is the sprite the art was made as.

**What was given up:** this is a tint, not the original's crisp two-colour swap, and two
weapons authored close together on the colour wheel will look alike. `tests/test_combat.gd`
asserts every weapon moves the hue by more than 0.05 turns, which catches that at the
point a new weapon is added rather than in a screenshot later.

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

### 6a. Generating a whole roster — what the batch of 2026-09-02 taught

Thirteen characters (seven bosses, six enemies) and fifty animations, in one batch so the
style holds. Five things that are not in the tool descriptions:

**Costs, measured.** `create_character` is 1 credit at `turbo` and 3 at `pro`;
`generate_spritesheet` is 5 per animation at the default `turbo` video tier. The roster
cost 39 (13 base images at `pro`) + 3 (one redo) + 250 (fifty animations) = 292 of 366.
`pro` base images are worth it: every animation is generated *from* the base, so a weak
base is paid for once per animation afterwards.

**Do the base images first, all of them, and look at them together.** A base is 3 credits
and its six animations are 30. One character came back with a wooden piling baked into
the sprite — scenery that would never match the wall it was supposed to cling to — and
catching that before animating cost 3 credits instead of 33.

**Bearer auth fetches files directly; the `sig=` tokens are optional.** The tool output
warns that `baseImageUrl` and `sheetUrl` carry `?sig=` tokens that expire in minutes,
which makes a long batch awkward. They are not required:

```sh
curl -fsSL -H "Authorization: Bearer $AUTOSPRITE_API_KEY" \
  https://www.autosprite.io/api/files/characters/<id>/base
curl -fsSL -H "Authorization: Bearer $AUTOSPRITE_API_KEY" \
  https://www.autosprite.io/api/files/spritesheets/<id>/sheet   # and /atlas
```

**`get_job_status` rate-limits hard, and fails as non-JSON rather than as an error.** A
tight loop over fifty jobs starts returning something that is not JSON at all, so a naive
parser crashes mid-download. Pace the calls (6 s was enough), treat a parse failure as
"not ready", and make the downloader resumable by skipping any animation whose
`atlas.json` already exists.

**`create_character` can time out at 60 s and still have created the character.** Check
`list_characters` before retrying, or you will pay twice for the same design.

**Custom animations come back in submission order.** The mapping still has to go through
the `jobId` — the sheet listing reports `kind: "custom"` for all of them and never the
`name` — but where the order was checked against the art (Arc's `attack` fires its
weapon, `hurt` recoils, `death` collapses), submission order held.

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
- The two-tone palette swap (§3) is not viable. Hue rotation was the fallback and is what
  shipped at M5 — see §3, which now records the decision and what it cost.

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

### Per-animation *size* drift — corrected in the scene

The baseline fix above answers "do the feet line up". It does not answer "is the character
the same size", which is a separate consequence of the same cause and was noticed by eye
long before it was measured: **the character visibly grows when it starts walking.**

**The problem.** Because each clip is framed independently, the character is *drawn* at a
different scale in each one. Measured head-to-feet on the player:

| | `idle_shoot` | `walk_shoot` | `climb` | `idle` | `hurt` | `walk` |
| --- | --- | --- | --- | --- | --- | --- |
| Source px | 149 | 164 | 152 | **172** | 187 | **197** |
| vs. idle | −13% | −5% | −12% | — | +9% | **+15%** |

One scale factor applied to all of them reproduces that spread exactly: the character
grows 15% on the walk and shrinks 13% when it stands still and fires — the two most common
transitions in the game.

**Why the bounding box is the wrong ruler.** The obvious fix — scale each clip by its own
bounding-box height — inverts the bug. A pose with a raised arm or a lifted weapon has a
taller box and the *same* character, so scaling by the box shrinks the character for
raising its arm. `teleport_out` measures 208 px by bounding box and 161 head-to-feet; the
47 px difference is a raised arm.

**The measurement.** `AutoSpriteImporter._body_height` finds the head instead: the topmost
row carrying at least 15% of the frame's width in opaque pixels. A thin raised sword or
fist does not reach that threshold; a head does. It is sampled (five frames per clip,
scanning stops at the head) because scanning every row of every frame is millions of
`get_pixel` calls per character. The median lands in `metadata/body_heights`.

**The correction is in the scene, not the art.** `Player.UPRIGHT_ANIMS` lists the poses
where the character stands at full height, and each of those is scaled to render at
exactly `character_height()`. Everything else uses `idle`'s factor, so a tuck or a crouch
stays shorter by however much the artist drew it shorter.

That list is a judgement, and it is deliberately written down rather than derived.
`jump` is shorter because it is tucked, `slide` because it is prone, `death` because it is
collapsing — and **no measurement can tell "drawn smaller" from "crouching"**. Normalising
those would be this same bug pointed the other way: the character would stand up mid-slide.

**What this does not fix.** Head-to-feet normalisation equalises height, not bulk. A pose
that leans slightly into its stance gets scaled up as though it were drawn smaller, so it
reads a little heavier than `idle`. Visible on `idle_shoot` if you look for it; much
smaller than the 13% it replaced.

**Only the player is corrected, and that is a measurement, not laziness.** Tide's upright
clips span 150–159 px — under 6%, which does not read. The player's 15% does.
`tests/test_sprite_frames.gd` asserts idle-vs-walk within 8% for every *uncorrected*
character, so a future boss that comes back badly framed fails CI; the honest answers then
are to regenerate its art or extend this scaling to `Enemy`, not to raise the bound.

### A note on the unused clips

`attack` **is now used** — it is the sword swing (docs/PLAN.md §2a). It turned out to be a
dual-wield low guard stance rather than the two-handed lunge it was first described as,
which is why the swing reads as planted and committed. Its head-to-feet height is 21% under
`idle`, and that is correct posture rather than framing drift: the character really is
crouched in that stance. It is deliberately **not** in `Player.UPRIGHT_ANIMS` for that
reason — normalising it would stand the character up mid-swing.

`victory` and `teleport_out` are still never played. The player's states ask for `idle`,
`walk`, `jump`, `slide`, `climb`, `hurt`, `death`, `attack`, `teleport_in` and the `_shoot`
variants.

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
| 3 | ruined city skyline | **done** — `skyline.png` | image `356af9de-b93a-4f26-9d78-60ebd284be0e`, seed 10521 |
| 4 | floodwater | **done** — `water.png` | derived from the sky, no generation |
| 5 | foreground pilings | **done** — `pilings.png` | image `6702e1f9-b5f9-4f6a-8364-10b9a3ed3b97`, seed 10541 |

Twelve of the 40 trial generations spent: 3 on the tileset, 4 on the sky, and 5
across the other plates — of which two were thrown away, below.

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

#### Stage 2's enemy roster — the six skins, and what the M5 lesson saved

The roster's rule is that the six archetypes are **reskinned** per stage: the
behaviour is the archetype, the art is the theme. Substation's six, generated
2026-09-03 in one batch so the style holds against the boardwalk's:

| Archetype | Skin | What it is |
| --- | --- | --- |
| walker | **Breaker** | a switchgear cabinet walking on four insulated legs |
| hopper | **Isolator** | a ceramic insulator stack on a spring, knife switch on top |
| turret | **Arrester** | a fixed surge arrester whose discharge horn pivots and sparks |
| flyer-sine | **Corona** | a caged ball of discharge drifting on a conductor ring |
| spawner | **Splicebox** | a legless junction box spilling sparking cables |
| wall-crawler | **Creeper** | a flat many-legged clamp unit, blue tracking arcs on its back |

**One animation each, not six.** `Enemy` plays exactly one clip — `anim_name`,
falling back to the first in the resource — and nothing in the game ever switches
it. Stage 1's Lampjack has a `fire` clip and its Barnacle Hive a `spawn` clip;
neither has ever been played. So the substation set is six bases and six
animations rather than the roster batch's four-to-six apiece.

**Cost: 48 of 74 credits.** Six `pro` bases (18), two regenerated (6), six
animations (30). Which brings up the thing §6a said and this batch proved:

> *Do the base images first, all of them, and look at them together.*

Two of the six came back wrong, and both would have been invisible in a
spritesheet listing:

- **Creeper had a pipe baked into the sprite** — the exact failure §6a records
  from the first roster, where a character arrived with a wooden piling attached.
  A wall-crawler carrying its own scenery will never match the wall it clings to.
- **Splicebox had legs.** The spawner is a fixed emplacement; a legged one reads
  as a walker that happens not to walk.

Catching both at the base cost 6 credits. Catching them after animating would
have cost 16, and catching them in-engine would have cost a session. The
regenerated characters are named `Creeper2` and `Splicebox2` in AutoSprite — the
repo directories are `creeper/` and `splicebox/`, since the version number is an
artefact of the retry and not part of the design.

The prompt that fixed both was the same in each case: **name the absence.** "No
pipe, no cable, no wall, no floor, no scenery of any kind" and "no legs, no feet"
worked where describing only what was wanted did not.

#### A landmark belongs to one plate, and both stages got that wrong

Parallax plates move at different rates -- that is what makes them parallax --
so anything the player reads as a single object has to live on exactly one of
them. Both stages shipped a version of the same fault, and neither is visible in
a still:

| Stage | What was duplicated | The two rates |
| --- | --- | --- |
| Dawn Boardwalk | the sun's reflection, drawn into `water.png` | sky 0.05 vs water 0.4 |
| Substation | the moon and stars, left in `pylons.png` by the keying pass | sky 0.05 vs pylons 0.2 |

Stage 1's was the obvious one once the camera moved: the reflection slid out from
under the sun and two rooms along they were most of a screen apart -- two suns,
one of them in the sea. Stage 2's had not yet separated far enough to notice.

**Stage 1's fix moves the pixels, it does not redraw them.** The disc was lifted
out of `water.png` onto `sun_glint.png` -- same art, transparent everywhere else,
same 400 px width so it tiles on the sky's cadence -- and given the sky's scroll
factor. The hole it left was cloned from the same rows 90 px along rather than
filled with a flat colour: the plate is streaked bands, and a flat fill leaves a
visibly calm patch in the shape of the disc. Two details worth knowing if this is
ever redone:

- the footprint has to be the **whole disc**, not its bright pixels. The water's
  own dark bands are drawn across the reflection, so a mask of "what is yellow"
  lifts the top half and leaves the bottom half behind as a dark crescent;
- and the silhouette is a **circle**, derived from the horizontal extent and the
  top edge. Following the bright pixels row by row stops halfway down for the
  same reason.

Stage 2's fix is one threshold: the silhouette tops out at min-channel 111 and
the moon and stars start at 192, so clearing everything above 150 takes the sky
out and leaves the pylons untouched.

`tests/test_backdrops.gd` holds the rule for every stage, keyed on the **largest
connected bright region** rather than on a count of bright pixels. That
distinction is the whole test: the duplicated sun was one blob of 500 px and the
duplicated moon one of 71, while the substation's transformer lamps are 268
bright pixels in thirty blobs of five. Counting pixels ranks the lamps above the
moon and catches the wrong thing.

#### Stage 2's art, and one thing `no_background` does not do

Substation's terrain is `assets/tilesets/substation/`, generated the same way
stage 1's was and imported by the same tool. Two attempts: the first, prompted
for "wet concrete, oil stains, seeping water", came back olive-green and blobby —
readable as mossy stone, wrong for a switchyard, and worse under a dark overlay.
Naming the palette explicitly ("cold pale grey, grey and blue-grey only, no
plants, no moss") with `detail: low detail` and a higher `text_guidance_scale`
gave the cold concrete-and-steel set that shipped. Cost: 2 tilesets, ~5
generations.

The four backdrop plates are `create_image_pixflux`, and one of them is worth
knowing about:

| Plate | Notes |
| --- | --- |
| `sky.png` | Night sky, moon, distant lit shoreline. As generated. |
| `pylons.png` | Pylon silhouettes. **Keyed** — see below. |
| `yard.png` | Transformer row. **Keyed**. |
| `trench.png` | Cable-trench wall for the under band. As generated. |

**`no_background: true` does not reliably produce transparency for a
scene-shaped prompt.** Both plates that needed an alpha channel came back fully
opaque, twice each, including one attempt whose description said "fully
transparent background: no sky, no clouds, no hills, no ground, nothing behind
the towers" in as many words. Stage 1 hit the same thing without noticing —
`water.png` is 0% transparent and works only because it is placed as an opaque
band across the lower screen, while `skyline.png` (39%) and `pilings.png` (95%)
did come back keyed.

So the two that needed it were keyed after the fact, by flood-filling from the
top edge with a colour tolerance. That is recorded here rather than hidden
because it means those two PNGs are **not** reproducible from their prompt alone:
regenerating them needs the keying pass as well. It is cheaper and far more
predictable than spending generations hoping for an alpha channel, and it does
not touch the pixels it keeps.

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

### 8c. The rest of the backdrop, and where the plates go

All five plates are in and `art_preview.tscn` shows them stacked. The parallax
factors are §8a's; what §8a did not record, and what actually matters when
assembling them, is **where each plate sits vertically**.

`parallax_background.gd` hangs the whole backdrop off one constant, `HORIZON`,
in plate pixels from the top of the viewport. The skyline stands on it, the
water starts at it, the sun clears it. Change that number and the backdrop stays
coherent; place the plates independently and it will not.

| Plate | Size | Scroll | Top |
| --- | --- | --- | --- |
| sky | 400x240 | 0.05 | 0 |
| skyline | 220x40 | 0.2 | `HORIZON` − 40 |
| water | 400x120 | 0.4 | `HORIZON` |
| pilings | 400x84 | 1.2 | 156, i.e. flush with the bottom |

Vertical scroll is 0 on every plate: the backdrop is placed against the
viewport, not the world, so it must not drift when the camera rises or the
horizon walks off the top of the screen. The pilings are the only plate with a
positive `z_index` — everything else is behind the player, they are in front.

#### The sun had to move, and moving it cost the sky its band spacing

§8b put the sun at plate row 169. That is 70% of the way down the viewport, and
it left no room: the horizon has to sit below the sun, the water below that, and
the deck below that, all inside the remaining 30%. The sun is 234 screen pixels
across, which is simply large relative to the scene.

It now sits at row 100. Getting it there could not be done by re-cropping,
because the source has only 242 rows of sky *above* the sun and none below.
Instead the banded sky above the disc is squashed 215 rows into 74 with NEAREST
— flat bands stay flat under nearest-neighbour, they just get thinner — while
the sun's own 27-row band is kept at native scale so the disc keeps its shape.
The banding is tighter than the source's as a result. It reads as haze.

**The sun cannot clear the city.** With the disc 26 plate px in radius and the
horizon 30 px below its centre, a skyline that fits under it would be about
three pixels tall. The draft prompt's "low sun just clear of it" is not
achievable at this sun size, so the city crosses the disc instead — which is the
more familiar image anyway, and looks deliberate.

#### Two plates that had to be made rather than generated

**Water.** Generated twice and discarded twice. Asked for a water surface,
pixflux drew a lake — sky, hills, a far shore and a boat — in a pale blue
nothing like the dawn palette. Forcing the sky's own palette with
`color_image_url` (which does work: point it at any completed job's no-auth
download URL) fixed the colour and left the composition: still a lake, now a
warm one, with most of the frame collapsed onto the sun's yellow.

The plate that shipped is derived instead: **still water is the sky mirrored
about the waterline**, so it is exactly that, darkened and cooled with depth,
with the mirrored sun broken into a glitter path and some debris added. It costs
no generations and it cannot drift out of palette with the sky, because it *is*
the sky. A separately generated plate can and did.

**Pilings.** Asked for railing posts with gaps between them, pixflux returned a
picket fence at 100% alpha coverage — no transparency anywhere, which as a
foreground plate would have walled the player off completely. `no_background`
does not create gaps in a subject that fills its frame. What shipped is a single
generated piling composited into a plate at chosen positions, which is also the
only way to control the spacing. It is darkened to 45% and pulled toward the
water's blue: a foreground element that competes with the player for attention
is worse than no foreground element.

#### Making distance read

Two adjustments did more for depth than any prompt:

- **Scale both axes.** The skyline was generated 400x100 and is used at 220x40.
  Squashing only the height would have given stubby towers at the same apparent
  distance; scaling both makes them far away.
- **Haze by brightness.** Every skyline pixel is blended toward the sky colour
  behind it, by an amount that rises with its own luminance. The pale back rank
  the generator drew recedes into the sky, the dark front rank stays solid, and
  the speckled window detail stops reading as noise.

Neither is a PixelLab feature. Both are a few lines over the returned PNG.
