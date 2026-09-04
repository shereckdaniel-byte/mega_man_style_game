## Hopper: sits still, then jumps on a fixed arc.
##
## The archetype that punishes standing still under it. Where a walker is dodged
## by timing your approach, a hopper is dodged by timing *its* landing -- so the
## pause on the ground is the readable part and is deliberately longer than the
## hop.
##
## The arc is authored as apex height and distance in tiles rather than as a
## velocity, because that is what level design needs to know: whether it can
## clear the gap it is standing next to.
class_name Hopper
extends Enemy

## Frames waiting on the ground between hops.
@export var rest_frames: int = 48
## Apex of the hop, in tiles.
@export var hop_height_tiles := 2.0
## Horizontal distance covered, in tiles. 0 hops straight up.
@export var hop_distance_tiles := 1.5
## +1 right, -1 left.
@export var facing: int = -1
## Turns around on landing against a wall, so a hopper in a corridor bounces
## between the ends instead of grinding into one.
@export var turns_at_walls: bool = true

var _rested := 0


func setup() -> void:
	var size := body_size()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position.y = -size.y * 0.5
	add_child(shape)


func behave(_delta: float) -> void:
	# Before the mid-hop early return: a hopper that only faced while grounded
	# would flip direction in the air and turn round on landing.
	face(float(facing))
	if not is_on_floor():
		return  # mid-hop: the arc is ballistic, nothing to steer

	velocity.x = 0.0
	if turns_at_walls and is_on_wall():
		facing = -facing
	_rested += 1
	if _rested >= rest_frames:
		_rested = 0
		_hop()


func _hop() -> void:
	# From the same integration the player's jump uses: v = sqrt(2 g h), with g
	# in px/s^2 and h in px. Deriving it means a hopper's arc follows world_scale
	# and the gravity constant instead of drifting away from them.
	var gravity := tuning.px_s2(tuning.gravity_pf)
	var height := hop_height_tiles * tuning.tile_size()
	velocity.y = -sqrt(2.0 * gravity * height)
	# Time to apex and back, so the horizontal speed lands it the authored
	# distance away.
	var airborne := 2.0 * absf(velocity.y) / gravity
	if airborne > 0.0:
		velocity.x = float(facing) * hop_distance_tiles * tuning.tile_size() / airborne


func body_size() -> Vector2:
	var tile := tuning.tile_size()
	return Vector2(tile * 0.8, tile * 0.9)
