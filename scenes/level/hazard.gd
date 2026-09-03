## Spikes, crushers and the sensor under a bottomless pit.
##
## **It draws itself, which it did not until a playtest.** Every spike in the
## game was an invisible instant-kill box. That is the precise failure the room
## tables spend paragraphs refusing to author -- stage 1's comments turn down
## three spike placements for being "a kill on a flat run with nothing but the
## sprite to warn you" -- and then there was no sprite. The geometry was fair and
## the presentation was not, which the player experiences as the same thing.
##
## Instant death, not damage: in the original a spike kills a full-health player
## outright, and that is what makes spike corridors read as precision sections
## rather than as damage races. Implemented as a very large DamageInfo so it
## goes through the same Health path as everything else -- i-frames included,
## which is why a hazard cannot kill you during a respawn's grace period.
class_name Hazard
extends Hitbox

var _tile := 72.0

## Width and height of the kill volume, in tiles.
@export var size_tiles := Vector2(1.0, 1.0)

## Which way the teeth point. Set by the stage: ceiling spikes hang down, floor
## and pit spikes point up. Drawn rather than authored per placement, because a
## spike pointing the wrong way is a warning that reads as decoration.
@export var points_up := true

const TOOTH := Color(0.86, 0.88, 0.93)
const TOOTH_EDGE := Color(0.44, 0.47, 0.55)
const BASE := Color(0.36, 0.38, 0.45)


func _ready() -> void:
	super()
	amount = 9999
	weapon_id = &"hazard"
	one_shot = false

	collision_layer = Layers.bit(Layers.HAZARD)
	collision_mask = Layers.bit(Layers.PLAYER_HURTBOX)
	monitoring = true

	var autoload := get_node_or_null(^"/root/Tuning")
	if autoload != null:
		_tile = autoload.player.tile_size()

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size_tiles * _tile
	shape.shape = rect
	add_child(shape)
	queue_redraw()


## Contact damage has to keep landing while the boxes overlap, so the hazard
## drives its own Hitbox tick rather than waiting on an owner to do it.
func _physics_process(_delta: float) -> void:
	tick()


## A row of triangular teeth across the volume, on a thin base strip.
##
## One tooth per half tile, so a two-tile run of spikes reads as four teeth
## rather than as one large triangle -- the size of the tooth is what says
## "spike" and it has to stay constant as the run gets longer.
func _draw() -> void:
	var tile := _tile
	var size := size_tiles * tile
	var half := size * 0.5
	var tooth_width := tile * 0.5
	var count := maxi(int(round(size.x / tooth_width)), 1)
	var width := size.x / float(count)

	# The strip the teeth stand on, along the edge they are anchored to.
	var strip := maxf(size.y * 0.3, 3.0)
	var base_y := half.y - strip if points_up else -half.y
	draw_rect(Rect2(Vector2(-half.x, base_y), Vector2(size.x, strip)), BASE)

	for i in count:
		var left := -half.x + width * float(i)
		var tip_y := -half.y if points_up else half.y
		var root_y := half.y - strip if points_up else -half.y + strip
		var points := PackedVector2Array([
			Vector2(left, root_y),
			Vector2(left + width, root_y),
			Vector2(left + width * 0.5, tip_y),
		])
		draw_colored_polygon(points, TOOTH)
		draw_polyline(points + PackedVector2Array([points[0]]), TOOTH_EDGE,
			maxf(tile * 0.03, 1.0))
