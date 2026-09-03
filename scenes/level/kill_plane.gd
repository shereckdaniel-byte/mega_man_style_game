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

var _tile := 72.0


func _ready() -> void:
	collision_layer = Layers.bit(Layers.HAZARD)
	# Watches bodies, not hurtboxes: this is about where something *is*, not
	# about hitting it, and a body cannot turn its own position off.
	collision_mask = Layers.mask([Layers.PLAYER_BODY, Layers.ENEMY_BODY])
	monitoring = true

	var autoload := get_node_or_null(^"/root/Tuning")
	if autoload != null:
		_tile = autoload.player.tile_size()

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size_tiles * _tile
	shape.shape = rect
	add_child(shape)

	body_entered.connect(_on_body_entered)


## Also checked every frame, not only on entry.
##
## A body at terminal velocity covers 31.5 px per physics frame, so a plane only
## a couple of tiles deep can in principle be stepped over between ticks. Making
## the plane deep is the real defence; re-checking overlaps is the cheap belt to
## go with that brace.
##
## **The belt has to check where the body actually is.** `get_overlapping_bodies()`
## reports the physics server's answer from the *previous* step, and a respawn
## moves the player out of here in a single assignment -- so for one frame the
## list still holds someone standing at a checkpoint a hundred rows above the
## water. A pit is the one thing in the game that ignores i-frames, by design, so
## the respawn's grace period cannot stop it: every fall cost two lives, the
## second one at the checkpoint, immediately, with nothing on screen to explain
## it. `body_entered` is left alone -- that one is exact, and it is the entry
## this is a belt for.
func _physics_process(_delta: float) -> void:
	var volume := _volume()
	for body in get_overlapping_bodies():
		if volume.has_point(body.global_position):
			_claim(body)


## The kill volume in world space.
##
## Testing the body's origin rather than its shape is safe only because the plane
## is deep: a falling body is inside for a dozen frames at terminal velocity, so
## a frame spent with the feet in and the origin still out loses nothing. On a
## shallow plane this would be the wrong test.
func _volume() -> Rect2:
	var size := size_tiles * _tile
	return Rect2(global_position - size * 0.5, size)


func _on_body_entered(body: Node2D) -> void:
	_claim(body)


func _claim(body: Node2D) -> void:
	var health := _health_of(body)
	if health == null or health.is_dead():
		return
	# Named, because an unnamed kill is a `buster` one. `Health.kill()` with no
	# info builds a default DamageInfo, whose weapon_id is the buster -- so a
	# playtest ledger reading the cause off the killing blow reported every fall
	# into the sea as the player shooting themselves. Nothing in the game
	# branched on it, which is why it survived; a report does.
	health.kill(DamageInfo.new(9999, global_position, &"pit"))
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
