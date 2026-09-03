## Arc -- Substation's Robot Master, and the second of the eight.
##
## Tide's design rule was that every pattern needs an answer costing no ammo,
## because a player may arrive with nothing. Arc keeps that and adds the rule
## that makes a roster rather than a list: **the three answers must be different
## from each other, and different from the last boss's.** Tide asks for jump,
## move-under, and slide -- three timing answers. Repeat those with new sprites
## and boss two is boss one in a different colour.
##
## So Arc asks for three *kinds* of thing:
##
##   * **Lash** throws a slow seeker. The answer is **movement** -- keep going
##     and it expires behind you. Nothing to time; standing still is what loses.
##   * **Rail** turns Arc into a live conductor and sends it across the floor.
##     The answer is **timing** -- jump it, and the tell is long enough to set up.
##   * **Curtain** drops columns of sparks from the ceiling with one column left
##     open. The answer is **position** -- read the gap and be standing in it.
##
## Movement, timing, position. A player who has beaten Tide has learned none of
## these, which is the point of fighting a second boss.
##
## **Arc is not the buster-only boss** -- Tide holds that job (docs/PLAN.md
## section 4) -- but nothing here is unfair to a player who has no weapons, and
## `tools/playthrough.gd` is expected to win with the buster. What Arc is weak to
## is Rust Bloom, which does not exist yet: until stage 3 there is no weakness to
## exploit, and the fight has to stand on its own.
class_name Arc
extends Boss

const ENEMY_SHOT := preload("res://scenes/actors/projectiles/enemy_shot.gd")
const SPARK_ORB := preload("res://scenes/actors/projectiles/spark_orb.gd")
## Weakness table. Arc takes 4 from Rust Bloom, which is stage 3's weapon and not
## built -- the row is written now because the table is the design and a table
## that is filled in only when the weapon lands is a table nobody checks against
## the roster. Arc is deliberately NOT weak to its own Arc Lance.
const DAMAGE_TABLE := preload("res://resources/damage_tables/arc.tres")
const SPRITE_FRAMES := preload("res://resources/sprite_frames/arc.tres")

## Boss index 1 (docs/PLAN.md section 4).
const INDEX := 1

const BODY_NES := Vector2(20.0, 26.0)

## --- Lash: the seeker ---
const LASH_ORBS := 2
const LASH_SPEED_PF := 1.5
const LASH_DAMAGE := 3
const LASH_SIZE_NES := Vector2(9.0, 9.0)
## Frames between the two orbs, so they arrive as a pair to be walked around
## rather than as a wall.
const LASH_SPACING := 20
## Height the orbs leave from, above Arc's feet, in NES px.
const LASH_HEIGHT_NES := 17.0

## --- Rail: the floor dash ---
## Dash speed in NES px/frame. Faster than the player's 1.375 walk by a good
## margin -- outrunning it must not be an option, or the pattern has two answers
## and the jump stops being the one.
const RAIL_SPEED_PF := 3.6
## Frames of dash. Long enough to cross the arena from either end.
const RAIL_FRAMES := 46

## --- Curtain: the falling columns ---
## Columns the arena is divided into. One of them is left open.
const CURTAIN_COLUMNS := 5
const CURTAIN_SPEED_PF := 2.6
const CURTAIN_DAMAGE := 2
## Frames between successive sparks down one column, and how many fall.
const CURTAIN_INTERVAL := 12
const CURTAIN_DROPS := 4
## How far above Arc's feet the columns start, in NES px. Above the top of the
## screen would be unreadable; this is high enough to react to.
const CURTAIN_HEIGHT_NES := 62.0
## Arc's hop during Curtain, so the pattern is not a stationary boss watching its
## own attack. Small: this is a step aside, not a Spout.
const CURTAIN_HOP_PF := 3.4

## Horizontal bounds of the arena floor, set by the arena. Rail needs to know
## where to stop and Curtain needs to know what to divide up.
var arena_left := 0.0
var arena_right := 0.0

var _rail_direction := -1
var _open_column := 0


func _ready() -> void:
	boss_index = INDEX
	weapon_id = &"arc_lance"
	display_name = "Arc"
	contact_damage = 4
	anim_name = &"idle"
	if damage_table == null:
		damage_table = DAMAGE_TABLE
	if sprite_frames == null:
		sprite_frames = SPRITE_FRAMES
	super()


