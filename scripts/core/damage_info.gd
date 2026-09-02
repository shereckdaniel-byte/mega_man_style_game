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
