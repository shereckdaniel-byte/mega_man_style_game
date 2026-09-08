## The focal point of Prism's Sweep: a spot of concentrated sunlight walking
## across the arena floor.
##
## **The ask is to go towards it.** Every other pattern in the roster is answered
## by getting away from something -- Tide's waves, Arc's curtain, Rust's press.
## This one cannot be: it starts at Prism's feet and crosses the whole arena, so
## backing off only spends the floor behind you and arrives at a wall. The answer
## is to jump *over* the spot and come down on the side it started from, which is
## the side Prism is on. Committing forward, at a boss, is a decision the game
## has never asked for before.
##
## Three things make that fair rather than cruel:
##
##   * **It is low.** `HEIGHT_NES` is well under the jump, so clearing it is an
##     ordinary hop and not a frame-perfect one.
##   * **It is slower than a sprint over a short distance and faster than a walk
##     over a long one.** Backing away works for a while, which is what makes
##     hitting the wall feel like a consequence rather than a trap.
##   * **It damages rather than kills.** Same argument `CorrosionPatch` makes: a
##     hazard that removes floor during a boss fight and kills on contact is two
##     games at once.
##
## It repeats rather than hitting once, because it is a place you may not be and
## not a projectile you dodge. The player's own i-frames are what bound that.
class_name FocusSpot
extends Hitbox

## Travel speed in NES px/frame. Above the player's walk of 1.375, which is what
## makes retreating a losing move rather than a viable one.
const SPEED_PF := 1.7

## The bright patch itself, in NES px. Wide enough to read from across the arena,
## low enough that a jump is an ordinary one.
const WIDTH_NES := 16.0
const HEIGHT_NES := 11.0

## Frames of warning before it bites. The spot lights up where it is going to be
## before it is dangerous there, for the same reason `CorrosionPatch` arms.
const ARM_FRAMES := 20
## Frames between hits on a player standing in it.
const REPEAT_FRAMES := 30

## How far past the far wall it runs before it gives up, in NES px. It has to
## leave rather than stop at the edge, or the last thing the pattern does is park
## a hazard against a wall the player may be pinned to.
const OVERRUN_NES := 40.0

const CORE := Color(1.0, 1.0, 0.92)
const GLOW := Color(1.0, 0.94, 0.62)
const SCORCH := Color(0.92, 0.72, 0.34)

var _frames := 0
var _armed := false
var _direction := 1.0
var _limit := 0.0
var _tuning: PlayerTuning
var _spawn_position := Vector2.ZERO
var _damage := 3


## `towards` is the world x the spot is walking at; it stops `OVERRUN_NES` past
## it. The boss passes the far wall rather than a distance, so the pattern is the
## same length whatever size the arena is.
func sweep(from: Vector2, towards: float, damage: int, tuning: PlayerTuning) -> void:
	_spawn_position = from
	_damage = damage
	_tuning = tuning
	_direction = signf(towards - from.x)
	if _direction == 0.0:
		_direction = 1.0
	_limit = towards + _direction * OVERRUN_NES * tuning.world_scale


func _ready() -> void:
	super()
	if _tuning == null:
		var autoload := get_node_or_null(^"/root/Tuning")
		_tuning = autoload.player if autoload != null else PlayerTuning.new()
	global_position = _spawn_position

	amount = _damage
	weapon_id = &"focus"
	one_shot = false
	repeat_delay_frames = REPEAT_FRAMES

	collision_layer = Layers.bit(Layers.ENEMY_ATTACK)
	collision_mask = Layers.bit(Layers.PLAYER_HURTBOX)
	# Off until armed, so the frame it becomes dangerous is the frame it starts
	# looking -- rather than a branch inside `tick` that has to be remembered.
	monitoring = false

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(WIDTH_NES, HEIGHT_NES) * _tuning.world_scale
	shape.shape = rect
	# The box sits on the floor: the spot's origin is the floor line, so the
	# rectangle hangs above it rather than being centred on it. A centred box
	# would put half the danger underground and halve the height a jump has to
	# clear, which is the sort of quiet mismatch that makes a pattern read as
	# unfair without anybody being able to say why.
	shape.position = Vector2(0.0, -rect.size.y * 0.5)
	add_child(shape)
	queue_redraw()


func is_armed() -> bool:
	return _armed


func direction() -> float:
	return _direction


func _physics_process(delta: float) -> void:
	_frames += 1
	if not _armed and _frames >= ARM_FRAMES:
		_armed = true
		monitoring = true
	if _armed:
		position.x += _direction * _tuning.px_s(SPEED_PF) * delta
		tick()
	if (_direction > 0.0 and global_position.x >= _limit) \
			or (_direction < 0.0 and global_position.x <= _limit):
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var scale := _tuning.world_scale
	var width := WIDTH_NES * scale
	var height := HEIGHT_NES * scale
	var strength := 0.35 if not _armed else 1.0

	# The shaft coming down onto the spot, so the danger has a source rather than
	# being a bright patch that appeared. Drawn as a taper: wide up where it
	# leaves the receiver, tight where it lands.
	var reach := height * 9.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-width * 0.5, 0.0),
		Vector2(width * 0.5, 0.0),
		Vector2(width * 1.9, -reach),
		Vector2(-width * 1.9, -reach),
	]), Color(GLOW, 0.14 * strength))

	draw_rect(Rect2(Vector2(-width * 0.5, -height), Vector2(width, height)),
		Color(GLOW, 0.55 * strength))
	draw_rect(Rect2(Vector2(-width * 0.34, -height * 0.7),
		Vector2(width * 0.68, height * 0.7)), Color(CORE, 0.85 * strength))
	# A scorch line on the floor behind it, which is what says which way it came
	# from and therefore which way is already spent.
	draw_rect(Rect2(Vector2(-_direction * width * 2.2, -height * 0.12),
		Vector2(_direction * width * 2.2, height * 0.12)),
		Color(SCORCH, 0.30 * strength))
