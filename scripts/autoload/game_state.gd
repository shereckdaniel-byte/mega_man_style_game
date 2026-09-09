## Persistent run progress. Owns nothing that lives in the active scene tree.
##
## Stage/boss identity is a bit index (0-7) so progress packs into the save and
## the password grid without a name table (docs/ARCHITECTURE.md section 8).
extends Node

signal boss_defeated(boss_index: int)
signal fortress_cleared(fortress_index: int)
signal lives_changed(lives: int)
signal etanks_changed(etanks: int)

enum Item { COIL = 0, JET = 1, MARINE = 2 }

const BOSS_COUNT := 8
## The fortress is four stages played in order, not four stages chosen from.
## That is the one structural difference between the fortress and the eight, and
## it is why this is a count with an order rather than a second grid.
const FORTRESS_COUNT := 4
const MAX_ETANKS := 9
const STARTING_LIVES := 2

## Bitmask, one bit per boss index.
var bosses_defeated: int = 0
## Bitmask, one bit per fortress stage index.
var fortress_progress: int = 0
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
	fortress_progress = 0
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


## A boss with an index outside 0-7 records nothing: fortress bosses, reprises
## and the rival all carry -1 (see `Boss.boss_index`), and the guard lives here
## rather than at every call site so there is one place it can be wrong.
func mark_boss_defeated(index: int) -> void:
	if index < 0 or index >= BOSS_COUNT or is_boss_defeated(index):
		return
	bosses_defeated |= 1 << index
	boss_defeated.emit(index)


## The fortress is open once all eight Robot Masters are down, and not before.
##
## Deliberately a *derived* fact rather than a stored flag. A flag would be a
## second record of something `bosses_defeated` already says, and the first time
## the two disagreed the fortress would be open with a master still standing --
## or sealed after the last one fell, which is worse, because the player would
## have no way to tell what the game wanted from them.
func fortress_open() -> bool:
	for i in BOSS_COUNT:
		if not is_boss_defeated(i):
			return false
	return true


func is_fortress_cleared(index: int) -> bool:
	return fortress_progress & (1 << index) != 0


func mark_fortress_cleared(index: int) -> void:
	if index < 0 or index >= FORTRESS_COUNT or is_fortress_cleared(index):
		return
	fortress_progress |= 1 << index
	fortress_cleared.emit(index)


## The fortress stage the player is up to: the first one not yet cleared, or -1
## when the fortress is finished.
##
## **The lowest uncleared, not the highest cleared plus one.** They are the same
## number while progress is contiguous and they are not the same rule, and the
## second one sends a player who somehow cleared stage 3 straight past stage 2
## rather than back to it. The first rule cannot skip a stage; the second can
## only skip stages.
func fortress_stage() -> int:
	for i in FORTRESS_COUNT:
		if not is_fortress_cleared(i):
			return i
	return -1


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
		"fortress_progress": fortress_progress,
		"items_unlocked": items_unlocked,
		"etanks": etanks,
		"lives": lives,
	}


func from_dict(data: Dictionary) -> void:
	bosses_defeated = int(data.get("bosses_defeated", 0))
	fortress_progress = int(data.get("fortress_progress", 0))
	items_unlocked = int(data.get("items_unlocked", 0))
	etanks = clampi(int(data.get("etanks", 0)), 0, MAX_ETANKS)
	lives = int(data.get("lives", STARTING_LIVES))
	lives_changed.emit(lives)
	etanks_changed.emit(etanks)
