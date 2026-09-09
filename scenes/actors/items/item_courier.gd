## The one-frame courier that puts a utility item into the level.
##
## ### Why this exists at all
##
## `Player.fire()` has no branch per weapon and adding one would be the first:
## it instantiates the selected weapon's `projectile_script`, adds it to the
## level, and counts it against the on-screen cap. That contract is what let
## eight weapons ship without the player script growing a case for any of them,
## and it is worth keeping.
##
## A utility item is **not a projectile**. Rush Coil is a spring that sits on the
## floor; Rush Jet is an `AnimatableBody2D` the player stands on. Neither can be
## a `WeaponShot`, which is an `Area2D` that damages things.
##
## So the projectile a utility weapon fires is this: a shot that never moves,
## never touches anything, spawns the real item beside the player and frees
## itself on the same frame. One frame of indirection buys the whole existing
## weapon system -- selection, ammo, the pause menu, the HUD bar -- for objects
## that are nothing like a shot.
##
## **It is honest about being a stand-in.** The alternative considered was making
## the items themselves subclasses of `WeaponShot` with the damage switched off,
## which works for the Coil and cannot work for the Jet, because a thing the
## player stands on has to be a body. A courier that admits it is a courier is
## better than a base class that quietly is not one.
class_name ItemCourier
extends WeaponShot

## The scene or script the courier delivers. Set by each item's own subclass,
## because `WeaponData` has no field for it and should not grow one -- the
## indirection is the projectile script's business, not the resource's.
var _delivers: GDScript = null

## How far in front of the player the item lands, in NES px. Far enough that the
## Coil is not under the player's own feet when it appears (which would launch
## them on the frame they summoned it), close enough to be obviously theirs.
const DROP_AHEAD_NES := 22.0


## Overridden by each item weapon to say what it carries.
func delivers() -> GDScript:
	return _delivers


func shot_size() -> Vector2:
	return Vector2.ONE


func _configure() -> void:
	# It touches nothing. A courier that could collide would be a projectile
	# with a delivery job, and the one thing this must not be is a projectile.
	monitoring = false
	collision_layer = 0
	collision_mask = 0
	amount = 0


func _ready() -> void:
	super()
	_deliver_item()
	queue_free()


## Puts the item in the level, one player-width ahead and on the player's own
## line. Failing silently is right here: a courier with nothing to carry is a
## misconfigured `.tres`, and the loud version of that is an error every frame
## the player holds the fire button.
func _deliver_item() -> void:
	var carried := delivers()
	if carried == null:
		push_error("item courier for %s carries nothing" % _weapon_id)
		return
	var level := get_parent()
	if level == null:
		return
	var item: Object = carried.new()
	if not (item is Node2D):
		push_error("item courier for %s carries a %s, which is not a Node2D"
			% [_weapon_id, carried.get_global_name()])
		return
	var ahead := float(direction()) * DROP_AHEAD_NES * tuning().world_scale
	(item as Node2D).position = global_position + Vector2(ahead, 0.0)
	_configure_item(item as Node2D)
	# Deferred for the reason `Pickup.drop` is: `fire()` can run from inside a
	# physics callback, and these build collision shapes in `_ready`.
	level.add_child.call_deferred(item)


## Anything the item needs that the courier knows and it does not -- chiefly
## which way the player was facing. Overridden by the rides; the Coil has no
## direction and does not need it.
func _configure_item(_item: Node2D) -> void:
	pass
