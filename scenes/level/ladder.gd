## A climbable ladder.
##
## Registers itself with any player that overlaps, so the Climb state can ask
## "am I on a ladder" without searching the scene.
##
## **It draws itself, which it did not until a playtest.** Every ladder in the
## game was an invisible Area2D over a hole in the deck: the player arrived at
## the descent, saw a gap with nothing in it, and read it as a pit they were
## meant to jump and could not. The stage was finishable and looked unfinishable,
## which is the same thing from where the player is standing. M1 had already
## fixed this class of fault once -- `collision_mask = 0` made ladders
## undetectable, and the comment then said they "are sensed by the player, not
## sensing". A ladder nobody can see is the visual half of the same mistake.
class_name Ladder
extends Area2D

## Height in tiles. The collision shape is built from this so a ladder is placed
## in tile units rather than pixels.
@export var height_tiles: int = 4:
	set(value):
		height_tiles = maxi(1, value)
		if is_inside_tree():
			_rebuild()

## Weathered steel against the boardwalk's warm deck. Bright enough to read as
## an object in front of the backdrop rather than as part of it -- the under-deck
## band is very dark and a subtle ladder there is an invisible one again.
const RAIL := Color(0.78, 0.80, 0.86)
const RUNG := Color(0.62, 0.65, 0.72)

var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = 1 << 2   # layer 3: ladder
	# The ladder is what watches: body_entered only fires for layers in this
	# mask, so leaving it at 0 silently made every ladder undetectable and Climb
	# unreachable. Watch player_body (layer 4) and nothing else.
	collision_mask = 1 << 3    # layer 4: player_body
	monitoring = false
	monitorable = true
	_rebuild()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	monitoring = true
	queue_redraw()


func _rebuild() -> void:
	var tile := _tile_size()
	if _shape == null:
		_shape = CollisionShape2D.new()
		add_child(_shape)
	var rect := RectangleShape2D.new()
	# Narrower than a tile so you cannot mount it from a neighbouring column.
	rect.size = Vector2(tile * 0.5, tile * float(height_tiles))
	_shape.shape = rect
	# Origin at the ladder's foot.
	_shape.position = Vector2(0.0, -rect.size.y * 0.5)


## Rails and rungs, drawn from the foot upward.
##
## Wider than the collision box on purpose. The box is half a tile so the ladder
## cannot be mounted from the next column along; the *art* is a full tile, because
## a ladder drawn at its own hitbox width reads as a rope and the player has to
## be able to see it from across the room.
func _draw() -> void:
	var tile := _tile_size()
	var height := tile * float(height_tiles)
	var width := tile * 0.8
	var rail := maxf(tile * 0.09, 2.0)

	# Two rails, from the foot (origin) up.
	draw_rect(Rect2(Vector2(-width * 0.5, -height), Vector2(rail, height)), RAIL)
	draw_rect(Rect2(Vector2(width * 0.5 - rail, -height), Vector2(rail, height)), RAIL)

	# A rung every half tile, which is close enough to read as a ladder at a
	# glance and sparse enough not to become a solid bar at this scale.
	var step := tile * 0.5
	var thickness := maxf(tile * 0.07, 2.0)
	var y := -step * 0.5
	while y > -height:
		draw_rect(Rect2(Vector2(-width * 0.5, y - thickness * 0.5),
			Vector2(width, thickness)), RUNG)
		y -= step


func _tile_size() -> float:
	var autoload := get_node_or_null(^"/root/Tuning")
	return autoload.player.tile_size() if autoload != null else 48.0


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		(body as Player).register_ladder(self, true)


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		(body as Player).register_ladder(self, false)
