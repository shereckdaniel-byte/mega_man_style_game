## The floor of the world: anything that falls this far is gone.
##
## **Not a Hazard, and the difference is the whole point.** A hazard is damage —
## it goes through `Health.take()`, which honours i-frames, immunity and the
## damage table. That is right for spikes: a player who just took a hit gets the
## same mercy from a spike as from anything else.
##
## A bottomless pit is not damage. There is no floor under it and no way back,
## so a pit that could be survived is a soft lock rather than a lucky escape.
## This was not hypothetical: the first version of stage 1 used a Hazard, and a
## player who fell in while still flickering from a contact hit sailed straight
## through it and kept falling forever, gaining altitude in the negative for as
## long as the run lasted.
##
## So this calls `Health.kill()` directly, which bypasses i-frames by design.
class_name KillPlane
extends Area2D

signal killed(body: Node2D)

## Width and height in tiles.
@export var size_tiles := Vector2(1.0, 4.0)


func _ready() -> void:
	collision_layer = Layers.bit(Layers.HAZARD)
	# Watches bodies, not hurtboxes: this is about where something *is*, not
	# about hitting it, and a body cannot turn its own position off.
	collision_mask = Layers.mask([Layers.PLAYER_BODY, Layers.ENEMY_BODY])
	monitoring = true

	var tile := 72.0
	var autoload := get_node_or_null(^"/root/Tuning")
	if autoload != null:
		tile = autoload.player.tile_size()

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size_tiles * tile
	shape.shape = rect
	add_child(shape)

	body_entered.connect(_on_body_entered)


## Also checked every frame, not only on entry.
##
## A body at terminal velocity covers 31.5 px per physics frame, so a plane only
## a couple of tiles deep can in principle be stepped over between ticks. Making
## the plane deep is the real defence; re-checking overlaps is the cheap belt to
## go with that brace.
func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		_claim(body)


func _on_body_entered(body: Node2D) -> void:
	_claim(body)


func _claim(body: Node2D) -> void:
	var health := _health_of(body)
	if health == null or health.is_dead():
		return
	health.kill()
	killed.emit(body)


func _health_of(body: Node2D) -> Health:
	if body is Player:
		return (body as Player).health
	if body is Enemy:
		return (body as Enemy).health
	for child in body.get_children():
		if child is Health:
			return child as Health
	return null
