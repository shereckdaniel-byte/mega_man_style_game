## The fortress: the gate in front of it, the order behind it, and the chain.
##
## Nothing here builds a fortress stage -- there are none on disk while M7 is
## being written, and that is the state this has to survive as much as any
## other. What it checks is the *rules*: that the centre cell is sealed until
## the eighth master falls, that the four are walked in order rather than chosen
## from, and that a stage that has not landed yet refuses instead of crashing.
##
## The refusals get most of the file, for the same reason the password's do. A
## gate that opens correctly and also opens incorrectly is not a gate.
extends TestCase

const SELECT := preload("res://scenes/ui/stage_select.gd")
const FORTRESS_STAGE := preload("res://scenes/level/fortress_stage.gd")

var state: Node


func is_async() -> bool:
	return true


func before_each_async() -> void:
	state = tree.root.get_node_or_null(^"GameState")
	_clear()
	await tree.physics_frame


func after_each_async() -> void:
	_clear()
	await tree.physics_frame


func _clear() -> void:
	if state != null:
		state.bosses_defeated = 0
		state.fortress_progress = 0


func _beat_all_eight() -> void:
	for i in GameState.BOSS_COUNT:
		state.mark_boss_defeated(i)


# --- The gate ---------------------------------------------------------------------

## **The fortress is derived from the eight, not stored.** Seven masters is not
## seven-eighths open; it is shut.
func test_the_fortress_opens_only_on_the_eighth_master() -> void:
	for i in GameState.BOSS_COUNT:
		assert_false(state.fortress_open(),
			"the fortress was open with %d masters down" % i)
		state.mark_boss_defeated(i)
	assert_true(state.fortress_open(), "the eighth master did not open it")


## And the order the eight fall in does not matter, which is the whole promise
## of the stage select. Every one of the eight is checked as the last one.
func test_any_master_can_be_the_eighth() -> void:
	for last in GameState.BOSS_COUNT:
		_clear()
		for i in GameState.BOSS_COUNT:
			if i != last:
				state.mark_boss_defeated(i)
		assert_false(state.fortress_open(),
			"open with master %d still standing" % last)
		state.mark_boss_defeated(last)
		assert_true(state.fortress_open(),
			"master %d as the eighth did not open the fortress" % last)


# --- The order ---------------------------------------------------------------------

## The four are walked in order: the stage you are up to is the lowest one you
## have not cleared.
func test_the_fortress_is_walked_in_order() -> void:
	assert_eq(int(state.fortress_stage()), 0, "a fresh fortress does not start at 0")
	for i in GameState.FORTRESS_COUNT:
		state.mark_fortress_cleared(i)
		var expected := i + 1 if i + 1 < GameState.FORTRESS_COUNT else -1
		assert_eq(int(state.fortress_stage()), expected,
			"after clearing %d the fortress is at %s" % [i, state.fortress_stage()])


## **The lowest uncleared, not the highest cleared plus one.** The two rules
## agree while progress is contiguous and only one of them sends a player who
## somehow skipped a stage back to it.
func test_a_skipped_stage_is_still_the_one_you_are_up_to() -> void:
	state.mark_fortress_cleared(0)
	state.mark_fortress_cleared(2)
	state.mark_fortress_cleared(3)
	assert_eq(int(state.fortress_stage()), 1,
		"a skipped stage was skipped again")


## Clearing something that is not one of the four records nothing, so a stray
## index cannot set a bit that belongs to a stage.
func test_an_index_off_the_end_clears_nothing() -> void:
	state.mark_fortress_cleared(-1)
	state.mark_fortress_cleared(GameState.FORTRESS_COUNT)
	state.mark_fortress_cleared(99)
	assert_eq(state.fortress_progress, 0, "an illegal index wrote a fortress bit")


## Progress survives the save round trip, which is what puts the fortress in the
## same persistence path as everything else rather than beside it.
func test_fortress_progress_round_trips_through_a_save() -> void:
	_beat_all_eight()
	state.mark_fortress_cleared(0)
	state.mark_fortress_cleared(1)
	var saved: Dictionary = state.to_dict()
	state.fortress_progress = 0
	state.from_dict(saved)
	assert_eq(state.fortress_progress, 0b11, "the fortress did not survive a save")
	assert_eq(int(state.fortress_stage()), 2)


## **A boss that is not one of the eight sets no boss bit.** Fortress bosses,
## reprises and the rival all carry `boss_index = -1`, and the alternative --
## letting them write into `bosses_defeated` -- would either claim a master the
## player never fought or need a second bitmask to keep them out of the first.
func test_a_boss_outside_the_eight_records_nothing() -> void:
	for index in [-1, GameState.BOSS_COUNT, 99]:
		state.mark_boss_defeated(index)
		assert_eq(state.bosses_defeated, 0,
			"boss index %d wrote a bit" % index)
	# And it does not accidentally open the fortress either, which is the state
	# the bit actually feeds.
	assert_false(state.fortress_open())


# --- The roster --------------------------------------------------------------------

func test_the_fortress_roster_has_four_in_order() -> void:
	assert_eq(StageRoster.FORTRESS.size(), GameState.FORTRESS_COUNT)
	for i in StageRoster.FORTRESS.size():
		assert_eq(int(StageRoster.FORTRESS[i]["index"]), i,
			"fortress row %d declares index %s -- these are save bits, not list order"
				% [i, StageRoster.FORTRESS[i]["index"]])
		assert_false(String(StageRoster.FORTRESS[i]["name"]).is_empty())
		assert_false(String(StageRoster.FORTRESS[i]["scene"]).is_empty())


