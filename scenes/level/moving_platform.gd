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

const FACE := Color(0.62, 0.68, 0.78)
const EDGE := Color(0.28, 0.33, 0.42)
const RIVET := Color(0.85, 0.90, 0.98)

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
	draw_rect(Rect2(Vector2.ZERO, size), FACE)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, maxf(size.y * 0.3, 3.0))), RIVET)
	draw_rect(Rect2(Vector2.ZERO, size), EDGE, false, maxf(size.y * 0.12, 2.0))
