## Gale -- Turbine Row's Robot Master, and the fifth of the eight.
##
## The roster's rule, restated once per boss: every pattern has an answer that
## costs no ammo, and **the three answers must differ from each other and from
## every previous boss's.** Twelve are spent by the time this one is written --
## Tide's three timings; Arc's movement, timing and position; Rust's offence,
## distance and attrition; Prism's anticipation, reading and commitment -- and
## the honest position at boss five is that the space of *new verbs* is nearly
## gone. So Gale's three are not new verbs. They are the three places the
## **wind** changes what an old verb costs, which is the only thing this boss
## has that the other four do not.
##
##   * **Crosswind** blows while a blade goes out and comes back. The answer is
##     **being carried** -- the wind cannot touch a player who stays on the
##     ground (`WindZone`'s first fairness rule), so the instinct is to walk it
##     out, and walking is exactly what the returning blade is timed against.
##     Jumping hands your horizontal position to the arena, and that is the way
##     through. It is the only answer in the game that is *fewer* inputs.
##   * **Rotor** throws a train of blades along one lane, and **Gale hovers at
##     the lane it is about to throw down**. The answer is **reading the boss's
##     body instead of its attack**: every tell before this one is an animation
##     or a planted object, and this one is where the boss is standing. Gale
##     low means jump the train; Gale high means stay down through it -- and
##     staying down is the harder half, because four bosses have now taught the
##     player that the air is where safety is.
##   * **Downdraft** takes the floor away. Not part of it -- all of it, for
##     `Downdraft.SLAB_FRAMES`. The answer is **leaving the ground entirely**,
##     which is the inverse of the assumption every other pattern in the game
##     is built on, Prism's high return included: there, not jumping was the
##     action. Here there is nowhere to not jump to.
##
## Being carried, reading the boss, and abandoning the floor. None of them is
## Tide's timing or Arc's positioning wearing a hat, and each one only works
## because the stage spent nineteen rooms teaching what moving air does.
##
## ### Gale is weak to Tide Crawler
##
## Which the player has, if they have beaten stage 1 -- and stage 1 is the
## buster-only stage, so they can have. This is the first boss in the roster
## whose weakness has been obtainable since before its stage was built.
##
## ### And Gale Cutter is what unblocks Prism
##
## `resources/damage_tables/prism.tres` has had a `gale_cutter` row since stage
## 4 landed, pointing at a weapon that did not exist. It exists now
## (`CutterShot`), which closes the one dangling weakness in the chain.
class_name Gale
extends Boss

const BLADE := preload("res://scenes/actors/projectiles/gale_blade.gd")
const SLAB := preload("res://scenes/actors/projectiles/downdraft.gd")
const DAMAGE_TABLE := preload("res://resources/damage_tables/gale.tres")
const SPRITE_FRAMES := preload("res://resources/sprite_frames/gale.tres")

## Boss index 4 (docs/PLAN.md section 4).
const INDEX := 4

## Taller and narrower than any of the first four -- Rust is 26x27, Prism 22x26,
## Arc 20x26. A rotor unit should read as something built to stand in weather,
## and the body is what says so before the art does.
const BODY_NES := Vector2(19.0, 29.0)

# --- Crosswind ------------------------------------------------------------------

## The push, in NES px/frame, written onto the player every act frame.
##
## **Under `PlayerTuning.walk_speed_pf` (1.375), and that is a rule rather than a
## taste** -- the same one `WindZone` is built on. A wind at or above the walk
## speed is a wind that can hold a player still or walk them backwards, and a
## player who cannot get where they are going has no answer to give.
## `tests/test_gale.gd` checks it against the tuning rather than against 1.375.
const CROSSWIND_DRIFT_PF := 1.0

## Blades per Crosswind, and the act frames they leave on.
##
## Two, spaced so the second goes out while the first is coming back. That
## crossing is the pattern: at any moment after the second throw there is a
## blade travelling each way, and a player trying to hold one spot on the floor
## is between them.
const CROSSWIND_THROW_FRAMES := [0, 34]
const CROSSWIND_BLADE_SPEED_PF := 3.4
## How far a Crosswind blade goes before it turns, in NES px.
const CROSSWIND_RANGE_NES := 110.0
## Height above the floor a Crosswind blade travels at, in NES px. Chest height
## on a standing player (24) and clear over a sliding one (14) -- so sliding is
## an answer to a single blade, which is what makes the *pair* the pattern.
const CROSSWIND_HEIGHT_NES := 17.0

