## A sheet of fire that stands still for a while: Cinder's Backdraft breath and
## the draught at the foot of its Flue.
##
## One class for both because they are the same object with different numbers --
## a rectangle of deck that is on fire for a fixed count and then is not. The
## difference between the two patterns is what the *boss* does around it, which
## is where a difference between patterns belongs.
##
## It repeats rather than hitting once, because it is a place you may not be
## rather than a projectile you dodge -- the same argument `FocusSpot` and
## `Downdraft` make. The player's own i-frames bound it.
class_name FlameWall
extends Hitbox

## Frames between hits on a player standing in it.
const REPEAT_FRAMES := 24
## Frames of the life spent guttering, so it says it is going before it goes.
const FADE_FRAMES := 20

const CORE := Color(1.0, 0.96, 0.80)
const FLAME := Color(1.0, 0.52, 0.16)
const SMOKE := Color(0.32, 0.24, 0.24)

var _tuning: PlayerTuning
var _spawn_position := Vector2.ZERO
var _size := Vector2.ZERO
var _life := 60
var _damage := 3
var _frames := 0


## `size` is in NES px and `at` is the **floor line** the sheet stands on, so a
## caller places it where the deck is rather than where its middle would be.
func light(at: Vector2, size: Vector2, life: int, damage: int,
		tuning: PlayerTuning) -> void:
	_spawn_position = at
	_size = size
	_life = maxi(life, 1)
	_damage = damage
	_tuning = tuning


func _ready() -> void:
	super()
	if _tuning == null:
		var autoload := get_node_or_null(^"/root/Tuning")
		_tuning = autoload.player if autoload != null else PlayerTuning.new()
	global_position = _spawn_position

	amount = _damage
	weapon_id = &"flame"
	one_shot = false
	repeat_delay_frames = REPEAT_FRAMES

	collision_layer = Layers.bit(Layers.ENEMY_ATTACK)
	collision_mask = Layers.bit(Layers.PLAYER_HURTBOX)
	monitoring = true

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = _size * _tuning.world_scale
	shape.shape = rect
	shape.position = Vector2(0.0, -rect.size.y * 0.5)
	add_child(shape)
	queue_redraw()


func frames_alive() -> int:
	return _frames


func _physics_process(_delta: float) -> void:
	_frames += 1
	tick()
	if _frames >= _life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var size := _size * _tuning.world_scale
	var left := float(_life - _frames)
	var alpha := clampf(left / float(FADE_FRAMES), 0.0, 1.0)
	# Tongues rather than a block: a rectangle of orange reads as a wall the
	# player should be able to stand on.
	var tongues := maxi(int(size.x / (size.y * 0.5)), 3)
	for i in tongues:
		var t := (float(i) + 0.5) / float(tongues)
		var x := -size.x * 0.5 + size.x * t
		var lick := size.y * (0.72 + 0.28 * sin(float(_frames) * 0.3 + float(i) * 1.7))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - size.x / float(tongues) * 0.6, 0.0),
			Vector2(x + size.x / float(tongues) * 0.6, 0.0),
			Vector2(x, -lick),
		]), Color(FLAME, 0.85 * alpha))
	draw_rect(Rect2(Vector2(-size.x * 0.5, -size.y * 0.34),
		Vector2(size.x, size.y * 0.34)), Color(CORE, 0.6 * alpha))
	draw_rect(Rect2(Vector2(-size.x * 0.5, -size.y * 1.15),
		Vector2(size.x, size.y * 0.4)), Color(SMOKE, 0.22 * alpha))
