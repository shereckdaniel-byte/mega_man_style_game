## Wall-crawler: clings to a surface and follows it around corners.
##
## The archetype that makes a shaft dangerous, because it arrives from a
## direction the player is not watching. Its whole behaviour is "keep the
## surface on my right hand", which is what produces the corner-following for
## free rather than as a special case per corner.
##
## Gravity is off: it is stuck to the wall, and a crawler that fell off the
## moment it crossed a seam would be a walker with extra steps.
class_name WallCrawler
extends Enemy

## Which way it walks along the surface: +1 clockwise, -1 anticlockwise.
@export var spin: int = 1
@export var speed_pf := 0.4

## Surface normal it is currently stuck to. Starts pointing up, i.e. clinging to
## a floor; a marker on a wall sets this to LEFT or RIGHT.
@export var surface_normal := Vector2.UP

var _probe: RayCast2D


func setup() -> void:
	affected_by_gravity = false
	var size := body_size()

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	add_child(shape)

	_probe = RayCast2D.new()
	_probe.collision_mask = Layers.mask([Layers.WORLD, Layers.PLATFORM])
	add_child(_probe)


func behave(delta: float) -> void:
	# `spin` is the travel direction along the sprite's own x, and the node is
	# already rotated onto the surface, so a local flip is the right one.
	face(float(spin))
	var along := _along()
	var step := along * tuning.px_s(speed_pf) * delta

	# Look for surface just past where this step lands. Losing it means an
	# outside corner: rotate towards the missing surface and take the corner.
	_probe.position = along * body_size().x * 0.5
	_probe.target_position = -surface_normal * body_size().y
	_probe.force_raycast_update()
	if not _probe.is_colliding():
		surface_normal = surface_normal.rotated(float(-spin) * PI * 0.5)
		return

	# And an inside corner is the opposite: something in the way along the path.
	_probe.position = Vector2.ZERO
	_probe.target_position = along * body_size().x
	_probe.force_raycast_update()
	if _probe.is_colliding():
		surface_normal = surface_normal.rotated(float(spin) * PI * 0.5)
		return

	velocity = Vector2.ZERO
	global_position += step
	rotation = surface_normal.angle() + PI * 0.5


## Travel direction: along the surface, perpendicular to its normal.
func _along() -> Vector2:
	return surface_normal.rotated(float(spin) * PI * 0.5)


func body_size() -> Vector2:
	var tile := tuning.tile_size()
	return Vector2(tile * 0.7, tile * 0.7)
