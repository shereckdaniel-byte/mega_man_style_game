## A scroll-locked room: the camera never leaves its bounds.
##
## Mega Man does not free-scroll. The screen is locked to a room and moves only
## within it, which is what makes a room a designable unit -- you know exactly
## what the player can see from anywhere inside it, so an off-screen enemy is
## off-screen by design rather than by accident.
##
## Bounds are in **tiles**, because that is how level geometry is authored and
## because it keeps the numbers readable: a room 27 tiles wide is exactly one
## screen at the project's scale, and a 54-wide room is exactly two.
class_name Room
extends Node2D

## Room rectangle in tile coordinates. The default is one screen at 1920x1080
## and world_scale 4.5 -- 26.7 x 15 tiles, rounded down to something that tiles.
@export var bounds_tiles := Rect2i(0, 0, 26, 15)

## Rooms this one leads to, for the door transitions M4 adds next. Kept here
## rather than on the Door so a room can be validated on its own.
@export var exits: Array[NodePath] = []


func tile_size() -> float:
	var autoload := get_node_or_null(^"/root/Tuning")
	return autoload.player.tile_size() if autoload != null else 72.0


## The room in world coordinates.
func world_bounds() -> Rect2:
	var tile := tile_size()
	return Rect2(Vector2(bounds_tiles.position) * tile, Vector2(bounds_tiles.size) * tile)


func contains_point(point: Vector2) -> bool:
	return world_bounds().has_point(point)


## Camera limits for this room, as the four ints Camera2D wants.
##
## A room narrower or shorter than the viewport would give limits the camera
## cannot satisfy; Godot resolves that by pinning to the left/top edge, which
## looks like the room is stuck. Rooms are expected to be at least one screen in
## each axis, and `tests/test_rooms.gd` asserts it rather than leaving it to be
## discovered in a stage.
func camera_limits() -> Rect2:
	return world_bounds()
