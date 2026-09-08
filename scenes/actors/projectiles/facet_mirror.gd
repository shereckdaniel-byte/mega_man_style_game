## One of the two mirrors Prism plants for a Facets pattern.
##
## **It is scenery, and that is the whole job.** It carries no hitbox, deals no
## damage and blocks nothing. What it does is stand somewhere visible for the
## length of a tell, so that by the time the beam arrives the player already
## knows exactly which stretch of floor it is going to rattle up and down.
##
## That is the same fairness bound Rust's Bloom has and `DarkRoom`'s three rules
## are: a pattern may take space away, but it may not take away the information
## that the space is going. Prism's Facets is the most obviously unfair attack in
## the roster if the corridor is invisible until the beam is in it -- the player
## would be asked to guess which half of the arena to be in, and guessing is not
## play. With the mirrors planted first, the answer is "read it, then leave", and
## the ask is a real one because leaving takes time.
##
## It is drawn upright and tall so the corridor reads as a *place* rather than as
## two markers on the floor.
class_name FacetMirror
extends Node2D

## How tall, in NES px. Taller than the player, so the corridor is a pair of
## posts you can see over the top of anything else in the arena.
const HEIGHT_NES := 40.0
const WIDTH_NES := 6.0

const POST := Color(0.30, 0.33, 0.40)
const POST_EDGE := Color(0.16, 0.18, 0.23)
const FACE := Color(0.74, 0.90, 1.0)
const FACE_LIT := Color(1.0, 1.0, 0.96)

## Frames it stands for. Set by the boss to the rest of the pattern, so a mirror
## never outlives the beam that uses it and the arena is never left decorated.
var life_frames := 240
## Frames it spends rising out of the floor before it counts as planted. The
## corridor should not appear in a single frame under a player's feet.
const RAISE_FRAMES := 14

var _frames := 0
var _tuning: PlayerTuning
var _spawn_position := Vector2.ZERO


func plant(at: Vector2, p_life_frames: int, tuning: PlayerTuning) -> void:
	_spawn_position = at
	life_frames = p_life_frames
	_tuning = tuning


func _ready() -> void:
	if _tuning == null:
		var autoload := get_node_or_null(^"/root/Tuning")
		_tuning = autoload.player if autoload != null else PlayerTuning.new()
	global_position = _spawn_position
	queue_redraw()


func is_planted() -> bool:
	return _frames >= RAISE_FRAMES


func frames_left() -> int:
	return maxi(life_frames - _frames, 0)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames >= life_frames:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var scale := _tuning.world_scale
	var rise := clampf(float(_frames) / float(RAISE_FRAMES), 0.0, 1.0)
	var height := HEIGHT_NES * scale * rise
	var width := WIDTH_NES * scale
	if height <= 0.0:
		return
	# Anchored at the floor and growing upward, so the plant reads as something
	# coming out of the ground rather than dropping onto the player.
	var rect := Rect2(Vector2(-width * 0.5, -height), Vector2(width, height))
	draw_rect(rect, POST)
	draw_rect(Rect2(rect.position + Vector2(width * 0.25, 0.0),
		Vector2(width * 0.5, height)), FACE)
	# A highlight running down the face, so a mirror reads as reflective at the
	# distance the player is reading it from.
	draw_line(rect.position + Vector2(width * 0.38, height * 0.08),
		rect.position + Vector2(width * 0.38, height * 0.92), FACE_LIT,
		maxf(width * 0.12, 1.5))
	draw_rect(rect, POST_EDGE, false, maxf(width * 0.14, 2.0))
