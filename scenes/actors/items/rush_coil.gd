## Rush Coil: a spring you put down and land on.
##
## The vertical half of the utility set. It reaches ledges an ordinary jump
## cannot, which is the whole of its job -- there is no combat use, no damage,
## and nothing to aim.
##
## ### It launches on the way down, not on contact
##
## A spring that fired the moment the player touched it would fire on the frame
## it was summoned, because the player is standing where they summoned it. So it
## waits for a player who is **falling** -- `velocity.y > 0` -- which is what
## landing on a spring actually is, and which cannot be true of somebody who has
## not left the ground yet.
##
## ### It expires
##
## `LIFETIME_FRAMES`, for the reason `Pickup` expires: a room that accumulates
## every coil a player ever put down stops reading as a room. It also stops a
## coil being a permanent step that trivialises a climb the level meant to
## charge for.
class_name RushCoil
extends Area2D

## Launch speed, in NES px/frame up.
##
## **Derived from the jump rather than picked.** The player's own jump is
## `jump_velocity_pf` and reaches about 46 NES px; `LAUNCH_MULTIPLE` of that
## reaches roughly `n^2` times as high, so 1.7 is about two and a half tiles of
## extra height -- one storey, which is what a utility item should buy. Written
## as a multiple so retuning the jump carries the coil with it.
const LAUNCH_MULTIPLE := 1.7

const LIFETIME_FRAMES := 420
## Frames of the life spent blinking, so it says it is going before it goes --
## the same fair-warning rule `Pickup` and `PhaseBlock` are built on.
const BLINK_FRAMES := 90
const BLINK_PERIOD := 6

const SIZE_NES := Vector2(20.0, 10.0)

const BASE := Color(0.86, 0.28, 0.26)
const SPRING := Color(0.92, 0.90, 0.86)
const SHADOW := Color(0.16, 0.12, 0.14)

var _tuning: PlayerTuning
var _frames := 0
var _compress := 0.0


func _ready() -> void:
	var autoload := get_node_or_null(^"/root/Tuning")
	_tuning = autoload.player if autoload != null else PlayerTuning.new()

	collision_layer = 0
	collision_mask = Layers.bit(Layers.PLAYER_BODY)
	monitoring = true

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE_NES * _tuning.world_scale
	shape.shape = rect
	shape.position = Vector2(0.0, -rect.size.y * 0.5)
	add_child(shape)
	z_index = 5
	queue_redraw()


func frames_left() -> int:
	return maxi(LIFETIME_FRAMES - _frames, 0)


func is_blinking() -> bool:
	return frames_left() <= BLINK_FRAMES


## Launches a player who is falling onto it. Public so a test can drive it
## without arranging a real fall.
func launch(player: Player) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	# Falling, not merely touching. See the class docstring: a spring that fires
	# on contact fires on the frame it is summoned.
	if player.velocity.y <= 0.0:
		return false
	player.velocity.y = -_tuning.px_s(_tuning.jump_velocity_pf * LAUNCH_MULTIPLE)
	_compress = 1.0
	return true


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames >= LIFETIME_FRAMES:
		queue_free()
		return
	_compress = maxf(_compress - 0.08, 0.0)
	for body in get_overlapping_bodies():
		if body is Player:
			launch(body as Player)
	queue_redraw()


func _draw() -> void:
	if is_blinking() and (_frames / BLINK_PERIOD) % 2 == 1:
		return
	var size := SIZE_NES * _tuning.world_scale
	# Squashed while it is giving back, so a launch is visible on the spring
	# rather than only on the player.
	var height := size.y * (1.0 - 0.5 * _compress)
	draw_rect(Rect2(Vector2(-size.x * 0.5, -size.y * 0.22),
		Vector2(size.x, size.y * 0.22)), SHADOW)
	# The coil itself: three turns, so it reads as a spring and not a box.
	var turns := 3
	for i in turns:
		var y := -height * (float(i) + 1.0) / float(turns)
		draw_rect(Rect2(Vector2(-size.x * 0.34, y), Vector2(size.x * 0.68,
			height / float(turns) * 0.5)), SPRING)
	draw_rect(Rect2(Vector2(-size.x * 0.5, -height - size.y * 0.3),
		Vector2(size.x, size.y * 0.3)), BASE)
