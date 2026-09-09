## The stage select, and the roster behind it.
##
## What this really guards is that **the grid does not move**. Most of the eight
## stages are unbuilt, and the tempting thing is to list only what exists -- which
## makes the screen change shape every time a stage lands. A select screen's whole
## interface is the player's memory of where a stage *is*, so the cells are fixed
## from the start and the unbuilt ones refuse rather than disappear.
extends TestCase

const SELECT := preload("res://scenes/ui/stage_select.gd")

var select: CanvasLayer
var state: Node


func is_async() -> bool:
	return true


func before_each_async() -> void:
	state = tree.root.get_node_or_null(^"GameState")
	if state != null:
		state.bosses_defeated = 0
	select = SELECT.new()
	tree.root.add_child(select)
	await tree.physics_frame


func after_each_async() -> void:
	if is_instance_valid(select):
		select.queue_free()
	if state != null:
		state.bosses_defeated = 0
	await tree.physics_frame


# --- The roster ----------------------------------------------------------------

func test_the_roster_has_all_eight_and_they_match_the_save_bits() -> void:
	assert_eq(StageRoster.ENTRIES.size(), 8)
	for i in StageRoster.ENTRIES.size():
		assert_eq(int(StageRoster.ENTRIES[i]["index"]), i,
			"entry %d declares index %s -- these are save bits, not list order"
				% [i, StageRoster.ENTRIES[i]["index"]])


func test_every_roster_entry_has_a_portrait_on_disk() -> void:
	for row in StageRoster.ENTRIES:
		assert_true(ResourceLoader.exists(String(row["frames"])),
			"%s has no sprite frames at %s" % [row["boss"], row["frames"]])


## The stages that exist must be reachable, and the ones that do not must say so
## rather than pointing at a scene that is not there.
func test_built_stages_are_the_ones_with_a_scene() -> void:
	var built := StageRoster.built()
	assert_true(built.has(0), "Dawn Boardwalk should be built")
	assert_true(built.has(1), "Substation should be built")
	assert_true(built.has(2), "Breakers should be built")
	for row in StageRoster.ENTRIES:
		var path: String = row["scene"]
		if path.is_empty():
			continue
		assert_true(ResourceLoader.exists(path),
			"%s names a scene that is not on disk: %s" % [row["boss"], path])


## Every boss owns exactly one cell, and the centre owns none.
func test_the_grid_places_all_eight_and_leaves_the_centre_free() -> void:
	assert_eq(StageRoster.GRID.size(), 8)
	var seen := {}
	for i in 8:
		var cell := StageRoster.grid_position(i)
		assert_false(seen.has(cell), "two bosses share cell %s" % cell)
		seen[cell] = true
		assert_ne(cell, StageRoster.CENTRE, "boss %d is in the fortress slot" % i)
	assert_eq(StageRoster.at(StageRoster.CENTRE), -1)


# --- The screen ----------------------------------------------------------------

func test_it_opens_on_a_stage_that_can_be_entered() -> void:
	var index: int = select.selected_index()
	assert_true(index >= 0, "opened on the fortress")
	assert_true(StageRoster.is_built(index),
		"opened on %s, which is not built" % StageRoster.entry(index)["boss"])


func test_the_cursor_wraps_in_both_axes() -> void:
	select.cursor = Vector2i(0, 0)
	select.move_cursor(Vector2i(-1, 0))
	assert_eq(select.cursor, Vector2i(2, 0))
	select.move_cursor(Vector2i(0, -1))
	assert_eq(select.cursor, Vector2i(2, 2))
	select.move_cursor(Vector2i(1, 1))
	assert_eq(select.cursor, Vector2i(0, 0))


## **All eight stages are built, and this test used to be about the ones that
## were not.**
##
## It picked the first stage the roster still called unbuilt and checked that
## the select screen refused it by name -- deliberately not a hard-coded index,
## because it named Breakers until stage 3 landed and then failed on it, and a
## test edited every time a stage ships is a test that gets edited into passing.
##
## What it could not survive was the roster filling up. It said so itself when
## Sinkhole landed ("every stage is built; this test has nothing to check"),
## which is the right way for a test to become obsolete: loudly, on the run that
## obsoletes it, rather than by quietly passing over an empty loop.
##
## The by-name refusal path is not dead -- the fortress still uses it, and
## `test_the_fortress_is_refused` covers that -- so what is left worth pinning
## here is the guard the path hangs off, and the milestone itself.
func test_every_stage_in_the_roster_is_built() -> void:
	var unbuilt: Array[String] = []
	for row in StageRoster.ENTRIES:
		if not StageRoster.is_built(int(row["index"])):
			unbuilt.append(String(row["stage"]))
	assert_eq(unbuilt.size(), 0, "still unbuilt: %s" % ", ".join(unbuilt))
	assert_eq(StageRoster.built().size(), 8, "there are eight stages")


## And the guard still refuses anything it cannot load, which is what the
## refusal above was built on and what will catch a stage whose scene is
## renamed or deleted.
func test_is_built_refuses_what_is_not_on_disk() -> void:
	assert_false(StageRoster.is_built(99), "an index off the end reads as built")
	assert_false(StageRoster.is_built(-1), "a negative index reads as built")
	assert_true(StageRoster.entry(99).is_empty(), "an index off the end has a row")


func test_the_fortress_is_refused() -> void:
	var said: Array[String] = []
	select.refused.connect(func(m: String) -> void: said.append(m))
	select.cursor = StageRoster.CENTRE
	assert_false(select.confirm())
	assert_true(said.size() == 1 and said[0].contains("FORTRESS"), "said %s" % str(said))


## Every cell exists whether or not its stage does. This is the one that stops a
## later "only show what is built" from quietly reshaping the grid.
func test_all_nine_cells_are_present_including_the_unbuilt_ones() -> void:
	for y in 3:
		for x in 3:
			assert_not_null(select.cell_node(Vector2i(x, y)),
				"no cell at %d,%d" % [x, y])


func test_a_cleared_boss_is_marked_on_the_grid() -> void:
	if state == null:
		return
	state.mark_boss_defeated(0)
	select._refresh()
	var cell: Control = select.cell_node(StageRoster.grid_position(0))
	var stage_label: Label = cell.get_node(^"Stage")
	assert_true(stage_label.text.contains("CLEARED"),
		"a beaten boss should read as cleared, said %s" % stage_label.text)
