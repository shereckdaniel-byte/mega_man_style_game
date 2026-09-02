## The player.
##
## Movement constants come from PlayerTuning and are authored in NES units; this
## script never hard-codes a speed. States live as child nodes under
## StateMachine and own transitions between themselves; the player owns the
## things that are true in every state -- input snapshot, gravity, the sprite,
## the hitbox swap, and the shoot timer.
class_name Player
extends CharacterBody2D

signal state_changed(from: StringName, to: StringName)
## Health reached zero. The Dead state runs the sequence; this is for the HUD,
## the stage and anything else that wants to know.
signal died()
signal respawned()
## Death sequence finished and the last life is gone. The stage decides what a
## game over means; the player only reports it.
signal game_over()
signal shot_fired(shot: BusterShot)

const FLOOR_NORMAL := Vector2.UP
## Measured from the AutoSprite export's opaque bounding box. The character does
## not fill its 256 px cell -- it is 177 px tall and its feet sit on row 223 --
## so neither the scale nor the ground alignment can be derived from the cell.
## Re-measure if the art is regenerated at a different size; the test
## `test_sprite_feet_sit_on_the_origin` will catch it if these drift.
const SOURCE_ART_HEIGHT := 177.0
const SOURCE_ART_BASELINE := 223.0

const BUSTER_SHOT := preload("res://scenes/actors/projectiles/buster_shot.gd")

## Where the arm cannon is, per state, in NES pixels from the actor's origin --
## which is at its feet, so y is negative. x is forward, and gets mirrored by
## `facing`. The character is 24 NES px tall and holds the cannon at chest
## height; sliding drops it almost to the floor.
##
## A state with no entry here uses DEFAULT_MUZZLE. Firing a pellet out of the
## character's ankle is the visible symptom of a missing row.
const MUZZLE := {
	&"Idle": Vector2(13.0, -16.0),
	&"Walk": Vector2(13.0, -16.0),
	&"Jump": Vector2(13.0, -18.0),
	&"Fall": Vector2(13.0, -18.0),
	&"Climb": Vector2(10.0, -17.0),
}
const DEFAULT_MUZZLE := Vector2(13.0, -16.0)

@export var tuning: PlayerTuning

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var headroom: RayCast2D = $HeadroomCast
@onready var state_machine: StateMachine = $StateMachine
@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox

## +1 right, -1 left. Never 0, so the character keeps facing where it last was.
var facing: int = 1
## Ladders currently overlapping. Climb needs to know one is there.
var ladders: Array[Area2D] = []
## Where this player entered the stage. Used when no checkpoint has been reached
## yet, so a stage that never places one still respawns somewhere sensible.
var entry_position := Vector2.ZERO

var _shoot_frames_left := 0
var _jump_buffer_left := 0
var _coyote_left := 0
var _stand_shape: RectangleShape2D
var _slide_shape: RectangleShape2D
## Live pellets, for the 3-on-screen cap. Freed shots are filtered out on read
## rather than tracked with signals -- queue_free is deferred, so a shot that
## died this frame is still a valid reference until the frame ends.
var _shots: Array[BusterShot] = []
## Frozen during a door transition and the teleport-in: physics still runs so
## the player keeps standing on the floor, but input and state changes do not.
var _frozen := false


func _ready() -> void:
	if tuning == null:
		# Autoload when there is one; a fresh default under a bare test tree.
		var autoload := get_node_or_null(^"/root/Tuning")
		tuning = autoload.player if autoload != null else PlayerTuning.new()
	_build_shapes()
	_scale_sprite()
	state_machine.setup(self)
	state_machine.state_changed.connect(
		func(from: StringName, to: StringName) -> void: state_changed.emit(from, to))
	floor_snap_length = tuning.px(2.0)
	entry_position = global_position
	_setup_damage()


func _physics_process(delta: float) -> void:
	if _frozen:
		# Gravity still applies, so a player frozen in mid-air lands rather than
		# hanging there, but nothing else about them moves.
		velocity.x = 0.0
		apply_gravity(delta)
		move_and_slide()
		_update_sprite()
		return
	_tick_timers()
	health.tick()
	state_machine.physics_update(delta)
	move_and_slide()
	_try_shoot()
	_update_sprite()


