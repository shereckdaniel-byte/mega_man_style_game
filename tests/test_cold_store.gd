## Cold Store: the shape of the stage, the order its gimmick is taught in, and
## the one rule the whole thing rests on.
##
## The rules about the *player* live in `test_stage_authoring.gd` and apply to
## every stage. What is here is what is true of stage 7 in particular.
##
## **The reachability test below was written after the bot, and that was the
## wrong order.** Rail shipped without the shaft that reaches the room under it:
## a stage with no way past its third room, which every authoring rule passed
## because none of them knows that the next room is a band down. The bot found
## it in one run and this file would have found it in a second.
extends TestCase

const ColdStore := preload("res://scenes/stages/cold_store/cold_store.gd")
const Sheet := preload("res://scenes/level/ice_floor.gd")
const SCENE := "res://scenes/stages/cold_store/cold_store.tscn"

const SETTLE_FRAMES := 6


func is_async() -> bool:
	return true


# --- Shape ------------------------------------------------------------------------

## **Two bands, crossed five times** -- the fewest bands since stage 1 and the
## most changes between them, which is what two decks of cold rooms stacked on
## each other actually is.
func test_the_stage_zigzags_between_two_decks() -> void:
	var bands := {}
	var changes := 0
	for i in ColdStore.ROOMS.size():
		bands[int(ColdStore.ROOMS[i]["band"])] = true
		if i > 0 and int(ColdStore.ROOMS[i]["band"]) != int(ColdStore.ROOMS[i - 1]["band"]):
			changes += 1
	assert_eq(bands.size(), 2, "Cold Store is a two-deck plant")
	assert_true(changes >= 5,
		"only %d band changes; the zigzag is the shape" % changes)
	# And never more than a few rooms from a ladder, which is the promise the
	# shape makes.
	var run := 0
	var longest := 0
	for i in range(1, ColdStore.ROOMS.size()):
		if int(ColdStore.ROOMS[i]["band"]) == int(ColdStore.ROOMS[i - 1]["band"]):
			run += 1
			longest = maxi(longest, run)
		else:
			run = 0
	assert_true(longest <= 4,
		"%d rooms in one band without a crossing" % (longest + 1))


## **Every room is reachable from the one before it.** Either it is the column
## next door in the same band, or the previous room has a ladder into it.
##
## This is the test that was missing when the stage was first driven, and Rail
## shipped without its shaft: three rooms in, no way down, and every authoring
## rule green because not one of them knows what the *next* room is.
func test_every_room_is_reachable_from_the_one_before_it() -> void:
	for i in range(1, ColdStore.ROOMS.size()):
		var here: Dictionary = ColdStore.ROOMS[i - 1]
		var there: Dictionary = ColdStore.ROOMS[i]
		var same_band := int(here["band"]) == int(there["band"])
		var adjacent := absi(int(here["col"]) - int(there["col"])) == 1
		var climbs := here.has("shaft_up") and int(here["col"]) == int(there["col"]) \
			and int(there["band"]) == int(here["band"]) - 1
		var drops := here.has("shaft") and int(here["col"]) == int(there["col"]) \
			and int(there["band"]) == int(here["band"]) + 1
		assert_true((same_band and adjacent) or climbs or drops,
			"%s -> %s is not a walk or a ladder" % [here["name"], there["name"]])


# --- The ice, and the order it is taught in ---------------------------------------

func test_the_first_room_has_no_ice() -> void:
	assert_false(ColdStore.ROOMS[0].has("ice"),
		"%s takes the floor away before the player has used it"
			% ColdStore.ROOMS[0]["name"])


