## Tide Crawler -- archetype 6, the terrain-crawling shot.
##
## It drops to whatever surface is under it and then follows that surface: down
## the far side of a ledge, up the face of a wall, round the underside of a
## platform. The point of the archetype is reaching things a straight shot
## cannot -- an enemy sitting behind a raised block, or a crawler clinging low
## on a piling -- so it has to hug geometry rather than merely fall onto it.
##
## Surface following is two vectors and two probes. `_along` is the way it
## travels, `_up` points away from the surface, and each frame asks two
## questions: is there a wall ahead (turn towards `_up`), and is there still
## floor beneath (if not, turn away from it). Both turns are the same 90-degree
## rotation of the pair, in opposite directions, which is why a concave corner
## and a convex one need no separate cases.
class_name CrawlerShot
extends WeaponShot

const SIZE_NES := Vector2(10.0, 8.0)

## Travel speed in NES px/frame. Slower than the buster: it is a shot you place,
## and it has to be readable as it crawls.
const DEFAULT_SPEED_PF := 2.6
## Fall speed while it has not found a surface yet, in NES px/frame.
const DROP_SPEED_PF := 5.0
## How far ahead of itself it looks for a wall, in NES px.
const FEELER_NES := 5.0
## How far below itself it looks for floor, in NES px. Longer than the forward
## feeler so it commits to a surface rather than skimming it.
const GROUND_REACH_NES := 8.0
## Frames before it gives up. A crawler that finds a closed loop of geometry
## would otherwise circle it forever, off-camera, until the level unloads.
const LIFETIME_FRAMES := 300

const BODY_COLOUR := Color(0.34, 0.82, 0.90)
const CORE_COLOUR := Color(0.90, 1.0, 1.0)

## Travel direction along the surface.
var _along := Vector2.RIGHT
## Away from the surface it is following. Zero until it has found one.
var _up := Vector2.ZERO
var _attached := false


func shot_size() -> Vector2:
	return SIZE_NES


func _configure() -> void:
	_along = Vector2(float(direction()), 0.0)


func _advance(delta: float) -> void:
	if frames_alive() > LIFETIME_FRAMES:
		queue_free()
		return
	if _attached:
		_crawl(delta)
	else:
		_seek_surface(delta)
	queue_redraw()


## Before it has a surface: drift forward and fall, until something is under it.
func _seek_surface(delta: float) -> void:
	var speed := number(&"speed_pf", DEFAULT_SPEED_PF)
	position += _along * tuning().px_s(speed) * delta
	position += Vector2.DOWN * tuning().px_s(DROP_SPEED_PF) * delta

	var hit := _probe(Vector2.DOWN, GROUND_REACH_NES)
	if hit.is_empty():
		return
	_attach(hit)


## Following a surface. Wall first: a shot that stepped forward into a wall and
## only then checked the floor would embed itself in the corner.
func _crawl(delta: float) -> void:
	var step := tuning().px_s(number(&"speed_pf", DEFAULT_SPEED_PF)) * delta

	if not _probe(_along, FEELER_NES).is_empty():
		# Concave corner: the wall ahead becomes the new floor.
		var was := _along
		_along = _up
		_up = -was
		return

	position += _along * step

	var ground := _probe(-_up, GROUND_REACH_NES)
	if ground.is_empty():
		# Convex corner: the floor ran out, so turn down around the edge.
		var was := _along
		_along = -_up
		_up = was
		return
	_snap_to(ground)


func _attach(hit: Dictionary) -> void:
	_attached = true
	_up = (hit.get("normal", Vector2.UP) as Vector2).normalized()
	if _up.length() < 0.5:
		_up = Vector2.UP
	# Keep travelling the way it was fired, projected onto the new surface.
	var travel := Vector2(float(direction()), 0.0)
	_along = (travel - _up * travel.dot(_up)).normalized()
	if _along.length() < 0.5:
		_along = _up.orthogonal()
	_snap_to(hit)


func _snap_to(hit: Dictionary) -> void:
	var point := hit.get("position", global_position) as Vector2
	global_position = point + _up * SIZE_NES.y * 0.5 * tuning().world_scale


## Ray from the shot's centre. Returns {} when nothing is in reach.
func _probe(heading: Vector2, distance_nes: float) -> Dictionary:
	var world := get_world_2d()
	if world == null:
		return {}
	var reach := heading.normalized() * distance_nes * tuning().world_scale
	var query := PhysicsRayQueryParameters2D.create(global_position,
			global_position + reach)
	query.collision_mask = Layers.mask([Layers.WORLD, Layers.ONE_WAY])
	query.collide_with_areas = false
	return world.direct_space_state.intersect_ray(query)


## Terrain does not stop it -- crawling along terrain is the whole weapon.
func _on_body_entered(_body: Node2D) -> void:
	pass


func _draw() -> void:
	var scale := tuning().world_scale
	var half := SIZE_NES * scale * 0.5
	draw_rect(Rect2(-half, half * 2.0), BODY_COLOUR)
	draw_rect(Rect2(-half * 0.5, half), CORE_COLOUR)