func body_size() -> Vector2:
	return BODY_NES * tuning.world_scale


## The arena hands over the floor span. Without it Rail would dash into a wall
## and Curtain would have nothing to divide.
func set_arena_span(left: float, right: float) -> void:
	arena_left = minf(left, right)
	arena_right = maxf(left, right)


func build_patterns() -> Array[BossPattern]:
	var out: Array[BossPattern] = []
	# Lash first and most often: it is the pattern that teaches the fight -- the
	# one whose answer is "keep moving", which is also the answer to being in
	# the wrong place for either of the others.
	out.append(BossPattern.new(&"lash", 28, LASH_SPACING * LASH_ORBS + 4, 44, 1.3)
		.with_anims(&"attack", &"attack", &"idle"))
	# The longest tell in the fight. Rail is the pattern that punishes standing
	# still hardest, so it is the one that must be readable from furthest away.
	out.append(BossPattern.new(&"rail", 34, RAIL_FRAMES, 32, 1.0)
		.with_anims(&"walk", &"walk", &"idle"))
	out.append(BossPattern.new(&"curtain",
			32, CURTAIN_INTERVAL * CURTAIN_DROPS + 8, 36, 0.9)
		.with_anims(&"jump", &"attack", &"idle"))
	return out


func fight_move(_delta: float) -> void:
	# Arc holds its ground except during Rail's dash and Curtain's hop, both of
	# which drive their own velocity.
	var pattern := current_pattern()
	var driving: bool = pattern != null and pattern_step() == 1 \
		and (pattern.id == &"rail" or pattern.id == &"curtain")
	if not driving:
		velocity.x = 0.0
	_hold_inside_arena()


## Keeps Arc in the room, whatever a pattern asks for.
##
## **A bound, not a tuned number, and that distinction is the lesson from M5.**
## Tide left the arena through the ceiling because its leap velocity was chosen
## to look right rather than derived, and the fix was a smaller number -- which
## works until the next pattern, on the next boss, picks the wrong one again.
## Curtain's hop did the same thing sideways here: 56 frames of act phase at a
## walking speed nobody thought of as travel, and Arc was 900 px outside the
## arena still fighting.
##
## So the constraint lives where it can be stated once: whatever a pattern does
## with `velocity`, Arc is inside the span at the end of the frame. A pattern is
## then free to be wrong about its own arithmetic without taking the fight off
## the screen.
func _hold_inside_arena() -> void:
	var span := _span()
	var margin := BODY_NES.x * 0.5 * tuning.world_scale
	var low := span.x + margin
	var high := span.y - margin
	if low >= high:
		return
	if global_position.x < low:
		global_position.x = low
		velocity.x = maxf(velocity.x, 0.0)
	elif global_position.x > high:
		global_position.x = high
		velocity.x = minf(velocity.x, 0.0)


func tell(pattern: BossPattern, frame: int) -> void:
	# Nothing is fired during a tell, by design -- see BossPattern.
	velocity.x = 0.0
	if frame != 0:
		return
	match pattern.id:
		&"rail":
			# Decided on the first frame of the tell, not the first frame of the
			# dash, so the direction is part of what the tell shows. A dash whose
			# direction is chosen at the last moment is a tell that says
			# "something is coming" and not "it is coming *here*".
			_rail_direction = -1 if global_position.x > _centre() else 1
		&"curtain":
			_open_column = _choose_open_column()


func act(pattern: BossPattern, frame: int) -> void:
	match pattern.id:
		&"lash":
			if frame % LASH_SPACING == 0 and frame / LASH_SPACING < LASH_ORBS:
				_fire_orb()
		&"rail":
			_do_rail(frame)
		&"curtain":
			_do_curtain(frame)


func recover(_pattern: BossPattern, _frame: int) -> void:
	velocity.x = 0.0


## Which column is left open.
##
## The one the player is standing in, whenever there is a player to ask. That
## reads backwards -- the boss aiming its gap *at* you -- and it is the fair
## choice: the alternative is a random column, which asks the player to cross the
## arena during a falling attack and is a coin flip when they cannot. Aiming the
## gap at them makes the answer "stay put and hold your nerve", and moving out of
## it is the mistake. `tests/test_arc.gd` pins this.
func _choose_open_column() -> int:
	if target == null or not is_instance_valid(target):
		return CURTAIN_COLUMNS / 2
	return _column_at(target.global_position.x)


