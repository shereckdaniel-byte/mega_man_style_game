## Gale Cutter -- archetype 8, the returning throwable.
##
## Thrown level, it **rises as it flies** and then **comes back to whoever threw
## it**, and it does not stop at anything on either leg. One throw therefore
## covers three lines rather than one: knee height where it leaves, above head
## height where it turns, and a diagonal home that is steeper the further the
## player has moved in the meantime.
##
## ### Why the outbound leg rises
##
## Because it is a wind blade and because it is the whole of "multi-angle".
##
## The player's `fire()` has no branch per weapon and adding one would be the
## first -- the projectile comes from the weapon's resource and nothing about
## firing knows which weapon it is. So a cutter that picked its angle from an
## aim input would mean teaching the player about aiming for exactly one weapon
## in eight. `LIFT_PF` gets the same coverage out of a number: over a full
## outbound leg the blade climbs past the top of a standing player, so a turret
## bolted above the walkway and a walker on it are both on the arc.
##
## ### Why the return homes at the player rather than retracing
##
## Retracing makes the return leg a second copy of the first, which is one line
## and not two. Homing makes the weapon **about where you stand while it is
## away** -- throw it into a corridor, walk somewhere better, and it cuts a new
## line getting back to you. Nothing else in the arsenal asks anything of the
## player after the trigger.
##
## It is not the Arc Lance twice over: the Lance turns towards the *enemy* and
## is a weapon for things that will not hold still. This turns towards *you*.
##
## ### Why a wall turns it round instead of eating it
##
## Every other player shot in the game stops at terrain, which is the convention
## and is right for them. A boomerang that could be lost to a wall would be a
## weapon you stop throwing near walls, and near walls is where the coverage is
## worth having. So the wall is the turn: the blade uses it, and a throw down a
## corridor you cannot walk into comes back with whatever was in there hit twice.
##
## ### It is not caught for ammo back
##
## The obvious flourish -- refund the tick when the blade reaches you -- makes
## the weapon free, because a throw into the wall two feet away also returns.
## There is no version of the refund that survives that, so there is no refund.
## `max_on_screen` is what limits it instead.
class_name CutterShot
extends WeaponShot

## Square, because it spins. Wider than a pellet: it is thrown, not fired.
const SIZE_NES := Vector2(12.0, 12.0)

## Travel out, NES px/frame. Under the buster's 5.0 -- the blade is heavy, and
## it is on screen for two legs rather than one.
const DEFAULT_SPEED_PF := 4.5
## Travel home. **Above the outbound speed and above `walk_speed_pf` (1.375)**,
## so a player who throws and keeps running is still caught up with. A return
## the player can outrun is a return that never arrives.
const DEFAULT_RETURN_SPEED_PF := 5.5
## How far out it goes before turning, in NES px. The view is about 426 NES px
## across, so this is a comfortable half-screen: far enough to be worth throwing
## ahead, short enough that the turn happens where the player can see it.
const DEFAULT_RANGE_NES := 150.0
## Climb per frame on the outbound leg, in NES px. Over `DEFAULT_RANGE_NES` at
## `DEFAULT_SPEED_PF` that is about 33 frames and a 30 px rise -- more than a
## standing player is tall (24), which is the point of the number.
const DEFAULT_LIFT_PF := 0.9

## Frames the blade keeps looking for a thrower who is no longer there before it
## gives up. A player who dies mid-throw leaves a blade with nowhere to go, and
## a blade that hangs in the air forever is worse than one that fades.
const ORPHAN_FRAMES := 90
## Absolute cap, in frames. Nothing should reach it -- the return is faster than
## the player can move -- so reaching it means something is wrong and the right
## outcome is a blade that leaves rather than one that stays wrong forever.
const LIFETIME_FRAMES := 300

const EDGE := Color(0.86, 0.96, 1.0)
const BODY := Color(0.42, 0.72, 0.86)

## Degrees the drawn blade spins per frame. Cosmetic only.
const SPIN_DEG := 22.0

