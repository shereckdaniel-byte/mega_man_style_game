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

The sword is a committed swing — planted, no cancel, ground only. Take the commitment away
and there is no reason ever to fire the buster. Ground-only is a limitation, not a
decision: the clip is a planted two-blade guard stance that reads wrong in mid-air, and an
air slash wants its own animation and its own arc.

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
- ⬜ Vertical scroll rooms and ladder-driven vertical transitions. Not needed by stage 1,
  which is horizontal; the first stage that needs a shaft will want them.

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

### M5a — Level-element library and stage 1 extended (prerequisite for M6)

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
| **Vertical room transitions** | The M4 ⬜ item. Turns ladders from decoration into structure |
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

**Accept:** stage 1 runs 60–90 s of traversal, uses at least five distinct level elements,
and the rising tide cannot soft-lock a player anywhere in it.

### M6 — Content build-out (2–3 weeks)

- Remaining 7 stages + 7 Robot Masters, each with one stage-unique gimmick. Note the
  original list here named seven gimmicks for seven *remaining* stages, which left stage 1
  with none — section 4's roster adds **rising tide** for Dawn Boardwalk and moves
  **water** (swim physics) to the Sinkhole, so all eight stages have one.
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
| Art style drifts between separately generated animations | Inconsistent character | Generate a character's animations in one batch. Regenerating a single animation from the same base image held style fine; a fresh batch weeks later is the untested case |
| Hand-authoring 8 stages is the schedule | Slips M6 | Build stage 1 fully, then extract a gimmick-block library before stages 2–8 |
| ~~Tileset art style clashes with the HD character~~ | ~~Looks like two games~~ | **Closed 2026-09-02.** Stage 1 was generated and judged against the player in `art_preview.tscn`: flat banded pixel terrain behind a smooth anti-aliased character reads as deliberate. 16 px tiles fit the 72 px grid exactly at 4.5×, and a per-node `TEXTURE_FILTER_NEAREST` keeps them crisp without touching the project default — SPRITES.md §8b |
| PixelLab trial is 40 generations | Stops stage art mid-way | **Tighter than it looked.** Stage 1's backdrop and tileset cost 12 of 40 — 2 of those thrown away, and the sky took 4 attempts. 28 left for 7 Robot Master stages plus the fortress, so stage 2 onward has to reuse the technique rather than re-derive it (SPRITES.md §8b–8c), and fortress stages should share a tileset |
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
