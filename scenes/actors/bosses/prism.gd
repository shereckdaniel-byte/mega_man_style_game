## Prism -- Mirror Field's Robot Master, and the fourth of the eight.
##
## The roster's rule, restated once per boss: every pattern has an answer that
## costs no ammo, and **the three answers must differ from each other and from
## every previous boss's.** By stage 4 that is a real constraint rather than a
## slogan. Tide asked for three timings. Arc asked for movement, timing and
## position -- all of which are dodging, which is why Rust had to break out of it
## with offence, distance and attrition.
##
## Prism's three are built out of light, and none of them is any of those:
##
##   * **Split** casts a beam at chest height that reaches the far wall and comes
##     back as two, low first and high second. The answer is **anticipation** --
##     the thing that hurts you arrives from behind, and it arrives because of
##     something you already dealt with. Jump the outbound beam, jump the low
##     return, and then *stay on the ground* for the high one, which is the first
##     time in the game that not jumping is an action.
##   * **Facets** plants two mirrors and rattles a beam between them. The answer
##     is **reading a diagram** -- the corridor is drawn in full before anything
##     in it can hurt you, and the ask is to get out of a place you can see
##     rather than to react to a thing you cannot.
##   * **Sweep** walks a focal point across the whole arena with Prism behind it.
##     The answer is **committing forward** -- backing away spends the floor and
##     ends at a wall, so the way out is over the top of it, towards the boss.
##
## Anticipation, reading, commitment. And Split is the pattern the player is
## handed as Prism Ray, which is the trade a weapon-get is supposed to feel like
## -- the same argument Rust Bloom is built on.
##
## ### Prism is weak to Gale Cutter, which does not exist yet
##
## The position Arc was in until stage 3 landed and Rust was in until this one:
## the row is in `resources/damage_tables/prism.tres` because the table is the
## design, and the fight has to stand up buster-only until stage 5.
## `tools/playthrough.gd` is expected to win it with the buster.
##
## ### The bound on Facets
##
## A pattern that forbids a stretch of floor can be made unwinnable by making the
## stretch the whole arena, so the constraint is structural rather than tuned:
## the arena is divided into `FACET_COLUMNS` and a corridor is never more than
## `FACET_SPAN` of them wide. Whatever the pattern chooses, three columns are
## outside it, and `tests/test_prism.gd` pins that rather than trusting the
## numbers. It is the same shape of guarantee as Rust's alternate columns, and it
## is here for the same reason.
class_name Prism
extends Boss

const BEAM := preload("res://scenes/actors/projectiles/prism_beam.gd")
const MIRROR := preload("res://scenes/actors/projectiles/facet_mirror.gd")
const SPOT := preload("res://scenes/actors/projectiles/focus_spot.gd")
const DAMAGE_TABLE := preload("res://resources/damage_tables/prism.tres")
const SPRITE_FRAMES := preload("res://resources/sprite_frames/prism.tres")

## Boss index 3 (docs/PLAN.md section 4).
const INDEX := 3

## Narrower than Rust's 26x27 and a shade wider than Arc's 20x26. A faceted
## optical unit should read as light on its feet next to the scrapper, and the
## body is what says so before the art does.
const BODY_NES := Vector2(22.0, 26.0)

## --- Split: the beam that comes back doubled ---
## Height the cast leaves from, above Prism's feet, in NES px.
##
## Chosen from the beam's **underside** rather than from where it looks right,
## which is the arithmetic `Rust.SCRAP_HEIGHT_NES` had to be corrected on. The
## beam is `PrismBeam.BEAM_NES.y` tall, so at 20 its underside sits at 17.5: a
## standing player (24 NES px) is caught and a sliding one (14) passes under with
## three and a half pixels to spare. Both answers stay open on the outbound leg,
## which matters because the returning pair takes one of them away.
const CAST_HEIGHT_NES := 20.0

## What a beam does. **Two, not three, because a Split is three chances to be
## hit** -- the outbound cast, the low return and the high return -- and Facets
## is a beam that passes you four times. At 3 the playthrough bot lost 18 HP to
## beams alone and died in the arena, where it wins Tide, Arc and Rust
## buster-only; at 2 the fight costs about what theirs do. The pattern did not
## change, only what it charges.
const BEAM_DAMAGE := 2

