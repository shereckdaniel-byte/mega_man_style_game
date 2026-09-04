## A platform that carries the player along a path.
##
## An **AnimatableBody2D**, not a StaticBody2D moved by hand. That is the whole
## trick: `sync_to_physics` makes the physics server treat the movement as
## motion rather than teleportation, so a CharacterBody2D standing on it is
## carried by `move_and_slide` with no code on the rider's side. Moving a
## StaticBody2D instead leaves the player standing still while the platform
## slides out from under them -- the platform arrives, the player does not.
##
## Paths are counted in **physics frames**, like everything else here, so a
## platform's cycle is exactly the same length every run and a headless test can
## step it. A Tween would drift against the physics tick.
class_name MovingPlatform
extends AnimatableBody2D

## How the platform travels between its two ends.
enum Mode {
	## Out and back, reversing at each end. The common case.
	PING_PONG,
	## Straight to the far end, then jump back to the start. Reads as a conveyor
	## of platforms rather than one platform pacing.
	LOOP,
}

## Size in tiles.
@export var size_tiles := Vector2(3.0, 0.5):
	set(value):
		size_tiles = Vector2(maxf(value.x, 0.25), maxf(value.y, 0.125))
		if is_inside_tree():
			_rebuild()

## Where the platform travels to, relative to where it starts, in tiles.
## A vertical platform is just this with x at 0.
@export var travel_tiles := Vector2(4.0, 0.0)

## Physics frames for one leg of the journey. 120 is two seconds, which is
## about the slowest that still reads as moving rather than parked.
@export var frames_per_leg: int = 120

@export var mode: Mode = Mode.PING_PONG

## Frames to wait at each end before setting off again. A pause is what makes a
## platform catchable: without one the player has to jump at exactly the frame
## it arrives.
@export var pause_frames: int = 24

## Offsets the cycle at spawn, so a row of platforms can be staggered without
## each one needing its own timing.
@export var phase_frames: int = 0

## Set false to leave it parked, for a platform switched on by something else.
@export var running: bool = true

## Drawn to read as a cut piece of the deck rather than as a coloured bar.
##
## The first version was one flat rectangle with a lighter strip on top, and a
## playtester's note on it was that it "does not look good, should look like the
## floor below or very close" -- which is exactly right: it is the only thing in
## the room the player stands on that does not come from the tileset, so it is
## the only thing that reads as placeholder.
##
## Still drawn rather than tiled. A TileMapLayer that moves is a second source of
## collision travelling through the level, and the platform's whole contract is
## that it carries its rider (`MovingPlatform` moves the body it is under). What
## closes the gap is the *shape* -- plank ends, a bright top lip, bolt heads and
## a shadowed underside -- not the exact pixels.
const FACE := Color(0.60, 0.55, 0.52)
const PLANK := Color(0.52, 0.47, 0.45)
const LIP := Color(0.88, 0.85, 0.72)
const EDGE := Color(0.24, 0.22, 0.24)
const BOLT := Color(0.36, 0.34, 0.34)
const UNDER := Color(0.30, 0.27, 0.28)

var _origin := Vector2.ZERO
var _frames := 0
var _shape: CollisionShape2D


func _ready() -> void:
	# Layer 13 is `platform`, which the player's body already masks. Reserved in
	# the collision table from the start with nothing on it until now.
	collision_layer = Layers.bit(Layers.PLATFORM)
	collision_mask = 0
	# The reason this class is an AnimatableBody2D at all -- see the note above.
	sync_to_physics = true
	_origin = position
	_frames = phase_frames
	_rebuild()
	_apply_position()


func tile_size() -> float:
	var autoload := get_node_or_null(^"/root/Tuning")
	return autoload.player.tile_size() if autoload != null else 72.0


func world_size() -> Vector2:
	return size_tiles * tile_size()


func travel() -> Vector2:
	return travel_tiles * tile_size()


## Total frames in one full cycle: out, pause, back, pause.
func cycle_frames() -> int:
	var leg := maxi(frames_per_leg, 1)
	if mode == Mode.LOOP:
		return leg + maxi(pause_frames, 0)
	return (leg + maxi(pause_frames, 0)) * 2


