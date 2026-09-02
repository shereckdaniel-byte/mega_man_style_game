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

const FLOOR_NORMAL := Vector2.UP
## Measured from the AutoSprite export's opaque bounding box. The character does
## not fill its 256 px cell -- it is 177 px tall and its feet sit on row 223 --
## so neither the scale nor the ground alignment can be derived from the cell.
## Re-measure if the art is regenerated at a different size; the test
## `test_sprite_feet_sit_on_the_origin` will catch it if these drift.
const SOURCE_ART_HEIGHT := 177.0
const SOURCE_ART_BASELINE := 223.0

@export var tuning: PlayerTuning

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var headroom: RayCast2D = $HeadroomCast
@onready var state_machine: StateMachine = $StateMachine

## +1 right, -1 left. Never 0, so the character keeps facing where it last was.
var facing: int = 1
## Ladders currently overlapping. Climb needs to know one is there.
var ladders: Array[Area2D] = []

var _shoot_frames_left := 0
var _jump_buffer_left := 0
var _coyote_left := 0
var _stand_shape: RectangleShape2D
var _slide_shape: RectangleShape2D


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


func _physics_process(delta: float) -> void:
	_tick_timers()
	state_machine.physics_update(delta)
	move_and_slide()
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


func note_shot_fired() -> void:
	_shoot_frames_left = tuning.shoot_pose_frames


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


## Where the drawn feet land relative to the node origin, in world px. Zero
## means the sprite stands exactly on the base of the collision box; positive
## means it sinks into the floor.
##
## The sprite is centred, so the cell's centre sits at `offset`; the baseline row
## is `BASELINE - cell_height / 2` below that centre.
func sprite_feet_offset() -> float:
	var half_cell := _cell_size().y * 0.5
	var baseline_from_centre := SOURCE_ART_BASELINE - half_cell
	return (sprite.offset.y + baseline_from_centre) * tuning.sprite_scale(SOURCE_ART_HEIGHT)


func _update_sprite() -> void:
	sprite.flip_h = facing < 0
	var wanted := _sprite_animation()
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(wanted):
		if sprite.animation != wanted:
			sprite.play(wanted)
	elif sprite.animation != &"idle" and sprite.sprite_frames != null \
			and sprite.sprite_frames.has_animation(&"idle"):
		sprite.play(&"idle")


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
