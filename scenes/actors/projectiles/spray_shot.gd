## Cinder Spray -- archetype 1, the rapid low-damage spread.
##
## One trigger pull throws `PELLETS` embers in a fan, each doing very little.
## It is the arsenal's answer to **a lot of small things at once**, and it is the
## only weapon in the game whose value goes up the more targets are on screen --
## every other one is worth the same against a crowd as against a wall.
##
## ### Why the pellets are short-lived rather than short-ranged
##
## A fan that reached across the room would be a shotgun at every distance,
## which is a sniper rifle with extra steps. `LIFETIME_FRAMES` is what makes it a
## close-quarters weapon: the embers die at about a third of a screen, so
## choosing the Spray is choosing to be near the thing you are shooting. That is
## the cost the damage number does not have to carry, and it is why each ember
## can be worth a real hit rather than a scratch.
##
## ### Why they fall
##
## `GRAVITY_PF` bends the fan downward over its life, so the spread covers a
## *cone* of ground rather than a line of air. A swarm in this game is walkers
## and crawlers on a deck, and a flat fan misses most of them by aiming where
## nothing is standing. It also means the weapon reads as embers off a fire
## rather than as a triple buster.
##
## ### It is Cinder's own attack
##
## Cinder's Ashfall throws a fan of embers that settle onto the deck, and being
## handed that is the trade a weapon-get is supposed to feel like -- the same
## argument Rust Bloom and Prism Ray are built on.
class_name SprayShot
extends WeaponShot

const SIZE_NES := Vector2(5.0, 5.0)

## Embers per shot. Three, because the fan has to read as a fan at a glance and
## five at this size is a cloud whose edges nobody can judge.
const DEFAULT_PELLETS := 3
## Total half-angle of the fan, in degrees.
const DEFAULT_SPREAD_DEG := 15.0
## Travel, NES px/frame. Faster than the buster's 5.0 -- an ember is light, and
## a slow spread is one the player watches instead of aims.
const DEFAULT_SPEED_PF := 5.6
## Downward pull on an ember, in NES px/frame^2. Well under the player's 0.25:
## the fan should sag, not drop.
const DEFAULT_GRAVITY_PF := 0.055
## How long an ember lives. About a third of a screen at the speed above, which
## is what makes this a weapon you close with.
const LIFETIME_FRAMES := 42

const CORE := Color(1.0, 0.94, 0.72)
const EMBER := Color(1.0, 0.58, 0.20)
const SMOKE := Color(0.42, 0.34, 0.34)

## Set on every ember but the first, so one trigger pull makes one shot's worth
## of `max_on_screen` rather than three.
var _is_extra := false
var _heading := Vector2.RIGHT
var _speed := 0.0
var _fall := 0.0


func shot_size() -> Vector2:
	return SIZE_NES


## Marks this ember as one of the fan's outriders, launched by the first.
func become_extra(heading: Vector2) -> void:
	_is_extra = true
	_heading = heading.normalized()


func is_extra() -> bool:
	return _is_extra


func heading() -> Vector2:
	return _heading


func _configure() -> void:
	_speed = tuning().px_s(number(&"speed_pf", DEFAULT_SPEED_PF))
	_fall = tuning().px_s2(number(&"gravity_pf", DEFAULT_GRAVITY_PF))
	if not _is_extra:
		_heading = Vector2(float(direction()), 0.0)
		_throw_fan()


## The rest of the fan, launched from the same muzzle on the same frame.
##
## **Only the shot the player fired is counted against `max_on_screen`.** The
## outriders are parented to the level like any other projectile but are never
## added to the player's own list, because a cap of 3 that a single trigger pull
## fills is a weapon that fires once.
func _throw_fan() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var pellets := int(number(&"pellets", float(DEFAULT_PELLETS)))
	if pellets <= 1:
		return
	var spread := deg_to_rad(number(&"spread_deg", DEFAULT_SPREAD_DEG))
	# Evenly either side of the centre line, which is the shot the player aimed.
	for i in range(1, pellets):
		var step := spread * (float((i + 1) / 2) / float(pellets / 2 + 1))
		var turn := step if i % 2 == 1 else -step
		var ember := (get_script() as GDScript).new() as SprayShot
		ember.launch(_spawn_position, direction(), tuning(), data)
		ember.become_extra(_heading.rotated(turn))
		parent.add_child(ember)


func _advance(delta: float) -> void:
	if frames_alive() > LIFETIME_FRAMES:
		queue_free()
		return
	# The sag. Applied to the heading rather than to the position so the drawn
	# angle and the travel stay the same thing.
	_heading = (_heading * _speed + Vector2.DOWN * _fall * float(frames_alive()) * delta).normalized()
	position += _heading * _speed * delta
	rotation = _heading.angle()


func _draw() -> void:
	var scale := tuning().world_scale
	var radius := SIZE_NES.x * scale * 0.5
	# A short trail behind it, so a fan of three reads as three moving things
	# rather than three dots.
	draw_line(Vector2(-radius * 3.4, 0.0), Vector2.ZERO, Color(SMOKE, 0.5),
		radius * 0.7)
	draw_circle(Vector2.ZERO, radius, EMBER)
	draw_circle(Vector2.ZERO, radius * 0.48, CORE)
