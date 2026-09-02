## Flyer: crosses the screen on a sine path, ignoring terrain.
##
## Unaffected by gravity and unaffected by walls -- it is an air hazard, and a
## flyer that collided with the level would snag on the boardwalk's raised
## sections and stop being one.
##
## Amplitude and wavelength are in tiles because that is what decides whether
## the player can duck under it or has to jump over it, which is the only
## question level design asks of this archetype.
class_name Flyer
extends Enemy

@export var speed_pf := 1.0
## Height of the sine, peak to centre, in tiles.
@export var amplitude_tiles := 1.5
## Distance covered per full wave, in tiles.
@export var wavelength_tiles := 6.0
## +1 right, -1 left.
@export var facing: int = -1

var _origin_y := 0.0
var _travelled := 0.0


func setup() -> void:
	affected_by_gravity = false
	# Nothing to collide with: the body exists only to carry the boxes.
	collision_mask = 0
	_origin_y = global_position.y

	var size := body_size()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position.y = -size.y * 0.5
	add_child(shape)


func behave(delta: float) -> void:
	var speed := tuning.px_s(speed_pf)
	_travelled += speed * delta

	var wavelength := wavelength_tiles * tuning.tile_size()
	var phase := TAU * _travelled / maxf(wavelength, 1.0)
	var wanted := _origin_y + sin(phase) * amplitude_tiles * tuning.tile_size()

	# Position is driven directly rather than through velocity: the sine is a
	# path, and integrating a velocity towards it accumulates the drift that
	# makes a "sine" flyer slowly sag.
	velocity = Vector2.ZERO
	global_position = Vector2(global_position.x + float(facing) * speed * delta, wanted)


func body_size() -> Vector2:
	var tile := tuning.tile_size()
	return Vector2(tile * 0.9, tile * 0.6)


## A flyer is fought in the air, so its hurtbox is its body and nothing more.
##
## Enemy's minimum exists to stop a *ground* enemy sitting under the buster's
## line. Applying it here would hang a tile of invisible hurtbox below a flying
## enemy, and the player would hit something where nothing is drawn.
##
## What makes a flyer fair is therefore its **path**, not its box: the bottom of
## its sweep has to come within reach. At stage 1's placement the Gullbot
## descends to 1.5 tiles above the deck, which a standing shot reaches at the
## bottom of the arc and a jump reaches comfortably.
func shootable_from_the_ground() -> bool:
	return false
