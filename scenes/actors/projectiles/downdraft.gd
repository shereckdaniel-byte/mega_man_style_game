## Gale's Downdraft: a slab of hammering air that falls the height of the arena
## and lands across the **whole floor**.
##
## ### The floor is the hazard, and that is the whole idea
##
## Every other attack in the game is answered by the ground. Tide's waves are
## jumped, Arc's rail is jumped, Rust's press is stepped out from under, Prism's
## beams are jumped and its Sweep is jumped over. Being on the floor is what
## safe means. This takes the floor away for half a second, and the answer is to
## **not be standing anywhere** -- not somewhere better, nowhere at all.
##
## There is no safe span, deliberately. A slab that covered part of the arena
## would be answered by walking to the rest of it, which is Arc's answer and is
## already spent.
##
## ### Why it is fair
##
## `SLAB_FRAMES` is **shorter than a full jump**, and that bound is the pattern's
## whole guarantee: 30 frames against the 39.5 the player's jump arc lasts
## (`2 * jump_velocity_pf / gravity_pf`). A player who leaves the ground as it
## lands is still in the air when it lifts, with about nine frames to spare.
## `tests/test_gale.gd` checks the inequality against `PlayerTuning` rather than
## against 39.5, so retuning the jump cannot quietly make the pattern
## unsurvivable.
##
## And the cue is a **falling object, not a countdown**. The slab is drawn from
## the moment it is spawned and visibly descends; it is harmless the whole way
## down and becomes dangerous on touchdown. Judging when a thing arriving from
## above will arrive is ordinary platforming. A hidden arm timer would have made
## the same pattern a memory test.
class_name Downdraft
extends Hitbox

## How fast the slab falls, in NES px/frame. Slow enough to be read across the
## arena, fast enough that the descent is not most of the pattern.
const DESCENT_SPEED_PF := 4.0

## Frames the slab is live on the floor once it lands. **Must stay under the
## player's jump airtime** -- see the note above.
const SLAB_FRAMES := 30

## Height of the live band above the floor, in NES px. Over a standing player
## (24) and well over a sliding one (14), so sliding is not a second answer;
## far under the jump apex (about 49), so the one answer is a real one.
const BAND_HEIGHT_NES := 20.0

## Frames between hits on a player caught inside it.
##
## **Equal to `SLAB_FRAMES`, which means at most one hit per slab**, and that is
## a rule rather than a number: a pattern with exactly one answer should cost
## exactly once when the player fails to give it. FocusSpot repeats because it
## is a place the player may leave and re-enter by choice; this covers the whole
## arena, so a player who is caught by it has already made the only mistake
## available and charging them twice for it is charging them for having no
## floor to stand on.
##
## It was 24 -- under the slab's life, so a caught player took it twice -- and
## the playthrough bot lost eighteen health to Downdraft alone in one fight,
## more than any single pattern in the game.
const REPEAT_FRAMES := SLAB_FRAMES

const AIR := Color(0.72, 0.88, 0.98)
const DUST := Color(0.86, 0.90, 0.86)

var _tuning: PlayerTuning
var _span := Vector2.ZERO
var _floor_y := 0.0
var _damage := 3
var _landed := false
var _live_frames := 0
var _shape: CollisionShape2D


## `span` is the arena's left and right world x; the slab covers all of it.
## `from_y` is where the slab starts its fall.
func drop(span: Vector2, floor_y: float, from_y: float, damage: int,
		tuning: PlayerTuning) -> void:
	_span = Vector2(minf(span.x, span.y), maxf(span.x, span.y))
	_floor_y = floor_y
	_damage = damage
	_tuning = tuning
	position = Vector2((_span.x + _span.y) * 0.5, from_y)


func _ready() -> void:
	super()
	if _tuning == null:
		var autoload := get_node_or_null(^"/root/Tuning")
		_tuning = autoload.player if autoload != null else PlayerTuning.new()

	amount = _damage
	weapon_id = &"downdraft"
	one_shot = false
	repeat_delay_frames = REPEAT_FRAMES

	collision_layer = Layers.bit(Layers.ENEMY_ATTACK)
	collision_mask = Layers.bit(Layers.PLAYER_HURTBOX)
	# Harmless all the way down. It becomes dangerous on touchdown and not
	# before -- switching `monitoring` rather than testing a flag inside `tick`,
	# so the frame it can hurt you is the frame it starts looking.
	monitoring = false

	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(maxf(_span.y - _span.x, 1.0),
		BAND_HEIGHT_NES * _tuning.world_scale)
	_shape.shape = rect
	# The band sits on the floor rather than being centred on it: the node's
	# origin is the floor line once it has landed, so half a centred box would
	# be underground and the height a jump has to clear would be half what the
	# constant says.
	_shape.position = Vector2(0.0, -rect.size.y * 0.5)
	add_child(_shape)
	queue_redraw()


func is_landed() -> bool:
	return _landed


func live_frames() -> int:
	return _live_frames


func _physics_process(delta: float) -> void:
	if not _landed:
		global_position.y = minf(global_position.y
			+ _tuning.px_s(DESCENT_SPEED_PF) * delta, _floor_y)
		if global_position.y >= _floor_y:
			_landed = true
			monitoring = true
		queue_redraw()
		return

	_live_frames += 1
	tick()
	if _live_frames >= SLAB_FRAMES:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var width := maxf(_span.y - _span.x, 1.0)
	var band := BAND_HEIGHT_NES * _tuning.world_scale
	var half := width * 0.5

	if not _landed:
		# The falling slab: a wide, thin sheet with streaks trailing above it,
		# so which way it is going is legible without watching it move.
		draw_rect(Rect2(Vector2(-half, -band * 0.4), Vector2(width, band * 0.8)),
			Color(AIR, 0.42))
		for i in 9:
			var x := -half + width * (float(i) + 0.5) / 9.0
			var length := band * (1.4 + 0.5 * float(i % 3))
			draw_line(Vector2(x, -band * 0.4), Vector2(x, -band * 0.4 - length),
				Color(AIR, 0.30), 3.0)
		return

	# Landed: the band itself, plus dust kicking out along the floor line, which
	# is what says the pressure is on the ground rather than in the air.
	draw_rect(Rect2(Vector2(-half, -band), Vector2(width, band)),
		Color(AIR, 0.50))
	draw_rect(Rect2(Vector2(-half, -band * 0.35), Vector2(width, band * 0.35)),
		Color(DUST, 0.34))
	var spread := band * (0.4 + 1.2 * float(_live_frames) / float(SLAB_FRAMES))
	for side in [-1.0, 1.0]:
		draw_line(Vector2(side * half, -band * 0.1),
			Vector2(side * (half + spread), -band * 0.1), Color(DUST, 0.24), 4.0)
