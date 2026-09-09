# Project Plan — Mega Man 3 Style Game

Target engine: **Godot 4.7.x** · Language: **GDScript** · Art pipeline: **AutoSprite**

> **API note — resolved at M0.** The project is built and tested against
> **Godot 4.7.stable** (`4.7.stable.official.5b4e0cb0f`), pinned in `.godot-version`.
> Every project setting in ARCHITECTURE §2 was verified to take effect on that build, and
> CI runs the suite against it. One deviation from the pre-M0 draft is recorded below and
> in ARCHITECTURE §9: the test framework is an in-house runner rather than gdUnit4.

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

Deliberately **not** in scope:

- No shop, no upgrade currency, no branching narrative.

**Reversed:** this list used to open with "no charge shot — these are MM4+ features, not
MM3". The charge shot is in, by decision, along with a sword. Both are departures from the
MM3 template and both are wanted; the template is a starting point, not a cage. What the
departure costs is written down in §2a so it is not rediscovered later.

### 2a. Three attacks

| | Input | Cost | Damage | Range |
| --- | --- | --- | --- | --- |
| **Arm cannon** | tap `shoot` | free | 1 | screen, 3 live |
| **Charged cannon** | hold `shoot`, release | free | 2 mid / 3 full | screen, 1 live |
| **Sword** | `melee` | free | 3 | adjacent, commits 20 frames |

Pressing fire shoots a pellet **immediately** and starts the charge, so a full charge costs
one ordinary shot up front. That is MM4-onward behaviour and it is what stops holding from
being strictly better than tapping — in raw damage per frame, tapping still wins. What a
charge buys is one big hit landed while you are busy staying alive, not a faster kill.

**The charged shot does 3, not 4, and that number is load-bearing.** A boss's weakness does
4 where the buster does 1 (§4). If a charge matched a weakness there would be no reason to
hunt for the right weapon, and boss order — the rock-paper-scissors spine of the whole
game — would stop meaning anything. `tests/test_attacks.gd` asserts a weakness still beats
a full charge, so this cannot be tuned away by accident.

The charge is **per weapon, opt-in**: `WeaponData` carries the whole block and only the
buster sets `chargeable` today. The mechanism is built for all eight; proving it on one
weapon first is deliberate.

The sword is a committed swing — planted, no cancel. Take the commitment away and there is
no reason ever to fire the buster. It works in the air as well as on the ground, which is
a decision about reach rather than about the art: half the things worth hitting are
reached by jumping at them. Since M6l the clip is **the arm cannon unfolding into a
blade** — the same limb, reconfigured — so there is no second weapon to hold and no hand
to hold it in. It still reads slightly wrong mid-air, because a swing plants a stance, and
an air slash would want its own arc; that is recorded rather than fixed.

Two things that would have shipped broken and are worth remembering:

- A charged shot must carry its **own weapon id**. Tagged `buster`, it looks up the 1 that
  tap fire is meant to do and quietly does 1 damage no matter how long you held the
  button. Nothing errors.
- The sword's hitbox starts at the **ground line**, not at the arm. A blade at the buster's
  height would sail over a Dockrat for exactly the reason the buster did — and with no
  projectile to watch flying past, it would simply look broken.

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

### M0 — Bootstrap ✅ done

- `project.godot` with the pixel-perfect settings from ARCHITECTURE §2, Compatibility
  renderer, and all 13 collision layers named.
- Folder skeleton and `.gitignore`; `.godot-version` pins `4.7-stable`.
- Input map generated by `tools/bootstrap_input_map.gd` (10 actions, keyboard + gamepad).
- Autoloads: `GameState`, `WeaponManager`, `Tuning`, `AudioManager`, `SceneRouter`.
  The first two are functional, not stubs, and are covered by tests.
- `PlayerTuning` resource holding every movement constant in px/frame.
- Test runner (`tests/run_tests.gd` + `tests/test_case.gd`) and `tools/check.sh`;
  CI workflow running import → boot → tests on Godot 4.7-stable.

**Accepted:** `godot --headless --quit` exits 0 and prints a settings self-check;
**31 tests / 105 assertions pass.**

Deviations from the pre-M0 draft, both deliberate:

1. **In-house test runner instead of gdUnit4.** Rationale in ARCHITECTURE §9. Swapping
   later is a rename of assert calls.
2. **Jump apex is 46.3 px, not 48.8 px.** Writing the test exposed the error — see below
   and ARCHITECTURE §3.

### M1 — Player controller ✅ done

Built at the HD scale against the real sprites rather than grey boxes, since the art
arrived early and the scale was settled first.

- ✅ `Player` as `CharacterBody2D` with a node-based state machine —
  `Idle/Walk/Jump/Fall/Slide/Climb/Hurt/Dead/Teleport`.
- ✅ Every constant read from `PlayerTuning`; nothing hard-codes a speed.
- ✅ Test room with ground, a pit, 1/2/3-tile steps straddling the jump apex, a
  slide-only tunnel, a ladder and a one-way platform. Built from a tile-coordinate
  table in code, because each block exists to test one number.
- ✅ Debug overlay (F3): state, frame counter, velocity in **both** px/s and px/frame
  NES, floor/ladder/shooting flags, and measured-vs-expected jump apex.
- ✅ 16 integration tests driving the real node through `move_and_slide()`.

**Accepted:** measured jump apex is 2.89 tiles — clears a 2-tile ledge, fails a 3-tile
one; a full slide is exactly 26 frames and 4.06 tiles; releasing jump early produces a
hop under 70% of full height; there is no coyote time and no double jump; knockback
cannot be steered out of. All asserted in `tests/test_player_movement.gd` against the
real `CharacterBody2D`, not against a re-implementation of the integration.

Two bugs the integration tests caught that the arithmetic tests could not:

1. **Jump overshot the apex by a third of a tile.** A transition took effect the frame
   *after* it was decided, so the launch frame moved at full velocity with no gravity —
   one integration step out of phase. Fixed in `StateMachine.physics_update`.
2. **The sprite sank into the floor.** The art does not fill its 256 px cell; its feet
   are on row 223. Aligning to the cell instead of the art buries the character.

Still open from M1: **calibrate the absolute values against reference footage.** The
constants are internally consistent and tested, but whether 4.9375 px/frame is the true
NES jump velocity is unverified. `world_scale` makes this a one-line change if it moves.

Also deferred to M4: ladder *behaviour* is implemented and the test room has one, but
spikes and mount/dismount polish land with the real level tooling.

A third bug surfaced on 2026-09-02 while screenshotting the new `climb` animation:
**`Ladder` set `collision_mask = 0`**, so its `body_entered` never fired, `player.ladders`
stayed empty and the `Climb` state was unreachable — every ladder in the game was scenery.
The comment said ladders "are sensed by the player, not sensing", but an `Area2D` that
connects `body_entered` is the thing doing the sensing and needs the player's layer in its
mask. Fixed to `1 << 3` (`player_body`). It went unnoticed because no test covers ladders;
M4 should add one when it picks up mount/dismount polish.

### M2 — Sprite pipeline (partly done, brought forward)

Art arrived before M1, so the importer was built early against real exports rather than
the guessed format. See SPRITES.md, which is now verified rather than assumed.

- ✅ Importer built and working: 17 animations across two characters import clean.
  Split into `AutoSpriteImporter` (logic) + SceneTree and EditorScript wrappers, because
  `EditorScript` cannot run headless and therefore cannot run in CI.
- ✅ `tests/test_sprite_frames.gd` lints generated resources and name normalisation.
- ✅ Redundant per-frame PNGs excluded from the repo: 15 MB of export becomes 3 MB.
- ✅ Art scale and style settled as HD (SPRITES.md §7); filtering reversed to linear.
- ✅ **The six missing player animations exist** — `slide`, `climb`, `walk_shoot`,
  `jump_shoot`, `teleport_in`, `teleport_out`, generated 2026-09-02 in one batch so the
  style matches. 14 player animations now import.
- ✅ Importer gained a `TRIM` policy table. Generated clips open with a wind-up, and the
  controller never waits on an animation, so a short state showed only the wind-up — a
  slide displayed the character standing up. SPRITES.md §4a.
- ⛔ **Still blocked:** the weapon palette approach (§3), which waits on M5.
- ✅ Per-animation baseline drift fixed at import (SPRITES.md §7). AutoSprite framed each
  clip independently, so the row the character stood on ranged 204–238 across the
  player's fourteen animations; `walk` sank 6 px into the floor and `slide` hovered 39 px
  above it. The importer now measures each animation's alpha and shifts it onto a shared
  `BASELINE_ROW`. Both characters land within 1 px. The pre-existing
  `test_sprite_feet_sit_on_the_origin` could never have caught this — it derives its
  answer from the same constant it is checking, so it returns 0 for any art.

**Accepted:** re-running the importer after regenerating a character updates animations in
place with no scene edits and no lost frame ordering; the sprites were checked in-engine
at the chosen scale via `tools/screenshot.gd`, which now drives the player into each state
and prints the state and animation it actually captured. **63 tests / 1688 assertions.**

### M3 — Combat core ✅ done

- ✅ Buster: 3-shot cap, muzzle offset per state, shoot-animation hold of 16 frames.
- ✅ `Hurtbox`/`Hitbox` `Area2D` pair, damage values, 90-frame i-frames with 2-frame
  flicker, knockback lock. Damage tables hold absolute values, not multipliers.
- ✅ Health system + HUD energy bar, segmented, one tick at a time. **No SFX yet** —
  AudioManager stays a stub until there are sound assets.
- ✅ Death: freeze, explosion ring of 8 bolts, respawn at last checkpoint, a life spent,
  and a game over reported rather than a silent respawn on the last one.
- ✅ `Hazard` — spikes, crushers, pit sensors — as instant death through the same Health
  path, so the respawn grace period covers it too.

**Accepted:** a knockback you cannot steer out of drops the player into the boardwalk's
gap and the pit sensor kills; the flicker is visible (sampled at 6 of 12 frames); the bar
drains and refills tick-by-tick, and drains faster than it fills so a full drain finishes
inside the 72-frame death sequence. **110 tests / 1887 assertions.**

Two traps found while building it, both worth knowing before M4:
`Area2D.monitorable = false` also switches off that area's *body* detection on Godot 4.7,
and autoload identifiers do not resolve in a `--script` entry point — reach them by path.

### M4 — Enemy framework + Stage 1 ✅ done

- ✅ `Enemy` base class: health, contact damage, weapon-damage table lookup, death
  explosion, off-screen despawn + respawn-on-rescroll. Art is scaled from the sprite's
  own measured height rather than a per-enemy constant, because the whole roster shares
  one 256 px cell whatever size the art inside it is.
- ✅ Six enemy archetypes: walker, hopper, turret, flyer-sine, spawner, wall-crawler.
- ✅ Scroll-locked rooms, the stage camera, and screen-transition doors. This removed two
  pieces of scaffolding: the invisible walls at the deck ends are the room's limits now,
  and the fixed camera offset is the camera's vertical anchor.
- ✅ Stage 1 built end-to-end: four rooms authored from a table, with gaps, raised spans,
  per-room checkpoints, nine enemy markers across five archetypes, and a boss door.
- ✅ Vertical scroll rooms and ladder-driven vertical transitions. Deferred here as "not
  needed by stage 1, which is horizontal" — and then stage 1 stopped being horizontal.
  Built in M5a; the camera turned out to have been axis-agnostic all along, and what was
  missing was a door that knew which way round it was.

**Accepted:** `tools/playthrough.gd` drives the stage from spawn to the boss door —
four rooms, three transitions, **0 deaths, 14 of 28 HP left**. Enemies respawn identically
on rescroll, which `tests/test_rooms.gd` locks down.

