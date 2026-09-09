## Bulwark: the seawall itself, and the thing that has been running it.
##
## The last fight in the game and the only one with two forms. Both are the same
## node -- `Boss` refills the bar, rebuilds the patterns and holds for a beat
## (see `Boss.forms`), so the second form fills the bar the first one emptied and
## nothing has to be wired specially for it.
##
## ### The two forms are opposites, and that is the whole fight
##
## **Form 0, the shell.** It is a wall: it does not move, it does not jump, and
## it never comes to you. Everything it does travels along the floor or falls
## from the ceiling, so the player's answer is *positioning* -- read the tell,
## be somewhere else. It is slow and it telegraphs enormously, and it hits for
## more than anything else in the game.
##
## **Form 1, the core.** The shell breaks and what is inside does not touch the
## ground once. It hovers, it aims at where you are, and it closes. The player's
## answer is *timing* -- there is nowhere to stand that is safe, so the fight
## becomes about when to jump rather than where to be.
##
## Eight stages of Robot Masters are one or the other of those. The final boss is
## both, in order, and the transition is the point at which everything the player
## worked out in the first half stops applying.
##
## ### The shell is weak to the bore, and the core is weak to nothing
##
## `resources/damage_tables/bulwark_shell.tres` gives Quarry Bore 4 -- the
## piercing drill against the armoured wall, which is the one weakness in the
## game that a player could guess from the fiction rather than from a chart.
##
## The core's table lists nothing at all. **The last blow of the game is always
## the buster**, whatever the player has left, which is worth more than one more
## weakness: it means nobody arrives at the end of the fortress dry and stuck,
## and it means the weapon the player has had since the first frame is the one
## that finishes it.
##
## ### It has no weapon and no bit
##
## `boss_index = -1` and `weapon_id = &""`. There is no ninth master and nothing
## after this, so `Keep` takes the `stage_cleared` and turns it into an ending.
class_name Bulwark
extends Boss

const ENEMY_SHOT := preload("res://scenes/actors/projectiles/enemy_shot.gd")
const CREST_WAVE := preload("res://scenes/actors/projectiles/crest_wave.gd")
const RUBBLE := preload("res://scenes/actors/projectiles/rubble.gd")
const SHELL_TABLE := preload("res://resources/damage_tables/bulwark_shell.tres")
const CORE_TABLE := preload("res://resources/damage_tables/bulwark_core.tres")
## TODO(art): Bulwark has none of its own. Stage 3's boss is the closest thing
## in the project to a wall with arms, and greyboxing against it is the same
## call every stage since 4 has made.
const SPRITE_FRAMES := preload("res://resources/sprite_frames/rust.tres")

## Not one of the eight. See `Boss.boss_index`.
const INDEX := -1

const FORM_SHELL := 0
const FORM_CORE := 1
const FORM_COUNT := 2

## The shell is wide and squat; the core is small and quick. The body follows,
## because a hitbox that did not would be the fight lying about what it is.
const SHELL_NES := Vector2(28.0, 30.0)
const CORE_NES := Vector2(16.0, 18.0)

## The shell's tint. The core comes out of it pale and lit from inside.
const SHELL_TINT := Color(0.62, 0.66, 0.72)
const CORE_TINT := Color(1.0, 0.92, 0.78)

# --- The shell ---------------------------------------------------------------

## The floor wave. Slower than Tide's crest and wider, because the answer is a
## jump and a jump wants to be readable rather than reflexive.
const SURGE_SPEED_PF := 2.0
const SURGE_DAMAGE := 4
const SURGE_RIDE_NES := 5.0
## Two waves, the second far enough behind the first to be a separate decision.
const SURGE_SECOND_FRAME := 34

## The ceiling collapse: rubble down the arena in a sweep the player walks out
## of, rather than a wall of it they cannot.
const FALL_PIECES := 5
const FALL_SPACING := 13
const FALL_DAMAGE := 3
const FALL_HEIGHT_NES := 96.0

## The spread. Fired low and wide from a boss that cannot chase, so its job is
## to take away the standing room rather than to hit.
const SPREAD_SHOTS := 5
const SPREAD_SPEED_PF := 2.6
const SPREAD_DAMAGE := 3
const SPREAD_ARC := 0.55

# --- The core ----------------------------------------------------------------

## Where the core sits when it is not diving, in NES px above the floor.
const CORE_LANE_NES := 40.0
const CORE_CLIMB_PF := 2.2

## The aimed volley: three shots at where the player *is*, not where they were.
const VOLLEY_SHOTS := 3
const VOLLEY_SPACING := 12
const VOLLEY_SPEED_PF := 3.6
const VOLLEY_DAMAGE := 3

## The dive. It commits to a line at the tell and does not steer, which is what
## makes it dodgeable at all.
const DIVE_SPEED_PF := 4.4
const DIVE_DAMAGE := 4