func _column_at(x: float) -> int:
	var span := _span()
	if span.y - span.x < 0.001:
		return CURTAIN_COLUMNS / 2
	var t := (x - span.x) / (span.y - span.x)
	return clampi(int(t * float(CURTAIN_COLUMNS)), 0, CURTAIN_COLUMNS - 1)


func _column_centre(column: int) -> float:
	var span := _span()
	var width := (span.y - span.x) / float(CURTAIN_COLUMNS)
	return span.x + width * (float(column) + 0.5)


# --- Patterns -------------------------------------------------------------------

## One seeker, aimed off the facing rather than straight at the player: it turns,
## so firing it directly at them makes the turn invisible and the shot reads as
## hitscan. Leaving at an angle is what shows the player it steers.
func _fire_orb() -> void:
	var orb := SPARK_ORB.new() as SparkOrb
	orb.size_nes = LASH_SIZE_NES
	orb.target = target
	var at := global_position + Vector2(
		float(facing()) * BODY_NES.x * 0.6 * tuning.world_scale,
		-LASH_HEIGHT_NES * tuning.world_scale)
	orb.launch(at, Vector2(float(facing()), -0.45).normalized(), LASH_SPEED_PF,
		LASH_DAMAGE, tuning)
	_spawn(orb)


## The floor dash. One push, then it runs until it reaches the far side.
##
## It stops at the wall rather than turning round: a dash that bounced would ask
## for a second jump on a timing the player cannot see coming, which is two
## answers to one pattern.
func _do_rail(frame: int) -> void:
	if frame == 0:
		velocity.x = float(_rail_direction) * tuning.px_s(RAIL_SPEED_PF)
		return
	var span := _span()
	var margin := BODY_NES.x * 0.5 * tuning.world_scale
	if (_rail_direction < 0 and global_position.x <= span.x + margin) \
			or (_rail_direction > 0 and global_position.x >= span.y - margin):
		velocity.x = 0.0


## Sparks fall in every column but one.
func _do_curtain(frame: int) -> void:
	if frame == 0:
		# A hop away from the open column, so Arc is not standing in the one safe
		# place it just offered the player.
		var away := -1.0 if _open_column >= CURTAIN_COLUMNS / 2 else 1.0
		velocity = Vector2(away * tuning.px_s(1.4), -tuning.px_s(CURTAIN_HOP_PF))
		return
	# The hop is a step aside, not a journey: once it lands, it stops. Without
	# this the horizontal push runs for the whole act phase, because nothing else
	# touches velocity.x while a pattern is driving.
	if is_on_floor() and frame > 4:
		velocity.x = 0.0
	if frame % CURTAIN_INTERVAL != 0:
		return
	if frame / CURTAIN_INTERVAL > CURTAIN_DROPS:
		return
	for column in CURTAIN_COLUMNS:
		if column == _open_column:
			continue
		var shot := ENEMY_SHOT.new() as EnemyShot
		shot.launch(
			Vector2(_column_centre(column),
				global_position.y - CURTAIN_HEIGHT_NES * tuning.world_scale),
			Vector2.DOWN, CURTAIN_SPEED_PF, CURTAIN_DAMAGE, tuning)
		_spawn(shot)


## Projectiles are parented to the level, not to the boss: they must outlive the
## boss's own death, and they must not travel with it during Rail.
func _spawn(shot: Node2D) -> void:
	var level := get_parent()
	if level == null:
		shot.free()
		return
	level.add_child(shot)


## The arena floor, or a span around Arc when there is no arena -- which is what
## a bare test has, and returning a zero-width span there would put every
## curtain column on the same pixel.
func _span() -> Vector2:
	if is_equal_approx(arena_left, arena_right):
		var half := 12.0 * tuning.tile_size()
		return Vector2(global_position.x - half, global_position.x + half)
	return Vector2(arena_left, arena_right)


func _centre() -> float:
	var span := _span()
	return (span.x + span.y) * 0.5
