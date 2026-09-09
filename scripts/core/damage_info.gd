## One instance of damage, in flight from a Hitbox to a Hurtbox.
##
## RefCounted rather than a Dictionary so the fields are typed and a typo in a
## key name is a parse error rather than a silent zero. Cheap to allocate: one
## per overlap, not one per frame.
class_name DamageInfo
extends RefCounted

## Flags ride along with the hit so a weapon can say something about *how* it
## lands without needing its own code path in Health.
const NONE := 0
## Locks the target instead of (or as well as) hurting it -- archetype 7.
const STUN := 1
## Passes through the target rather than being consumed by it.
const PIERCE := 2
## Damage without the knockback, for hits that should not move the player.
const NO_KNOCKBACK := 4
## Hurts, but never to zero: the target is left on one point instead of dying.
##
## For a scripted encounter that is not allowed to end the run. The rival duel
## is the one that needed it -- docs/PLAN.md section 1 asks for "a scripted
## mid-stage duel with an unbeatable, **non-lethal** rival", and a rival who can
## kill you turns a set piece into a boss fight with no reward.
##
## **A flag on the hit rather than a state on the target**, for the same reason
## every other flag here is: the property belongs to the attack. A "cannot die
## right now" mode on `Health` would have to be switched on when the duel starts
## and off when it ends, and the frame it was left on by mistake is a frame the
## player is immortal for the rest of the run.
const NON_LETHAL := 8

var amount: int
var source_position: Vector2
var weapon_id: StringName
var flags: int


func _init(p_amount: int = 1, p_source_position: Vector2 = Vector2.ZERO,
		p_weapon_id: StringName = &"buster", p_flags: int = NONE) -> void:
	amount = p_amount
	source_position = p_source_position
	weapon_id = p_weapon_id
	flags = p_flags


func has_flag(flag: int) -> bool:
	return flags & flag != 0
