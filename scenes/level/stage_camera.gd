## The stage camera: follows the player, but never outside the active room.
##
## Replaces two pieces of scaffolding the art preview was using -- a fixed
## `offset` standing in for framing, and invisible walls standing in for room
## edges. Both were band-aids for not having rooms yet.
##
## Not a child of the player. The camera belongs to the stage, because which
## room is active is a stage-level fact and because a door transition has to
## move the camera independently of the player for 32 frames.
##
## Smoothing stays off and rotation is ignored, per ARCHITECTURE section 5.4:
## smoothing fights the scroll lock at a room edge, where the camera must stop
## dead rather than easing into the limit.
class_name StageCamera
extends Camera2D

## How far up the screen the player sits, as a fraction of the viewport height.
##
## 0.5 centres them, which buries the horizon behind the level geometry -- the
## art is composed for a camera that keeps the ground low. 0.62 puts the player
## below centre with sky above, which is also roughly where Mega Man sits.
@export_range(0.3, 0.9) var vertical_anchor := 0.62

var target: Node2D
var room: Room

var _sliding := false


func _ready() -> void:
	position_smoothing_enabled = false
	ignore_rotation = true
	make_current()


func follow(node: Node2D) -> void:
	target = node


## Switches rooms and re-applies the limits. Called by the stage on entry and by
## a door transition when it completes.
func enter_room(next: Room) -> void:
	room = next
	_apply_limits()
	_snap()


func _apply_limits() -> void:
	if room == null:
		return
	var bounds := room.camera_limits()
	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y)
	limit_right = int(bounds.end.x)
	limit_bottom = int(bounds.end.y)


func _physics_process(_delta: float) -> void:
	if _sliding:
		return  # the transition drives the camera directly
	_snap()


## Widens the limits to cover both rooms for the duration of a slide.
##
## Without this the slide cannot happen at all: Camera2D clamps to its limits
## every frame, so a camera still limited to the outgoing room simply refuses to
## move into the next one and the transition looks frozen.
func begin_slide(next: Room) -> void:
	_sliding = true
	var union := room.world_bounds().merge(next.world_bounds()) if room != null \
		else next.world_bounds()
	limit_left = int(union.position.x)
	limit_top = int(union.position.y)
	limit_right = int(union.end.x)
	limit_bottom = int(union.end.y)


## Where the camera should end up once `next` is the active room, with the
## player wherever they will be standing.
func slide_target(next: Room, player_position: Vector2) -> Vector2:
	var viewport := get_viewport_rect().size
	var above_centre := (vertical_anchor - 0.5) * viewport.y
	var wanted := Vector2(player_position.x, player_position.y - above_centre)
	var bounds := next.world_bounds()
	# Clamped the same way Camera2D would clamp it, so the slide ends exactly
	# where the camera settles rather than a few pixels off it.
	return Vector2(
		clampf(wanted.x, bounds.position.x + viewport.x * 0.5,
			maxf(bounds.position.x + viewport.x * 0.5, bounds.end.x - viewport.x * 0.5)),
		clampf(wanted.y, bounds.position.y + viewport.y * 0.5,
			maxf(bounds.position.y + viewport.y * 0.5, bounds.end.y - viewport.y * 0.5)))


func end_slide(next: Room) -> void:
	_sliding = false
	enter_room(next)


func is_sliding() -> bool:
	return _sliding


## The camera's own position, before Godot clamps it to the limits.
##
## Only the vertical anchor is applied here: horizontally the player stays
## centred, and the room's limits are what stop the view at the edges. Offsetting
## horizontally as well would mean the player is not centred in the middle of a
## wide room either, which reads as the camera lagging.
func _snap() -> void:
	if target == null or not is_instance_valid(target):
		return
	var viewport_height := float(get_viewport_rect().size.y)
	var above_centre := (vertical_anchor - 0.5) * viewport_height
	global_position = Vector2(target.global_position.x,
		target.global_position.y - above_centre)


## The world rectangle currently on screen, after the room's limits have been
## applied. This is what the spawn markers test themselves against, so it has to
## be the *clamped* view and not where the camera would like to be.
func view_rect() -> Rect2:
	var size := get_viewport_rect().size / zoom
	var centre := get_screen_center_position()
	return Rect2(centre - size * 0.5, size)
