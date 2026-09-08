## Prism Ray -- archetype 3, the splitting beam.
##
## It flies level and fast, and **on the first thing it touches it becomes two**:
## the parent is spent on that target and two arms carry on past it, one angled
## up and one angled down. Walls count. So a ray fired into a wall behind a
## cluster comes back out of it along two new lines, and a ray fired at a walker
## standing under a flyer takes both.
##
## ### It is the boss's own attack, which is the point
##
## Prism's Split casts a beam that reaches the far wall and returns as two, and
## learning that pattern is learning that a beam of this kind does not stop where
## it arrives. The weapon is that fact handed over. Rust Bloom is built on the
## same trade -- the pattern the player had to live with is the one they are
## given -- and it is what a weapon-get is supposed to feel like.
##
## ### Why it splits on contact rather than after a distance
##
## A fixed-distance fork would be aimed by judging range, which is the skill Rust
## Bloom already asks for; the arsenal is meant to stay non-redundant. Splitting
## on contact makes the weapon about **what is behind what you are shooting**,
## which nothing else in the arsenal is about, and it means the fork happens
## somewhere the player chose rather than somewhere the maths landed.
##
## ### The arms cannot split again
##
## Otherwise one shot fills a room. `_generation` is what stops it, and it is
## checked rather than assumed by `tests/test_prism_ray.gd` -- an exponential
## weapon is the sort of thing that is funny once and then has to be deleted.
class_name RayShot
extends WeaponShot

const SIZE_NES := Vector2(14.0, 5.0)

## Travel, NES px/frame. Level with the buster's 5.0: a beam that is slower than
## a pellet does not read as light.
const DEFAULT_SPEED_PF := 5.0
## How far off the parent's line each arm leaves, in degrees. Wide enough to
## clear a body the parent just hit, narrow enough that both arms stay in the
## same fight rather than flying off the screen.
const DEFAULT_SPREAD_DEG := 26.0
## What an arm does. Less than the parent, because two arms plus a parent at full
## damage would make one shot worth four buster pellets for one tick of ammo.
const DEFAULT_ARM_DAMAGE := 1
const LIFETIME_FRAMES := 200

const CORE := Color(1.0, 1.0, 0.96)
const HALO := Color(0.58, 0.84, 1.0)

## 0 is the shot the player fired; 1 is an arm. Arms do not split.
var _generation := 0
var _heading := Vector2.RIGHT
var _speed := 0.0


func shot_size() -> Vector2:
	return SIZE_NES


## Marks this shot as an arm. Called by the parent before the arm enters the
## tree, so `_ready` sees the right damage.
func become_arm(heading: Vector2, damage: int) -> void:
	_generation = 1
	_heading = heading.normalized()
	amount = damage


func generation() -> int:
	return _generation


func can_split() -> bool:
	return _generation == 0


func _configure() -> void:
	if _generation == 0:
		_heading = Vector2(float(direction()), 0.0)
	_speed = tuning().px_s(number(&"speed_pf", DEFAULT_SPEED_PF))
	# An arm's damage is set by `become_arm` and must survive `WeaponShot._ready`
	# having already written the weapon's own number over it.
	if _generation == 1:
		amount = int(number(&"arm_damage", float(DEFAULT_ARM_DAMAGE)))


func _advance(delta: float) -> void:
	if frames_alive() > LIFETIME_FRAMES:
		queue_free()
		return
	position += _heading * _speed * delta
	rotation = _heading.angle()


## Splits on an enemy. `WeaponShot`'s default frees the shot here, which is right
## for every weapon that stops at what it hits and wrong for this one.
func _on_hit(_hurtbox: Hurtbox, _taken: int) -> void:
	_split()
	queue_free()


## Splits on terrain too. A wall is a thing the beam arrived at, and the pattern
## this weapon comes from is a beam arriving at a wall.
func _on_body_entered(_body: Node2D) -> void:
	_split()
	queue_free()


func _split() -> void:
	if not can_split():
		return
	var parent := get_parent()
	if parent == null:
		return
	var spread := deg_to_rad(number(&"spread_deg", DEFAULT_SPREAD_DEG))
	var arm_damage := int(number(&"arm_damage", float(DEFAULT_ARM_DAMAGE)))
	for turn in [spread, -spread]:
		var arm := (get_script() as GDScript).new() as RayShot
		# Launched from where the parent is now, not from where it started: the
		# fork has to happen at the thing that was hit, or the arms appear behind
		# the player and the weapon reads as a bug.
		arm.launch(global_position, direction(), tuning(), data)
		arm.become_arm(_heading.rotated(turn), arm_damage)
		parent.add_child(arm)


func _draw() -> void:
	var scale := tuning().world_scale
	var half := SIZE_NES * scale * 0.5
	# Arms are drawn thinner as well as weaker, so a glance says which is which.
	var thin := 1.0 if _generation == 0 else 0.62
	draw_rect(Rect2(Vector2(-half.x * 1.2, -half.y * 2.0 * thin),
		Vector2(half.x * 2.4, half.y * 4.0 * thin)), Color(HALO, 0.26))
	draw_rect(Rect2(Vector2(-half.x, -half.y * thin),
		Vector2(half.x * 2.0, half.y * 2.0 * thin)), HALO)
	draw_rect(Rect2(Vector2(-half.x, -half.y * 0.45 * thin),
		Vector2(half.x * 2.0, half.y * 0.9 * thin)), CORE)