# --- Shared movement helpers, used by the states ------------------------------

## Applies gravity for one frame and clamps to terminal velocity.
func apply_gravity(delta: float) -> void:
	velocity.y = minf(
		velocity.y + tuning.px_s2(tuning.gravity_pf) * delta,
		tuning.px_s(tuning.terminal_velocity_pf))


## -1, 0 or +1. Uses raw actions rather than get_axis so that holding both
## directions reads as neither, which is what the original did.
func input_direction() -> int:
	var right := 1 if Input.is_action_pressed(&"move_right") else 0
	var left := 1 if Input.is_action_pressed(&"move_left") else 0
	return right - left


## Ground movement is instant-on, instant-off: no acceleration, no friction.
func apply_walk() -> void:
	var direction := input_direction()
	if direction != 0:
		facing = direction
	velocity.x = float(direction) * tuning.px_s(tuning.walk_speed_pf)


func start_jump() -> void:
	velocity.y = -tuning.px_s(tuning.jump_velocity_pf)
	_jump_buffer_left = 0
	_coyote_left = 0


## The hard cut is what gives the original its short hop; do not scale by a
## factor here.
func cut_jump() -> void:
	if velocity.y < 0.0:
		velocity.y = 0.0


## True when jump was pressed this frame or within the buffer window.
func jump_requested() -> bool:
	return _jump_buffer_left > 0


func consume_jump_request() -> void:
	_jump_buffer_left = 0


## Slide is down + jump, as in Mega Man 3 -- not its own action.
func slide_requested() -> bool:
	return jump_requested() and Input.is_action_pressed(&"move_down")


func can_jump_from_ground() -> bool:
	return is_on_floor() or _coyote_left > 0


func on_ladder() -> bool:
	return not ladders.is_empty()


## Whether there is room to stand up out of a slide. Without this check the
## player pops into the ceiling at the end of every tunnel.
func has_headroom() -> bool:
	headroom.force_raycast_update()
	return not headroom.is_colliding()


func use_slide_hitbox(sliding: bool) -> void:
	var shape := _slide_shape if sliding else _stand_shape
	collision.shape = shape
	# Shapes are centred, and the actor's origin is at its feet.
	collision.position.y = -shape.size.y * 0.5


## Freezes input and state. Used by door transitions, which move the player
## themselves for 24 px and must not fight the controller while doing it.
func set_frozen(value: bool) -> void:
	_frozen = value
	if value:
		velocity = Vector2.ZERO


func is_frozen() -> bool:
	return _frozen


func note_shot_fired() -> void:
	_shoot_frames_left = tuning.shoot_pose_frames


# --- Buster -------------------------------------------------------------------

## Live pellets on screen, after dropping any freed since last frame.
func live_shots() -> int:
	# Rebuilt by hand rather than with Array.filter(): filter() returns an
	# untyped Array, which will not assign back into an Array[BusterShot].
	var alive: Array[BusterShot] = []
	for shot in _shots:
		if is_instance_valid(shot):
			alive.append(shot)
	_shots = alive
	return _shots.size()


func can_shoot() -> bool:
	var state := state_machine.current
	if state == null or not state.can_shoot:
		return false
	if health.is_dead():
		return false
	return live_shots() < tuning.max_buster_shots


## Arm-cannon position for the current state, in world coordinates.
func muzzle_position() -> Vector2:
	var offset: Vector2 = MUZZLE.get(state_machine.current_name(), DEFAULT_MUZZLE)
	return global_position + Vector2(offset.x * float(facing), offset.y) * tuning.world_scale


