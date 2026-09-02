## A respawn point.
##
## Records its position on GameState when the player crosses it, so the
## checkpoint survives the player node being reset -- and so it is already in
## the place the save system reads (ARCHITECTURE section 5.7).
class_name Checkpoint
extends Area2D

signal reached()

## Where the player comes back. Defaults to the node's own position; set this
## when the marker sits somewhere you would not want to stand, such as inside a
## door frame.
@export var respawn_offset := Vector2.ZERO
## Width and height of the trigger, in tiles.
@export var size_tiles := Vector2(1.0, 4.0)

var _triggered := false


func _ready() -> void:
	collision_layer = Layers.bit(Layers.TRIGGER)
	# The checkpoint is what watches, so it masks the player's body.
	collision_mask = Layers.bit(Layers.PLAYER_BODY)
	monitoring = true

	var tile := 72.0
	var autoload := get_node_or_null(^"/root/Tuning")
	if autoload != null:
		tile = autoload.player.tile_size()

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size_tiles * tile
	shape.shape = rect
	# Addressed at its foot, like everything else placed in tile coordinates.
	shape.position.y = -rect.size.y * 0.5
	add_child(shape)

	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _triggered or not (body is Player):
		return
	_triggered = true
	# By path rather than by identifier -- see the note in player.gd's fire().
	var state := get_node_or_null(^"/root/GameState")
	if state != null:
		state.set_checkpoint(global_position + respawn_offset)
	reached.emit()
