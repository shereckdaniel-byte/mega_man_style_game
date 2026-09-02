# Project Plan — Mega Man 3 Style Game

Target engine: **Godot 4.7.x** · Language: **GDScript** · Art pipeline: **AutoSprite**

> API note: this plan is written against the Godot 4.3+ API surface (`TileMapLayer`,
> `CharacterBody2D.move_and_slide()`, `AnimatedSprite2D`/`SpriteFrames`). 4.7 is a newer
> minor than the versions these were introduced in, so everything here should hold, but
> confirm against the 4.7 changelog at M0 and record any deltas in `docs/ARCHITECTURE.md`.

---

## 1. What we are building

An original 8-stage action platformer that reproduces the *Mega Man 3* game feel and
progression loop:

- **Stage select** — 8 Robot Master stages playable in any order, plus a locked centre slot.
- **Weapon get** — beating a boss grants its weapon; weapons have finite ammo and a
  rock-paper-scissors weakness chain, so play order affects difficulty.
- **Slide** — down+jump gives a short low dash. This is the MM3 signature move.
- **Utility dog** — three summonable helper modes (spring/coil, hover platform, submarine)
  that consume a shared meter and gate optional routes.
- **Rival encounter** — a scripted mid-stage duel with an unbeatable, non-lethal rival.
- **Second half** — revisit-stages with harder mini-bosses, then a 4-stage fortress ending
  in a boss rush and a two-phase final boss.

Deliberately **not** in scope (these are MM4+ features, not MM3):

- No charge shot. The buster fires a fixed pellet; max 3 player shots on screen.
- No shop, no upgrade currency, no branching narrative.

### Definition of "MM3 feel"

Four things carry the whole game. If these are wrong, nothing else matters:

1. **Momentum-free ground movement.** Walk speed is instant on, instant off — zero
   acceleration, zero friction slide.
2. **Fixed-arc jump with variable height.** Releasing jump early cuts upward velocity
   immediately; no double jump, no coyote time (the original had none — see §6 Risks).
3. **Fire while doing anything.** Shooting never interrupts walking, jumping, or climbing;
   it swaps the animation set, not the state.
4. **Knockback on hit.** Damage pushes the player backwards ~0.5 px/frame for 16 frames
   with control locked, which is what makes pits lethal near enemies.

---

## 2. Milestones

Each milestone is a shippable, playable increment. Do not start the next one until the
acceptance criteria pass.

### M0 — Bootstrap (0.5 day)

- `project.godot` with pixel-perfect settings (see ARCHITECTURE §2), Compatibility renderer.
- Folder skeleton, `.gitattributes` (LFS off — PNGs are tiny), `.gitignore` for
  `.godot/`, `export/`, `*.translation`.
- Input map with keyboard + gamepad bindings, all actions named in ARCHITECTURE §6.
- Autoload stubs: `GameState`, `AudioManager`, `SceneRouter`.
- gdUnit4 (or GUT) installed with one trivial passing test; CI workflow running headless.

**Accept:** `godot --headless --quit` exits 0; test suite runs in CI.

### M1 — Player controller, grey boxes (2–3 days)

- `Player` as `CharacterBody2D` with a hand-rolled state machine
  (`Idle/Walk/Jump/Fall/Slide/Climb/Hurt/Dead/Teleport`).
- Tuned constants from ARCHITECTURE §3, `ColorRect` placeholder art.
- One test room: flat ground, ladders, one-way platforms, spikes, a pit.
- Debug overlay: state name, velocity, on-floor flag, physics frame counter.

**Accept:** jump apex is 48–50 px from a standing start; a full slide covers 65 px; ladder
mount/dismount at top and bottom both work; releasing jump at frame 4 produces a
noticeably shorter hop. Automated test asserts jump apex and slide distance in pixels.

### M2 — Sprite pipeline (1–2 days)

- Generate the player character in AutoSprite per `docs/SPRITES.md`.
- Build `tools/autosprite_import.gd`: an `EditorScript` that reads an AutoSprite JSON
  atlas and writes a `SpriteFrames` `.tres` — no hand-clicking in the SpriteFrames panel.
- Import preset forcing Nearest filter / mipmaps off for `res://assets/sprites/**`.
- Swap the player's placeholder for `AnimatedSprite2D`; wire state → animation mapping.

**Accept:** re-running the importer after regenerating a character updates animations
in place with no scene edits and no lost frame ordering. Sprites are crisp at 1×, 3×, 6×.

### M3 — Combat core (2–3 days)

- Buster: 3-shot cap, muzzle offset per state, shoot-animation hold of 16 frames.
- `Hurtbox`/`Hitbox` `Area2D` pair, damage values, 90-frame i-frames with 2-frame
  flicker, knockback lock.
- Health system + HUD energy bar (segmented, fills one tick at a time with SFX).
- Death: freeze, explosion ring of 8 particles, respawn at last checkpoint.

**Accept:** taking damage in mid-air over a pit kills you the way it does in the original;
i-frame flicker is visible; the HUD bar drains and refills tick-by-tick.

### M4 — Enemy framework + Stage 1 (3–4 days)

- `Enemy` base class: health, contact damage, weapon-damage table lookup, death explosion,
  off-screen despawn + respawn-on-rescroll (MM's exact behaviour — enemies reset when
  their spawn point re-enters the camera region).
- Six enemy archetypes: walker, hopper, turret, flyer-sine, spawner, wall-crawler.
- Room-based camera: horizontal scroll-lock rooms, screen-transition doors, vertical
  scroll rooms, ladder-driven vertical transitions.
- Stage 1 built end-to-end in `TileMapLayer` with checkpoints and a boss door.

**Accept:** a full stage is playable from teleport-in to boss door with no soft locks;
scrolling back and forth respawns enemies identically each time.

