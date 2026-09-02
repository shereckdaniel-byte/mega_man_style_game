## What a given weapon does to a given entity.
##
## Values are **absolute damage, not multipliers** (docs/ARCHITECTURE.md section
## 5.2). NES games used flat tables, and a flat value is easier to balance and
## far easier to read in a diff than a multiplier applied to a base somewhere
## else. A weakness is just a bigger number in this table.
##
## One resource per entity, in resources/damage_tables/.
class_name DamageTable
extends Resource

## Matches the entity this table belongs to, for readability and for the tests.
@export var entity_id: StringName = &""

## weapon_id -> absolute damage. A weapon that is not listed does whatever
## damage the hit itself carried, which is what makes the buster's 1 work
## without every table having to spell it out.
@export var by_weapon: Dictionary = {}

## Weapons listed here do nothing at all -- for an enemy immune to a weapon,
## which is a different thing from one that merely resists it.
@export var immune_to: Array[StringName] = []


func damage_for(weapon_id: StringName, fallback: int) -> int:
	if immune_to.has(weapon_id):
		return 0
	return int(by_weapon.get(weapon_id, fallback))


func is_immune(weapon_id: StringName) -> bool:
	return immune_to.has(weapon_id)
