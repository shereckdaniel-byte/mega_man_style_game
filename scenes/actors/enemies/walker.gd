## Walker: patrols a surface and turns around at a wall or a ledge.
##
## The simplest archetype and the one that carries the most level-design weight,
## because "walks until the floor runs out" is what makes a plank run readable
## at a glance.
##
## Turning at a *ledge* rather than only at a wall is what separates this from a
## thing that walks off into the pit. It is done with a downward cast placed
## ahead of the body: if there is no floor under the next step, turn now.
class_name Walker
extends Enemy

## Patrol speed in NES px/frame, so it scales with everything else. The player
## walks at 1.375; a walker slower than that can always be outrun, which is the
## point of the archetype.
@export var speed_pf := 0.5
## +1 right, -1 left. Set by the spawn marker.
@export var facing: int = -1
## Turn around at a ledge as well as at a wall. Off for an enemy that is meant
## to walk off an edge and fall.
@export var turns_at_ledges: bool = true

var _floor_probe: RayCast2D
var _wall_probe: RayCast2D


func setup() -> void:
	var size := body_size()

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position.y = -size.y * 0.5
	add_child(shape)

	# Cast down from just beyond the leading edge: this is the "is there still
	# floor ahead" question, and asking it from the centre would turn a frame too
	# late and drop a foot over the edge.
	_floor_probe = RayCast2D.new()
	_floor_probe.collision_mask = Layers.mask([Layers.WORLD, Layers.PLATFORM])
	_floor_probe.target_position = Vector2(0.0, size.y * 0.6)
	add_child(_floor_probe)

	_wall_probe = RayCast2D.new()
	_wall_probe.collision_mask = Layers.mask([Layers.WORLD])
	_wall_probe.position = Vector2(0.0, -size.y * 0.5)
	add_child(_wall_probe)

	_aim_probes()


func behave(_delta: float) -> void:
	velocity.x = float(facing) * tuning.px_s(speed_pf)
	face(float(facing))

	if not is_on_floor():
		return  # in the air: no ledge to read, and nothing to turn on

	_floor_probe.force_raycast_update()
	_wall_probe.force_raycast_update()
	var at_ledge := turns_at_ledges and not _floor_probe.is_colliding()
	var at_wall := _wall_probe.is_colliding() or is_on_wall()
	if at_ledge or at_wall:
		turn()


func turn() -> void:
	facing = -facing
	_aim_probes()
	velocity.x = float(facing) * tuning.px_s(speed_pf)


func body_size() -> Vector2:
	# Two thirds of a tile, so small fry read as small.
	#
	# The second half of this comment used to claim a full-tile walker "would not
	# fit under the boardwalk's raised sections". There is nothing to fit under:
	# stage 1's raised sections are solid blocks standing on the deck, not
	# overhangs. The constraint was imaginary, and the number it justified put
	# the Dockrat's hurtbox at 10.6 NES px -- entirely below the buster's line,
	# which made the most common enemy in the game unkillable.
	#
	# The height stays, because it is right for how the enemy reads. What
	# changed is that the hurtbox no longer follows it down: see
	# Enemy.MIN_HURTBOX_NES.
	var tile := tuning.tile_size()
	return Vector2(tile * 0.66, tile * 0.66)


func _aim_probes() -> void:
	var size := body_size()
	var ahead := float(facing) * size.x * 0.6
	_floor_probe.position = Vector2(ahead, -size.y * 0.1)
	_wall_probe.target_position = Vector2(ahead, 0.0)
