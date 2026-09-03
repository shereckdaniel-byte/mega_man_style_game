## Spikes, crushers and the sensor under a bottomless pit.
##
## Instant death, not damage: in the original a spike kills a full-health player
## outright, and that is what makes spike corridors read as precision sections
## rather than as damage races. Implemented as a very large DamageInfo so it
## goes through the same Health path as everything else -- i-frames included,
## which is why a hazard cannot kill you during a respawn's grace period.
class_name Hazard
extends Hitbox

## Width and height of the kill volume, in tiles.
@export var size_tiles := Vector2(1.0, 1.0)


func _ready() -> void:
	super()
	amount = 9999
	weapon_id = &"hazard"
	one_shot = false

	collision_layer = Layers.bit(Layers.HAZARD)
	collision_mask = Layers.bit(Layers.PLAYER_HURTBOX)
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


## Contact damage has to keep landing while the boxes overlap, so the hazard
## drives its own Hitbox tick rather than waiting on an owner to do it.
func _physics_process(_delta: float) -> void:
	tick()