## --- Facets: the corridor ---
## Columns the arena is divided into for placing mirrors. Seven, like Rust's, so
## the two bosses' spatial vocabularies are the same size.
const FACET_COLUMNS := 7
## Columns a corridor may span. Four of seven leaves three outside it, always.
const FACET_SPAN := 4
## Times the beam turns round before it gives up.
##
## **Two, and the number is about the fight's density rather than the pattern.**
## Prism has more live damage in the air than any boss before it -- a Split is
## three separate chances to be hit and a Sweep crosses the whole arena -- so a
## Facet that rattles four times is a beam passing through the player's half of
## the room five times on top of that. Two keeps the idea (it goes, it comes
## back, and you have to be outside the corridor for both) and stops the pattern
## being a blender.
const FACET_BOUNCES := 2
## Frames the mirrors stand for beyond the pattern they belong to. Enough for the
## beam's last leg, which in the worst case sets off at the end of the recovery.
const FACET_LINGER_FRAMES := 70

## --- Sweep: the focal point ---
const SWEEP_DAMAGE := 3
## Prism's own speed while it follows the spot in, in NES px/frame. **Below the
## spot's `FocusSpot.SPEED_PF`**, so the boss never overtakes the thing it is
## driving and the player who jumps the spot lands in open floor rather than on
## top of Prism.
const SWEEP_FOLLOW_PF := 0.9

var _facet_span := Vector2i.ZERO


func _ready() -> void:
	boss_index = INDEX
	weapon_id = &"prism_ray"
	display_name = "Prism"
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
	# Split first and most often: it is the pattern that teaches the fight, the
	# one the player is least likely to have an answer to already, and the one
	# they will be given as a weapon.
	#
	# The act phase is short because the beam has a life of its own -- it is
	# still crossing the arena during the recovery, and coming back through the
	# pattern after that. **That is deliberate and it is what makes the pattern
	# anticipation rather than a dodge**: the player is answering the last attack
	# while the next tell is already running.
	out.append(BossPattern.new(&"split", 34, 12, 46, 1.2)
		.with_anims(&"attack", &"attack", &"idle"))
	# The longest tell in the fight, and all of it is the mirrors standing there
	# being looked at. A shorter one would make the corridor something the player
	# discovers rather than reads.
	out.append(BossPattern.new(&"facets", 46, 16, 44, 1.0)
		.with_anims(&"jump", &"attack", &"idle"))
	out.append(BossPattern.new(&"sweep", 34, 26, 40, 0.9)
		.with_anims(&"walk", &"attack", &"idle"))
	return out


func fight_move(_delta: float) -> void:
	# Prism holds its ground except while walking in behind a Sweep, which drives
	# its own velocity through the act phase.
	var pattern := current_pattern()
	var following: bool = pattern != null and pattern.id == &"sweep" \
		and pattern_step() == 1
	if not following:
		velocity.x = 0.0
	hold_inside_arena()


func tell(pattern: BossPattern, frame: int) -> void:
	# Nothing is fired during a tell, by design -- see BossPattern. What Facets
	# does here is not an attack: it is the diagram.
	velocity.x = 0.0
	if frame != 0:
		return
	if pattern.id == &"facets":
		_plant_mirrors(pattern)


func act(pattern: BossPattern, frame: int) -> void:
	match pattern.id:
		&"split":
			if frame == 0:
				_cast()
		&"facets":
			if frame == 0:
				_rattle()
		&"sweep":
			if frame == 0:
				_open_sweep()
			_follow_sweep()


func recover(_pattern: BossPattern, _frame: int) -> void:
	velocity.x = 0.0


# --- Patterns -------------------------------------------------------------------

## One beam, cast level at chest height in the direction Prism is facing.
##
## Level rather than angled: the whole pattern turns on the player being able to
## tell the low return from the high one at a glance, and a cast that arrived on
## a slope would make "which height is this" a judgement instead of a look.
func _cast() -> void:
	var beam := BEAM.new() as PrismBeam
	var at := global_position + Vector2(
		float(facing()) * BODY_NES.x * 0.6 * tuning.world_scale,
		-CAST_HEIGHT_NES * tuning.world_scale)
	beam.launch(at, Vector2(float(facing()), 0.0), PrismBeam.CAST_SPEED_PF,
		BEAM_DAMAGE, tuning)
	beam.aim(arena_span(), PrismBeam.OnEdge.SPLIT, 0, global_position.y)
	_spawn(beam)


