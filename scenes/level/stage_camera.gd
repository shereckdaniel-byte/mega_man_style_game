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
	_snap()


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