## Fires one pellet. Returns it, or null when the shot was refused.
func fire() -> BusterShot:
	if not can_shoot():
		return null
	# Autoloads are reached by path, not by identifier, for the same reason
	# Tuning is above: an autoload name only resolves once the project's
	# autoloads are registered, which is not true for a script run as a
	# `--script` entry point, and not true under a bare test tree either.
	var weapons := get_node_or_null(^"/root/WeaponManager")
	var weapon: StringName = weapons.current if weapons != null else &"buster"
	if weapons != null and not weapons.consume(weapon):
		return null

	var shot := BUSTER_SHOT.new() as BusterShot
	shot.launch(muzzle_position(), facing, tuning, weapon)
	# Parented to the level, not to the player: a pellet does not travel with
	# the shooter, and a shot fired on the frame the player dies must outlive it.
	var level := get_parent()
	if level == null:
		shot.free()
		return null
	level.add_child(shot)
	_shots.append(shot)
	note_shot_fired()
	shot_fired.emit(shot)
	return shot


# --- Damage -------------------------------------------------------------------

## Health reached zero, however it got there. The Dead state owns the sequence.
func _on_health_died(_info: DamageInfo) -> void:
	died.emit()
	if state_machine.current_name() != &"Dead":
		state_machine.transition_to(&"Dead")


## Applied by the Hurtbox when a hit lands. Knockback is a state, because being
## unable to steer out of it is the whole point -- see states/hurt.gd.
##
## Death is deliberately not handled here: _on_health_died does it, so a kill
## that never went through a hurtbox still stops the player.
func on_damaged(info: DamageInfo, taken: int) -> void:
	if taken <= 0 or health.is_dead():
		return
	if info.has_flag(DamageInfo.NO_KNOCKBACK):
		return
	state_machine.transition_to(&"Hurt", {"source_position": info.source_position})


## Called by the Dead state once the burst has played out. Spends a life and
## either returns the player to the checkpoint or reports a game over.
func finish_death() -> void:
	var state := get_node_or_null(^"/root/GameState")
	if state == null:
		respawn_at(entry_position)
		return
	if state.consume_life():
		respawn_at(state.respawn_position(entry_position))
	else:
		game_over.emit()


## Full health, back at the checkpoint, with a moment of grace so the thing that
## killed you cannot kill you again on the first frame.
func respawn_at(position: Vector2) -> void:
	global_position = position
	velocity = Vector2.ZERO
	facing = 1
	health.refill()
	health.grant_invulnerability(tuning.iframes)
	use_slide_hitbox(false)
	sprite.visible = true
	state_machine.transition_to(&"Idle")
	respawned.emit()


func is_shooting() -> bool:
	return _shoot_frames_left > 0


func register_ladder(area: Area2D, entered: bool) -> void:
	if entered:
		if not ladders.has(area):
			ladders.append(area)
	else:
		ladders.erase(area)


# --- Internals ----------------------------------------------------------------

func _tick_timers() -> void:
	if _shoot_frames_left > 0:
		_shoot_frames_left -= 1
	if Input.is_action_just_pressed(&"jump"):
		_jump_buffer_left = tuning.jump_buffer_frames
	elif _jump_buffer_left > 0:
		_jump_buffer_left -= 1
	if is_on_floor():
		_coyote_left = tuning.coyote_frames
	elif _coyote_left > 0:
		_coyote_left -= 1


## Wires the damage components. Layers come from Layers rather than literal
## shifts -- see scripts/core/collision_layers.gd for why.
func _setup_damage() -> void:
	health.max_hp = Health.BAR_TICKS
	health.invulnerable_frames = tuning.iframes
	health.current = health.max_hp

	hurtbox.collision_layer = Layers.bit(Layers.PLAYER_HURTBOX)
	# A hurtbox never looks; hitboxes find it. Masking anything here would only
	# cost overlap checks that nothing reads.
	hurtbox.collision_mask = 0
	var box := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = tuning.hitbox_size()
	box.shape = rect
	box.position.y = -rect.size.y * 0.5
	hurtbox.add_child(box)

	hurtbox.took_damage.connect(on_damaged)
	# Death is driven by Health, not by the hurtbox. A kill can arrive without
	# any hit at all -- a KillPlane calls Health.kill() directly, bypassing
	# i-frames on purpose -- and routing death through the hurtbox meant those
	# kills set the bar to zero and left the player walking around on it.
	health.died.connect(_on_health_died)


