## Persistent run progress. Owns nothing that lives in the active scene tree.
##
## Stage/boss identity is a bit index (0-7) so progress packs into the save and
## the password grid without a name table (docs/ARCHITECTURE.md section 8).
extends Node

signal boss_defeated(boss_index: int)
signal lives_changed(lives: int)
signal etanks_changed(etanks: int)

enum Item { COIL = 0, JET = 1, MARINE = 2 }

const BOSS_COUNT := 8
const MAX_ETANKS := 9
const STARTING_LIVES := 2

## Bitmask, one bit per boss index.
var bosses_defeated: int = 0
## Bitmask over Item.
var items_unlocked: int = 0
var etanks: int = 0
var lives: int = STARTING_LIVES

## Stage currently being played, or -1 on the stage select / title.
var current_stage: int = -1
## Respawn point within the current stage, in global coordinates. Only meaningful
## when `checkpoint_set` is true -- Vector2.ZERO is a legitimate world position,
## so it cannot double as "no checkpoint yet" and a stage that forgot to set one
## would silently respawn the player at the world origin.
var checkpoint: Vector2 = Vector2.ZERO
var checkpoint_set: bool = false


func reset() -> void:
	bosses_defeated = 0
	items_unlocked = 0
	etanks = 0
	lives = STARTING_LIVES
	current_stage = -1
	clear_checkpoint()
	lives_changed.emit(lives)
	etanks_changed.emit(etanks)


func set_checkpoint(position: Vector2) -> void:
	checkpoint = position
	checkpoint_set = true


func clear_checkpoint() -> void:
	checkpoint = Vector2.ZERO
	checkpoint_set = false


## The checkpoint if one has been reached, otherwise the fallback -- normally
## the stage's own entry point.
func respawn_position(fallback: Vector2) -> Vector2:
	return checkpoint if checkpoint_set else fallback


func is_boss_defeated(index: int) -> bool:
	return bosses_defeated & (1 << index) != 0


func mark_boss_defeated(index: int) -> void:
	if is_boss_defeated(index):
		return
	bosses_defeated |= 1 << index
	boss_defeated.emit(index)


func has_item(item: Item) -> bool:
	return items_unlocked & (1 << int(item)) != 0


func unlock_item(item: Item) -> void:
	items_unlocked |= 1 << int(item)


func add_etank() -> bool:
	if etanks >= MAX_ETANKS:
		return false
	etanks += 1
	etanks_changed.emit(etanks)
	return true


func consume_etank() -> bool:
	if etanks <= 0:
		return false
	etanks -= 1
	etanks_changed.emit(etanks)
	return true


func add_life(delta: int = 1) -> void:
	lives += delta
	lives_changed.emit(lives)


## Returns false when that was the last life.
func consume_life() -> bool:
	lives -= 1
	lives_changed.emit(lives)
	return lives >= 0


func to_dict() -> Dictionary:
	return {
		"bosses_defeated": bosses_defeated,
		"items_unlocked": items_unlocked,
		"etanks": etanks,
		"lives": lives,
	}


func from_dict(data: Dictionary) -> void:
	bosses_defeated = int(data.get("bosses_defeated", 0))
	items_unlocked = int(data.get("items_unlocked", 0))
	etanks = clampi(int(data.get("etanks", 0)), 0, MAX_ETANKS)
	lives = int(data.get("lives", STARTING_LIVES))
	lives_changed.emit(lives)
	etanks_changed.emit(etanks)
