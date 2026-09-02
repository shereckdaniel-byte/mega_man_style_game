## Unlocked weapons, current selection, and ammo.
##
## The buster is always available and has no ammo. Everything else is unlocked by
## defeating its boss and drains on fire.
extends Node

signal weapon_changed(weapon_id: StringName)
signal ammo_changed(weapon_id: StringName, ammo: int)

const BUSTER := &"buster"
const AMMO_MAX := 28

var current: StringName = BUSTER
## weapon_id -> WeaponData. Populated from res://resources/weapons at M5.
var catalogue: Dictionary = {}
## weapon_id -> int. A key exists only once the weapon is unlocked.
var ammo: Dictionary = {}


func _ready() -> void:
	reset()


func reset() -> void:
	current = BUSTER
	ammo.clear()
	weapon_changed.emit(current)


func unlocked() -> Array[StringName]:
	var out: Array[StringName] = [BUSTER]
	for id: StringName in ammo:
		out.append(id)
	return out


func is_unlocked(weapon_id: StringName) -> bool:
	return weapon_id == BUSTER or ammo.has(weapon_id)


func unlock(weapon_id: StringName) -> void:
	if weapon_id == BUSTER or ammo.has(weapon_id):
		return
	ammo[weapon_id] = AMMO_MAX
	ammo_changed.emit(weapon_id, AMMO_MAX)


func select(weapon_id: StringName) -> bool:
	if not is_unlocked(weapon_id):
		return false
	current = weapon_id
	weapon_changed.emit(current)
	return true


## Cycles the selection. Direction is +1 or -1.
func cycle(direction: int) -> void:
	var list := unlocked()
	var index := list.find(current)
	if index < 0:
		index = 0
	select(list[wrapi(index + direction, 0, list.size())])


func get_ammo(weapon_id: StringName) -> int:
	if weapon_id == BUSTER:
		return AMMO_MAX  # the buster never runs dry
	return int(ammo.get(weapon_id, 0))


func can_fire(weapon_id: StringName, cost: int = 1) -> bool:
	return weapon_id == BUSTER or get_ammo(weapon_id) >= cost


## Spends ammo. Returns false (and spends nothing) when there is not enough.
func consume(weapon_id: StringName, cost: int = 1) -> bool:
	if weapon_id == BUSTER:
		return true
	if not can_fire(weapon_id, cost):
		return false
	ammo[weapon_id] = get_ammo(weapon_id) - cost
	ammo_changed.emit(weapon_id, ammo[weapon_id])
	return true


func refill(weapon_id: StringName, amount: int) -> void:
	if weapon_id == BUSTER or not ammo.has(weapon_id):
		return
	ammo[weapon_id] = mini(get_ammo(weapon_id) + amount, AMMO_MAX)
	ammo_changed.emit(weapon_id, ammo[weapon_id])


func refill_all() -> void:
	for id: StringName in ammo:
		ammo[id] = AMMO_MAX
		ammo_changed.emit(id, AMMO_MAX)
