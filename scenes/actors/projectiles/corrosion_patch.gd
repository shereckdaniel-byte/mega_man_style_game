## A patch of corrosion on the arena floor, left by Rust's Bloom.
##
## **What makes it a different kind of attack.** Every other thing that hurts the
## player in this game is an event: it arrives, it is dodged or it is not, and
## then it is gone. A patch is a *constraint* -- it takes a piece of the floor
## away and holds it for a few seconds, so the mistake it punishes is not a badly
## timed jump but a badly chosen place to stand thirty frames ago. That is the
## third kind of answer Rust needs (see `Rust`), and nothing else in the roster
## asks for it.
##
## It **damages rather than kills**, unlike a spike. A hazard that removed a
## third of the floor and killed on contact would turn the fight into a
## precision-platforming section against a boss that is also attacking, which is
## two games at once.
##
## It expires on its own, and the boss caps how many can exist. Both of those
## are the fight's bound rather than this class's business -- see `Rust.BLOOM_*`.
class_name CorrosionPatch
extends Hitbox

## Frames it lasts. Long enough that two blooms overlap in time, which is what
## makes the floor shrink; short enough that a full cycle of patterns clears it.
const LIFE_FRAMES := 190
## Frames of warning before it bites, during which it is drawn but harmless.
## The patch lands under a player who may already be standing there, and a hazard
## that appears *on* you is not a decision you were offered.
const ARM_FRAMES := 22
## Frames between hits on a player standing in it. Long: this is a place you may
## not stand, not a shredder.
const REPEAT_FRAMES := 34

const SIZE_NES := Vector2(22.0, 7.0)

const WET := Color(0.72, 0.36, 0.13)
const DRY := Color(0.50, 0.26, 0.11)
const SPORE := Color(0.96, 0.74, 0.36)

var _frames := 0
var _armed := false
var _tuning: PlayerTuning
var _spawn_position := Vector2.ZERO
var _damage := 2


func land(at: Vector2, damage: int, tuning: PlayerTuning) -> void:
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
	weapon_id = &"corrosion"
	one_shot = false
	repeat_delay_frames = REPEAT_FRAMES

	collision_layer = Layers.bit(Layers.ENEMY_ATTACK)
	collision_mask = Layers.bit(Layers.PLAYER_HURTBOX)
	# Off until it has finished arming. Set here rather than by a branch in
	# `tick`, so the frame it becomes dangerous is the frame it starts looking.
	monitoring = false

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE_NES * _tuning.world_scale
	shape.shape = rect
	add_child(shape)
	queue_redraw()


func is_armed() -> bool:
	return _armed


func frames_left() -> int:
	return maxi(LIFE_FRAMES - _frames, 0)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if not _armed and _frames >= ARM_FRAMES:
		_armed = true
		monitoring = true
	if _armed:
		tick()
	if _frames >= LIFE_FRAMES:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var size := SIZE_NES * _tuning.world_scale
	var half := size * 0.5
	# Fades out over the last quarter of its life, so "about to be safe" is
	# visible rather than something the player has to have counted.
	var left := float(frames_left()) / float(LIFE_FRAMES)
	var alpha := clampf(left * 4.0, 0.0, 1.0)
	var body := DRY if not _armed else WET
	draw_rect(Rect2(-half, size), Color(body, (0.35 if not _armed else 0.85) * alpha))
	# Bubbles along the top edge: the part that says it is eating the floor.
	var count := 5
	for i in count:
		var t := (float(i) + 0.5) / float(count)
		var lift := sin(float(_frames) * 0.09 + float(i)) * half.y * 0.35
		draw_circle(Vector2(-half.x + size.x * t, -half.y * 0.4 + lift),
			half.y * 0.42, Color(SPORE, (0.30 if not _armed else 0.80) * alpha))
