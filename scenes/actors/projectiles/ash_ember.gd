## An ember from Cinder's Ashfall: thrown up, it falls, and where it lands it
## **stays for a while as a patch of burning deck**.
##
## The pattern's whole idea is that the danger is not the thing in the air. An
## ember in flight is easy to walk under; what it does is take a piece of floor
## away for `BURN_FRAMES`, and the fan of them takes several pieces at once. The
## player is reading a floor that is being deleted under them rather than dodging
## a projectile.
##
## It arms on landing rather than on spawn, so nothing can be hit by an ember
## that is still on its way up -- the same rule `FocusSpot` and `Downdraft` are
## built on.
class_name AshEmber
extends Hitbox

## Travel while airborne, in NES px/frame^2 down. The player's own gravity, so
## an arc reads as the same physics the player lives under.
const FALL_PF := 0.25
## How long the patch burns once it lands.
const BURN_FRAMES := 96
## Frames of the burn spent fading, so it says it is going before it goes.
const FADE_FRAMES := 26
## Frames between hits on a player standing in it.
const REPEAT_FRAMES := 26

## Size of the patch on the deck, in NES px. Low: it is a place you may not
## stand, not a wall -- a jump clears it and that is deliberate.
const PATCH_NES := Vector2(14.0, 9.0)
## Size of the ember while it is still in the air.
const EMBER_NES := Vector2(6.0, 6.0)

const CORE := Color(1.0, 0.95, 0.76)
const FLAME := Color(1.0, 0.55, 0.18)
const CHAR := Color(0.24, 0.16, 0.14)

var _tuning: PlayerTuning
var _spawn_position := Vector2.ZERO
var _velocity := Vector2.ZERO
var _floor_y := 0.0
var _damage := 3
var _landed := false
var _burn := 0
var _shape: CollisionShape2D


## `floor_y` is the deck the ember settles onto. Passed in rather than found by
## raycast: the arena floor is a fact the boss already has, and an ember that
## looked for its own floor would land on the boss's head.
func throw(from: Vector2, velocity: Vector2, floor_y: float, damage: int,
		tuning: PlayerTuning) -> void:
	_spawn_position = from
	_velocity = velocity
	_floor_y = floor_y
	_damage = damage
	_tuning = tuning


func _ready() -> void:
	super()
	if _tuning == null:
		var autoload := get_node_or_null(^"/root/Tuning")
		_tuning = autoload.player if autoload != null else PlayerTuning.new()
	global_position = _spawn_position

	amount = _damage
	weapon_id = &"ash"
	one_shot = false
	repeat_delay_frames = REPEAT_FRAMES

	collision_layer = Layers.bit(Layers.ENEMY_ATTACK)
	collision_mask = Layers.bit(Layers.PLAYER_HURTBOX)
	# Off until it lands: an ember in flight is scenery.
	monitoring = false

	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = PATCH_NES * _tuning.world_scale
	_shape.shape = rect
	# Sitting on the floor line rather than centred on it, so the height a jump
	# has to clear is the height the constant says.
	_shape.position = Vector2(0.0, -rect.size.y * 0.5)
	add_child(_shape)
	queue_redraw()


func is_landed() -> bool:
	return _landed


func burn_frames() -> int:
	return _burn


func _physics_process(delta: float) -> void:
	if not _landed:
		_velocity.y += _tuning.px_s2(FALL_PF) * delta
		position += _velocity * delta
		if global_position.y >= _floor_y:
			global_position.y = _floor_y
			_landed = true
			monitoring = true
		queue_redraw()
		return

	_burn += 1
	tick()
	if _burn >= BURN_FRAMES:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var scale := _tuning.world_scale
	if not _landed:
		var radius := EMBER_NES.x * scale * 0.5
		draw_circle(Vector2.ZERO, radius, FLAME)
		draw_circle(Vector2.ZERO, radius * 0.5, CORE)
		return

	var size := PATCH_NES * scale
	# Fading over the last stretch, so the patch says it is going out.
	var left := float(BURN_FRAMES - _burn)
	var alpha := clampf(left / float(FADE_FRAMES), 0.0, 1.0)
	# The scorch stays solid while the flame fades -- the mark is what tells the
	# player where the fire was, which is the half of it worth reading.
	draw_rect(Rect2(Vector2(-size.x * 0.5, -size.y * 0.22),
		Vector2(size.x, size.y * 0.22)), Color(CHAR, 0.7))
	# Flames as a row of tongues rather than a rectangle, so it reads as fire.
	var tongues := 5
	for i in tongues:
		var t := (float(i) + 0.5) / float(tongues)
		var x := -size.x * 0.5 + size.x * t
		var lick := size.y * (0.55 + 0.45 * sin(float(_burn) * 0.22 + float(i)))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - size.x * 0.12, 0.0),
			Vector2(x + size.x * 0.12, 0.0),
			Vector2(x, -lick),
		]), Color(FLAME, 0.8 * alpha))
	draw_rect(Rect2(Vector2(-size.x * 0.42, -size.y * 0.3),
		Vector2(size.x * 0.84, size.y * 0.3)), Color(CORE, 0.45 * alpha))
