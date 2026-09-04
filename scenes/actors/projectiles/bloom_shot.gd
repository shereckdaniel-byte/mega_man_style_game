## Rust Bloom -- archetype 4, the heavy slow arcing knuckle.
##
## Two beats, and the second is what makes it worth its ammo. The knuckle is
## **lobbed**: it leaves at an angle and falls under its own gravity, so where it
## lands is a judgement about distance rather than a line the player can see.
## That is the archetype's "hard to aim". Then it **blooms** -- on hitting
## anything, terrain included, it bursts into a short-lived patch of corrosion
## several times its own size.
##
## ### Why the bloom exists rather than just a big number
##
## Archetype 4 is "high damage, hard to aim", and a weapon that is only those two
## things is a worse buster with a penalty. The bloom is what you are buying with
## the difficulty: it reaches round a corner, it clears a cluster, and it lands
## on a floor the player cannot stand on. Arc's Curtain and the Splicebox's
## spawns are both answered by it in a way nothing else in the arsenal answers.
##
## ### The lob is authored in the resource, not here
##
## `speed_pf`, `lift_pf` and `fall_pf` live in `rust_bloom.tres` next to the
## damage and the ammo cost, because they are what the weapon *is*. Nothing here
## hard-codes them -- see `WeaponShot.number`.
##
## ### It does not stop at an enemy
##
## `_on_hit` blooms rather than freeing, which is the one place this diverges
## from `WeaponShot`'s default. A knuckle that vanished on the first thing it
## touched would never bloom on a group, which is the whole point of it.
class_name BloomShot
extends WeaponShot

const SIZE_NES := Vector2(11.0, 11.0)

## Horizontal travel, NES px/frame. Slower than the buster's 5: it is a lob and
## it has to be watchable, because watching it is how the range is learned.
const DEFAULT_SPEED_PF := 3.0
## Upward push at launch, NES px/frame.
const DEFAULT_LIFT_PF := 2.4
## Downward acceleration, NES px/frame^2. Deliberately lighter than the player's
## 0.25: at the player's gravity the arc is three tiles long and the weapon is a
## melee attack with extra steps.
const DEFAULT_FALL_PF := 0.11

## How much wider the bloom is than the knuckle, and how long it lasts.
const BLOOM_TILES := 1.7
const BLOOM_FRAMES := 20
## Frames between hits on the same target once bloomed. The bloom is an area,
## not a drill: it should catch a group once, not grind one enemy down.
const BLOOM_REPEAT := 6

## Frames before an unobstructed knuckle gives up. A lob that lands on nothing
## still has to stop being a projectile.
const LIFETIME_FRAMES := 240

const IRON := Color(0.45, 0.30, 0.20)
const RUST := Color(0.78, 0.42, 0.16)
const SPORE := Color(0.94, 0.72, 0.35)

var _velocity := Vector2.ZERO
var _bloomed := false
var _bloom_frames := 0


func shot_size() -> Vector2:
	return SIZE_NES


func _configure() -> void:
	var speed := number(&"speed_pf", DEFAULT_SPEED_PF)
	var lift := number(&"lift_pf", DEFAULT_LIFT_PF)
	_velocity = Vector2(float(direction()) * speed, -lift)
	# The knuckle has to survive contact with the level long enough to bloom on
	# it, and the bloom has to reach more than one thing. Both are the opposite
	# of the base class's default, and both are set here rather than in a branch
	# further down so the shape of this weapon is stated in one place.
	one_shot = false
	repeat_delay_frames = BLOOM_REPEAT


func is_bloomed() -> bool:
	return _bloomed


## Travel in NES px/frame, integrated per physics frame like everything else in
## this project rather than per second, so the arc is identical every run.
func _advance(_delta: float) -> void:
	if _bloomed:
		_bloom_frames += 1
		tick()
		if _bloom_frames >= BLOOM_FRAMES:
			queue_free()
		queue_redraw()
		return

	if frames_alive() > LIFETIME_FRAMES:
		queue_free()
		return
	_velocity.y += number(&"fall_pf", DEFAULT_FALL_PF)
	global_position += _velocity * tuning().world_scale
	rotation = _velocity.angle()
	queue_redraw()


## Hitting an enemy blooms on it. Overrides the base class, which frees.
func _on_hit(_hurtbox: Hurtbox, _taken: int) -> void:
	_bloom()


func _on_body_entered(_body: Node2D) -> void:
	_bloom()


func _bloom() -> void:
	if _bloomed:
		return
	_bloomed = true
	_bloom_frames = 0
	rotation = 0.0
	_velocity = Vector2.ZERO
	# Rearm so the knuckle's own landing hit does not count as the bloom's, and
	# widen the box. The shape is the first child the base class added.
	rearm()
	var shape := get_child(0) as CollisionShape2D
	if shape != null and shape.shape is RectangleShape2D:
		var side := BLOOM_TILES * tuning().tile_size()
		(shape.shape as RectangleShape2D).size = Vector2(side, side)
	queue_redraw()


func _draw() -> void:
	var scale := tuning().world_scale
	if not _bloomed:
		var size := SIZE_NES * scale
		# A blunt wedge rather than a ball: it is rotated to its travel, and a
		# ball would make the arc invisible.
		draw_colored_polygon(PackedVector2Array([
			Vector2(size.x * 0.5, 0.0),
			Vector2(-size.x * 0.35, -size.y * 0.42),
			Vector2(-size.x * 0.5, 0.0),
			Vector2(-size.x * 0.35, size.y * 0.42),
		]), IRON)
		draw_circle(Vector2(size.x * 0.1, 0.0), size.y * 0.26, RUST)
		return

	# The bloom fades out over its life, so the frame it stops being dangerous
	# is the frame it stops being drawn.
	var life := 1.0 - float(_bloom_frames) / float(BLOOM_FRAMES)
	var radius := BLOOM_TILES * tuning().tile_size() * 0.5
	draw_circle(Vector2.ZERO, radius * (0.55 + 0.45 * (1.0 - life)),
		Color(RUST, 0.30 * life))
	for i in 7:
		var angle := TAU * float(i) / 7.0 + float(_bloom_frames) * 0.06
		var at := Vector2(cos(angle), sin(angle)) * radius * (0.45 + 0.5 * (1.0 - life))
		draw_circle(at, radius * 0.18 * life, Color(SPORE, 0.75 * life))
