## A block of roof Quarry brings down, and **the only boss attack in the game
## that leaves the player something.**
##
## It falls, it hurts on the way, and where it lands it stays as a one-way
## platform for the rest of the pattern. So Cave-In clutters the arena and
## simultaneously builds the height the player needs to answer the Bore, which
## comes up through the floor and cannot be jumped from the floor.
##
## That is the trade the pattern is for: the debris is in your way and it is the
## only way up, and deciding which of those it is this time is the fight.
class_name Rubble
extends Area2D

const PLATFORM := preload("res://scenes/level/one_way_platform.gd")

const SIZE_NES := Vector2(20.0, 12.0)
const FALL_PF := 0.25
const TOUCH_DAMAGE := 3
## How long the landed platform stands. It has to outlive the pattern that made
## it -- a step that vanished before the next Bore would be a promise broken --
## and it must not outlive the fight, or the arena silently becomes a staircase.
const PLATFORM_FRAMES := 340

const ROCK := Color(0.46, 0.40, 0.35)
const ROCK_DARK := Color(0.26, 0.22, 0.20)
const DUST := Color(0.66, 0.60, 0.54)

var _tuning: PlayerTuning
var _spawn_position := Vector2.ZERO
var _floor_y := 0.0
var _velocity := Vector2.ZERO
var _landed := false
var _hitbox: Hitbox


func drop(from: Vector2, floor_y: float, tuning: PlayerTuning) -> void:
	_spawn_position = from
	_floor_y = floor_y
	_tuning = tuning


func _ready() -> void:
	if _tuning == null:
		var autoload := get_node_or_null(^"/root/Tuning")
		_tuning = autoload.player if autoload != null else PlayerTuning.new()
	global_position = _spawn_position

	# The falling block is a hitbox; the landed one is a platform. Two nodes
	# rather than one that changes role, because a thing that is both at once is
	# a platform that hurts you for standing on it.
	_hitbox = Hitbox.new()
	_hitbox.name = "Falling"
	_hitbox.amount = TOUCH_DAMAGE
	_hitbox.weapon_id = &"rubble"
	_hitbox.collision_layer = Layers.bit(Layers.ENEMY_ATTACK)
	_hitbox.collision_mask = Layers.bit(Layers.PLAYER_HURTBOX)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE_NES * _tuning.world_scale
	shape.shape = rect
	_hitbox.add_child(shape)
	add_child(_hitbox)
	queue_redraw()


func is_landed() -> bool:
	return _landed


func _physics_process(delta: float) -> void:
	if _landed:
		return
	_velocity.y += _tuning.px_s2(FALL_PF) * delta
	global_position += _velocity * delta
	if global_position.y >= _floor_y:
		global_position.y = _floor_y
		_land()
	queue_redraw()


## Becomes a step.
func _land() -> void:
	_landed = true
	var parent := get_parent()
	if parent != null:
		var step := PLATFORM.new() as OneWayPlatform
		step.size_tiles = Vector2(SIZE_NES.x / PlayerTuning.NES_TILE, 0.5)
		step.position = global_position
		parent.add_child(step)
		var timer := get_tree().create_timer(float(PLATFORM_FRAMES) / 60.0)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(step):
				step.queue_free())
	queue_free()


func _draw() -> void:
	var size := SIZE_NES * _tuning.world_scale
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, ROCK_DARK)
	draw_rect(rect.grow(-size.y * 0.14), ROCK)
	# Dust trailing above it, so a falling block reads as falling.
	for i in 3:
		var x := -size.x * 0.3 + size.x * 0.3 * float(i)
		draw_rect(Rect2(Vector2(x, -size.y * (0.7 + 0.3 * float(i))),
			Vector2(size.x * 0.16, size.y * 0.3)), Color(DUST, 0.35))