Three bugs came out of that playthrough that no unit test would have found, all now
fixed: a bottomless pit that did not kill during i-frames (a `Hazard` honours them; a pit
is not damage, so it is a `KillPlane` that bypasses them); a kill that left the player
walking at 0 HP, because death was routed through the hurtbox rather than through
`Health`; and a block three tiles above the deck in a corridor with no way round it.

**Authoring limits, now constants with a test each** (`tests/test_dawn_boardwalk.gd`): a
block rises at most 2 tiles above the deck and a gap is at most 2 cells wide. A full jump
reaches 2.89 tiles and covers about 3.4 across, so 3 is frame-perfect in either axis —
a late-stage ask, not a first-stage one. Checkpoints must stand on solid deck.

**A caution about the playthrough tool.** It is a traversal check, not a difficulty one,
and its failures are not automatically the stage's. Set to jump when a gap is two cells
ahead rather than one, it launched a cell early, landed *in* the gap, and made a
perfectly finishable stage look impossible. Read a failure as "look at this", not as
"the stage is broken".

### M5 — Boss framework + weapon get ✅ done

- ✅ Boss arena: door seal, boss teleport-in, health bar fill (one tick per 4 frames,
  player locked until full), fight, defeat explosion, weapon-get screen.
- ✅ **Tide**, the first Robot Master, with three telegraphed patterns.
- ✅ Weapon system: WeaponData resources, a scanned catalogue, ammo meters, per-weapon
  on-screen caps and cooldowns, three projectile behaviours, weakness table.
- ✅ Pause/weapon menu with the sub-screen layout, ammo bars, and E-tank use.

**Accepted:** `tools/playthrough.gd` now runs the stage *and* the fight. It reaches the
boss door, walks into the arena, and beats Tide **with the buster alone**, after which
Tide Crawler is unlocked with a full 28-tick bar. The weakness table gives the Arc Lance
4 damage where the buster does 1, inside the roster's 2–4× rule, and Tide is not weak to
its own weapon.

**Measured over six runs: six wins, arriving at the arena on 24 of 28 HP and finishing
on 16–20.**

Those numbers replace an earlier set (arrive on 14, finish on 4–12, five wins in six) that
was measured against a bugged stage and a bot that never fired during it. Both halves of
that were wrong and the errors pulled in the same direction, which is why the first
figures looked reassuringly like a first boss should:

- Most of stage 1's enemies could not be shot at all. The Dockrat's hurtbox topped out
  below the buster's line, so the walkers, the Limpets and the Bollards were unkillable.
- The traversal bot never pressed fire, so its runs measured *surviving* the stage rather
  than fighting it — and a run that never fires cannot notice that firing does nothing.
  It fires the whole way now.

**Read this as a difficulty signal.** With the enemies actually killable and the bot
actually shooting, stage 1 costs 4 HP end to end and Tide costs another 4–8. That is
comfortable, and possibly too comfortable — a first stage should not be *free*. It is not
a reason to buff anything yet: the bot is crude, no human has played it, and the honest
next step is for one to. But when stage 2 gets built, stage 1 is the wrong yardstick to
copy without a person's opinion of it first.

**Telegraphs are structural, not a convention.** `BossPattern` is tell → act → recover
as three frame counts, and `Boss` runs them in that order, so there is nowhere to put an
attack that skips its windup. A design rule stated in a doc is a rule that gets forgotten
on boss six.

**Three bugs worth remembering:**

- **`Enemy` leaves the body collider to its subclasses**, and `Boss` did not build one.
  A CharacterBody2D with no shape does not land on the floor, it passes through it — the
  boss kept running patterns the whole way down, the fight looked live, and the only
  visible symptom was projectiles appearing thousands of pixels below the room. Now built
  in `Boss.setup()` with a test that stands a boss on a floor and checks it is still there.
- **Volley's stated answer did not work.** The pattern was documented as "slide under it"
  and fired at 15 NES px, whose lower edge sits *below* the 14 px slide box. Nothing but
  the arithmetic would have said so. It fires at 18.5 now, which clears a slide by 1.5 px
  and still catches anyone standing.
- **The playthrough bot emptied its magazine into a wall.** Firing follows facing, facing
  follows movement input, so a bot that stopped moving at its ideal range kept pointing
  wherever it last walked — usually away. Ninety seconds of a fight where neither side
  could hit the other. The bot holds a direction now; standing still is not neutral.

**The palette swap is resolved**, closing the question SPRITES.md §3 parked for M5: hue
rotation weighted by saturation, so the outline and highlights stay put and only the body
tones carry the weapon's colour. It is a tint rather than the original's crisp two-colour
swap — the trade is written up in §3.

**Both closed.** The weapon-get screen shows the defeated boss, and a boss flashes while
its i-frames run. Beating Tide now runs a full sequence — award, victory pose, beam out —
which consumes the last two player animations nothing played.

Two bugs closed with them, neither visible to the test suite, both found by looking at the
screen. **Tide had no art**: nothing ever assigned the boss's sprite frames, so it fought
through the whole milestone as an invisible collision box — the fight worked, the tests
passed and the playthrough won. And **Tide jumped out of the arena**: apex goes with the
*square* of launch velocity, so a value chosen to look "a bit more than the player's" was
an 11.6-tile leap into an 11-tile room; it left through the ceiling and kept fighting from
above it.

### M5a — Level-element library and stage 1 extended ✅ done

**Why this exists.** Stage 1 is built from exactly two things: gaps in the deck, and
raised blocks. Everything else in `scenes/level/` is structural — rooms, doors,
checkpoints, spawn markers. `Ladder` and `Hazard` are built and used by nothing; layer 2
(`one_way`) and layer 13 (`platform`) are reserved in the collision table with no
implementation behind them.

M6 promises eight stages that each have their own gimmick, and that promise is real — but
**a gimmick is seasoning, not the meal.** Eight stages built from "the same two elements
plus one twist" are eight versions of stage 1 with a filter over each. MM3's stages feel
distinct because the *base* vocabulary is rich — moving platforms and ladders are in
nearly every stage, arranged differently — and the gimmick sits on top of that.

So the base vocabulary gets built once, before seven stages are authored against a kit of
two:

| Element | Why |
| --- | --- |
| **Moving platforms** — horizontal, vertical, cyclic | The most-used element in the genre after solid ground |
| **One-way platforms** | Jump up through, drop down with Down+Jump; layer 2 already reserved |
| **Vertical room transitions** | The M4 deferred item. Turns ladders from decoration into structure |
| **Crumbling blocks** | Timed geometry — and the basis for Mirror Field's disappearing blocks |
| **Spikes** (`Hazard`, already built) | Stage 1 has none; the class has never been placed |

This also makes four of the eight gimmicks nearly free. Dark room, conveyor, wind and ice
are a shader or a physics tweak on top of ordinary rooms; crusher and disappearing blocks
are timed geometry, which is the crumbling block generalised. Only **rising tide** and
**swim** need new movement states.

**Stage 1 is then extended to eight rooms**, from four. At ~19 s of traversal it is a
quarter of an MM3 stage (90–150 s), and it has no gimmick at all — the one stage that
exists is the one missing the thing every stage is supposed to have.

| Rooms | Content |
| --- | --- |
| 1–2 | Boardwalk as now: walking, gaps, the archetypes |
| 3 | **Descend** — ladders down under the deck |
| 4–5 | Under-deck: tight, crawlers on the pilings, low ceilings that want the slide |
| 6 | **The tide rises** — water climbs, you climb ahead of it |
| 7 | Back on the deck, the hardest run in the stage |
| 8 | Boss door → arena |

Doing this **before** stage 2 is the point, not a detour: stage 2 copies whatever stage 1
is. Copying four flat rooms sets the ceiling for the whole game.

**Accepted:** stage 1 uses ladders, one-way platforms, a moving platform, crumbling
planks, a slide tunnel, ceiling spikes, pit spikes and the rising tide — eight elements
against the two it had. `tools/playthrough.gd` runs it end to end: eight rooms, boss door
reached, 22 of 28 HP.

Also closed here, because the extension exposed them: `Player.game_over` was emitted into
nothing, so running out of lives stopped the game dead; a hit landing *while sliding*
swapped the collision shape from inside a physics callback, which Godot refuses; and the
pause menu gained a restart row, since with no title screen the only way to try again was
to close the game.

**The difficulty moved twice today and nobody has played it.** The stage cost 4 HP this
morning, 12 after the extension, and the bot now takes eight deaths getting through where
it took none. Some of that is the bot choosing the crumbling planks over the ferry, and
some of it is real. That is the open question, and it is not one more measurement will
answer.

**Under the deck now looks like it.** The backdrop's plates are hung against the
viewport with no vertical scroll -- they have to be, or the horizon walks off the top of
the screen when the camera rises -- so the rooms under the boardwalk were showing the same
sunrise as the deck above them, and the stage read as one long boardwalk at two heights.
The backdrop now carries two sets of plates and the stage swaps them on the room change,
because which band a room is in is the stage's fact rather than the backdrop's. The
under-deck set is **drawn, not generated**: a depth gradient, silhouetted pilings with
cross-bracing, and shafts of light coming down between the planks -- shapes that describe
themselves in code and want tuning against the tileset rather than a new art pass. Its
palette is sampled from the surface plates so the two bands read as one world at two
depths; the first attempt sampled the water at mid-height, which is where the sunset
reflects, and came out mauve.

**On length, a correction.** This originally said "60–90 s of traversal", and the finished
eight-room stage runs **21 s** — against 19 s for the four-room version. Eight rooms did
not double the distance, because the U reuses columns: the path is six room-widths plus
two vertical transitions, where four rooms in a line were four. Reaching 60 s means roughly
twenty rooms, not eight.

That number was written before the shape was, and the shape is the better outcome — the
stage now has a descent, a platform crossing, crumbling planks, a rising-tide climb and
two vertical transitions where before it had gaps and blocks. Length is the cheapest of
those to add later and the least useful on its own. But the criterion was missed and is
recorded as missed rather than quietly rewritten to fit.

### M5b — The open question, and why it could not be asked ✅ done

M5a closed with "the difficulty moved twice today and nobody has played it": the stage
cost 4 HP in the morning and 12 by the evening, and the bot went from no deaths to eight.
The conclusion drawn was that no further measurement would settle it and a person had to
play. **That conclusion was right and the reasoning under it was wrong.** None of those
three figures measured the stage.

**The bot was measuring the machine.** `tools/playthrough.gd` advanced on
`process_frame` — a *rendered* frame — while every constant in it counts physics ticks,
and Godot runs as many physics ticks per rendered frame as it needs to keep up with the
wall clock. Alone on a quiet box that is one and the two agree. Under load it is two or
three, and the bot then decides once per three ticks: it holds a jump for 48 ticks instead
of 16 and walks blindly past the lip of every gap it is watching for. Four runs of the
same commit, no code change between them:

| | deaths to the boss door | outcome |
| --- | --- | --- |
| alone on the box | **0** | reached, 22 HP |
| four in parallel | **34** | reached, 20 HP |
| four in parallel | **36** | reached, 20 HP |
| four in parallel | **32** | never left room 1 |

Eight is a sample from that spread, and so is zero. Awaiting `physics_frame` instead locks
one decision to one tick whatever else the box is doing. The same four-in-parallel run now
returns the same ledger four times, to the HP.

Two more things fell out of fixing it, both invisible until the frames lined up:

- **`JUMP_HOLD` was 16 where the rise takes 19.75** (`jump_velocity_pf / gravity_pf`), so
  the bot cut every jump to four-fifths and landed a third of a tile short. It never
  showed, because 16 rendered frames used to be 28 physics ticks and the release landed
  past the apex anyway. A constant that only works when the loop is broken.