var _heading := Vector2.RIGHT
var _speed := 0.0
var _returning := false
## World distance covered on the outbound leg, against which the range is
## measured. Counted rather than compared against the launch point, so a blade
## that turned early at a wall does not get its range back.
var _travelled := 0.0
var _orphan_frames := 0
var _thrower: Node2D = null


func shot_size() -> Vector2:
	return SIZE_NES


## True once the blade has turned for home.
func is_returning() -> bool:
	return _returning


func heading() -> Vector2:
	return _heading


func _configure() -> void:
	_heading = Vector2(float(direction()), 0.0)
	_speed = tuning().px_s(number(&"speed_pf", DEFAULT_SPEED_PF))
	# It passes through what it hits and hurts it again on the way back. The
	# victim's own i-frames are what stop the two legs from stacking into one
	# long grind, which is why there is no per-leg bookkeeping here.
	one_shot = false
	_thrower = _find_thrower()


func _advance(delta: float) -> void:
	if frames_alive() > LIFETIME_FRAMES:
		queue_free()
		return
	if _returning:
		_steer_home()
	else:
		_climb()
	var step := _heading * _speed * delta
	position += step
	if not _returning:
		_travelled += step.length()
		if _travelled >= number(&"range_nes", DEFAULT_RANGE_NES) * tuning().world_scale:
			turn_for_home()
	rotation += deg_to_rad(SPIN_DEG) * delta * 60.0


## The wind under the blade. Applied to the heading rather than to the position
## so the sprite's travel and its drawn angle stay the same thing.
func _climb() -> void:
	var lift := tuning().px_s(number(&"lift_pf", DEFAULT_LIFT_PF))
	_heading = (_heading * _speed + Vector2.UP * lift).normalized()


## Turns the blade round: back towards the thrower, at the return speed, and
## with the range spent. Public because a wall calls it too.
func turn_for_home() -> void:
	if _returning:
		return
	_returning = true
	_speed = tuning().px_s(number(&"return_speed_pf", DEFAULT_RETURN_SPEED_PF))
	_steer_home()


## Points at the thrower. Straight at them rather than turned towards them by a
## rate: this is not a guided shot, it is a thing on a string, and a turn rate
## would give a running player a way to shake it off.
func _steer_home() -> void:
	if _thrower == null or not is_instance_valid(_thrower):
		_thrower = _find_thrower()
	if _thrower == null or not is_instance_valid(_thrower):
		_orphan_frames += 1
		if _orphan_frames >= ORPHAN_FRAMES:
			queue_free()
		return
	_orphan_frames = 0
	var wanted := _thrower.global_position - global_position
	if wanted.length() < 0.001:
		queue_free()
		return
	_heading = wanted.normalized()


## The player, found among the level's children.
##
## The launch signature is shared by every weapon and says nothing about who
## fired -- a pellet does not care. Rather than widen it for one weapon, the
## blade looks: it is parented to the level, the player is too, and `is Player`
## is exact where a name or a group would be a convention to remember.
func _find_thrower() -> Node2D:
	var level := get_parent()
	if level == null:
		return null
	for child in level.get_children():
		if child is Player:
			return child as Node2D
	return null


## Terrain turns it round on the way out and is ignored on the way home -- a
## blade that stopped dead against the wall it had just passed through would
## strand itself. `WeaponShot`'s default frees the shot here, which is right for
## every weapon that ends at what it hits and wrong for the one that comes back.
func _on_body_entered(_body: Node2D) -> void:
	turn_for_home()


## Piercing: the blade carries on through whatever it hit. The base frees here.
func _on_hit(_hurtbox: Hurtbox, _taken: int) -> void:
	pass


func _draw() -> void:
	var scale := tuning().world_scale
	var half := SIZE_NES.x * 0.5 * scale
	# Two crossed blades rather than a disc, so the spin is legible at speed.
	for turn in [0.0, PI * 0.5]:
		var along := Vector2.RIGHT.rotated(turn)
		var across := Vector2.DOWN.rotated(turn)
		draw_colored_polygon(PackedVector2Array([
			along * half,
			across * half * 0.34,
			-along * half * 0.34,
			-across * half * 0.34,
		]), BODY)
	draw_circle(Vector2.ZERO, half * 0.3, EDGE)