const BLADE_DAMAGE := 2

# --- Rotor ----------------------------------------------------------------------

## The two lanes, in NES px above the floor.
##
## Two and not four. A lane a player can be *between* needs 24 px of clearance
## for the standing body plus the blade's own 11, so lanes spaced closely enough
## to look like a grid are lanes with no gap a player fits in -- the arithmetic
## is in `tests/test_gale.gd`. Two lanes far apart always leave one honest
## answer: the low train is jumped, the high train is stood under.
const ROTOR_LANE_LOW_NES := 8.0
const ROTOR_LANE_HIGH_NES := 48.0

const ROTOR_BLADES := 3
## Act frames between blades. Above the jump's 39.5-frame arc would make each
## blade a separate hop; below it, the train has to be taken in one posture,
## which is the ask.
const ROTOR_SPACING_FRAMES := 22
const ROTOR_BLADE_SPEED_PF := 3.0

# --- Downdraft ------------------------------------------------------------------

## Where Gale hangs while the slab falls, in NES px above the floor. Above the
## player's jump apex (about 49), so the boss is not something the player can be
## pushed into while they are busy not being on the ground.
const DOWNDRAFT_HOVER_NES := 76.0
## Where the slab starts its fall, in NES px above the floor. Above Gale, so it
## reads as coming off the rotor rather than out of it.
const DOWNDRAFT_START_NES := 132.0
const DOWNDRAFT_DAMAGE := 3

# --- Hovering -------------------------------------------------------------------

## Fastest Gale climbs or sinks while holding a height, in NES px/frame.
const HOVER_SPEED_PF := 3.4
## Servo gain on the hover, per second. Enough to arrive inside a tell, low
## enough not to oscillate at 60 Hz.
const HOVER_GAIN := 7.0

## Lane the last Rotor chose, in NES px above the floor.
var _rotor_lane := ROTOR_LANE_LOW_NES


func _ready() -> void:
	boss_index = INDEX
	weapon_id = &"gale_cutter"
	display_name = "Gale"
	contact_damage = 4
	anim_name = &"idle"
	if damage_table == null:
		damage_table = DAMAGE_TABLE
	if sprite_frames == null:
		sprite_frames = SPRITE_FRAMES
	super()


func body_size() -> Vector2:
	return BODY_NES * tuning.world_scale


func build_patterns() -> Array[BossPattern]:
	var out: Array[BossPattern] = []
	# Crosswind first and most often: it is the pattern that teaches the fight,
	# it is the one the stage has been teaching for nineteen rooms, and it is the
	# only one whose answer the player is unlikely to already have.
	out.append(BossPattern.new(&"crosswind", 40, 70, 34, 1.2)
		.with_anims(&"attack", &"attack", &"idle"))
	# The tell is long because the tell is Gale climbing to the lane, and a
	# player who has not seen the boss arrive at its height has not been told
	# anything.
	out.append(BossPattern.new(&"rotor", 44, 78, 36, 1.0)
		.with_anims(&"jump", &"attack", &"idle"))
	out.append(BossPattern.new(&"downdraft", 38, 46, 42, 0.9)
		.with_anims(&"jump", &"attack", &"idle"))
	return out


# --- Movement -------------------------------------------------------------------

## Gale never walks. It plants, or it holds a height -- and which of those it is
## doing is the tell for two of the three patterns, so it is derived from the
## pattern rather than set by it.
func fight_move(_delta: float) -> void:
	velocity.x = 0.0
	var wanted := hover_height()
	if wanted < 0.0:
		affected_by_gravity = true
	else:
		affected_by_gravity = false
		_hold(wanted)
	hold_inside_arena()


## Height above the floor Gale should be holding right now, in NES px, or -1 for
## "stand on the floor". Public and pure enough to be asserted directly, because
## on two of the three patterns this *is* the telegraph and a test that only
## watched the projectiles would not be watching the tell.
func hover_height() -> float:
	var pattern := current_pattern()
	if pattern == null:
		return -1.0
	# The recovery is always a landing, whatever the pattern was. A boss that
	# stayed in the air between patterns would make the height mean nothing.
	if pattern_step() >= 2:
		return -1.0
	match pattern.id:
		&"rotor":
			return _rotor_lane
		&"downdraft":
			return DOWNDRAFT_HOVER_NES
	return -1.0


