## Quarry Bore -- archetype 5, the piercing bore, and the last of the eight.
##
## It **passes through what it hits** instead of stopping at it. Every other
## weapon in the arsenal is spent on the first thing it touches; this one keeps
## going, which makes it the answer to things that are lined up -- a corridor of
## walkers, a crawler behind a hopper, a spawner with its own drones between you
## and it.
##
## ### Why it is capped rather than infinite
##
## `PIERCE_LIMIT` is what stops it being strictly better than the buster in
## every situation, which is the failure mode a piercing weapon has. Capped at
## three, choosing the Bore is a bet that three things are in a line; when they
## are not, an uncapped shot would still have been the best weapon and the
## choice would not have been one.
##
## It also stops the pathological case a piercing shot always has: a spawner
## producing drones into the same column faster than the shot leaves it, which
## is a weapon that never despawns and a frame budget that quietly goes.
##
## ### It stops at walls, and that is not a compromise
##
## docs/PLAN.md's archetype line says "passes *through* enemies and breakable
## blocks instead of stopping at the first thing it hits". Terrain is neither.
## A shot that went through walls would make every room's geometry irrelevant to
## aiming, which is a bigger change to the game than an arsenal slot should
## make -- and the player already has a weapon for things behind cover, which is
## the Tide Crawler running along the floor.
##
## Each target is hit **once**, tracked by instance, because a shot travelling
## slowly through a wide enemy would otherwise deliver a hit a frame for as long
## as it took to cross it -- which is not piercing, it is a drill, and it would
## do more damage to one large thing than to three small ones.
class_name BoreShot
extends WeaponShot

const SIZE_NES := Vector2(16.0, 6.0)

## Travel, NES px/frame. Fast: a bore that dawdled would let the second target
## in a line walk out of it.
const DEFAULT_SPEED_PF := 6.0
## Targets one shot may pass through, including the first.
const DEFAULT_PIERCE := 3
const LIFETIME_FRAMES := 180

const STEEL := Color(0.78, 0.80, 0.86)
const EDGE := Color(0.42, 0.45, 0.54)
const SPARK := Color(1.0, 0.86, 0.52)

var _speed := 0.0
## Instance ids already hit, so a wide target is worth one hit and not one a
## frame.
var _pierced: Dictionary = {}


func shot_size() -> Vector2:
	return SIZE_NES


## How many more things this shot may pass through.
func pierces_left() -> int:
	return maxi(int(number(&"pierce", float(DEFAULT_PIERCE))) - _pierced.size(), 0)


func _configure() -> void:
	_speed = tuning().px_s(number(&"speed_pf", DEFAULT_SPEED_PF))
	# The flag rides on the shot as well as on the resource, so a bore built in
	# a test without a `.tres` still behaves like one -- the same belt-and-braces
	# the Frost Lock's stun uses, and for the same reason.
	flags |= DamageInfo.PIERCE


func _advance(delta: float) -> void:
	if frames_alive() > LIFETIME_FRAMES:
		queue_free()
		return
	position.x += float(direction()) * _speed * delta


## Carries on through. `WeaponShot`'s default frees the shot here, which is
## right for every weapon that ends at what it hits and wrong for this one.
func _on_hit(hurtbox: Hurtbox, _taken: int) -> void:
	if hurtbox != null:
		_pierced[hurtbox.get_instance_id()] = true
	if pierces_left() <= 0:
		queue_free()


func _draw() -> void:
	var scale := tuning().world_scale
	var half := SIZE_NES * scale * 0.5
	# A drill bit: a shaft with a point on the leading end, so which way it is
	# going is legible from the shape alone.
	var tip := float(direction()) * half.x
	var back := -tip
	draw_colored_polygon(PackedVector2Array([
		Vector2(tip, 0.0),
		Vector2(back * 0.35, -half.y),
		Vector2(back, -half.y * 0.7),
		Vector2(back, half.y * 0.7),
		Vector2(back * 0.35, half.y),
	]), STEEL)
	draw_line(Vector2(back, 0.0), Vector2(tip * 0.6, 0.0), EDGE, half.y * 0.6)
	# A spark at the point, brighter the more it has left to give.
	var heat := float(pierces_left()) / float(maxi(int(number(&"pierce",
		float(DEFAULT_PIERCE))), 1))
	draw_circle(Vector2(tip * 0.86, 0.0), half.y * 0.5, Color(SPARK, 0.35 + 0.65 * heat))