## The sweep: the core crosses the arena at head height, firing down.
const SWEEP_SPEED_PF := 2.8
const SWEEP_DROP_SPACING := 10
const SWEEP_DROP_SPEED_PF := 3.0
const SWEEP_DROP_DAMAGE := 2

var _dive_heading := Vector2.DOWN
var _sweep_direction := 1


func _ready() -> void:
	boss_index = INDEX
	weapon_id = &""
	display_name = "Bulwark"
	if sprite_frames == null:
		sprite_frames = SPRITE_FRAMES
	damage_table = SHELL_TABLE
	super()
	if sprite != null:
		sprite.modulate = SHELL_TINT


func forms() -> int:
	return FORM_COUNT


func body_size() -> Vector2:
	var nes := CORE_NES if form() == FORM_CORE else SHELL_NES
	return nes * tuning.world_scale


## The shell breaks. Everything that is a property of *which* boss this now is
## changes here, and nothing that is a property of the fight.
func enter_form(index: int) -> void:
	if index != FORM_CORE:
		return
	damage_table = CORE_TABLE
	health.damage_table = CORE_TABLE
	if sprite != null:
		sprite.modulate = CORE_TINT
	# The body shrinks with the boss. A hitbox left at the shell's size would be
	# a small fast target that is still hit like a wall.
	_resize_body()
	# The core does not touch the ground again.
	affected_by_gravity = false
	# Running into it hurts more than running into the wall did, which is the
	# one place a boss that closes the distance should be worse than one that
	# cannot. Set here rather than per-pattern so it cannot be left switched on.
	contact_damage = DIVE_DAMAGE
	if contact != null:
		contact.amount = DIVE_DAMAGE


func build_patterns() -> Array[BossPattern]:
	return _core_patterns() if form() == FORM_CORE else _shell_patterns()


## Slow, enormous tells, and everything travels along the floor or falls onto
## it. The answer is where you stand.
func _shell_patterns() -> Array[BossPattern]:
	var out: Array[BossPattern] = []
	out.append(BossPattern.new(&"surge", 44, SURGE_SECOND_FRAME + 20, 40, 1.2)
		.with_anims(&"attack_special", &"attack", &"idle"))
	out.append(BossPattern.new(&"collapse", 46, FALL_PIECES * FALL_SPACING + 20, 44, 1.0)
		.with_anims(&"attack_special", &"attack", &"idle"))
	out.append(BossPattern.new(&"spread", 38, 24, 38, 0.9)
		.with_anims(&"attack", &"attack", &"idle"))
	return out


## Fast, airborne, aimed. The answer is when you jump.
func _core_patterns() -> Array[BossPattern]:
	var out: Array[BossPattern] = []
	out.append(BossPattern.new(&"volley", 26, VOLLEY_SHOTS * VOLLEY_SPACING + 6, 30, 1.2)
		.with_anims(&"attack", &"attack", &"idle"))
	out.append(BossPattern.new(&"dive", 30, 40, 34, 1.0)
		.with_anims(&"jump", &"jump", &"idle"))
	out.append(BossPattern.new(&"sweep", 28, 62, 32, 0.9)
		.with_anims(&"walk", &"attack", &"idle"))
	return out


# --- Movement ------------------------------------------------------------------

func fight_move(_delta: float) -> void:
	if form() == FORM_SHELL:
		# It is a wall. It does not move, ever, and that is the read.
		velocity.x = 0.0
		hold_inside_arena()
		return
	_core_move()
	hold_inside_arena()


## The core holds a lane except while diving or sweeping, which move it
## themselves.
func _core_move() -> void:
	var pattern := current_pattern()
	var id: StringName = pattern.id if pattern != null else &""
	if id == &"dive" and pattern_step() == 1:
		return
	if id == &"sweep" and pattern_step() == 1:
		return
	velocity.x = 0.0
	_hold_lane()


func _hold_lane() -> void:
	var wanted := arena_floor_y() - CORE_LANE_NES * tuning.world_scale
	var step := tuning.px_s(CORE_CLIMB_PF)
	if absf(global_position.y - wanted) <= step * get_physics_process_delta_time():
		global_position.y = wanted
		velocity.y = 0.0
		return
	velocity.y = -step if global_position.y > wanted else step


## Where the core is holding, in world y. Public because it is the fight's one
## piece of readable state and a test that only watched projectiles would not be
## watching it.
func lane_y() -> float:
	return arena_floor_y() - CORE_LANE_NES * tuning.world_scale


# --- Patterns --------------------------------------------------------------------

func tell(pattern: BossPattern, frame: int) -> void:
	velocity.x = 0.0
	if pattern.id == &"dive" and frame == 0:
		_dive_heading = _toward_target()
	elif pattern.id == &"sweep" and frame == 0:
		_sweep_direction = -1 if global_position.x > arena_centre() else 1


