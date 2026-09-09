## Frost Lock -- archetype 7, the stun.
##
## It does almost no damage and **switches a target off for
## `Enemy.STUN_FRAMES`**. That is the whole weapon: the arsenal's other seven
## are ways of removing an enemy, and this is the only one that is a way of
## ignoring one.
##
## ### Why it does 1 and not 0
##
## docs/PLAN.md's archetype list says "often deals no damage", and zero was
## tried first. A zero-damage hit is refused before it reaches anything --
## `Health.take` has nothing to take, the `damaged` signal never fires, and the
## flag that does the freezing rides on that signal. Making the whole mechanism
## depend on a damage number being non-zero is fragile in a way nobody would
## guess from reading either file, so the bolt does 1 and the stun rides along
## with it.
##
## ### It is the answer to the things the buster is worst against
##
## A turret on a ledge, a spawner filling a corridor, a wall-crawler on the only
## route: all of them are cheap to kill and expensive to *reach*. Freezing one
## costs a tick of ammo and buys a walk past it, which is a different kind of
## solution from more damage and is why the arsenal needed one.
##
## The freeze is carried by `DamageInfo.STUN` rather than by this script, so
## `Enemy._on_damaged` does the work and any future stunning thing gets it free.
class_name LockBolt
extends WeaponShot

const SIZE_NES := Vector2(9.0, 9.0)

## Travel, NES px/frame. Slower than the buster's 5.0: a lock is a considered
## shot, and a slow bolt is one the player has to lead a moving target with.
const DEFAULT_SPEED_PF := 4.0
const LIFETIME_FRAMES := 150

const RIME := Color(0.66, 0.88, 1.0)
const CORE := Color(0.96, 1.0, 1.0)
const EDGE := Color(0.36, 0.60, 0.78)

var _speed := 0.0


func shot_size() -> Vector2:
	return SIZE_NES


func _configure() -> void:
	_speed = tuning().px_s(number(&"speed_pf", DEFAULT_SPEED_PF))
	# Belt and braces: the resource sets the flag, and a bolt constructed in a
	# test without one still stuns. A weapon whose defining behaviour depends on
	# a `.tres` being right is a weapon that silently becomes a bad buster.
	flags |= DamageInfo.STUN


func _advance(delta: float) -> void:
	if frames_alive() > LIFETIME_FRAMES:
		queue_free()
		return
	position.x += float(direction()) * _speed * delta
	rotation += deg_to_rad(6.0) * delta * 60.0


func _draw() -> void:
	var scale := tuning().world_scale
	var half := SIZE_NES.x * scale * 0.5
	# A six-pointed crystal: the only radially symmetric projectile in the game,
	# so a bolt in flight is never mistaken for a pellet.
	for i in 3:
		var angle := float(i) * PI / 3.0
		var along := Vector2.RIGHT.rotated(angle)
		draw_line(-along * half, along * half, EDGE, half * 0.62)
		draw_line(-along * half * 0.94, along * half * 0.94, RIME, half * 0.4)
	draw_circle(Vector2.ZERO, half * 0.34, CORE)