## How far along the journey the platform is, 0..1, at a given frame.
##
## Static and pure so a test can check the whole cycle without stepping physics
## for four seconds per case.
static func progress_at(frame: int, leg_frames: int, pause: int,
		platform_mode: Mode) -> float:
	var leg := maxi(leg_frames, 1)
	var hold := maxi(pause, 0)
	if platform_mode == Mode.LOOP:
		var span := leg + hold
		var t := posmod(frame, span)
		return clampf(float(t) / float(leg), 0.0, 1.0)

	var half := leg + hold
	var whole := half * 2
	var at := posmod(frame, whole)
	if at < leg:
		return float(at) / float(leg)
	if at < half:
		return 1.0
	var back := at - half
	if back < leg:
		return 1.0 - float(back) / float(leg)
	return 0.0


func progress() -> float:
	return progress_at(_frames, frames_per_leg, pause_frames, mode)


## Which way the platform is about to travel along x, as -1, 0 or +1.
##
## **Progress alone cannot answer this**, which is the trap: a ping-pong platform
## at progress 0.16 is either sixteen percent into its outward leg or eighty-four
## percent of the way home, and those are opposite answers to "will this carry me
## forwards". The playthrough bot boarded one on its return leg, kept walking
## forwards because it was still on the near side of the hole, and stepped off
## the far end into the spikes -- deterministically, on the same frame every run.
##
## Answered by looking ahead rather than by remembering: the cycle is pure
## arithmetic, so the platform can simply be asked where it will be. The scan
## walks past a pause, because "stationary" is not an answer a rider can use.
func next_heading() -> int:
	if not running or absf(travel().x) < 0.001:
		return 0
	var here := progress()
	var ahead := maxi(pause_frames, 0) + 2
	for step in range(1, ahead + 1):
		var then := progress_at(_frames + step, frames_per_leg, pause_frames, mode)
		if absf(then - here) > 0.0001:
			return signi(int(signf((then - here) * travel().x)))
	return 0


## Where the platform is right now, in world coordinates.
func current_position() -> Vector2:
	return _origin + travel() * progress()


func _physics_process(_delta: float) -> void:
	if not running:
		return
	_frames += 1
	_apply_position()


func _apply_position() -> void:
	position = current_position()


func _rebuild() -> void:
	if _shape == null:
		_shape = CollisionShape2D.new()
		_shape.name = "Shape"
		add_child(_shape)
	var rect := RectangleShape2D.new()
	rect.size = world_size()
	_shape.shape = rect
	_shape.position = Vector2(rect.size.x * 0.5, rect.size.y * 0.5)
	queue_redraw()


func _draw() -> void:
	var size := world_size()
	var tile := tile_size()
	var lip := maxf(size.y * 0.34, 4.0)

	# Body, then a shadowed underside so it sits in the light like the deck does.
	draw_rect(Rect2(Vector2.ZERO, size), FACE)
	draw_rect(Rect2(Vector2(0.0, size.y - lip * 0.7), Vector2(size.x, lip * 0.7)), UNDER)

	# Plank ends across the span, on the tile grid, so the walking surface has
	# the same rhythm as the boardwalk it was cut from.
	var plank := tile * 0.5
	var x := plank
	while x < size.x - 1.0:
		draw_rect(Rect2(Vector2(x - maxf(tile * 0.02, 1.0), lip),
			Vector2(maxf(tile * 0.04, 2.0), size.y - lip)), PLANK)
		x += plank

	# The bright top lip: the part the player actually aims their feet at.
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, lip)), LIP)

	# Bolt heads at the ends, which is what says "this one is a fitting that
	# moves" rather than "this one is a piece someone forgot to texture".
	var bolt := maxf(tile * 0.07, 2.0)
	for at in [tile * 0.22, size.x - tile * 0.22]:
		draw_circle(Vector2(at, lip * 0.5), bolt, BOLT)

	draw_rect(Rect2(Vector2.ZERO, size), EDGE, false, maxf(size.y * 0.1, 2.0))