- **Falling in a pit cost two lives.** `KillPlane` re-checks `get_overlapping_bodies()`
  every frame, and that list is the physics server's answer from the *previous* step. A
  respawn moves the player out in one assignment, so for one frame the list still holds
  them — and a pit is the one thing in the game that ignores i-frames by design, so the
  respawn's grace period could not stop it. The player reappeared at the checkpoint and
  died again immediately, at coordinates a hundred rows above the nearest water. Nothing
  in the game reads *why* something died, which is why it survived M4 and M5a; it surfaced
  the hour a ledger started printing the cause and the place.

**What stage 1 actually costs**, now that the number is reproducible — same result on four
concurrent runs:

| Room | HP | Deaths |
| --- | --- | --- |
| Arrival, Under West, Tide, Boss Door | 0 | 0 |
| Pilings | 2 | 0 |
| Descent | 2 | 0 |
| Under East | 2 | 0 |
| **Traversal total** | **6 of 28** | **0** |
| Arena (Tide) | 22 | 1 |

So the stage is not the expensive half and never was: **6 HP across eight rooms, and the
boss takes everything else.** Both earlier readings — "4 HP, possibly too comfortable" and
"12 HP and eight deaths" — pointed at the wrong half of the level.

**The open question is still open, and it is now a smaller one.** Nobody has played this.
Six HP over eight rooms is the bot's cost, and the bot knows where every gap is and never
panics; a person meeting the crumbling planks over spiked water for the first time will
pay more, and how much more is exactly what no bot run can say. What has changed is that
the question is now *askable*: it is about the arena and the three rooms that cost
anything, rather than about a number that moved twice for reasons nobody had found.

**How to ask it.** Run the game — a windowed run drops straight into stage 1 — and play it
through. **F3** shows the run so far: health lost per room, deaths, and re-entries. The
same ledger prints to the console on a game over and on a stage clear, in the same layout
`tools/playthrough.gd` prints, so a session and a bot run can be laid side by side. That
comparison is the instrument: **a cost only the person pays is the stage asking for
something, and a cost they both pay is the stage's arithmetic.**

Three things worth an opinion, in the order they will come up:

1. **Under East** — the ferry or the crumbling planks over spiked water. It is the only
   real choice in the stage and it costs the bot 2 HP. Does the choice read as a choice?
2. **The Tide room** — costs nothing at all, which for the stage's one gimmick is either
   a well-judged introduction or a wasted room.
3. **Tide**, the fight, which costs 22 of the 28. The bot lost it on every run recorded
   here where M5 recorded six wins in six — but the bot's dodging counters were on the
   same broken clock as everything else, so read that as "look at the fight", not as
   evidence about it. That is the docstring's own instruction and it still holds.

**No difficulty number was changed here, deliberately.** Every knob was left where M5a put
it. Tuning against a bot that was measuring the machine is what produced two of the three
figures in the first place, and tuning against a fixed bot before a person has played
would just be the same mistake with better instruments.

### M6a — Substation, Arc, and the dark ✅ done

Stage 2 of the eight, and the first one built against a shared base rather than
by copying stage 1.

- ✅ **`AuthoredStage`**, the machinery every stage shares: deck, rooms, doors,
  the M5a element kit, ladders, spawn markers, per-band pit sensors, arena, HUD,
  pause menu, playtest ledger, F3 overlay, game over, restart, weapon-get. A
  stage is now its table plus its differences — `DawnBoardwalk` went from 850
  lines to 269, most of which is the table.
- ✅ **Substation**, eight rooms as a **J**: a short lit run across the yard, down
  into the cable trench in room 2, four dark rooms along the bottom, and one
  climb into the arena. Deliberately not stage 1's U — copying that shape would
  have made stage 2 the same walk with different tiles.
- ✅ **`DarkRoom`**, the gimmick: the lights are out and the switchgear arcs every
  2.5 seconds. Three rules keep it the fair kind of dark room — never fully
  black (`MAX_DARKNESS` caps it well short of opaque), a fixed period rather than
  a random one, and purely visual, so nothing in a dark room can be killed *by*
  the dark.
- ✅ **Arc**, the second Robot Master, with three patterns whose answers are three
  different kinds of thing: **Lash** (a slow seeker — the answer is movement),
  **Rail** (a floor dash — timing), **Curtain** (falling columns with one left
  open — position). Tide asks for jump, move-under and slide, which are three
  timing answers; repeating those with new sprites would have been boss one in a
  different colour.
- ✅ Art: a cold blue-grey concrete tileset and four backdrop plates, generated
  through the PixelLab pipeline (SPRITES.md §8).
- ⛔ **Stage 2 wears stage 1's enemy skins.** The roster says the six archetypes
  are reskinned per stage; the substation's six have not been drawn. The stage is
  playable and tested meanwhile, and the swap is one column of its table.

**Accepted:** `tools/playthrough.gd -- stage=substation` runs it end to end —
eight rooms, boss door reached, **0 deaths, 26 of 28 HP**. Stage 1 is unchanged
at 0 deaths and 22 HP.

**Three bugs, and all three were in code stage 1 had been shipping for two
milestones.** Building a second instance is what found them:

- **Every spike in the game sat half its own width to the left of its cell.**
  `OneWayPlatform`, `MovingPlatform` and `CrumblingBlock` each offset their shape
  so the table's x means "left edge"; `Hazard` is a plain `Hitbox` and centres on
  its origin. Stage 1's ceiling teeth hung a tile and a half back from the tunnel
  they belong to, over deck a player walks upright along, and its pit spikes lay
  mostly under solid boardwalk rather than under the gap they were meant to make
  visible. Nothing caught it because a spike is lethal wherever it is: the stage
  played, and killed you somewhere slightly wrong.
- **A spiked tunnel with one row of clearance is impassable.** One row is 16 NES
  px against a 24 px standing box, so the tiles already forbid walking; hanging
  12 px of teeth in it leaves 4 px for a 14 px slide. Stage 1 has had one since
  M5a. It went unnoticed because that room is entered from a ladder *beyond* the
  tunnel, so nothing ever had to slide under it — and the ladder was the second
  half of the fault, because the tunnel had been authored in the shaft's own
  column. Spiked tunnels now use `SPIKED_CLEARANCE` (two rows: standing fits, and
  the teeth are what forbid it), and stage 1's moved to where the player walks.
- **A gap cut over another room is not a pit.** In a column that carries a band
  beneath it, a hole drops the player into the room below without passing through
  its door — the camera, the enemies and everything hung off `room_changed` stay
  behind, and the player is standing in a room the stage does not think they are
  in. Stage 2's first draft did this and read as a soft lock at the far wall.

Those three now live in **`tests/test_stage_authoring.gd`**, which loops over
every stage in the roster. That file exists because of a fourth realisation:
`test_dawn_boardwalk.gd` has caught real faults since M4, and every rule in it is
about the *player* rather than about the boardwalk — but they lived in a file
named after stage 1, so stage 2 was authored against none of them. Rules about
the player belong where every stage is held to them.

**A fifth thing, from Arc's own tests.** Curtain's hop walked Arc 900 px out of
the arena, which is Tide's M5 ceiling escape again in a different axis. The M5
fix was a smaller number; this one is a bound — `_hold_inside_arena()` puts Arc
back inside the span at the end of every frame, whatever a pattern did with its
velocity. A pattern is now free to be wrong about its own arithmetic without
taking the fight off the screen.

### M6b — A landmark belongs to one plate ✅ done

Shooting every room of both stages onto their room grids (`tools/stage_map.gd`)
showed stage 1's sun with a second sun below it, drifting further right with each
room. The reflection had been drawn into `water.png`, which scrolls at 0.4
against the sky's 0.05, so it slid out from under the sun as the camera moved.

The same fault was in stage 2, one milestone old and not yet far enough apart to
notice: the pylon plate was generated with its own sky, and the keying pass that
removed that sky left the moon and the stars behind as islands — so the moon
existed twice, at 0.05 and at 0.2.

Fixed in both by moving pixels rather than redrawing them: stage 1's reflection
now has its own plate at the sky's scroll rate, and stage 2's pylons have had the
sky's leftovers cleared. SPRITES.md §8c has the mechanics.

**The rule is now a test** (`tests/test_backdrops.gd`), across every stage, and
what makes it work is measuring the **largest connected bright region** rather
than counting bright pixels. The duplicated sun was one blob of 500 px and the
duplicated moon one of 71; the substation's transformer lamps are 268 bright
pixels in thirty blobs of five. A pixel count ranks the lamps above the moon and
catches the wrong thing. Verified against the pre-fix art, where it names both
faults and fails.

Worth stating plainly because it is the second time in two milestones: **both of
these were found by looking at the game, not by running it.** The suite was green
and the bot was winning through the whole of stage 1's two-sun period.

### M6c — Substation's own six ✅ done

M6a shipped stage 2 wearing the boardwalk's enemy skins and said so. Closed here:
six substation reskins — **Breaker, Isolator, Arrester, Corona, Splicebox,
Creeper** — one per archetype, generated in one batch so the style holds. Each is
a thing that is actually in a switchyard and does roughly what its archetype
does, which is the naming rule the boardwalk's Dockrat and Lampjack already set.

The swap was one column of the room table, which is what M6a's base class was
for. SPRITES.md §8d has the batch's numbers.

**One animation each, because the game only ever plays one.** `Enemy` plays
`anim_name` and nothing switches it; stage 1's Lampjack `fire` and Barnacle Hive
`spawn` clips have never been played by anything. Six bases and six animations
instead of the roster batch's thirty-odd.

**Two of six bases were wrong, and §6a's rule caught both** — look at every base
before animating any. Creeper came back with a pipe baked into the sprite, which
is precisely the failure the first roster recorded, and the spawner came back
with legs. Six credits to fix at the base; sixteen after animating.

**Two authoring rules moved out of stage 1's test file** while this was in:
"every enemy a stage names has art" and "the art carries the animation the table
asks for" both lived in `test_dawn_boardwalk.gd`, so stage 2 was held to neither
— and both fail silently by design, since `AuthoredStage` skips a marker whose
art is missing and `Enemy` falls back to the first animation it finds. They are
in `test_stage_authoring.gd` now, which loops over the roster.

**Accepted:** the bot runs Substation end to end with the new roster — 0 deaths,
26 of 28 HP, unchanged from M6a, which is the point: a reskin is not a rebalance.

### M6e — The first playtest ✅ done

Somebody played stage 1 and came back with seven things. Six were real, one was
a feature that does not exist yet, and **three of the six were invisible art on
working mechanics** — which is the theme of this whole entry.

| # | Reported | What it was |
| --- | --- | --- |
| 1 | the turret is floating | it was. Elevated fixed enemies had nothing under them since M4 |
| 2 | cannot reach rooms 4–5, there is a gap I cannot jump | **`Ladder` had no `_draw`.** Every ladder in the game was an invisible Area2D over a hole in the deck |
| 3 | the falling blocks look odd, need more of them | four crumbling blocks spaced two apart; each gap was a jump taken while the block you left was collapsing |
| 4 | the sword shows one frame | the clip is 25 frames over 2.33 s and the swing is 0.33 s, so about three frames played |
| 5 | menu items do nothing | two of the three rows correctly do nothing on a fresh run, and said nothing about it |
| 6 | the platform does not look like the floor | the one-way and moving platforms were flat coloured bars, the only surfaces not from the tileset |
| 7 | no stage select | correct — it is not built. M6 scope |

**The one that matters is #2, and the one nobody reported is worse.** Chasing the
invisible ladder turned up that **`Hazard` had no `_draw` either**: every spike in
the game was an unmarked instant-kill box. The room tables spend paragraphs
refusing to author exactly that — stage 1 turns down three spike placements for
being "a kill on a flat run with nothing but the sprite to warn you" — and then
there was no sprite. The geometry was fair and the presentation was not, which
from where the player stands is the same thing.

Both were invisible to everything that guards this project. The suite was green,
the playthrough bot was winning, and the ledger recorded honest numbers, because
**a bot reads the tile map and the player reads the screen.** That is the third
time in three milestones a fault has been found by looking rather than running,
and it is now a pattern worth naming rather than a coincidence.

