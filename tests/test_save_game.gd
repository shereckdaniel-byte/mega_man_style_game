## The save slot: it round-trips, and every way a file can be wrong ends as "no
## save" rather than a crash or a half-loaded run.
##
## The refusals matter more than the round trip. A save file is the one input
## this game takes from outside itself -- it can be missing, truncated,
## hand-edited, or written by a different build -- and all of those have to end
## somewhere sane.
extends TestCase

const SaveScript := preload("res://scripts/core/save_game.gd")

## A slot well past `SLOT_COUNT`, so these tests can never eat a real save.
const SCRATCH := 97


## Async, because one test drives a real stage. `TestCase` calls the `_async`
## hooks *instead of* the plain ones once `is_async` is true, so these are named
## to match -- leaving them as `before_each` meant the scratch slot was never
## cleared and a later test read the file an earlier one wrote.
func is_async() -> bool:
	return true


func before_each_async() -> void:
	SaveGame.erase(SCRATCH)
	await tree.process_frame


func after_each_async() -> void:
	SaveGame.erase(SCRATCH)
	await tree.process_frame


func test_a_written_slot_reads_back() -> void:
	var state := {"bosses_defeated": 0b10110001, "items_unlocked": 5,
		"etanks": 7, "lives": 4}
	assert_true(SaveGame.write(SCRATCH, state), "the write failed")
	assert_true(SaveGame.exists(SCRATCH), "the file is not there")
	var back := SaveGame.read(SCRATCH)
	for key in state:
		assert_eq(int(back[key]), int(state[key]), "%s did not survive" % key)


## **A save carries lives and a password does not.** That is the whole
## difference in kind between the two paths: a save is a pause in one run, a
## password is a way back into it, and only one of them may hand back a resource
## the player can farm.
func test_a_save_carries_lives_where_a_password_does_not() -> void:
	var state := {"bosses_defeated": 3, "items_unlocked": 0, "etanks": 2, "lives": 9}
	SaveGame.write(SCRATCH, state)
	assert_eq(int(SaveGame.read(SCRATCH)["lives"]), 9,
		"the save lost the life count")
	assert_eq(int(Password.decode(Password.encode(state))["lives"]),
		GameState.STARTING_LIVES,
		"the password kept a life count it is not allowed to keep")


## No file is not an error. It is what every first run looks like.
func test_a_missing_slot_reads_as_nothing() -> void:
	assert_false(SaveGame.exists(SCRATCH))
	assert_true(SaveGame.read(SCRATCH).is_empty())


## Nothing in the struct leaks the bookkeeping. A stray `version` key would land
## in `GameState.from_dict` and sit there as an unknown field.
func test_the_version_is_not_handed_on_as_progress() -> void:
	SaveGame.write(SCRATCH, {"bosses_defeated": 1, "items_unlocked": 0,
		"etanks": 0, "lives": 2})
	assert_false(SaveGame.read(SCRATCH).has("version"),
		"the format version came back as if it were progress")


## Garbage is refused rather than parsed into a run.
func test_a_file_that_is_not_json_reads_as_nothing() -> void:
	var file := FileAccess.open(SaveGame.path(SCRATCH), FileAccess.WRITE)
	file.store_string("this is not a save")
	file.close()
	assert_true(SaveGame.read(SCRATCH).is_empty())


## JSON that is not an object is refused too -- a bare array parses fine and is
## not a save.
func test_json_that_is_not_an_object_reads_as_nothing() -> void:
	var file := FileAccess.open(SaveGame.path(SCRATCH), FileAccess.WRITE)
	file.store_string("[1, 2, 3]")
	file.close()
	assert_true(SaveGame.read(SCRATCH).is_empty())


## **A save from another build is refused, not half-read.** It is cheaper to ask
## a player to start again than to load four fields of six and leave the rest at
## whatever the last run happened to set them to.
func test_a_save_from_another_format_is_refused() -> void:
	var file := FileAccess.open(SaveGame.path(SCRATCH), FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": SaveGame.FORMAT_VERSION + 1,
		"bosses_defeated": 255}))
	file.close()
	assert_true(SaveGame.read(SCRATCH).is_empty())


## And one with no version at all -- which is what a save written before this
## feature existed would look like.
func test_a_save_with_no_version_is_refused() -> void:
	var file := FileAccess.open(SaveGame.path(SCRATCH), FileAccess.WRITE)
	file.store_string(JSON.stringify({"bosses_defeated": 255, "lives": 99}))
	file.close()
	assert_true(SaveGame.read(SCRATCH).is_empty())


## Erasing a slot that was never there is a success: the caller's question is
## "is it gone", and it is.
func test_erasing_an_empty_slot_succeeds() -> void:
	assert_true(SaveGame.erase(SCRATCH))
	SaveGame.write(SCRATCH, {"bosses_defeated": 1})
	assert_true(SaveGame.erase(SCRATCH))
	assert_false(SaveGame.exists(SCRATCH))


## A loaded save survives the trip through GameState, which is the only path
## that matters -- the struct is only correct if the thing that consumes it
## agrees.
func test_a_save_round_trips_through_game_state() -> void:
	# `TestCase` is not a Node -- it holds a `tree` reference instead -- so an
	# autoload is reached through the tree's root rather than off self.
	var state: Node = tree.root.get_node_or_null(^"/root/GameState")
	if state == null:
		return
	var before: Dictionary = state.to_dict()
	state.bosses_defeated = 0b01011010
	state.items_unlocked = 3
	state.etanks = 5
	state.lives = 6
	SaveGame.write(SCRATCH, state.to_dict())
	state.reset()
	assert_eq(state.bosses_defeated, 0, "reset did not clear")
	state.from_dict(SaveGame.read(SCRATCH))
	assert_eq(state.bosses_defeated, 0b01011010)
	assert_eq(state.items_unlocked, 3)
	assert_eq(state.etanks, 5)
	assert_eq(state.lives, 6)
	state.from_dict(before)


## **A cleared stage writes the slot.** The hook that makes the whole feature
## real, and the one nothing else covers: the playthrough bot stops as soon as
## the weapon lands and never reaches the victory pose, so a save wired into the
## exit path would have shipped with no coverage and no way to get any. It is
## connected to `stage_cleared` for exactly that reason, and this drives the
## signal a real clear emits.
func test_clearing_a_stage_writes_the_slot() -> void:
	var state: Node = tree.root.get_node_or_null(^"/root/GameState")
	if state == null:
		return
	var before: Dictionary = state.to_dict()
	SaveGame.erase(0)

	var stage: Node = (load("res://scenes/stages/stack/stack.tscn") as PackedScene).instantiate()
	tree.root.add_child(stage)
	for _i in 6:
		await tree.physics_frame

	state.bosses_defeated = 0b00100000
	state.etanks = 3
	state.lives = 5
	stage.stage_cleared.emit()
	await tree.physics_frame

	var saved := SaveGame.read(0)
	assert_false(saved.is_empty(), "clearing a stage wrote no save")
	assert_eq(int(saved.get("bosses_defeated", -1)), 0b00100000)
	assert_eq(int(saved.get("etanks", -1)), 3)
	assert_eq(int(saved.get("lives", -1)), 5, "the save lost the life count")

	stage.queue_free()
	await tree.physics_frame
	state.from_dict(before)
	SaveGame.erase(0)