func _hold(height_nes: float) -> void:
	var wanted_y := arena_floor_y() - height_nes * tuning.world_scale
	var limit := tuning.px_s(HOVER_SPEED_PF)
	velocity.y = clampf((wanted_y - global_position.y) * HOVER_GAIN, -limit, limit)


# --- Patterns -------------------------------------------------------------------

func tell(pattern: BossPattern, frame: int) -> void:
	# Nothing is fired during a tell, by design -- see BossPattern. What Rotor
	# does here is not an attack: it is the boss climbing to the lane, which is
	# the only thing the player is given to read.
	if pattern.id == &"rotor" and frame == 0:
		_rotor_lane = ROTOR_LANE_HIGH_NES if _rng.randi() % 2 == 0 \
			else ROTOR_LANE_LOW_NES


func act(pattern: BossPattern, frame: int) -> void:
	match pattern.id:
		&"crosswind":
			_blow()
			if CROSSWIND_THROW_FRAMES.has(frame):
				_throw_returning()
		&"rotor":
			if frame % ROTOR_SPACING_FRAMES == 0 \
					and frame / ROTOR_SPACING_FRAMES < ROTOR_BLADES:
				_throw_lane()
		&"downdraft":
			if frame == 0:
				_drop_slab()


func recover(_pattern: BossPattern, _frame: int) -> void:
	velocity.x = 0.0


## One frame of push, written onto the player.
##
## Written every frame rather than latched, and cleared by the player every
## frame -- the same contract `WindZone` uses, and the reason a boss dying
## mid-Crosswind does not leave the player permanently blown sideways.
##
## It blows the way Gale is facing, which is at the player: an airborne player is
## carried *away* from the boss, towards the open floor. Blowing the other way
## would pull the player into the thing with contact damage, which is a hazard
## dressed as a mechanic.
func _blow() -> void:
	if target == null or not is_instance_valid(target):
		return
	if target is Player:
		(target as Player).wind_drift_pf = float(facing()) * CROSSWIND_DRIFT_PF


## A blade out and back, at chest height, returning to where Gale is now.
func _throw_returning() -> void:
	var blade := BLADE.new() as GaleBlade
	var at := global_position + Vector2(
		float(facing()) * BODY_NES.x * 0.6 * tuning.world_scale,
		-CROSSWIND_HEIGHT_NES * tuning.world_scale)
	blade.launch(at, Vector2(float(facing()), 0.0), CROSSWIND_BLADE_SPEED_PF,
		BLADE_DAMAGE, tuning)
	blade.set_return(at, CROSSWIND_RANGE_NES * tuning.world_scale)
	_spawn(blade)


## One blade of the train, along the lane Gale is holding.
##
## Launched from Gale's own height rather than from the lane constant, so what
## the player read during the tell and what arrives during the act cannot come
## apart -- if the hover has not finished climbing, the blades are where the boss
## actually is.
func _throw_lane() -> void:
	var blade := BLADE.new() as GaleBlade
	var at := global_position + Vector2(
		float(facing()) * BODY_NES.x * 0.6 * tuning.world_scale, 0.0)
	blade.launch(at, Vector2(float(facing()), 0.0), ROTOR_BLADE_SPEED_PF,
		BLADE_DAMAGE, tuning)
	_spawn(blade)


## The slab, over the whole arena floor.
func _drop_slab() -> void:
	var slab := SLAB.new() as Downdraft
	slab.drop(arena_span(), arena_floor_y(),
		arena_floor_y() - DOWNDRAFT_START_NES * tuning.world_scale,
		DOWNDRAFT_DAMAGE, tuning)
	_spawn(slab)


## The lane the last Rotor chose, for the tests and for anything that later
## wants to draw it.
func rotor_lane() -> float:
	return _rotor_lane


## Projectiles are parented to the level, not to the boss: they must outlive the
## boss's own death, and a blade must not travel with it while it hovers.
func _spawn(node: Node2D) -> void:
	var level := get_parent()
	if level == null:
		node.free()
		return
	level.add_child(node)