func act(pattern: BossPattern, frame: int) -> void:
	match pattern.id:
		&"surge":
			if frame == 0 or frame == SURGE_SECOND_FRAME:
				_fire_surge()
		&"collapse":
			if frame % FALL_SPACING == 0 and frame / FALL_SPACING < FALL_PIECES:
				_drop_rubble(frame / FALL_SPACING)
		&"spread":
			if frame == 0:
				_fire_spread()
		&"volley":
			if frame % VOLLEY_SPACING == 0 and frame / VOLLEY_SPACING < VOLLEY_SHOTS:
				_fire_aimed()
		&"dive":
			_do_dive(frame)
		&"sweep":
			_do_sweep(frame)


func recover(_pattern: BossPattern, _frame: int) -> void:
	velocity.x = 0.0


## Two waves along the floor, out of both sides, because a wall does not have a
## front.
func _fire_surge() -> void:
	for side in [-1.0, 1.0]:
		var shot := CREST_WAVE.new() as CrestWave
		var at := global_position + Vector2(
			side * SHELL_NES.x * 0.5 * tuning.world_scale,
			-SURGE_RIDE_NES * tuning.world_scale)
		shot.launch(at, Vector2(side, 0.0), SURGE_SPEED_PF, SURGE_DAMAGE, tuning)
		_spawn(shot)


## Rubble down the arena, one piece at a time, so it reads as a sweep the player
## walks out of rather than a wall they cannot.
func _drop_rubble(index: int) -> void:
	var span := arena_span()
	var t := (float(index) + 0.5) / float(FALL_PIECES)
	var x := lerpf(span.x, span.y, t)
	var piece := RUBBLE.new() as Rubble
	_spawn(piece)
	# Quarry's own rubble, reused rather than reimplemented: same fiction, and
	# the pieces become one-way platforms where they land, which gives the shell
	# fight somewhere to stand that it built itself.
	piece.drop(Vector2(x, arena_floor_y() - FALL_HEIGHT_NES * tuning.world_scale),
		arena_floor_y(), tuning)


func _fire_spread() -> void:
	for i in SPREAD_SHOTS:
		var t := (float(i) / float(maxi(SPREAD_SHOTS - 1, 1))) * 2.0 - 1.0
		var shot := ENEMY_SHOT.new() as EnemyShot
		shot.launch(global_position - Vector2(0.0, SHELL_NES.y * 0.5 * tuning.world_scale),
			Vector2(t * SPREAD_ARC, -0.35).normalized(),
			SPREAD_SPEED_PF, SPREAD_DAMAGE, tuning)
		_spawn(shot)


## At the player, read fresh on the frame it leaves. The shell never aims; the
## core always does, and that difference is most of what the second form is.
func _fire_aimed() -> void:
	var shot := ENEMY_SHOT.new() as EnemyShot
	shot.launch(global_position, _toward_target(), VOLLEY_SPEED_PF,
		VOLLEY_DAMAGE, tuning)
	_spawn(shot)


## A committed line, chosen at the tell and not steered. A dive that tracked
## would be undodgeable, which is a different thing from hard. `DIVE_DAMAGE` is
## the core's contact damage, set once on the form change.
func _do_dive(frame: int) -> void:
	if frame == 0:
		velocity = _dive_heading * tuning.px_s(DIVE_SPEED_PF)
		return
	if global_position.y >= arena_floor_y() - body_size().y * 0.5:
		velocity = Vector2.ZERO


func _do_sweep(frame: int) -> void:
	if frame == 0:
		velocity = Vector2(float(_sweep_direction) * tuning.px_s(SWEEP_SPEED_PF), 0.0)
		global_position.y = lane_y()
		return
	velocity.y = 0.0
	if frame % SWEEP_DROP_SPACING == 0:
		var shot := ENEMY_SHOT.new() as EnemyShot
		shot.launch(global_position, Vector2.DOWN, SWEEP_DROP_SPEED_PF,
			SWEEP_DROP_DAMAGE, tuning)
		_spawn(shot)


func _toward_target() -> Vector2:
	if target == null or not is_instance_valid(target):
		return Vector2(float(facing()), 0.0)
	var to: Vector2 = target.global_position - global_position
	return to.normalized() if to.length() > 0.001 else Vector2.DOWN


## Rebuilds the body collider after the form change. `Boss.setup` builds it once
## from `body_size()`, and the core is a different size.
func _resize_body() -> void:
	for child in get_children():
		if child is CollisionShape2D and child.name == "Body":
			var rect := (child as CollisionShape2D).shape as RectangleShape2D
			if rect != null:
				rect.size = body_size()
				(child as CollisionShape2D).position.y = -rect.size.y * 0.5
			return


## Projectiles are parented to the level: they outlive the boss's own death, and
## they must not travel with it during a dive.
func _spawn(shot: Node2D) -> void:
	var level := get_parent()
	if level == null:
		shot.free()
		return
	level.add_child(shot)