Also fixed here, from the same pass: fixed enemies placed above the deck get a
drawn mounting post (`EnemyMount` — scenery, not collision, so traversal the
tests and the bot have signed off on does not move); the crumbling blocks form a
continuous walkway across Under East's water; the one-way and moving platforms
are drawn as cut deck rather than as bars; and every confirm in the pause menu
now reports what it did or why it refused.

**One regression caught on the way**, worth recording because the fix for it is a
fact about the room rather than a rule: filling the walkway from cell 9 put a
solid block in the moving platform's parking cell, and the bot stood at the lip
waiting for a ferry that could not arrive. The walkway starts at 10. Stage 1's
ledger is back to 0 deaths and 22 HP, unchanged, which is the check that it is
the same stage.

### M6f — The stage select ✅ done

The seventh item from the playtest, and the oldest promise in the plan: section 1
opens with "8 Robot Master stages playable in any order" and the game booted
straight into stage 1 because there was nothing to pick from. `SceneRouter` has
had a `STAGE_SELECT` constant pointing at a scene that did not exist since M0.

- ✅ **`StageRoster`** — the eight, in one place. Boss index, name, stage, weapon,
  portrait and scene path. The roster previously existed in three partial copies
  (the playthrough tool's stage list, each stage's own boss constants, and
  section 4 of this document), which is a roster that disagrees in two of them
  the first time a stage is renamed.
- ✅ **A 3×3 grid**, eight bosses around a sealed fortress centre, cursor wrapping
  in both axes, confirm on jump or shoot.
- ✅ Boot lands here; beating a boss returns here. That last one is what makes
  "any order" a loop rather than a one-way trip — `stage_cleared` was previously
  emitted into nothing.

**Unbuilt stages are shown, not hidden**, and that is the decision worth
recording. Six of the eight have a boss, a portrait and a name and no level yet.
Listing only what exists would make the grid change shape every time a stage
lands — and a select screen's entire interface is the player's memory of *where*
a stage is. So all nine cells exist from the start, the six without a level read
as `NOT BUILT` and refuse by name, and `tests/test_stage_select.gd` asserts every
cell is present so a later "only show what is built" cannot quietly reshape it.

Two smaller things, both the same lesson as the pause menu: a refusal says which
stage it refused and why, rather than doing nothing; and the cursor is a border
rather than only a tint, because a tint has to compete with the cleared and
unbuilt states, which are also colour.

**Not done here:** no title screen (M8), no password or save (M6), and the
fortress centre stays sealed until M7. The centre is drawn locked rather than
left blank so the shape of the finished screen is visible now.

### M6h — Breakers, Rust, and the press ✅ done

Stage 3, and the first one that closes a loop rather than opening one: Arc's
damage table has named `rust_bloom` since M6a and there was no such weapon.
Now there is, and beating Rust gives it to you.

- ✅ **Breakers** — nine rooms that *climb*, through **three bands**. Stage 1 is
  a U and stage 2 a J; both finish roughly where they started. This one starts
  at the waterline among the beached hulls and ends three screens up on the
  gantry. `AuthoredStage` already supported any number of bands — `band_deck_row`
  is `DECK_ROW + band * ROOM_HEIGHT` and never cared — so the shape cost nothing
  but the table.
- ✅ **`CrusherPress`** — the gimmick, and the first piece of level that is
  dangerous *sometimes*. Its grammar is the bosses', not the kit's: hold, tell,
  drop, rest, rise. **The cycle is a fact about the press, not a number a room
  supplies** — the phases are constants, the travelling phases are derived from
  the distance, and a room may only offset the phase. Stage 2 shipped a 130-frame
  mover leg that walked a late rider off a lip; the fix was to stop inventing
  timings per placement.
- ✅ **Rust** — three answers that are **not dodging**, which after two bosses is
  the whole vocabulary the player has. Scrap throws a hull plate that can be
  **shot down** (offence); Press walks in slower than a walk and slams
  (distance); Bloom vents corrosion that stays on the floor (attrition).
- ✅ **Rust Bloom** — archetype 4. A lob you aim by judging distance, that bursts
  into a patch several times its own size. The pattern the player had to learn to
  live with is the weapon they are given, which is the trade a weapon-get should
  feel like.
- ✅ Six enemy skins — **Cutter, Jack, Rivetgun, Slag, Skip, Seam** — one per
  archetype, generated in one batch. All six bases passed §6a's look-before-you-
  animate check first time, which is the first batch that has.
- ✅ Own tileset and a four-plate backdrop; `StageRoster` index 2 now names a
  scene, so the select screen offers it.

**The bound on Bloom is structural, not tuned.** A pattern that takes floor away
can make a fight unwinnable, so the arena is divided into seven columns and
patches only ever land in alternate ones — whichever parity is chosen, at least
three columns are clear at all times. `tests/test_rust.gd` checks that rather
than trusting the numbers.

#### Four things that were wrong, and how each was caught

1. **The slide clearance under a press had to be a fraction, and the first
   version was a whole number.** `tests/test_breakers.gd` measures the opening
   against `PlayerTuning`'s real boxes rather than against the comment, and
   failed: two rows leaves 26.6 NES px after the teeth, and a *standing* player
   is 24, so the press asked for nothing. One row leaves 10.6 and a slide is 14,
   so it asked for the impossible. Only 1.5 catches one and passes the other.
   The comment had the arithmetic wrong in exactly the direction that ships a
   press nobody has to slide under.
2. **Rust's plate could not be slid under either** — the same class of error, in
   the same session, found the same way. Thrown from 20 NES px it sat 11 px off
   the floor and a 14 px slide did not fit. Sliding under is the *old* answer the
   pattern keeps available while its new one is being learned, so it mattered.
3. **The stage shipped with its walkway under the sea.** The waterline plate was
   placed at row 150 and a room's deck lands at row 176. Caught by looking at a
   screenshot; nothing else would have.
4. **A retracted press had no rail and hung in the sky** — the same fault a
   playtester reported on stage 1 as "the turret is just floating in the air",
   arrived at from the other direction. The rails now draw the whole track,
   because a press is a thing that runs in one whether or not it has left the top.

#### The bot found a real bug, and it was in the bot

Crane cost 52 HP and two lives, on the same frame every run. The room was fine:
the bot boarded the ferry **on its return leg**, kept walking forward because it
was still on the near side of the hole, and stepped off the far end into the
spikes. `progress` cannot distinguish "just set off" from "nearly home" — 0.16 is
both — so `MovingPlatform.next_heading()` answers it by looking ahead through the
cycle instead. With that, Crane is 0 HP and 0 deaths, and Substation's identical
crossing is unchanged at 0 and 0.

**Accepted:** the bot runs Breakers end to end and beats Rust. Substation's
traversal is unchanged (2 HP across seven rooms, 0 deaths) and stage 1 still
finishes with 0 deaths, which is the check that adding a stage did not move the
two that already worked.

### M6i — The second playtest ✅ done

Somebody played the built stages and came back with three things. All three were
real, and **two of them were the same bug**.

| # | Reported | What it was |
| --- | --- | --- |
| 1 | "I cannot climb this, I am blocked" | every `shaft_up` in the game left the deck above it solid |
| 2 | "these enemies have the weapons on the right but shoot left" | **no enemy in the game had ever flipped its sprite** |
| 3 | "how are we supposed to get on this ladder by jumping on it?" | the same `shaft_up` bug, from below: it holed the floor its own ladder stands on |

#### One bug, two symptoms, three stages

A `shaft` leaves a room downward, so the hole belongs in that room's own deck. A
`shaft_up` **arrives** from below, and the deck it has to pass through is the one
a band higher — not the declaring room's, which is the floor the player is
standing on to reach the ladder. `AuthoredStage` cut both in the declaring room's
own deck, so every `shaft_up` did two wrong things at once and they read from the
outside as two separate faults.

It shipped in stage 1 at M4 and was copied into stages 2 and 3. Probing the built
tilemap says it plainly:

```
before   shaft    ladders: floor_under_foot=true   blocked_rows=[]
         shaft_up ladders: floor_under_foot=false  blocked_rows=[11, 12]
after    all six ladders:  floor_under_foot=true   blocked_rows=[]
```

**Nothing caught it because every existing check reads the room table, and the
table was right.** The translation from table to tiles was wrong.
`tests/test_shafts.gd` builds each stage for real and asks the TileMapLayer;
reverting the one-line fix makes three of its five tests fail, which was checked
rather than assumed.

#### No enemy had ever faced anywhere

Every enemy's art is drawn facing right, and nothing flipped any of it. Every
walker, hopper, flyer and crawler in three stages moonwalked half the time, and
the one a playtester noticed was the turret — because a barrel makes it
unmissable where a pair of legs does not. `Enemy.face()` states the art's
convention once and all six archetypes call it.

That is the **fifth** milestone running where the fault was found by looking
rather than by running. It is no longer a coincidence worth remarking on; it is
the strongest argument in this document for a human playing every stage before it
is called done.

#### Two things about the press, from the same session

- **A press that rests clear of the deck drew its rails only as far as its own
  travel**, leaving two steel rails stopping in mid-air a tile and a half above
  the ground. The gap under it is the point — it is the one you slide through —
  but it only reads as deliberate if the machine around it looks finished. The
  track now runs to the floor (`CrusherPress.track_extra_tiles`).
- **The press has real art now.** It was a drawn grey box with a yellow band;
  it is now a 48×32 sprite that matches the tileset's palette and pixel density
  exactly (SPRITES.md §8f). The drawn version stays as the fallback.

#### Fixing it broke stage 1, and the bot said so immediately

Correcting the band put a two-cell hole four cells from the right-hand edge of
every upper room — which on stage 1 is exactly where the boss door is. The
playthrough bot climbed out of the shaft, walked right into the hole, fell back
down and did it again: **147 entries to the Boss Door room, 90 seconds, never
reached the arena.** The stage was unfinishable in a way no test noticed, because
every test was still passing the fix that caused it.

The position was only ever safe *because* the hole was in the wrong place. Every
`shaft_up` moved from cell 24 to 23 — which clears the boss door, clears the
authored blocks in three rooms (20 collided with all three), and leaves
`SHAFT_LANDING_CELLS` of deck to step out onto. Both halves are now tests.

**And that still was not enough**, which is the part worth recording. A vertical
transition carries the player 40 NES px through the doorway, and 40 px above the
boundary used to land them *on* a solid deck — the transition was teleporting
them through it. With the hole in the right place they arrived in mid-air over it
and fell straight back: 178 round trips in one run. So an upward door now names
where the player lands (`Door.exit_offset_tiles`) rather than pushing them a
fixed distance, and the room computes it as "the deck beside the hole".

That took two attempts as well. Measured from the *player* it depends on where
they happened to trip the trigger — anywhere in a one-tile band, for a ladder —
and the first version delivered them a tile inside the deck they were meant to
stand on. It is measured from the door.

**Accepted:** 414 tests / 10102 assertions. **Stage 1's traversal ledger is
exactly its recorded baseline — 0 deaths, 22 of 28 HP at the boss door** — which
is the substitution check that a fix to the shafts did not change the stage. Both
other stages reach their arena; Breakers is 18 HP and 0 deaths end to end. The
whole-run figure varies by several HP between runs because the boss fights seed
their RNG with `randomize()`; the traversal rooms do not vary at all, which is
why the ledger is read per room and not as a total.

### M6j — The deck was half a tile lower than the code thought ✅ done

Six more things from a playtest. Four root causes, and the biggest one had been
in the game since the first tileset landed.

#### The deck's surface is half a tile below its tile row

