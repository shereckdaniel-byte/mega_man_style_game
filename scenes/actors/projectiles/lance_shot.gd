## Arc Lance -- archetype 2, the homing shot.
##
## It leaves the muzzle straight and only then starts to steer, which is what
## makes it feel like a guided shot rather than a magnet: a target standing
## right on top of the player is not snapped onto instantly, and the player can
## still aim it by facing.
##
## Turning is rate-limited, not instantaneous. An unlimited turn makes the shot
## unmissable and the weapon uninteresting; a limited one can be outrun by
## something moving across it, which is the trade the archetype exists to make.
##
## Targets are found by asking the physics server for Hurtboxes on the enemy
## layer rather than by keeping a list of enemies. The spawn rule frees enemies
## off-screen (ARCHITECTURE 5.5), so any list this shot held would be a list of
## corpses within a second or two of scrolling.
class_name LanceShot
extends WeaponShot

const SIZE_NES := Vector2(12.0, 5.0)

const DEFAULT_SPEED_PF := 4.0
## Frames of straight flight before it begins to steer.
const STRAIGHT_FRAMES := 6
## Maximum turn per frame, in degrees.
const TURN_RATE_DEG := 7.0
## How far it looks for a target, in NES px. About one screen.
const SEEK_RANGE_NES := 140.0
const LIFETIME_FRAMES := 240

const BODY_COLOUR := Color(0.98, 0.86, 0.35)
const CORE_COLOUR := Color(1.0, 1.0, 0.92)

var _heading := Vector2.RIGHT
var _speed := 0.0


func shot_size() -> Vector2:
	return SIZE_NES


func _configure() -> void:
	_heading = Vector2(float(direction()), 0.0)
	_speed = tuning().px_s(number(&"speed_pf", DEFAULT_SPEED_PF))


func _advance(delta: float) -> void:
	if frames_alive() > LIFETIME_FRAMES:
		queue_free()
		return
	if frames_alive() > STRAIGHT_FRAMES:
		_steer()
	position += _heading * _speed * delta
	rotation = _heading.angle()


func _steer() -> void:
	var target := _nearest_target()
	if target == Vector2.INF:
		return
	var wanted := (target - global_position)
	if wanted.length() < 0.001:
		return
	var limit := deg_to_rad(number(&"turn_rate_deg", TURN_RATE_DEG))
	var delta_angle := clampf(_heading.angle_to(wanted.normalized()), -limit, limit)
	_heading = _heading.rotated(delta_angle).normalized()


## Nearest enemy hurtbox centre, or Vector2.INF when there is nothing in range.
## INF rather than ZERO because the world origin is a legitimate position and a
## shot that quietly homed on it would look like a physics bug.
func _nearest_target() -> Vector2:
	var world := get_world_2d()
	if world == null:
		return Vector2.INF

	var circle := CircleShape2D.new()
	circle.radius = number(&"seek_range_nes", SEEK_RANGE_NES) * tuning().world_scale
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = Layers.bit(Layers.ENEMY_HURTBOX)
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var best := Vector2.INF
	var best_distance := INF
	for result in world.direct_space_state.intersect_shape(query, 16):
		var collider: Object = result.get("collider")
		if collider == null or not (collider is Node2D):
			continue
		var at := (collider as Node2D).global_position
		var distance := global_position.distance_squared_to(at)
		if distance < best_distance:
			best_distance = distance
			best = at
	return best


func _draw() -> void:
	var scale := tuning().world_scale
	var half := SIZE_NES * scale * 0.5
	draw_rect(Rect2(-half, half * 2.0), BODY_COLOUR)
	draw_rect(Rect2(Vector2(-half.x, -half.y * 0.4), Vector2(half.x * 2.0, half.y * 0.8)),
			CORE_COLOUR)
