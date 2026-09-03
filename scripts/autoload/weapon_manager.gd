## Unlocked weapons, current selection, and ammo.
##
## The buster is always available and has no ammo. Everything else is unlocked by
## defeating its boss and drains on fire.
##
## The catalogue is loaded by scanning `res://resources/weapons/`, not by a hard
## list here. Adding a weapon is then a `.tres` and a projectile script, and this
## file never has to hear about it -- which is the point of WeaponData holding
## the per-weapon numbers.
extends Node

signal weapon_changed(weapon_id: StringName)
signal ammo_changed(weapon_id: StringName, ammo: int)

const BUSTER := &"buster"
## Fallback maximum for a weapon with no resource behind it. Real weapons carry
## their own `ammo_max`; this is what a test's bare id gets.
const AMMO_MAX := 28

const CATALOGUE_DIR := "res://resources/weapons"

var current: StringName = BUSTER
## weapon_id -> WeaponData, loaded from CATALOGUE_DIR.
var catalogue: Dictionary = {}
## weapon_id -> int. A key exists only once the weapon is unlocked.
var ammo: Dictionary = {}


func _ready() -> void:
	load_catalogue()
	reset()


func reset() -> void:
	current = BUSTER
	ammo.clear()
	weapon_changed.emit(current)


## Reads every WeaponData in CATALOGUE_DIR. Safe to call twice.
##
## Not called from `reset()`: reset is the start of a new run and happens often,
## while the catalogue is a property of the build and never changes. A test that
## wants weapon resources calls this itself.
func load_catalogue() -> int:
	catalogue.clear()
	var dir := DirAccess.open(CATALOGUE_DIR)
	if dir == null:
		return 0
	for file in dir.get_files():
		# Exported projects rename .tres to .remap; load() wants the original.
		var file_name := file.trim_suffix(".remap")
		if not file_name.ends_with(".tres"):
			continue
		var res := load(CATALOGUE_DIR.path_join(file_name))
		if res is WeaponData and (res as WeaponData).id != &"":
			catalogue[(res as WeaponData).id] = res
	return catalogue.size()


## The resource for a weapon, or null when it has none. Null is legal: ammo
## bookkeeping works from ids alone, so a test can unlock &"anything".
func data_for(weapon_id: StringName) -> WeaponData:
	return catalogue.get(weapon_id, null) as WeaponData


func current_data() -> WeaponData:
	return data_for(current)


## The weapon's own maximum, or the 28-tick default when it has no resource.
func max_ammo(weapon_id: StringName) -> int:
	var data := data_for(weapon_id)
	return data.ammo_max if data != null else AMMO_MAX


## What one shot costs. The buster is free, which is what makes it the fallback
## when everything else is dry.
func cost_of(weapon_id: StringName) -> int:
	if weapon_id == BUSTER:
		return 0
	var data := data_for(weapon_id)
	return data.ammo_cost if data != null else 1


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
	var full := max_ammo(weapon_id)
	ammo[weapon_id] = full
	ammo_changed.emit(weapon_id, full)


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
		return max_ammo(weapon_id)  # the buster never runs dry
	return int(ammo.get(weapon_id, 0))


## `cost` of -1 means "whatever this weapon charges", which is what callers
## should pass. An explicit cost is for the odd case that spends extra.
func can_fire(weapon_id: StringName, cost: int = -1) -> bool:
	if weapon_id == BUSTER:
		return true
	return get_ammo(weapon_id) >= (cost_of(weapon_id) if cost < 0 else cost)


## Spends ammo. Returns false (and spends nothing) when there is not enough.
func consume(weapon_id: StringName, cost: int = -1) -> bool:
	if weapon_id == BUSTER:
		return true
	var spend := cost_of(weapon_id) if cost < 0 else cost
	if not can_fire(weapon_id, spend):
		return false
	ammo[weapon_id] = get_ammo(weapon_id) - spend
	ammo_changed.emit(weapon_id, ammo[weapon_id])
	return true


func refill(weapon_id: StringName, amount: int) -> void:
	if weapon_id == BUSTER or not ammo.has(weapon_id):
		return
	ammo[weapon_id] = mini(get_ammo(weapon_id) + amount, max_ammo(weapon_id))
	ammo_changed.emit(weapon_id, ammo[weapon_id])


func refill_all() -> void:
	for id: StringName in ammo:
		var full := max_ammo(id)
		ammo[id] = full
		ammo_changed.emit(id, full)