## No fortress stage may sit on one of the eight's scenes. They are different
## tables and a shared path would make one of them a lie.
func test_no_fortress_stage_reuses_a_master_stage_scene() -> void:
	var master_scenes: Array[String] = []
	for row in StageRoster.ENTRIES:
		master_scenes.append(String(row["scene"]))
	for row in StageRoster.FORTRESS:
		assert_false(master_scenes.has(String(row["scene"])),
			"%s points at a master's stage" % row["name"])


func test_a_fortress_index_off_the_end_has_no_entry() -> void:
	assert_true(StageRoster.fortress_entry(-1).is_empty())
	assert_true(StageRoster.fortress_entry(GameState.FORTRESS_COUNT).is_empty())
	assert_false(StageRoster.fortress_is_built(-1))
	assert_false(StageRoster.fortress_is_built(99))


## Whatever is on disk, `fortress_built()` reports it in order and reports only
## what can actually be loaded -- the select screen confirms straight into these
## paths, so a row it got wrong would be a hard failure on a button press.
func test_fortress_built_reports_only_what_is_on_disk() -> void:
	var built := StageRoster.fortress_built()
	for i in built:
		assert_true(ResourceLoader.exists(String(StageRoster.fortress_entry(i)["scene"])),
			"fortress stage %d is reported built and is not on disk" % i)
	for i in GameState.FORTRESS_COUNT:
		if not built.has(i):
			assert_false(StageRoster.fortress_is_built(i),
				"fortress stage %d is built and was left out" % i)


# --- The centre cell ----------------------------------------------------------------

func _select() -> CanvasLayer:
	var node: CanvasLayer = SELECT.new()
	tree.root.add_child(node)
	return node


func _confirm_centre(node: CanvasLayer) -> Array[String]:
	var said: Array[String] = []
	node.refused.connect(func(m: String) -> void: said.append(m))
	node.cursor = StageRoster.CENTRE
	node.confirm()
	return said


## Sealed, and it says what it wants: the useful half of a refusal is the reason.
func test_the_sealed_fortress_says_what_it_is_waiting_for() -> void:
	var node := _select()
	await tree.physics_frame
	var said := _confirm_centre(node)
	assert_eq(said.size(), 1, "said %s" % str(said))
	assert_true(said[0].contains("SEALED") and said[0].contains("EIGHT"),
		"the refusal does not say what opens it: %s" % said[0])
	node.queue_free()
	await tree.physics_frame


## Open, and standing on a stage that has not been built yet: it refuses by
## name, which is the same honesty the eight get -- and once every fortress
## stage is on disk the same cell stops refusing at all.
##
## Both arms assert. This is the test that would otherwise have gone quiet as
## M7 lands: the refusal branch stops being reachable, and a test whose only
## assertion is behind a branch that no longer happens is a test that passes
## over an empty loop. `fortress_refusal()` exists so the *opening* branch is
## checkable too -- confirming it would change the scene out from under the
## harness.
func test_an_open_fortress_refuses_only_what_is_not_on_disk() -> void:
	_beat_all_eight()
	var node := _select()
	await tree.physics_frame
	var stage: int = int(state.fortress_stage())
	var refusal: String = node.fortress_refusal()
	if StageRoster.fortress_is_built(stage):
		assert_eq(refusal, "",
			"a built fortress stage refused: %s" % refusal)
	else:
		assert_true(refusal.contains(
				String(StageRoster.fortress_entry(stage)["name"]).to_upper()),
			"the refusal does not name the stage: %s" % refusal)
		assert_true(refusal.contains("NOT BUILT"), refusal)
	node.queue_free()
	await tree.physics_frame


## A finished fortress refuses too, and with a different sentence. Four states
## behind one cell, and "sealed" was the wrong word for three of them.
func test_a_finished_fortress_refuses_with_its_own_words() -> void:
	_beat_all_eight()
	for i in GameState.FORTRESS_COUNT:
		state.mark_fortress_cleared(i)
	var node := _select()
	await tree.physics_frame
	var said := _confirm_centre(node)
	assert_eq(said.size(), 1, "said %s" % str(said))
	assert_true(said[0].contains("DOWN"), "said %s" % said[0])
	assert_false(said[0].contains("SEALED"),
		"a finished fortress was called sealed")
	node.queue_free()
	await tree.physics_frame


## The centre cell never becomes a boss cell, whatever the fortress is doing.
## Everything that reads the grid keys off `at(cell) < 0`.
func test_the_centre_is_never_one_of_the_eight() -> void:
	assert_eq(StageRoster.at(StageRoster.CENTRE), -1)
	_beat_all_eight()
	assert_eq(StageRoster.at(StageRoster.CENTRE), -1,
		"the centre became a boss cell once the fortress opened")


# --- The base class ------------------------------------------------------------------

## A `FortressStage` that forgets to say which one it is records nothing, rather
## than writing bit 0 and claiming the first stage.
func test_a_fortress_stage_without_an_index_records_nothing() -> void:
	assert_eq(FORTRESS_STAGE.new().fortress_index(), -1)