## Ice is taught over solid ground: no hole and no spikes in the room that
## introduces it, so the first thing learned costs nothing.
func test_ice_is_taught_over_solid_ground() -> void:
	var index := _first_room_with_ice()
	assert_true(index > 0, "no room in the stage has ice")
	var spec: Dictionary = ColdStore.ROOMS[index]
	assert_true((spec.get("gaps", []) as Array).is_empty(),
		"%s introduces ice over a hole" % spec["name"])
	assert_true((spec.get("pit_spikes", []) as Array).is_empty()
		and (spec.get("spikes", []) as Array).is_empty(),
		"%s introduces ice over spikes" % spec["name"])


## **The rule the whole stage rests on: an ice run ends before a hole does.**
##
## Every sheet must leave `STOP_MARGIN_CELLS` of grippy deck before any gap in
## its room, and that margin has to cover the distance the player actually
## slides -- computed here from `PlayerTuning` and `IceFloor.DEFAULT_GRIP`, so
## retuning either re-checks the level instead of quietly outdating it.
##
## Stage 5 paid a lot to learn that a force reaching the take-off can make
## authored gaps uncrossable and that no retuning fixes it. Ice is grounded
## only, so it never reaches the arc -- but it absolutely reaches the approach.
func test_no_ice_run_reaches_a_hole() -> void:
	var t := PlayerTuning.new()
	var slide_cells := Sheet.stopping_distance_nes(t.walk_speed_pf, Sheet.DEFAULT_GRIP) \
		/ PlayerTuning.NES_TILE
	assert_true(float(ColdStore.STOP_MARGIN_CELLS) > slide_cells,
		"the margin is %d cells and the player slides %.2f"
			% [ColdStore.STOP_MARGIN_CELLS, slide_cells])

	for spec in ColdStore.ROOMS:
		for entry in spec.get("ice", []):
			var from := int(entry["from"])
			var to := int(entry["to"])
			for gap in spec.get("gaps", []):
				var g_from := int(gap[0])
				var g_to := int(gap[1])
				# The sheet must stop short of the near lip, or start clear of
				# the far one, by the whole margin.
				assert_true(to <= g_from - ColdStore.STOP_MARGIN_CELLS
						or from >= g_to + ColdStore.STOP_MARGIN_CELLS,
					"%s: ice at %d-%d against a hole at %d-%d leaves less than %d cells to stop in"
						% [spec["name"], from, to, g_from, g_to,
							ColdStore.STOP_MARGIN_CELLS])


## **Nothing slippery reaches a ladder.** A player sliding past a rung is a
## player who misses it -- the rule Turbine Row's Pier Head and Stack's Tip Head
## are both built on.
func test_no_ice_reaches_a_ladder() -> void:
	for spec in ColdStore.ROOMS:
		var shaft: Array = spec.get("shaft", spec.get("shaft_up", []))
		if shaft.is_empty():
			continue
		var from := int(shaft[0])
		var to := from + int(shaft[1])
		for entry in spec.get("ice", []):
			var i_from := int(entry["from"])
			var i_to := int(entry["to"])
			assert_true(i_to <= from - ColdStore.STOP_MARGIN_CELLS or i_from >= to,
				"%s: ice at %d-%d reaches the ladder at %d-%d"
					% [spec["name"], i_from, i_to, from, to])


## And the stage takes a breath -- the rule stage 4 writes on Foot.
func test_the_stage_is_not_ice_all_the_way_down() -> void:
	var grippy := 0
	var run := 0
	var longest := 0
	for spec in ColdStore.ROOMS:
		if spec.has("ice"):
			run += 1
			longest = maxi(longest, run)
		else:
			run = 0
			grippy += 1
	assert_true(grippy >= 5, "only %d of %d rooms have grip"
		% [grippy, ColdStore.ROOMS.size()])
	assert_true(longest <= 3,
		"%d ice rooms in a row; the sheets stop being an event" % longest)


# --- What the stage does not contain ----------------------------------------------

