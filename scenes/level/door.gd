## A screen transition between two rooms.
##
## Not a door you open — a threshold you cross. In Mega Man the player walks
## into one, control is taken away, the camera slides one screen, the player is
## walked a short distance through the doorway, and control comes back. The
## whole thing is on rails, which is what makes it read as a transition rather
## than as the camera catching up.
##
## The door belongs to the room the player is leaving and names the room they
## arrive in, so a corridor is a chain of rooms each pointing at the next.
##
## **Vertical doors work the same way.** Set `direction` to UP or DOWN and the
## trigger turns on its side: wide and shallow, spanning the width the player
## can cross rather than the height they can jump. The camera needed nothing --
## `StageCamera.begin_slide` merges room bounds on both axes and `slide_target`
## clamps both, so the slide was axis-agnostic from the day it was written.
##
## A vertical door is normally paired with a ladder that **spans the boundary**.
## The transition freezes the player and moves them through by hand; if the
## ladder stops at the room edge they arrive at the far side holding nothing and
## drop straight back down through the door they just came up.
class_name Door
extends Area2D

## The room on the far side.
@export var to_room: NodePath
## Which way the player travels through it. Only the sign of x is used for a
## horizontal door; a vertical door uses y.
@export var direction := Vector2.RIGHT
## Trigger size in tiles, for a horizontal door: tall and thin, so it cannot be
## jumped over. A vertical door uses `vertical_size_tiles` instead.
@export var size_tiles := Vector2(1.0, 6.0)

## Trigger size for a vertical door: wide and shallow, so it cannot be stepped
## around. Kept as its own export rather than asking authors to transpose the
## other one, because a door that is the wrong way round still *works* -- it
## just fires somewhere unexpected, which is a bad thing to debug.
@export var vertical_size_tiles := Vector2(6.0, 1.0)

var _used := false


func _ready() -> void:
	collision_layer = Layers.bit(Layers.TRIGGER)
	# The door watches; it masks the player's body and nothing else.
	collision_mask = Layers.bit(Layers.PLAYER_BODY)
	monitoring = true

	var tile := 72.0
	var autoload := get_node_or_null(^"/root/Tuning")
	if autoload != null:
		tile = autoload.player.tile_size()

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	if is_vertical():
		rect.size = vertical_size_tiles * tile
		# Centred on the node: a vertical door marks a line the player crosses,
		# not a wall they stand at the foot of.
		shape.position = Vector2.ZERO
	else:
		rect.size = size_tiles * tile
		# Placed in tile coordinates at its foot, like everything else.
		shape.position.y = -rect.size.y * 0.5
	shape.shape = rect
	add_child(shape)

	body_entered.connect(_on_body_entered)


## Which way the player travels through this door.
func is_vertical() -> bool:
	return absf(direction.y) > absf(direction.x)


## Cleared once the transition finishes, so walking back through works.
func release() -> void:
	_used = false


func target_room(from: Node) -> Room:
	if to_room.is_empty():
		return null
	return from.get_node_or_null(to_room) as Room


func _on_body_entered(body: Node2D) -> void:
	if _used or not (body is Player):
		return
	var stage := _find_stage()
	if stage == null:
		return
	_used = true
	stage.begin_transition(self)


func _find_stage() -> Stage:
	var node := get_parent()
	while node != null:
		if node is Stage:
			return node as Stage
		node = node.get_parent()
	return null
