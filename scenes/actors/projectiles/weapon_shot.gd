## What every player projectile has in common.
##
## A shot *is* a Hitbox rather than containing one: it is nothing but a moving
## point of damage, and a child node would only add a transform to keep in step.
##
## Subclasses override three things and nothing else -- `shot_size()` for the
## rectangle, `_configure()` for anything the base cannot guess, and
## `_advance(delta)` for the movement that makes the weapon what it is. Damage,
## the weapon id, the collision layers and the off-screen cleanup are settled
## here, so a new weapon cannot get them subtly wrong.
##
## Masking `enemy_hurtbox` and `world` is the convention from ARCHITECTURE
## section 4: player shots stop at walls, enemy shots do not.
class_name WeaponShot
extends Hitbox

## How far past the view edge a shot travels before giving up, in NES px.
const DESPAWN_MARGIN_NES := 32.0

## The weapon that fired this. Null is legal and means the buster's defaults,
## which keeps a shot constructible in a test without authoring a resource.
var data: WeaponData

var _tuning: PlayerTuning
## Applied in `_ready`: a Node2D outside the tree has no global transform, so
## setting global_position at launch time would be silently dropped.
var _spawn_position := Vector2.ZERO
var _direction := 1
var _weapon_id: StringName = &"buster"
var _frames_alive := 0


## Called by whoever fires it, before it is added to the tree.
##
## The weapon is passed in rather than read from the WeaponManager autoload, so
## a shot carries what actually fired it and this script has no dependency on a
## singleton. Autoload identifiers also only resolve once the project's
## autoloads are registered, which makes them a poor thing for a widely
## preloaded script to reference.
func launch(from: Vector2, direction: int, tuning: PlayerTuning,
		p_data: WeaponData = null) -> void:
	_tuning = tuning
	_spawn_position = from
	_direction = signi(direction) if direction != 0 else 1
	data = p_data
	if data != null and data.id != &"":
		_weapon_id = data.id


func _ready() -> void:
	super()
	if _tuning == null:
		var autoload := get_node_or_null(^"/root/Tuning")
		_tuning = autoload.player if autoload != null else PlayerTuning.new()

	global_position = _spawn_position

	amount = data.damage if data != null else 1
	weapon_id = _weapon_id
	flags = data.flags if data != null else DamageInfo.NONE
	one_shot = true

	collision_layer = Layers.bit(Layers.PLAYER_ATTACK)
	collision_mask = Layers.mask([Layers.ENEMY_HURTBOX, Layers.WORLD])
	monitoring = true

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = shot_size() * _tuning.world_scale
	shape.shape = rect
	add_child(shape)

	body_entered.connect(_on_body_entered)
	hit.connect(_on_hit)
	_configure()
	queue_redraw()


func _physics_process(delta: float) -> void:
	_frames_alive += 1
	_advance(delta)
	if is_off_screen():
		queue_free()


func direction() -> int:
	return _direction


func tuning() -> PlayerTuning:
	return _tuning


func frames_alive() -> int:
	return _frames_alive


## Number from the weapon resource, or the fallback when there is no resource.
## Weapon-specific constants belong in the `.tres` next to the rest of the
## weapon, not scattered through the projectile scripts.
func number(key: StringName, fallback: float) -> float:
	return data.get_number(key, fallback) if data != null else fallback


# --- Overridable ---------------------------------------------------------------

## Hitbox size in NES pixels, scaled up like every other world metric.
func shot_size() -> Vector2:
	return Vector2(8.0, 6.0)


## Anything the base cannot settle. Runs after the layers and the shape are set,
## so it can widen a mask or change `one_shot` without being overwritten.
func _configure() -> void:
	pass


## One physics frame of movement.
func _advance(_delta: float) -> void:
	pass


## A shot is spent on whatever it hits, whether or not that target was in
## i-frames at the time. Otherwise a shot fired into an invulnerable enemy would
## sail through, and the on-screen cap would quietly mean something different
## depending on the target's state. Override for a piercing weapon.
func _on_hit(_hurtbox: Hurtbox, _taken: int) -> void:
	queue_free()


func _on_body_entered(_body: Node2D) -> void:
	queue_free()


func is_off_screen() -> bool:
	var viewport := get_viewport()
	if viewport == null:
		return false
	var camera := viewport.get_camera_2d()
	if camera == null:
		return false
	var margin := DESPAWN_MARGIN_NES * _tuning.world_scale
	var view := viewport.get_visible_rect().size / camera.zoom
	var centre := camera.get_screen_center_position()
	return absf(global_position.x - centre.x) > view.x * 0.5 + margin \
		or absf(global_position.y - centre.y) > view.y * 0.5 + margin