## The two mirrors, planted during the tell so the corridor is readable before
## anything in it is dangerous. See `FacetMirror`.
func _plant_mirrors(pattern: BossPattern) -> void:
	_facet_span = facet_columns(_column_at(_target_x()), _rng.randi_range(1, 2))
	# They must outlive the beam, which is fired at the start of the act phase
	# and rattles through the recovery. Derived from the pattern rather than
	# guessed, so a retuned pattern cannot leave mirrors standing in an empty
	# arena or take them away with the beam still bouncing.
	var life := pattern.act_frames + pattern.recover_frames + FACET_LINGER_FRAMES
	for column in [_facet_span.x, _facet_span.y]:
		var mirror := MIRROR.new() as FacetMirror
		mirror.plant(Vector2(column_centre(column), global_position.y), life,
			tuning)
		_spawn(mirror)


## The beam that rattles between them, launched from the left mirror towards the
## right one so its first pass crosses the whole corridor -- a beam that started
## in the middle would give whichever half it left first a free bounce.
func _rattle() -> void:
	var left := column_centre(_facet_span.x)
	var right := column_centre(_facet_span.y)
	var beam := BEAM.new() as PrismBeam
	beam.launch(Vector2(left, global_position.y - CAST_HEIGHT_NES * 0.55 * tuning.world_scale),
		Vector2.RIGHT, PrismBeam.REFLECT_SPEED_PF, BEAM_DAMAGE, tuning)
	beam.aim(Vector2(left, right), PrismBeam.OnEdge.REFLECT, FACET_BOUNCES,
		global_position.y)
	_spawn(beam)


## The focal point, opened at Prism's own feet and walked at the wall the player
## is nearer to. Aimed at the player's side rather than away from it, for the
## same fairness argument Arc's Curtain and Rust's Bloom are built on: the player
## is asked to leave a place they can see, not to guess which half is safe.
func _open_sweep() -> void:
	var span := arena_span()
	var towards := span.y if _target_x() >= global_position.x else span.x
	var spot := SPOT.new() as FocusSpot
	spot.sweep(global_position, towards, SWEEP_DAMAGE, tuning)
	_spawn(spot)


## Prism walks in behind the spot, which is what makes retreating a losing move:
## the floor the player gives up is floor the boss takes. Slower than the spot,
## so the gap between them stays open -- that gap is where a player who jumps
## the spot lands.
func _follow_sweep() -> void:
	var span := arena_span()
	var towards := span.y if _target_x() >= global_position.x else span.x
	velocity.x = signf(towards - global_position.x) * tuning.px_s(SWEEP_FOLLOW_PF)


# --- Geometry -------------------------------------------------------------------

## The corridor, as a pair of columns. Pure, so `tests/test_prism.gd` can check
## the bound across every column and every offset without running a fight.
##
## `offset` is how far into the corridor the player's column sits -- 1 or 2, so
## the shorter way out is not always the same direction. Whatever it is, the
## corridor is `FACET_SPAN` columns wide and clamped inside the arena, which is
## what leaves `FACET_COLUMNS - FACET_SPAN` columns outside it. That subtraction
## is the whole bound, and it is why `FACET_SPAN` is a constant rather than a
## number chosen per cast.
static func facet_columns(player_column: int, offset: int) -> Vector2i:
	var left := clampi(player_column - offset, 0, FACET_COLUMNS - FACET_SPAN)
	return Vector2i(left, left + FACET_SPAN - 1)


func _column_at(x: float) -> int:
	var span := arena_span()
	if span.y - span.x < 0.001:
		return FACET_COLUMNS / 2
	var t := (x - span.x) / (span.y - span.x)
	return clampi(int(t * float(FACET_COLUMNS)), 0, FACET_COLUMNS - 1)


func column_centre(column: int) -> float:
	var span := arena_span()
	var width := (span.y - span.x) / float(FACET_COLUMNS)
	return span.x + width * (float(column) + 0.5)


## The corridor the last Facets chose, for tests and for anything that later
## wants to draw it.
func facet_span() -> Vector2i:
	return _facet_span


## Where the player is, or the arena's centre when there is nobody to aim at --
## which is what a bare test has, and aiming at the world origin would put every
## pattern against the left-hand wall.
func _target_x() -> float:
	if target == null or not is_instance_valid(target):
		return arena_centre()
	return target.global_position.x


## Projectiles are parented to the level, not to the boss: they must outlive the
## boss's own death, and a beam must not travel with it during a Sweep.
func _spawn(node: Node2D) -> void:
	var level := get_parent()
	if level == null:
		node.free()
		return
	level.add_child(node)
