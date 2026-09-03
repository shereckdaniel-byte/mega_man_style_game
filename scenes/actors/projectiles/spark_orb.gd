## Arc's seeker: a slow ball of charge that drifts after the player.
##
## The enemy-side mirror of `LanceShot`, and deliberately so -- Arc's fight shows
## the player the weapon they are about to win. Same idea, opposite end of the
## room.
##
## **What makes it fair is that it expires.** A homing shot with no lifetime is a
## shot the player must eventually be hit by, which turns a dodge into a delay;
## this one gives up after `LIFETIME_FRAMES` and fades out. Combined with a turn
## rate slow enough to be outrun, that makes "keep moving" a real answer rather
## than a stalling tactic: circle it once and it is gone.
##
## It also **stops at walls off**, like every other enemy shot (ARCHITECTURE
## section 4) -- a seeker that died on the arena's own pillar would be answerable
## by standing behind one, and there is nothing to stand behind.
class_name SparkOrb
extends EnemyShot

## Frames of straight flight before it begins to steer, so a shot fired at
## point-blank range is not glued on instantly and the player can still read
## which way it left.
const STRAIGHT_FRAMES := 10
## Maximum turn per frame, in degrees.
##
## 3.4, against LanceShot's 7. The player's weapon should out-turn the boss's:
## the same archetype in the player's hands is meant to feel like the upgrade,
## and a boss shot that turns as hard as the player's is one you cannot walk out
## of. At 3.4 a full reversal takes about 53 frames, which is a little under a
## second -- long enough to run past it.
const TURN_RATE_DEG := 3.4
## After this it fades and dies. Two seconds is long enough to chase the player
## across the arena once and not long enough to accumulate.
const LIFETIME_FRAMES := 120
## Frames of fade at the end of its life. Visible, because a shot that winks out
## teaches nothing -- watching it die is how the player learns it will.
const FADE_FRAMES := 20

const HALO := Color(0.55, 0.78, 1.0)
const CORE := Color(0.95, 0.99, 1.0)

## What it steers toward. Left null, it flies straight -- which is what happens
## when the player dies mid-flight, and is better than the alternative of
## reaching into a freed node.
var target: Node2D = null


func _physics_process(delta: float) -> void:
	if frames_alive() >= LIFETIME_FRAMES:
		queue_free()
		return
	if frames_alive() > STRAIGHT_FRAMES:
		_steer()
	super(delta)
	queue_redraw()


func _steer() -> void:
	if target == null or not is_instance_valid(target):
		return
	var wanted := target.global_position - global_position
	if wanted.length() < 0.001:
		return
	var limit := deg_to_rad(TURN_RATE_DEG)
	var turn := clampf(_velocity.angle_to(wanted.normalized()), -limit, limit)
	_velocity = _velocity.rotated(turn)


## How much of its life is left, 1 at launch and 0 at the end. Drawn as alpha,
## and read by the tests.
func remaining() -> float:
	var left := float(LIFETIME_FRAMES - frames_alive())
	return clampf(left / float(FADE_FRAMES), 0.0, 1.0)


func _draw() -> void:
	var radius := minf(size_nes.x, size_nes.y) * _tuning.world_scale * 0.5
	var alpha := remaining()
	draw_circle(Vector2.ZERO, radius * 1.35, Color(HALO.r, HALO.g, HALO.b, 0.35 * alpha))
	draw_circle(Vector2.ZERO, radius, Color(HALO.r, HALO.g, HALO.b, alpha))
	draw_circle(Vector2.ZERO, radius * 0.45, Color(CORE.r, CORE.g, CORE.b, alpha))