## **No belts and no wind.** Both push, and ice's whole claim is that it is not
## a push -- a claim that only survives if nothing beside it is one.
func test_the_stage_contains_nothing_that_pushes() -> void:
	for spec in ColdStore.ROOMS:
		assert_false(spec.has("belts"), "%s has a conveyor; stage 6 owns being carried"
			% spec["name"])
		assert_false(spec.has("wind"), "%s has wind; stage 5 owns moving air"
			% spec["name"])
		assert_false(spec.has("crushers"), "%s has a press" % spec["name"])
		assert_false(spec.has("mirrors"), "%s has a panel path" % spec["name"])


## The arena has grip. Frost's Rime lays its own sheets and the fight turns on
## which parts of the floor are frozen; a room sheet would make that unreadable.
func test_the_arena_has_grip() -> void:
	var arena: Dictionary = ColdStore.ROOMS[ColdStore.ROOMS.size() - 1]
	var gate: Dictionary = ColdStore.ROOMS[ColdStore.ROOMS.size() - 2]
	assert_false(arena.has("ice"), "the arena is iced as well as the boss")
	assert_false(gate.has("ice"), "the run-up to the fight is iced")


# --- Built, not just authored -----------------------------------------------------

func test_every_authored_sheet_is_built_where_its_room_puts_it() -> void:
	var stage: AuthoredStage = await _build()
	var tile := stage.tile_size()
	var matched := 0
	for index in ColdStore.ROOMS.size():
		var spec: Dictionary = ColdStore.ROOMS[index]
		var origin := stage.room_origin(index)
		var deck := stage.room_deck_row(index)
		for entry in spec.get("ice", []):
			var from := int(entry["from"])
			var to := int(entry["to"])
			var want := Vector2(float(origin + from),
				float(deck) + stage.deck_surface_offset()) * tile
			var sheet := _sheet_at(stage, want)
			assert_true(sheet != null, "%s: no sheet at cell %d" % [spec["name"], from])
			if sheet == null:
				continue
			matched += 1
			assert_almost_eq(sheet.width_tiles, float(to - from), 0.01,
				"%s: the sheet at cell %d is the wrong length" % [spec["name"], from])
			assert_true(sheet.grip > 0.0,
				"%s: a sheet with no grip is a floor you can never stand on"
					% spec["name"])
	assert_eq(stage.sheets().size(), matched,
		"%d sheets built, %d authored" % [stage.sheets().size(), matched])
	await _drop(stage)


func test_the_stage_brings_frost_its_tileset_and_its_backdrop() -> void:
	var stage: AuthoredStage = await _build()
	assert_eq(stage.boss_name(), "Frost")
	assert_true(stage.boss_script() != null, "no boss script")
	assert_true(stage.stage_tile_set() != null, "no tileset")
	assert_true(stage.backdrop_script() != null, "no backdrop")
	assert_true(ResourceLoader.exists(stage.boss_frames_path()),
		"Frost's sprite frames are missing")
	await _drop(stage)


func test_the_roster_points_at_this_stage() -> void:
	var row := StageRoster.entry(Frost.INDEX)
	assert_eq(String(row["stage"]), "Cold Store")
	assert_eq(String(row["boss"]), "Frost")
	assert_eq(String(row["scene"]), SCENE)
	assert_true(StageRoster.is_built(Frost.INDEX),
		"the select screen still shows Cold Store as unbuilt")


# --- Helpers ---------------------------------------------------------------------

func _first_room_with_ice() -> int:
	for i in ColdStore.ROOMS.size():
		if ColdStore.ROOMS[i].has("ice"):
			return i
	return -1


func _sheet_at(stage: AuthoredStage, at: Vector2) -> IceFloor:
	for sheet in stage.sheets():
		if sheet.position.distance_to(at) < 1.0:
			return sheet
	return null


func _build() -> AuthoredStage:
	var stage: Node = (load(SCENE) as PackedScene).instantiate()
	tree.root.add_child(stage)
	for _i in SETTLE_FRAMES:
		await tree.physics_frame
	return stage as AuthoredStage


func _drop(stage: Node) -> void:
	stage.queue_free()
	await tree.physics_frame
