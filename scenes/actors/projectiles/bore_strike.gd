## Quarry's Bore: a drill that comes up **through the floor**.
##
## It is the only attack in the game that arrives from below, and the whole
## point of it is where the tell is. Every other telegraph in the roster is on
## the boss -- an animation, a hover height, a plume of mirrors -- so the player
## reads it by watching the thing that is going to hurt them. This one is a
## crack in the deck, at the far end of the arena, on the ground the player is
## standing on. **You cannot watch the boss and answer this.**
##
## The crack is drawn for the whole arm and is harmless the entire time, which
## is the fairness half: the pattern asks the player to look somewhere else, so
## it has to be worth looking at and it has to be there long enough to find.
class_name BoreStrike
extends Hitbox

## Frames the crack shows before the drill comes through.
##
## Long, because the ask is to notice something that is not where the player is
## looking. `tests/test_quarry.gd` holds it above the reaction slack
## `PhaseBlock.BEAT_FRAMES` is built on -- it was drafted at exactly 40, which
## is a jump's airtime and no time at all to find a tell with, and the test
## caught it sitting on its own bound.
const ARM_FRAMES := 52
## Frames the drill stands out of the floor.
const STRIKE_FRAMES := 34
## Frames between hits on a player standing in it.
const REPEAT_FRAMES := 24

## How wide the crack and the drill are, and how far the drill rises, in NES px.
##
## **Narrower than a jump covers and taller than a jump clears**: you do not get
## over this one, you get off it. That is the difference between the Bore and
## every low attack in the game, and it is what makes the crack worth reading
## rather than something you can answer late with a hop.
##
## The height was drafted at 46, which is the jump apex **exactly** -- a bound
## met precisely is a bound that fails the first time anything is retuned, and
## in this case it also means the pattern is answerable by a perfect jump, which
## is the opposite of what it is for. `tests/test_quarry.gd` measures it against
## `PlayerTuning` rather than against a number here.
const WIDTH_NES := 18.0
const HEIGHT_NES := 58.0

const ROCK := Color(0.44, 0.38, 0.34)
const CRACK_DARK := Color(0.12, 0.10, 0.10)
const STEEL := Color(0.76, 0.78, 0.84)
const SPARK := Color(1.0, 0.84, 0.48)

var _tuning: PlayerTuning
var _spawn_position := Vector2.ZERO
var _damage := 4
var _frames := 0
var _up := false
var _shape: CollisionShape2D


## `at` is the floor line the drill comes through.
func mark(at: Vector2, damage: int, tuning: PlayerTuning) -> void:
	_spawn_position = at
	_damage = damage
	_tuning = tuning


func _ready() -> void:
	super()
	if _tuning == null:
		var autoload := get_node_or_null(^"/root/Tuning")
		_tuning = autoload.player if autoload != null else PlayerTuning.new()
	global_position = _spawn_position

	amount = _damage
	weapon_id = &"bore"
	one_shot = false
	repeat_delay_frames = REPEAT_FRAMES

	collision_layer = Layers.bit(Layers.ENEMY_ATTACK)
	collision_mask = Layers.bit(Layers.PLAYER_HURTBOX)
	# Off through the whole arm. The crack is a thing to read, not a thing to
	# avoid -- the same rule `FocusSpot`, `Downdraft` and `AshEmber` are built on.
	monitoring = false

	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(WIDTH_NES, HEIGHT_NES) * _tuning.world_scale
	_shape.shape = rect
	# Standing on the floor line rather than centred on it.
	_shape.position = Vector2(0.0, -rect.size.y * 0.5)
	add_child(_shape)
	queue_redraw()


func is_up() -> bool:
	return _up


func frames_alive() -> int:
	return _frames


func _physics_process(_delta: float) -> void:
	_frames += 1
	if not _up:
		if _frames >= ARM_FRAMES:
			_up = true
			monitoring = true
		queue_redraw()
		return
	tick()
	if _frames >= ARM_FRAMES + STRIKE_FRAMES:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var scale := _tuning.world_scale
	var width := WIDTH_NES * scale
	var height := HEIGHT_NES * scale

	if not _up:
		# The crack, opening as the arm runs so the player can tell how long is
		# left from its width rather than from a count.
		var t := clampf(float(_frames) / float(ARM_FRAMES), 0.0, 1.0)
		var open := width * (0.15 + 0.85 * t)
		draw_rect(Rect2(Vector2(-open * 0.5, -scale * 1.5), Vector2(open, scale * 3.0)),
			CRACK_DARK)
		# Dust jumping off the deck, which is the part that catches an eye that
		# is looking somewhere else.
		for i in 5:
			var x := -open * 0.5 + open * (float(i) + 0.5) / 5.0
			var lift := scale * (2.0 + 5.0 * t * absf(sin(float(_frames) * 0.3 + float(i))))
			draw_rect(Rect2(Vector2(x - scale * 0.6, -lift), Vector2(scale * 1.2, lift)),
				Color(ROCK, 0.55))
		return

	# The drill, out of the floor.
	var risen := clampf(float(_frames - ARM_FRAMES) / 6.0, 0.0, 1.0)
	var top := -height * risen
	draw_rect(Rect2(Vector2(-width * 0.42, top), Vector2(width * 0.84, -top)), STEEL)
	# Flutes, so it reads as a drill rather than a post.
	var flutes := 5
	for i in flutes:
		var y := top + (-top) * (float(i) + 0.5) / float(flutes)
		draw_rect(Rect2(Vector2(-width * 0.42, y), Vector2(width * 0.84, scale * 1.2)),
			Color(CRACK_DARK, 0.55))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, top - width * 0.36),
		Vector2(width * 0.42, top),
		Vector2(-width * 0.42, top),
	]), STEEL)
	draw_circle(Vector2(0.0, top), width * 0.14, Color(SPARK, 0.8))
