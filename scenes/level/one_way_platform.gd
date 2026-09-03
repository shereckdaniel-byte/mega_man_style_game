## A platform you can jump up through and then stand on.
##
## **No drop-through, deliberately.** The usual binding for dropping off one of
## these is Down+Jump, and in this game that is the *slide* -- the MM3 signature
## move (PLAN section 2). Shadowing it to gain a convenience would be trading
## the defining verb of the movement set for a shortcut, and there is already a
## way down from every one of these: walk off the edge.
##
## Built from a shape with `one_way_collision`, so the physics server does the
## work and the player needs no special case. It sits on layer 2, which the
## player's body already masks -- the layer was reserved from the start and
## nothing had ever been put on it.
class_name OneWayPlatform
extends StaticBody2D

## Size in tiles. Platforms are placed in tile units like everything else.
@export var size_tiles := Vector2(3.0, 0.5):
	set(value):
		size_tiles = Vector2(maxf(value.x, 0.25), maxf(value.y, 0.125))
		if is_inside_tree():
			_rebuild()

## How far above the surface a body is still allowed to be pushed up, in px.
## Godot's default lets a fast faller punch through; a margin the height of the
## platform itself is enough without letting a body snap up from below it.
@export var one_way_margin := 12.0

## Drawn to read as a cut piece of deck, like MovingPlatform.
##
## It was a flat tan bar, and a playtester pointed at one and said it "does not
## look good, should look like the floor below or very close". It is the only
## thing in the room the player stands on that does not come out of the tileset,
## so it is the only thing that reads as unfinished.
const FACE := Color(0.60, 0.55, 0.52)
const PLANK := Color(0.52, 0.47, 0.45)
const LIP := Color(0.88, 0.85, 0.72)
const EDGE := Color(0.24, 0.22, 0.24)
const UNDER := Color(0.30, 0.27, 0.28)

var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = Layers.bit(Layers.ONE_WAY)
	# A platform watches nothing; bodies collide with it, not the other way.
	collision_mask = 0
	_rebuild()


func tile_size() -> float:
	var autoload := get_node_or_null(^"/root/Tuning")
	return autoload.player.tile_size() if autoload != null else 72.0


## World size of the platform.
func world_size() -> Vector2:
	return size_tiles * tile_size()


func _rebuild() -> void:
	if _shape == null:
		_shape = CollisionShape2D.new()
		_shape.name = "Shape"
		add_child(_shape)
	var rect := RectangleShape2D.new()
	rect.size = world_size()
	_shape.shape = rect
	# The node's origin is the platform's top-left corner in tile terms, so the
	# centred shape is offset by half. Matches how rooms and doors are placed.
	_shape.position = Vector2(rect.size.x * 0.5, rect.size.y * 0.5)
	_shape.one_way_collision = true
	_shape.one_way_collision_margin = one_way_margin
	queue_redraw()


func _draw() -> void:
	var size := world_size()
	var tile := tile_size()
	# A bright lip along the top edge and a *soft* underside: the visual has to
	# say "solid from above, open from below" before the player finds out by
	# jumping, so the top is the hard, bright edge and the bottom fades.
	var lip := maxf(size.y * 0.34, 4.0)

	draw_rect(Rect2(Vector2.ZERO, size), FACE)
	draw_rect(Rect2(Vector2(0.0, size.y - lip * 0.6), Vector2(size.x, lip * 0.6)),
		Color(UNDER.r, UNDER.g, UNDER.b, 0.55))

	var plank := tile * 0.5
	var x := plank
	while x < size.x - 1.0:
		draw_rect(Rect2(Vector2(x - maxf(tile * 0.02, 1.0), lip),
			Vector2(maxf(tile * 0.04, 2.0), size.y - lip)), PLANK)
		x += plank

	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, lip)), LIP)
	# Top edge only, so the silhouette from below stays open.
	draw_line(Vector2.ZERO, Vector2(size.x, 0.0), EDGE, maxf(size.y * 0.12, 2.0))