### M5 — Boss framework + weapon get (2–3 days)

- Boss arena: door seal, boss teleport-in, health bar fill (one tick per 4 frames,
  player locked until full), fight, defeat explosion, weapon-get screen.
- First Robot Master with a 3-pattern state machine and telegraphed tells.
- Weapon system: ammo meters, weapon switch, projectile behaviours, weakness table.
- Pause/weapon menu with the sub-screen layout, ammo bars, and E-tank use.

**Accept:** beating the boss awards a weapon that is usable in stage 1 with correct ammo
drain; the weakness table applies 2–4× damage to the intended target.

### M6 — Content build-out (2–3 weeks)

- Remaining 7 stages + 7 Robot Masters, each with one stage-unique gimmick
  (disappearing blocks, conveyor, wind, dark room, crusher, water, ice).
- Utility-dog items, unlocked by beating specific bosses.
- Item drops (health/ammo/1UP/E-tank) with weighted tables.
- Password/save: MM3 used a password grid; ship a save slot **and** a password so the
  retro flow is intact.

**Accept:** all 8 stages clearable in any order; every weapon useful in at least two
non-boss situations; password round-trips full progress state.

### M7 — Endgame (1–2 weeks)

- Revisit stages with mini-bosses reusing earlier boss AI at higher aggression.
- 4 fortress stages, boss-rush teleporter room, two-phase final boss.
- Rival duel encounter and whistle-cue setpiece.

**Accept:** the game is completable start to finish without dev tools.

### M8 — Polish & ship (1–2 weeks)

- Music (8 stage themes + 6 jingles) and ~40 SFX; audio bus layout with ducking.
- Title, intro, ending, credits.
- Options: rebindable input, scale/fullscreen, volume, colourblind palette for the
  disappearing-block gimmick.
- Exports: Windows / Linux / macOS / Web. Web build must hold 60 fps.

**Accept:** a clean-machine playthrough by someone who has never seen the build.

**Rough total:** 7–10 weeks of focused solo work. M6 is the bulk; parallelise art
generation with code work from M2 onward.

---

## 3. Work order rationale

The controller comes before art (M1 before M2) because Mega Man's feel is measured in
pixels per frame — it is easier to verify against grey boxes with a debug overlay than
against animated sprites. The art pipeline comes before combat (M2 before M3) because
shooting states multiply the animation count, and you want the importer automated before
that multiplication happens, not after.

---

## 4. Reference tables

These are the canonical MM3 tables. Use them as a **structural** template — the shape of
the graph is the design; rename every entity before shipping.

### Weakness chain

| Boss | Weak to | Damage vs. buster (1) |
| --- | --- | --- |
| Top | Hard Knuckle | 4× |
| Hard | Magnet Missile | 3× |
| Magnet | Spark Shock | 4× |
| Spark | Shadow Blade | 3× |
| Shadow | Top Spin | 4× |
| Snake | Needle Cannon | 2× |
| Needle | Gemini Laser | 3× |
| Gemini | Search Snake | 4× |

The chain is a single 8-cycle: Top → Hard → Magnet → Spark → Shadow → Top, plus
Snake → Needle → Gemini → Snake. Preserve the property that **no boss is weak to a
weapon you get from it**, and that at least one boss is beatable buster-only.

### Weapon archetypes to fill

Whatever the names, cover these eight behaviours so the arsenal stays non-redundant:

1. Rapid low-damage spread (anti-swarm)
2. Homing / turning projectile (anti-evader)
3. Splitting or mirrored beam (multi-lane)
4. Heavy slow arcing knuckle (high damage, hard to aim)
5. Contact/ram melee (risk-reward, no projectile)
6. Terrain-crawling projectile (hits ground-huggers behind cover)
7. Stun/disable (locks a target, often deals no damage)
8. Multi-angle throwable that returns (utility + platform-cutting)

---

## 5. Task tracking

Each milestone becomes a GitHub milestone; each bullet becomes an issue labelled
`area:player`, `area:enemy`, `area:level`, `area:art`, `area:audio`, `area:tooling`.
Branch per issue off `main`, squash-merge. Tag `v0.M<n>` at each milestone acceptance.

---

## 6. Risks and open decisions

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Godot 4.7 API drift from what's documented here | Blocks M0 | Verify at M0, pin the exact patch version in `.godot-version`, record deltas |
| AutoSprite output style is inconsistent between characters | Art rework | Lock one character prompt/seed convention at M2, generate all 8 bosses in one batch |
| AutoSprite frame counts don't match the animation lengths the controller expects | Animation desync | Controller drives timing; animations are cosmetic. Never gate state exits on `animation_finished` except for teleport and weapon-get |
| Hand-authoring 8 stages is the schedule | Slips M6 | Build stage 1 fully, then extract a gimmick-block library before stages 2–8 |
| Pixel-perfect + camera smoothing fight each other | Jitter | Camera snapping off, no position smoothing, integer stretch — settled in ARCHITECTURE §2 |
| Web export audio latency | Feel | Test the web build from M3, not M8 |

**Open decisions to make at M1 (write the answer into ARCHITECTURE):**

- **Coyote time / jump buffering:** the original had neither. Modern players notice.
  Recommendation: ship 0 frames coyote, 4 frames jump buffer — buffering is invisible and
  forgiving, coyote time changes ledge geometry. Revisit after first playtest.
- **Slide cancelling:** MM3 lets you cancel a slide by pressing jump. Keep it; it's a
  skill expression the speedrun crowd expects.
- **Screen-transition style:** hard scroll-lock (MM1–5) vs free scroll. Recommendation:
  scroll-lock, because it makes enemy respawn rules coherent and stage authoring bounded.
