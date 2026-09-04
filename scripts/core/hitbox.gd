## Where an entity deals damage. Pairs with Hurtbox.
##
## This is the side that does the looking: it monitors, finds Hurtboxes, and
## hands each one a DamageInfo. Masks decide who it can reach, so the same node
## is a buster shot, an enemy's contact box or a spike, depending only on which
## layers it is set to.
class_name Hitbox
extends Area2D

## Emitted after the hit was delivered. `taken` is 0 when the target refused it,
## which is the normal case during the victim's i-frames.
signal hit(hurtbox: Hurtbox, taken: int)

@export var amount: int = 1
@export var weapon_id: StringName = &"buster"
@export var flags: int = DamageInfo.NONE

## Stops after the first hurtbox it damages -- a buster pellet is spent on one
## target. Off for contact damage, which must keep hurting while overlapping.
@export var one_shot: bool = false

## Frames between hits on the same target. 0 means every frame it overlaps,
## which the victim's own i-frames usually make moot.
@export var repeat_delay_frames: int = 0

var _spent := false
var _cooldown := 0


func _ready() -> void:
	# `monitorable` is deliberately left alone. It reads like "can other areas
	# see this one", and setting it false looks like the right way to keep a
	# hitbox from being detected -- but on Godot 4.7 it ALSO switches off this
	# area's own body detection, so a buster pellet stops colliding with walls
	# and flies through the level. Verified by toggling it on a live Area2D:
	# get_overlapping_bodies() goes 1 -> 0 -> 1 in step with the flag.
	#
	# Isolation is the masks' job instead, which is the convention anyway:
	# nothing masks its own attack layer (ARCHITECTURE section 4).
	area_entered.connect(_on_area_entered)


## Called once per physics frame by the owner when `repeat_delay_frames` or
## contact damage is in play. A projectile that hits once never needs it.
func tick() -> void:
	if _cooldown > 0:
		_cooldown -= 1
	# Contact damage has to keep landing while the boxes stay overlapped;
	# area_entered only fires on the frame the overlap begins.
	#
	# `monitoring` is checked because an Area2D that is not monitoring cannot be
	# asked for its overlaps -- Godot errors rather than returning an empty list.
	# A hitbox that is switched on and off by its owner (the crusher's teeth are
	# live only while the press is dropping) would otherwise print that error on
	# every frame it is off, and the owner would have to remember to stop
	# ticking it, which is a rule that will be forgotten by the second owner.
	if not one_shot and _cooldown == 0 and monitoring:
		for area in get_overlapping_areas():
			if area is Hurtbox:
				_deliver(area as Hurtbox)
				break


func rearm() -> void:
	_spent = false
	_cooldown = 0


func build_info() -> DamageInfo:
	return DamageInfo.new(amount, global_position, weapon_id, flags)


func _on_area_entered(area: Area2D) -> void:
	if area is Hurtbox:
		_deliver(area as Hurtbox)


func _deliver(hurtbox: Hurtbox) -> void:
	if _spent or _cooldown > 0:
		return
	var taken := hurtbox.receive(build_info())
	_cooldown = repeat_delay_frames
	if one_shot:
		_spent = true
	hit.emit(hurtbox, taken)
