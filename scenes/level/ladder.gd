## A climbable ladder.
##
## Registers itself with any player that overlaps, so the Climb state can ask
## "am I on a ladder" without searching the scene.
class_name Ladder
extends Area2D

## Height in tiles. The collision shape is built from this so a ladder is placed
## in tile units rather than pixels.
@export var height_tiles: int = 4:
	set(value):
		height_tiles = maxi(1, value)
		if is_inside_tree():
			_rebuild()

var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = 1 << 2   # layer 3: ladder
	collision_mask = 0         # ladders are sensed by the player, not sensing
	monitoring = false
	monitorable = true
	_rebuild()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	monitoring = true


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


func _tile_size() -> float:
	var autoload := get_node_or_null(^"/root/Tuning")
	return autoload.player.tile_size() if autoload != null else 48.0


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		(body as Player).register_ladder(self, true)


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		(body as Player).register_ladder(self, false)