func _try_shoot() -> void:
	if Input.is_action_just_pressed(&"shoot"):
		fire()


func _build_shapes() -> void:
	_stand_shape = RectangleShape2D.new()
	_stand_shape.size = tuning.hitbox_size()
	_slide_shape = RectangleShape2D.new()
	_slide_shape.size = tuning.slide_hitbox_size()
	use_slide_hitbox(false)
	# Cast from the top of the slide hitbox up to where the head would be.
	headroom.position = Vector2(0.0, -tuning.slide_hitbox_size().y)
	headroom.target_position = Vector2(
		0.0, -(tuning.hitbox_size().y - tuning.slide_hitbox_size().y))


## The art is ~177 px tall and the character is 72 px in world units, so the
## sprite is minified. That is why the project filters linearly.
func _scale_sprite() -> void:
	var factor := tuning.sprite_scale(SOURCE_ART_HEIGHT)
	sprite.scale = Vector2(factor, factor)
	sprite.centered = true
	# Put the art's baseline -- not the cell's bottom -- on the node origin,
	# which is where the collision box's feet are. Getting this from the cell
	# instead sinks the character into the floor by the cell's bottom padding.
	sprite.offset = Vector2(0.0, -(SOURCE_ART_BASELINE - _cell_size().y * 0.5))


## Frame size of the current animation, read from the atlas region.
func _cell_size() -> Vector2:
	var frames := sprite.sprite_frames
	if frames == null:
		return Vector2(256.0, 256.0)
	for name in frames.get_animation_names():
		if frames.get_frame_count(name) > 0:
			var tex := frames.get_frame_texture(name, 0)
			if tex != null:
				return tex.get_size()
	return Vector2(256.0, 256.0)


## Checks the sprite offset arithmetic: that the cell padding compensation lines
## SOURCE_ART_BASELINE up with the node origin. Zero means correct.
##
## The sprite is centred, so the cell's centre sits at `offset`; the baseline row
## is `BASELINE - cell_height / 2` below that centre.
##
## This does NOT measure the art. Both terms derive from SOURCE_ART_BASELINE and
## cancel, so it returns zero whatever the pixels look like -- which is why it
## missed the animations whose feet sat up to 15 px off their cell's baseline.
## `tests/test_sprite_frames.gd` reads the actual alpha; the importer normalises
## every animation onto AutoSpriteImporter.BASELINE_ROW so this stays honest.
func sprite_feet_offset() -> float:
	var half_cell := _cell_size().y * 0.5
	var baseline_from_centre := SOURCE_ART_BASELINE - half_cell
	return (sprite.offset.y + baseline_from_centre) * tuning.sprite_scale(SOURCE_ART_HEIGHT)


func _update_sprite() -> void:
	sprite.flip_h = facing < 0
	_update_flicker()
	var wanted := _sprite_animation()
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(wanted):
		if sprite.animation != wanted:
			sprite.play(wanted)
	elif sprite.animation != &"idle" and sprite.sprite_frames != null \
			and sprite.sprite_frames.has_animation(&"idle"):
		sprite.play(&"idle")


## Blinks the sprite while invulnerable, two frames on and two frames off. The
## flicker is the only feedback that i-frames are running, so it is deliberately
## coarse enough to see rather than a smooth fade.
##
## Driven off the countdown rather than a separate timer, so it cannot outlive
## the invulnerability and leave the player invisible.
func _update_flicker() -> void:
	var frames_left := health.invulnerable_frames_left()
	if frames_left <= 0:
		sprite.visible = true
		return
	var period := maxi(1, tuning.flicker_period_frames)
	sprite.visible = (frames_left / period) % 2 == 0


## Shooting is not a state -- it is a suffix. That is what keeps 9 states from
## becoming 18. Falls back to the base animation when the `_shoot` variant does
## not exist yet, which is currently true for walk, jump and climb.
func _sprite_animation() -> StringName:
	var base: StringName = state_machine.current.anim_name if state_machine.current != null \
		else &"idle"
	if not is_shooting():
		return base
	var shooting := StringName("%s_shoot" % base)
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(shooting):
		return shooting
	return base