The tilesets are Wang **corner** sets — `PixelLabTilesetImporter` says so in its
own header: the terrain grid is offset half a tile from the visual grid, a
top-surface tile's solid half is its *bottom* half, and collision follows the
art rather than the tile bounds. `DECK_ROW` is the tile row. The surface is 36 px
lower. Nothing in the stage code knew.

The player never exposed it because they spawn two tiles up and fall onto
whatever is there. The boss did. Traced in-engine:

```
f56  ENTERING  boss_y=792.0  gap_to_floor=  0.0  on_floor=false
f80  FILLING   boss_y=828.0  gap_to_floor=-36.0  on_floor=TRUE
```

— it finished its entrance in mid-air and dropped onto the floor the moment
gravity started at the bar-fill, which is exactly what was reported. Every kit
element placed at a deck row floated the same half tile, which is why the
crumbling blocks sat proud of the walkway they are meant to be part of.

`deck_surface_offset()` reads it out of the tile's own collision polygons rather
than hard-coding 0.5, so a stage whose tileset is not corner terrain gets 0 and
nothing moves.

**Applying it everywhere broke stage 1, and the bot found it in one run.** The
first version moved *all* placements. Ceiling spikes hang under a ceiling built
from tiles, so dropping them half a tile put them 8 NES px below the face they
hang from — which eats 8 of the 20 px of slide clearance in a `SPIKED_CLEARANCE`
tunnel and leaves 12 for a 14 px slide. Under West became impassable: **16 deaths,
4 rooms reached, 450 HP.** So the rule is now stated and narrow: what the player
*stands on* is placed against the surface (crumbles, one-ways, movers, ladder
feet, the boss's landing); what hangs off the tilemap is measured in tile rows;
and lethal boxes stay where they were playtested, because moving a spike is a
balance change rather than an alignment fix.

#### Every animation now draws at the actor's own height

AutoSprite frames each clip independently, so opaque height varies clip to clip.
`_build_sprite` measured the *starting* animation and kept that scale forever:

```
Arc    233-249 px   1.07x   invisible
Tide   133-180 px   1.35x
Rust   186-238 px   1.28x   "the boss size changes depending on what he is doing"
```

Arc's spread is why only one boss was reported. `Enemy.fit_art()` re-measures on
every animation change (cached per clip) — all three bosses now hold one drawn
height to within a pixel.

#### The seal was only ever a phase enum

The boss room "sealed" in the sense that the sequence started and the player was
frozen. Nothing stopped them walking out of either end — off the right-hand edge
of the last room in the stage, into the kill plane. Two `StaticBody2D` walls now
go up on the seal and come down when the boss dies. They are added deferred:
`body_entered` runs inside the physics query flush, and adding a body with a
collision shape there errors and silently drops the second wall.

#### The crumbling blocks are made of the deck now

They were a flat tan slab on a rust deck — the last thing in the kit that did not
look like the floor, which is the note a playtester made about the moving
platforms two milestones ago. They now draw from the stage's own terrain atlas,
so each stage gets its material for free and no new art was generated.

Plain deck tiles were tried first and rejected **after rendering all three
stages side by side**: they make the blocks vanish into the walkway on two stages
out of three, and a trap you cannot see is the exact failure the crack exists to
prevent. What shipped is damaged deck — the same tiles dulled and darkened,
corners bitten out, and a crack at triple the line weight, because a hairline
that read on a flat slab disappears on a textured one.

**Still open:** the reported choppiness is measured at **12.24 fps** animation
playback (the importer derives it from the source clip length), which at 60 Hz is
a new frame every five physics frames. That is a deliberate-looking number for
the genre and changing it is an art decision, not a bug fix, so it is left for a
decision rather than guessed at.

**Accepted:** 417 tests / 10123 assertions. All three stages complete every room;
stage 1 reaches the boss door on 22 of 28 HP with no traversal deaths, which is
its recorded baseline.
### M6k — Mirror Field, Prism, and a room that had gone missing ✅ done

Stage 4, and the first one whose gimmick *is* the terrain rather than sitting on
top of it.

- ✅ **Mirror Field** — nine rooms in an **L**. Stage 1 is a U, stage 2 a J,
  stage 3 a staircase that climbs the whole way; this one runs flat across the
  salt pan for five rooms and then turns up once into the receiver tower. **The
  flatness is the design.** Stages 1–3 take their variety from the shape of the
  terrain, and a heliostat field has none — so there is almost no authored
  vertical geometry here, because the panels are the vertical geometry.
- ✅ **`PhaseBlock`** — the gimmick, and it is `CrumblingBlock` with the clock
  swapped rather than a second copy of it. The parent grew exactly two hooks
  (`triggers_on_contact`, `_tick_solid`); everything else is inherited, which is
  what PLAN §4 meant by calling the crumbling block "the basis for" these.

  **A block is solid for two beats, and a beat is one jump.** Both halves are
  derived: a jump is airborne 39.5 frames by `PlayerTuning`'s own integration,
  and `BEAT_FRAMES` is that plus reaction slack. The consequence is the design —
  at any instant a path shows you the block you are on and the next one and
  nothing else, so you cannot stop and you never have to guess. A room may offset
  a set's phase and nothing else, which is `CrusherPress`'s rule one level up.
- ✅ **The order is the list.** A path is authored as positions in the order they
  are crossed, and a block's beat is its index. There is nowhere to write "beat 2
  is empty" or "two panels on beat 3" — the beats *are* the indices — so a room
  cannot author an incoherent set.
- ✅ **The mount is always drawn.** The fairness bound, and the same job Rust's
  alternate columns do: a gone panel leaves its empty steel mount, so the whole
  route is legible before it is committed to. It is a shape difference rather
  than a colour one, which is a down-payment on the colourblind palette M8 names
  for exactly this gimmick.
- ✅ **Prism** — three answers that are not Tide's timings, not Arc's positioning
  and not Rust's three. **Split** casts a beam that reaches the wall and returns
  as two, low first and high second: the ask is *anticipation*, and it is the
  first pattern in the game where **not** jumping is an action. **Facets** plants
  two mirrors and rattles a beam between them: the ask is reading a diagram drawn
  in full before anything in it can hurt you. **Sweep** walks a focal point
  across the whole arena with Prism behind it, so backing away spends the floor
  and ends at a wall: the ask is committing *forward*, at the boss.
- ✅ **Prism Ray** — archetype 3. It becomes two on the first thing it touches,
  walls included, so the weapon is about what is behind what you are shooting.
  Split is the pattern the player had to survive, which is the trade a weapon-get
  should feel like — the same argument Rust Bloom is built on.
- ✅ Six enemy skins — **Tracker, Ballast, Fresnel, Glint, Rack, Wiper**.
- ✅ `StageRoster` index 3 names a scene, so the select screen offers it.

**The bound on Facets is structural, not tuned.** A corridor is at most
`FACET_SPAN` of `FACET_COLUMNS`, so three columns are outside it whatever the
pattern picks, and `tests/test_prism.gd` walks every column and every offset
rather than trusting the numbers.

#### The bot could only make one jump, and it was the biggest one

`tools/playthrough.gd` held jump for a full arc at every gap, which is right at a
lip — the landing is a whole room of deck and overshooting costs nothing — and
wrong at a panel two cells away, where a 3.4-tile arc sails over a 2-tile target
and comes down in the hole past it. The bot cleared Trough's first panel and
landed a tile and a half beyond its second, six times running, and the stage
looked unfinishable.

It measures the hop now: the arc is integrated one frame at a time, exactly as
`PlayerTuning.jump_apex_px` does and for the same reason, and the shortest hold
that both reaches far enough and gets high enough wins. Same class of gap as the
spikes and the ceilings before it — **a checker whose vocabulary is narrower than
the level's measures itself.**

#### Four faults, and two of them predate this stage

1. **A door tripped during another transition was spent forever, and a room went
   missing.** `Door` marks itself used *before* calling `Stage.begin_transition`,
   which returns silently when a transition is already running — without
   releasing it, though the branch immediately below it does exactly that on its
   own refusal. Mirror Field reached it because a ladder delivers the player four
   cells from the next door. The stage then ran Tower → Gate with **Focus never
   entered at all**: its enemies never spawned, its row in the ledger stayed
   blank, and the bot walked the whole room while the game believed it was
   somewhere else. Nothing errored, and no test read anything that was wrong.
2. **The stage caused it, and that is now a rule.** Tower's mirror bank reached
   across the cells Foot's ladder arrives at, so the player was spawned inside
   solid terrain and shoved clear — and the shove was the last few pixels into
   the door. `SHAFT_LANDING_CELLS` had only ever promised the landing was not a
   *hole*; `test_stage_authoring.gd` now also holds every stage to it not being a
   *wall*, and the landing belongs to the band above, which is the same
   distinction the M6i shaft bug turned on.
3. **The playthrough bot fought Tide on every stage.** It printed "TIDE DOWN" and
   then waited 360 frames for `tide_crawler` to unlock. On stages 2–4 the award
   lands, the wrong id never appears, the wait runs long enough for the stage
   exit to free the level and its ledger, and a run that beat the boss and took
   its weapon is reported as a **loss** with a script error behind it. Written
   when there was one stage and never revisited when there were four — the same
   shape as the six enemy skins that had never flipped. The expected weapon comes
   off the award now, resolved at the moment of the clear rather than before it:
   asked earlier the boss does not exist yet and the answer is `buster`, which is
   always unlocked, so the check passed for a stage that awarded nothing.
4. **`PrismBeam` redeclared `SIZE_NES` from `EnemyShot`**, and the whole script
   failed to compile. The symptom was not an error about that line: it was
   `.new()` "not existing" on a preload, three files away, at runtime — while the
   fight otherwise ran and the ledger read clean. Worth knowing that a GDScript
   name collision with a parent surfaces as a missing method somewhere else.

#### Two rooms above a ladder, and only one of them can be a room

The bot entered every room of Mirror Field and spent **1.3 seconds** in the one
above the ladder — which at the time held two panel paths out of phase, the whole
point of it.

Two rooms stacked in a column share their x range, so a `shaft_up` at cell N
leaves the room above only `ROOM_WIDTH - N` cells: the player climbs out and is
already at its door. Every stage so far puts the ladder at cell 23 of 28, which
makes the **upper** room the short one — and the upper room is the one the stage
climbs into, so it tends to be the one carrying the new idea.

The obvious fix is to move the ladder early and spend the length upstairs, and
that was the first attempt. **It fails for a second reason, and the second reason
is the useful one.** A room stacked over another cannot have gaps — a hole would
drop the player past its door into a room the stage does not think they are in —
and a room with no gaps has a walkable floor from end to end that no authored
terrain can block, because `MAX_STEP_TILES` guarantees every block is climbable.
So the panels became an arc over a floor the bot simply walked along, and the
room asked nothing at all. **A panel path is only the way through if there is a
hole under it**, so the rooms that carry paths have to be the ones with nothing
beneath them.

Both facts point the same way: the short room is the one that gets nothing in it.
Mirror Field's Landing is a checkpoint and a breath, and the two-path idea became
the exam one column along, where the stage has floor to cut.

**Breakers gets this wrong twice and nobody noticed.** Its Hold has two presses
out of phase at cells 8 and 14 — the rhythm room, the third of its four press
ideas — and its Gantry has the stage's only spawner. The bot crosses both in 1.3
seconds, entering each a cell and a half from its exit. Both rooms are authored,
tested by `test_breakers.gd`, and never seen. Stages 1 and 2 get away with it by
luck: the room above their ladder is the empty run-up to the boss.

**This is not a test yet**, deliberately: as a rule it would fail stage 3 on two
rooms, and redesigning Breakers is its own change rather than a side effect of
building stage 4. Recorded here so it is a decision rather than a discovery next
time — and stage 3 is worth revisiting, because two of its nine rooms are
currently decoration.

#### The split had to be a delay, not a speed difference

Prism's Split returns as two beams, and they must arrive apart: one has to be
jumped and the other stood under, and no player is both at one instant. The first
version made the high half slower, which buys `d/v_high − d/v_low` frames — so
the separation depended on where the player happened to be standing.
`tests/test_prism.gd` failed it at close range: 33 frames apart against a
40-frame jump, which is exactly the case the design promised could not happen.
Slowing the high half enough to fix the near case left it barely outpacing a
walk.

It is a fixed hold at the wall now. A constant is the same everywhere, and it is
*visible* — the beam sits at the wall gathering before it sets off, which is a
tell rather than a surprise.

#### On the art, one thing open

The tileset is generated and paid for and **cannot be downloaded**: PixelLab
serves tileset spritesheets from `backblaze.pixellab.ai`, which this
environment's egress policy denies. That is written down in SPRITES.md §8 from
stage 1 and every alternate route was re-probed here; all still redirect. The
stage ships greyboxed against stage 3's tiles with the swap marked in one line,
and the tileset drops in as soon as the host is allowed — a generated tileset
stays on the server, so nothing has to be paid for twice.

The backdrop is three plates and the sky **came back as a whole scene again** —
haze bands, a sun, a mountain range and a strip of sand, against a prompt asking
for an empty banded sky. Cropped above its own horizon, measured rather than
eyeballed: scanning down from row 100 so the sun at row 53 is not mistaken for
terrain, the first structured row is 148. Third stage running for that fault and
the third time the answer was a few lines over the returned PNG rather than
another generation.

#### Prism was too dense, and the damage numbers were not the reason

The bot beat Prism comfortably before the Split's delay landed and lost to it
after — 28 HP and a death, where it wins Tide, Arc and Rust buster-only.
**Halving `BEAM_DAMAGE` from 3 to 2 barely moved it**: the beams went from 18 HP
to 19, because the bot was taking ten hits instead of six. The problem was never
the per-hit number.

Prism simply had more live damage in the air than any boss before it. A Split is
three separate chances to be hit — the cast, the low return, the high return —
and a Sweep crosses the entire arena; on top of that a Facet was rattling four
times, which is a beam passing through the player's half of the room five times.
Two bounces keeps the idea whole (it goes, it comes back, and you must be outside
the corridor for both) and the fight came back to **21 HP and 0 deaths**, which
is Breakers' number.

Worth recording that **the bot is a poor judge of this particular boss**, and
says so structurally rather than by bad luck: its two reflexes are "jump at
anything coming at it low" and "back off", and Prism's three answers are *stay on
the ground*, *leave a corridor you can see*, and *jump forward at the boss*. Two
of the three are the inverse of what it does. A win here means the fight is
survivable; it does not mean the patterns read, and that still wants a human.

**Accepted:** the bot runs Mirror Field end to end and beats Prism buster-only —
**21 HP lost, 0 deaths**, against Breakers' 20 and 0. Every one of the four panel
rooms costs 0 HP, and all nine rooms are entered.

### M6l — The player joins its own cast ✅ done

No new mechanics. The player was the last character still drawn in the original
2026-09-02 style, and standing next to Arc, Rust and Prism it read as a sprite
borrowed from somewhere else.

- ✅ **Fourteen clips, one batch, the bosses' style.** That is §6a's rule applied
  to the one character it had never been applied to. Two came back wrong and both
  were failure modes SPRITES already names: `climb` arrived with a **ladder baked
  into the sprite** (the level supplies its own), and `attack` arrived as a
  **cannon shot** duplicating `idle_shoot`, because the request carried a kind and
  no prompt and the base is a cannon-armed android. Both were caught on a contact
  sheet before animating.
- ✅ **The sword is the arm cannon, unfolding.** The replacement for that duff
  `attack`, and it is a better design than the dual blades it replaces rather
  than a workaround: the character has one weapon-bearing limb, so a sword that
  *is* the cannon reconfigured needs no second weapon, no hand to hold it, and no
  account of where it goes between swings. `Attack` already fitted the whole clip
  into `SWING_FRAMES` with `speed_scale`, so the swing's length did not change.
- ✅ **The pinned baseline moved, 223 → 247.** The new art is framed like the
  bosses' — feet near the bottom of the cell with single digits of padding — so
  the old row was above anything the new clips could reach and **twelve of the
  fourteen clamped in one run**. `AutoSpriteImporter.BASELINE_ROW` and
  `Player.SOURCE_ART_BASELINE` are one number in two files; a test asserts they
  agree, which is why moving one of them was never an option.
- ✅ **Every `TRIM` range re-derived, not adjusted.** The ranges described
  choreography that no longer existed. Two of them straddled a stance change and
  so were lying about the clip's own baseline as well as showing the wrong
  frames: `jump_shoot` was pointed at the frames where the tuck splays flat into
  a dive, and `attack` at the frames where the blade is put *away* — AutoSprite
  delivered that clip with its finished pose first and the transformation last.
- ✅ **`TRIM` is keyed by character now, and that is a bug it caught.** Keying on
  the animation name alone worked only because every trimmed name — `slide`,
  `climb`, `walk_shoot`, `jump_shoot` — is one the player alone owns. `attack` is
  not: five bosses have one. Trimming the player's sword to eleven frames cut
  four bosses' attacks to the same window in the same run and made three of them
  clamp, with nothing in the output naming the player as the cause.
- ✅ **`tools/contact_sheet.gd`**, because the rule this milestone kept leaning on
  had no tool behind it. The risk table below and SPRITES §4a have both said
  "check a contact sheet before judging a new animation" for four milestones, and
  neither the repo nor CI could produce one. It draws two things: the imported art with
  the character's ground line on it, which is what the game will show, and
  `raw=true`, every source frame untrimmed — which is the only view that shows
  the frames a `TRIM` range has to choose between.

**Accepted:** 470 tests green. All fourteen clips land on the ground line with no
clamping, which is the number that matters — twelve of them could not before.
The twelve states `tools/screenshot.gd` drives were looked at **in the engine**
rather than in the atlas, two of them new: the sword gets a shot at the cannon
and a shot at the blade, because it is the one move whose whole point is the
change between two frames.

The bot beats Rust (18 HP, 0 deaths) and Prism (26, 0) and loses to Tide and Arc,
both at a full bar and one death. **The same two runs on the commit before this
one lose identically**, so the losses are not this change, and nothing here could
have moved them: every collision box the player has comes from `PlayerTuning`, and
`sprite.scale`, `sprite.offset` and the clip a state asks for are read by nothing
but the renderer.

Worth recording that this contradicts M6k's note above, which says the bot wins
Tide, Arc and Rust buster-only. `Boss` seeds no RNG, so a fight is a different
fight on every run and a single run is a sample, not a result — Prism came back at
26 HP here against the 21 recorded a milestone ago on the same code. Whether Tide
and Arc have drifted out of reach or the bot is simply losing coin flips it used
to win is a question for repeated runs and a human, not for this milestone.

### M6m — Four things a player noticed ✅ done

The first session with the new player art, and every item here came from
somebody playing rather than from a test. Worth saying plainly: three of the
four were invisible to a green suite, and two of them were *created* by the
milestone before this one.

- ✅ **A `MENU` button on screen.** The pause menu has always existed and has
  always been opened by a key nothing on screen mentions. A key binding is not a
  control if the only place it is written down is the README, so there is now a
  button in the top-right corner. It is hidden until a stage wires it to a menu:
  a visible control that does nothing reads as broken rather than as absent,
  which is the same argument `PauseMenu.confirm`'s status line already makes.
- ✅ **The menu lists the controls**, generated from the live `InputMap` rather
  than written out. A hand-written control screen is a second copy of the
  bindings and the copy is the one that goes stale — `melee` spent two
  milestones bound in `project.godot` and missing from the generator that owns
  the bindings, and nothing noticed. Reading the map means the screen is wrong
  only if the game is wrong. `slide` is the one row spelled out by hand, because
  it is deliberately not an action (down + jump, as in Mega Man 3) and a list
  built only from actions would omit the one move nobody guesses.
- ✅ **A `RESUME` row**, which the button made necessary. Opening a screen by
  clicking and then having no way out of it by clicking is a trap, not a menu.
- ✅ **The climb was frozen**, and M6l froze it. `climb` was trimmed to its last
  six frames — a stable band, picked off measurements, in which the arms are
  already up. On a ladder that is no animation at all. The clip is a full reach
  cycle and wanted no trim, and the rule that came out of it is now asserted:
  **a looping animation is never trimmed.** A trim picks the frames a move lives
  in, which is right for a one-shot; a loop has no moment, it has a cycle, and
  cutting the cycle leaves the loop replaying an arc of it.
- ✅ **Bosses faced away through their own entrance.** `_face_target` ran only in
  `FIGHTING`, and sprites are authored right-facing, so a boss spent its beam,
  its landing and the entire bar fill turned away from a player who — in every
  arena in the game — arrives from the left. Several seconds of the one moment
  the boss is meant to be looked at. It now faces the target from the first
  frame of `begin_intro` and keeps facing through `ENTERING` and `POSING`.

**On the two that M6l caused:** both were visible on the contact sheet and
neither was caught there. Six similar poses in a still grid do not say "this will
look frozen" the way ten seconds on a ladder does, and a facing bug does not
appear in a sheet at all. The tool is still worth having — it caught a ladder
baked into a sprite and an attack that was the wrong move — but §6a's rule is
"look before you animate", not "looking replaces playing".

**Accepted:** 475 tests green. The boss fix is covered by a test verified against
the bug (it fails without the change and names the entrance); the climb by an
invariant over `TRIM` and `LOOPING` rather than by a pixel measurement, because
what makes a clip read as motion is not something a test can judge; the menu
button and the control list by driving them the way a player does.

**The boss fix is fight-neutral, and this is the run that says so rather than an
argument that it should be.** Turning during the entrance changes `sprite.flip_h`
and `Boss.facing()` reads from it, so the change *could* have moved the first
pattern of every fight. Seeding `Boss._rng` from the bot (`seed_rng` has been
there since M5 for exactly this) and running all four stages against `main` gives
**frame-identical** results on all four — same deaths, same HP, same frame
counts. Facing only ever changes in `ENTERING` and `POSING`, where no pattern
runs, and `FIGHTING` re-faces every frame regardless.

The same run settles M6l's open question. Unseeded, Breakers came back 18 HP /
0 deaths and then 28 / 1 within the hour, and Mirror Field 26 / 0, 23 / 0 and
28 / 1 — **on identical code**. A single bot run is a coin flip, not a
measurement, and the M6k note that the bot "wins Tide, Arc and Rust buster-only"
was reading one. Nothing here changes the bot; the seeding was an instrument, not
a fix. Making it an option (`seed=`, defaulting to unseeded so real variance is
still visible) is the obvious next step and is deliberately not in this
milestone.

### M6n — The bot can be pinned ✅ done

One flag, and it is here because M6m needed it and borrowed it rather than
shipping it.

- ✅ **`tools/playthrough.gd -- seed=<int>`** pins `Boss._rng`, which is the
  only `randomize()` in the game — the stage backdrops seed their own
  generators with a written-down constant and no enemy uses randomness at
  all — so one seed makes a whole run reproducible. The seed is printed in
  the header **and on the `SUMMARY` line**, because the summary is what
  gets pasted into a document and the header is what scrolls away.
- ✅ **It is off by default, and that is the design.** Seeding by default
  would replace a noisy number with one fight repeated forever, which is
  worse than knowing the number is noisy;
  `PlaytestLog.summary_line` has carried a docstring saying no single run
  should be quoted as a stage's cost since M5, and it was right. What a
  seed is *for* is comparing two builds that should behave the same — which
  is exactly how M6m established that facing a boss during its entrance
  moves no fight, a fact no number of unseeded runs could have shown.
- ✅ **A test for the property the flag rests on.** `seed_rng` has existed
  since M5 and two tests called it, but nothing asserted that the same seed
  actually gives the same fight. It does now, by running two seeded bosses
  and comparing the pattern order.

**Accepted:** 476 tests green. `seed=7` on Breakers twice gives the same
kill frame, the same HP and the same frame count; unseeded still varies.

**Still open, and not a tooling problem:** the bot loses to Tide and Arc
where M6k recorded wins. That was measured against the commit before the
player art landed and reproduces there too, so it is not the art. With a
seed it is now a question somebody can actually work on — pick a seed, watch
the fight, change one number — rather than a figure that moves when you look
at it again.

### M6o — Item drops ✅ done

Nothing in the game called `GameState.add_etank()`. The E-TANK row we had just
put a controls list next to could only ever read `x0`, there was no way to
recover a single hit point inside a stage, and spent weapon ammo was gone until
you died. That made the game harder than the design intends **in a way nobody
chose**, which is the worst kind of difficulty — ARCHITECTURE §5.3 has specified
"small health pickup 2, large 10" since M0 and §5.5 says the respawn rule "is
what makes farming health drops possible", a sentence about a feature that did
not exist.

- ✅ **`Pickup`** — health, weapon energy, a life and an E-tank, on the `pickup`
  layer that ARCHITECTURE §4 reserved at M0 and nothing had used since. It falls,
  because half the archetypes fly or hop and a capsule left hanging where a
  Gullbot was shot is unreachable about as often as it is convenient. It is on
  **collision layer 0** — it collides with the world without anything colliding
  with it, so a capsule can never block a jump. And it expires, blinking first:
  a room that accumulates every capsule ever dropped stops reading as a room,
  and the blink is the fair-warning half, the same thing `PhaseBlock`'s warn
  frames are.
- ✅ **A capsule that cannot be used is refused, not consumed.** Health at full
  health, weapon energy on the buster or on a full weapon — it stays on the floor
  for when it is worth something. That is `PauseMenu.use_etank`'s decision about
  spending a tank at full health, applied to the other end of the transaction.
  The E-tank capsule is the deliberate exception: a tank is *banked* rather than
  spent, so it is taken at full health.
- ✅ **Four silhouettes, not four colours.** Health a square, weapon energy a flat
  bar, a life a disc, an E-tank a tall canister; size says small or large. Six
  items told apart only by hue would have undone what `PhaseBlock` was careful
  about one system earlier — "a shape difference rather than a colour one, which
  is a down-payment on the colourblind palette M8 names".
- ✅ **A weighted table, written as percentages.** 55% of kills leave nothing;
  the two large capsules together are one kill in nine. The numbers sum to 100 so
  the drop rate can be read without arithmetic, and a test asserts they still do.
  It is an `@export` on `Enemy` rather than the `EnemyData` resource
  ARCHITECTURE pencilled in — `resources/enemies/` is empty and every other
  per-enemy number is an export, so a resource layer for one field would be a
  second way to configure an enemy rather than a better one.
- ✅ **The roll is seedable, because M6n's promise depended on it.** `seed=`
  claims a reproducible run, and it could only deliver that by pinning every
  source of randomness the run touches. Drops are the second one; a per-enemy
  RNG would have been randomly seeded by each of the dozens a stage spawns, with
  nowhere for the bot to reach them, so the RNG is `static` on `Enemy`. Adding a
  third source later and not wiring it in would fail nothing — runs would simply
  stop reproducing, quietly — so both halves are asserted.

**The bot found the bug the tests could not.** A capsule is dropped from
`Enemy._on_died`, which runs inside a `Hitbox` area callback — while the physics
server is flushing queries — and `_ready` builds two collision shapes there. The
server refuses to set each new shape's flags in that window and says so, **nine
errors per capsule**. Every test passed: they all drop capsules from test code,
which is not inside a physics callback. The playthrough bot killed one enemy.

Measured rather than assumed, because the obvious conclusion is wrong: the
refused flags default to what they were being set to, so the capsule works
either way and reverting the fix still passes the whole suite. What it costs is
a console printing nine errors per death, which is how a real error goes
unnoticed. The fix is a deferred `add_child`; the test added alongside it covers
the kill-to-landing path and is honest about **not** catching that particular
fault.

**Accepted:** 492 tests green, no engine errors in a full bot run, and all six
capsule kinds looked at in the engine rather than in a test.

**Still open:** the drop rates are playtest numbers. 55/20/12/7/4/1/1 is a guess
shaped by the original's feel, and the E-tank's 1% is the one that matters most
because a tank persists across stages. This is exactly the sort of question
M5b's playtest is for.

### M6p — Stage 1 at its proper length ✅ done

Stage 1 was seven rooms of traversal and about forty seconds of it, against
Mega Man 3's ninety to a hundred and fifty. It is now **eighteen rooms and
about a hundred and seven seconds**, which is inside that range rather than
past it. Nothing else changed: same six enemy skins, same element kit, same
boss.

- ✅ **A W, not a U.** The old shape went down under the deck once and came
  back up. This goes down twice, which is what lets every element be
  **introduced, complicated and then combined** rather than appearing once:
  the slide is optional in Pilings, required in Bait Shop and closes Long
  Pier; the ferry has a plank alternative in Under East, none in The Cut and
  no escort in Deep Water; the tide is rehearsed dry in Low Water before it
  is flooded in Tide. Length without new ideas is padding, and this is the
  arrangement that avoids it with the vocabulary already built.
- ✅ **Two rooms are deliberately empty**, and both are the far side of a
  ladder. `SHAFT_LANDING_CELLS` leaves three cells between where the player
  emerges and the door, so there is no room there for a room. Rise and Boss
  Door are written as breaths rather than pretended into content.
- ✅ **The bot's traversal budget was sized for the old stage.** 9000 frames
  while stage 1 crossed in 2400; the new one takes 6445, which fits, and a
  run that hit one bad jump would not have — so the bot would have reported a
  stage it can finish as one it cannot. Now 14000, which is twice the longest
  known crossing.

**A gap must not start within a jump of whatever stands before it**, and this
is the milestone that turned that from a comment into a test. Pilings has
carried the observation since M5a — a slide overhang that "sets the player
down at 10, which is the lip of the gap. The bot fell in fourteen times
running before this moved." Boardwalk then hit it twice while being authored:
once with two cells of run-up, and again with **four**, which reads like
plenty and is not, because the jump came off a two-tile step and a jump from
height carries further. Four deaths and the whole life counter, in one room,
without reaching the third.

The rule now measures: three cells of flat deck for every gap, plus one per
tile of height **for a block**. The height term is deliberately not applied to
tunnel roofs or one-way platforms, and that is not a loophole — it is why two
shipped rooms are correct. The player slides *under* Pilings' overhang and
walks *under* Under West's platform, so neither is somewhere they jump from. A
block is the floor; the route crosses its top.

**Accepted:** 493 tests green. The bot walks all nineteen rooms with **zero
traversal deaths across three seeds**, arriving at the boss door on 22–28 HP
having spent 12 across eighteen rooms.

**Worth saying plainly:** that traversal cost is *lower* per room than the
seven-room version's, and item drops are part of why — the bar is being topped
up as it goes. A longer stage that is no harder is a pacing question a bot
cannot answer, and it is the same question M5b has had open since M5.

### M6q — Stages 2, 3 and 4 at length ✅ done

M6p left the game with one stage of nineteen rooms and three of eight or
nine, which is a worse state than either. All four are nineteen now, and
**each grew along its own axis** rather than being made into stage 1:

- ✅ **Substation** is a longer J. It already committed down early and
  stayed down; now eleven of nineteen rooms are dark, in **two stretches
  split by a return to daylight**. The lit middle is not a rest, it is the
  rehearsal — Yard Two's slide is Blackout's spiked tunnel without the
  teeth, Transformer Row's gaps are Feeder's planks without the dark. A
  stage that only went further down would have to teach in the dark or
  not teach at all, and `DarkRoom`'s three rules exist because teaching in
  the dark is how a gimmick becomes unfair.
- ✅ **Breakers** is still the ascent, now **six rooms per band** instead
  of three-two-four. The old middle band was two screens, which made it a
  landing rather than a place. The press gets the room it needed: Keel
  gives the sealed press somewhere to be, Boiler Room puts both
  clearances twenty cells apart, and Bulkhead runs three on a rolling
  phase so the gate becomes a wave.
- ✅ **Mirror Field** runs flat for **fourteen rooms** before its one
  turn, which is the most extreme shape in the game and the right one for
  a plain of mirrors. The other stages get variety from terrain; this one
  has none, so all of it has to come from the panels — which means more
  room to vary them in, not less. Heliostat Row is the first path that
  *climbs* and leaves you higher than it found you; Sun Trap introduces
  the two-path shape Focus examines; Pan is the longest crossing in the
  game.

**Five rooms were designed wrong and the bot found every one.** Worth
listing, because the failures were more instructive than the successes:

| Room | What was wrong |
| --- | --- |
| Dead Section (2) | A hole a few cells inside the door, five dark rooms deep. Moving the gap and the turret both failed; the room wanted no hole at all |
| Deck Crane (3) | A press five cells inside the door on a cycle starting down — the player walks in under it. Crane solved this with a phase offset at M6h |
| Crust (4) | A panel path *starting* two rows up across a pit: a crossing whose first move commits you before you are on it |
| Sun Trap (4) | Two rows of panels stacked over one hole. Reads well in a table, illegible on screen — and legibility is the one thing this stage's backdrop is built around |
| Pan, Anneal (4) | Eight panels, then three panels three cells apart. A set's beat count is its panel count, so eight means two of eight solid and eight chances to be wrong; three-at-three has every number at its limit at once |

**And one that was not a rule.** Mirror Walk cost a life at an identical
frame on every seed. Two guesses at choreography — a hopper on the island,
then a crawler on the approach — changed nothing, because the 2 HP lost on
the way down was the pit's own spikes. An identical death frame across
seeds is what geometry looks like when you have been blaming enemies.

The temptation was to generalise it: *no enemy near a gap's landing*. The
data says no. Thirty-two placements across four stages sit within four
cells of a landing and almost none of them cost anything, so a test would
fail half the game to catch two rooms. It stays a comment.

**Accepted:** 493 tests green. All four stages complete with **clean
traversal** — Substation, Breakers and Mirror Field take zero traversal
deaths on seed 5 and beat their bosses; Dawn Boardwalk's one death is in
the arena, against Tide, which is where it has always been.

| Stage | Rooms | To the door | HP | Boss |
| --- | --- | --- | --- | --- |
| Dawn Boardwalk | 19 | 6445 | 40 | Tide still wins |
| Substation | 19 | 6247 | 35 | Arc down |
| Breakers | 19 | 6753 | 30 | Rust down |
| Mirror Field | 19 | 7955 | 26 | Prism down |

**Still open, and now four times over:** none of these has been walked by
a person. The bot says they are completable and says nothing about whether
they are worth completing.

### M6 — Content build-out (2–3 weeks)

- Remaining 7 stages + 7 Robot Masters, each with one stage-unique gimmick. Note the
  original list here named seven gimmicks for seven *remaining* stages, which left stage 1
  with none — section 4's roster adds **rising tide** for Dawn Boardwalk and moves
  **water** (swim physics) to the Sinkhole, so all eight stages have one.
- Utility-dog items, unlocked by beating specific bosses. **Built** — Coil (Rust), Jet
  (Gale), Marine (Quarry), carried on the weapon system so they inherit selection,
  ammo, the pause menu and the HUD bar.
- Item drops (health/ammo/1UP/E-tank) with weighted tables.
- Password/save: MM3 used a password grid; ship a save slot **and** a password so the
  retro flow is intact.

**Accept:** all 8 stages clearable in any order; every weapon useful in at least two
non-boss situations; password round-trips full progress state.

### M7 — Endgame (1–2 weeks)

- Revisit stages with mini-bosses reusing earlier boss AI at higher aggression.
  **Built as `Boss.aggression`** — one property, which shortens *recovery* and
  nothing else. The tell is the fairness contract `BossPattern` exists to enforce
  and the act is what the attack is, so scaling either would make a reprise a
  different fight wearing the first one's sprite rather than the same fight with
  fewer openings.
- 4 fortress stages, boss-rush teleporter room, two-phase final boss. **Outfall
  (F1) and Caisson (F2) are built**; Switchgear and Keep are declared in
  `StageRoster` and not yet on disk, which the stage select reports by name.
- Rival duel encounter and whistle-cue setpiece. **Built**, as Caisson's boss.
  The plan asked for a *mid-stage* duel and this is at the end of one: what makes
  a duel a set piece rather than an encounter is that the room shuts and the
  player cannot walk away, and `BossArena` is the thing in this project that
  shuts a room. Putting Ward behind a boss door also spends eight stages of
  training — the player knows exactly what that door means, and this one opens
  onto a fight with no bar, no weapon and a whistle first.

**Accept:** the game is completable start to finish without dev tools.

**Decided at M7a: the fortress is derived, not stored.** `GameState.fortress_open()`
walks the eight boss bits rather than setting a ninth flag, so the gate cannot
disagree with the thing it gates on. Progress *through* the fortress is stored
(four bits, in the save and in four of the password's five reserved cells), and
`fortress_stage()` returns the lowest uncleared rather than the highest cleared
plus one — the two rules agree while progress is contiguous, and only the first
can never skip a stage.

**Decided at M7c: unbeatable and non-lethal are the same design.** Ward's health
floors above the biggest single hit in the game, so he stops and leaves rather
than ever reaching zero; his attacks carry `DamageInfo.NON_LETHAL`, a flag on the
hit rather than a mode on the target, so they leave the player on at least one
point. Neither of you can finish it, and what is left is a conversation — the
only fight in the game with no stake in it, which is why it can afford to be the
one that says something. He also has a clock: a player who hides behind a block
still gets to leave, because the one fight with no reward is the worst possible
place to put a wall.

**Decided at M7b: a fortress stage has no gimmick of its own.** Each master stage
contains exactly one idea and deliberately none of the others, because a stage
that mixes two teaches neither (Sinkhole's docstring argues it at length). The
fortress can mix, because there is nothing left to teach — it is the second
examination, and the only new thing in it is that two answers are wanted at once.

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

The chain is **two cycles, not one**: a 5-cycle (Top → Hard → Magnet → Spark → Shadow →
Top) and a 3-cycle (Snake → Needle → Gemini → Snake). Earlier drafts of this line called
it "a single 8-cycle", which contradicts the table above it — the table is right. Preserve the property that **no boss is weak to a
weapon you get from it**, and that at least one boss is beatable buster-only.

### Weapon archetypes to fill

Whatever the names, cover these eight behaviours so the arsenal stays non-redundant:

1. Rapid low-damage spread (anti-swarm)
2. Homing / turning projectile (anti-evader)
3. Splitting or mirrored beam (multi-lane)
4. Heavy slow arcing knuckle (high damage, hard to aim)
5. Piercing bore (passes *through* enemies and breakable blocks instead of stopping at
   the first thing it hits — uses `DamageInfo.PIERCE`)
6. Terrain-crawling projectile (hits ground-huggers behind cover)
7. Stun/disable (locks a target, often deals no damage)
8. Multi-angle throwable that returns (utility + platform-cutting)

### The roster

Names are **working names** — the point of them is to stop referring to "boss 3", and they
are meant to be replaced. What is not arbitrary is the shape: bosses 1–5 form the 5-cycle
and 6–8 the 3-cycle, every one of the eight weapon archetypes above is used exactly once,
and no boss is weak to the weapon it drops.

The setting comes from stage 1's concept art rather than from a list of elements: a
drowned, post-industrial coast at dawn. Every stage is somewhere in that world.

| # | Boss | Stage | Weapon | Archetype | Gimmick | Weak to |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | **Tide** | Dawn Boardwalk — drowned coast | Tide Crawler | 6 · terrain-crawling | rising tide | Arc |
| 2 | **Arc** | Substation — flooded switchyard | Arc Lance | 2 · homing | dark room | Rust |
| 3 | **Rust** | Breakers — ship-scrapping yard | Rust Bloom | 4 · heavy arcing | crusher | Prism |
| 4 | **Prism** | Mirror Field — solar array | Prism Ray | 3 · splitting beam | disappearing blocks | Gale |
| 5 | **Gale** | Turbine Row — offshore wind farm | Gale Cutter | 8 · returning throwable | wind | Tide |
| 6 | **Cinder** | Stack — waste incinerator | Cinder Spray | 1 · rapid spread | conveyor | Frost |
| 7 | **Frost** | Cold Store — refrigerated docks | Frost Lock | 7 · stun/disable | ice | Quarry |
| 8 | **Quarry** | Sinkhole — flooded mine | Quarry Bore | 5 · piercing bore | water (swim) | Cinder |

**Tide is the buster-only boss.** Something has to be beatable with no weapons at all, and
it should be the stage that is actually built — that is where a player who wanders in
with nothing is most likely to land. Its pattern has to stay readable enough to dodge on
sight.

**Tide's art already exists**, as `assets/sprites/bosses/wave_man/` — a trident-and-wave-
cannon design generated before the roster was written. The directory keeps its original
name until there is a reason to churn every path; the *character* is Tide.

### Enemy archetypes

The six the enemy framework needs (M4), with stage 1 skins. The same six behaviours are
reskinned per stage rather than redesigned — the behaviour is the archetype, the art is
the theme.

| Archetype | Stage 1 skin | Behaviour |
| --- | --- | --- |
| walker | **Dockrat** — maintenance drone | patrols a plank run, turns at edges |
| hopper | **Bollard** — mooring-post unit | hops piling to piling on a fixed arc |
| turret | **Lampjack** — broken boardwalk lamp | fixed, pivots to fire on a cycle |
| flyer-sine | **Gullbot** — scavenger drone | sine sweep in over the water |
| spawner | **Barnacle Hive** — hull encrustation | fixed, releases small crawlers |
| wall-crawler | **Limpet** | clings to pilings, crawls around edges |

---

## 5. Task tracking

Each milestone becomes a GitHub milestone; each bullet becomes an issue labelled
`area:player`, `area:enemy`, `area:level`, `area:art`, `area:audio`, `area:tooling`.
Branch per issue off `main`, squash-merge. Tag `v0.M<n>` at each milestone acceptance.

---

## 6. Risks and open decisions

| Risk | Impact | Mitigation |
| --- | --- | --- |
| ~~Art scale/style does not match the design~~ | ~~Blocks M1~~ | **Closed.** Settled as HD: 1920 × 1080, `world_scale` 4.5, linear filtering. SPRITES.md §7 |
| ~~AutoSprite MCP unreachable from the web session~~ | ~~Blocks regeneration~~ | **Closed.** The domain is allowed and generation works. The `mcp__autosprite__*` tools now register normally, so the raw JSON-RPC recipe in SPRITES.md §6 is a fallback rather than the route |
| ~~Godot 4.7 API drift~~ | ~~Blocks M0~~ | **Closed at M0.** Verified on 4.7.stable, pinned in `.godot-version`, CI runs against it |
| AutoSprite output style is inconsistent between characters | Art rework | Lock one character prompt/seed convention at M2, generate all 8 bosses in one batch. Already visible: animation directory names alternate between `idle_right` and `Hit React` |
| AutoSprite frame counts don't match the animation lengths the controller expects | Animation desync | Controller drives timing; animations are cosmetic. Never gate state exits on `animation_finished` except for teleport and weapon-get. Confirmed: exports are 25 frames, the original batch at 10.7 fps and the 2026-09 batch at 12.2 fps (a 2.042 s `turbo` clip) — the mismatch is harmless for exactly this reason |
| ~~Missing animations block the controller~~ | ~~Blocks M1~~ | **Closed 2026-09-02.** All six generated and verified in-engine — SPRITES.md §4 |
| Generated clips open with a wind-up the player never sees | Move looks wrong | The controller owns timing, so a 26-frame slide shows ~5 animation frames. `AutoSpriteImporter.TRIM` selects the frames the move lives in; check a contact sheet before judging any new animation — SPRITES.md §4a |
| **Replacing a character's art invalidates every number measured off the old art** | Player floats or sinks, four moves show the wrong frames, and nothing errors | **Hit at M6l.** `BASELINE_ROW` and `Player.SOURCE_ART_BASELINE` are one number in two files and a test asserts they agree; the importer's clamp warnings are the signal that the pinned row is unreachable (twelve of fourteen clamped in one run). Re-derive every `TRIM` range off the new sheets rather than carrying it over, and key the table by character — a range named `attack` reaches five bosses otherwise. SPRITES.md §4a, §7 |
| Art style drifts between separately generated animations | Inconsistent character | Generate a character's animations in one batch. Regenerating a single animation from the same base image held style fine; a fresh batch weeks later is the untested case |
| Hand-authoring 8 stages is the schedule | Slips M6 | Build stage 1 fully, then extract a gimmick-block library before stages 2–8 |
| ~~Tileset art style clashes with the HD character~~ | ~~Looks like two games~~ | **Closed 2026-09-02.** Stage 1 was generated and judged against the player in `art_preview.tscn`: flat banded pixel terrain behind a smooth anti-aliased character reads as deliberate. 16 px tiles fit the 72 px grid exactly at 4.5×, and a per-node `TEXTURE_FILTER_NEAREST` keeps them crisp without touching the project default — SPRITES.md §8b |
| ~~PixelLab trial is 40 generations~~ | ~~Stops stage art mid-way~~ | **Closed at M6j — the account is a Tier 1 subscription, not a trial.** 2000 generations a cycle, resetting monthly; stage 4's whole art bill was 6. The budget is no longer what shapes stage art, so the advice that came out of the scarcity stands on its own merits instead: reuse the technique rather than re-derive it (SPRITES.md §8b–8f), because a prompt is not repeatable and a few lines over the returned PNG are |
| **`backblaze.pixellab.ai` is not in the environment's allowed domains** | Blocks every stage tileset | **Open, and it blocked stage 4's tileset.** Tileset *metadata* is served from `api.pixellab.ai` and downloads fine; the spritesheet PNG 302s to `backblaze.pixellab.ai`, which the egress proxy answers 403 to. Every alternate route was re-probed at M6j and all still redirect. A generated tileset stays on PixelLab's server, so opening the host recovers it without paying again — SPRITES.md §8 has had this written down since stage 1 |
| Pixel-perfect + camera smoothing fight each other | Jitter | Camera snapping off, no position smoothing, integer stretch — settled in ARCHITECTURE §2 and asserted in `tests/test_project_settings.gd` |
| Continuous-vs-discrete physics maths in level design | Unclearable ledges | **Hit once already at M0.** `jump_apex_px()` integrates for real; a test locks the number |
| Web export audio latency | Feel | Test the web build from M3, not M8 |

**Open decisions to make at M1 (write the answer into ARCHITECTURE):**

- **Coyote time / jump buffering:** the original had neither. Modern players notice.
  *Provisionally settled at M0:* `coyote_frames = 0`, `jump_buffer_frames = 4` — buffering
  is invisible and forgiving, coyote time changes ledge geometry. Encoded in
  `PlayerTuning` and asserted in `tests/test_tuning.gd`, so changing it after the first
  playtest is a one-line edit plus a test update. Revisit then.
- **Slide cancelling:** MM3 lets you cancel a slide by pressing jump. Keep it; it's a
  skill expression the speedrun crowd expects.
- **Screen-transition style:** hard scroll-lock (MM1–5) vs free scroll. Recommendation:
  scroll-lock, because it makes enemy respawn rules coherent and stage authoring bounded.
