## Every ladder in the game, checked against the tiles rather than the table.
##
## **This is the test that was missing, and the fault it now catches shipped in
## three stages.** A `shaft` leaves a room downward and a `shaft_up` arrives from
## below, and the hole each one opens belongs to the deck the *ladder passes
## through* -- which for a `shaft_up` is the deck one band higher, not the deck
## of the room that declares it. `AuthoredStage` cut both in the declaring room's
## own deck, so every `shaft_up` in the game did two wrong things at once:
##
##   * holed the floor its own ladder stands on, so the ladder hung over a pit;
##   * left the deck above solid, so climbing it stopped against the ceiling.
##
## A playtester reported those as two separate faults ("I cannot climb this" and
## "how are we supposed to get on this ladder"), which is what a single bug with
## two symptoms looks like from the outside.
##
## Nothing caught it because every existing check reads the room *table*, and the
## table was right -- it was the translation from table to tiles that was wrong.
## So this one builds each stage for real and asks the TileMapLayer.
extends TestCase

const STAGES := {
	"dawn_boardwalk": "res://scenes/stages/dawn_boardwalk/dawn_boardwalk.tscn",
	"substation": "res://scenes/stages/substation/substation.tscn",
	"breakers": "res://scenes/stages/breakers/breakers.tscn",
	"mirror_field": "res://scenes/stages/mirror_field/mirror_field.tscn",
	"turbine_row": "res://scenes/stages/turbine_row/turbine_row.tscn",
	"stack": "res://scenes/stages/stack/stack.tscn",
	"cold_store": "res://scenes/stages/cold_store/cold_store.tscn",
	"sinkhole": "res://scenes/stages/sinkhole/sinkhole.tscn",
	# The fortress. Its stages are authored from the same table and held to the
	# same rules -- a ladder that hangs over a pit does it whichever half of the
	# game it is in.
	"outfall": "res://scenes/stages/outfall/outfall.tscn",
	"caisson": "res://scenes/stages/caisson/caisson.tscn",
	"switchgear": "res://scenes/stages/switchgear/switchgear.tscn",
	"keep": "res://scenes/stages/keep/keep.tscn",
}

## Frames to let a stage build its deck, rooms and elements.
const SETTLE_FRAMES := 6


func is_async() -> bool:
	return true


func test_every_ladder_stands_on_solid_floor() -> void:
	for name in STAGES:
		var stage: AuthoredStage = await _build(name)
		for ladder in _ladders(stage):
			var cell := _cell_of(stage, ladder)
			# Floor, not round: a ladder's foot sits on the deck *surface*, half
			# a tile below its tile row (AuthoredStage.deck_surface_offset), so
			# rounding 26.5 lands on 27 and the scan then treats the deck the
			# ladder stands on as a ceiling blocking it.
			var foot := int(floor(ladder.position.y / stage.tile_size()))
			assert_true(_solid(stage, Vector2i(cell, foot)),
				"%s/%s: the deck under the ladder's foot is a hole"
					% [name, ladder.name])
		await _drop(stage)


func test_no_ladder_climbs_into_a_ceiling() -> void:
	for name in STAGES:
		var stage: AuthoredStage = await _build(name)
		for ladder in _ladders(stage):
			var cell := _cell_of(stage, ladder)
			# Floor, not round: a ladder's foot sits on the deck *surface*, half
			# a tile below its tile row (AuthoredStage.deck_surface_offset), so
			# rounding 26.5 lands on 27 and the scan then treats the deck the
			# ladder stands on as a ceiling blocking it.
			var foot := int(floor(ladder.position.y / stage.tile_size()))
			var head := foot - ladder.height_tiles
			var blocked: Array[int] = []
			for y in range(head, foot):
				for dx in [0, 1]:
					if _solid(stage, Vector2i(cell + dx, y)):
						blocked.append(y)
						break
			assert_eq(blocked.size(), 0,
				"%s/%s: solid tiles at rows %s block the climb"
					% [name, ladder.name, blocked])
		await _drop(stage)


func test_a_shaft_up_holes_the_band_above_and_not_its_own() -> void:
	# The rule, stated where it can fail loudly. Checked from the table against
	# the tiles, so it holds for a stage authored after this was written.
	for name in STAGES:
		var stage: AuthoredStage = await _build(name)
		var table := stage.room_table()
		for index in table.size():
			var spec: Dictionary = table[index]
			if not spec.has("shaft_up"):
				continue
			var shaft: Array = spec["shaft_up"]
			var origin := stage.room_origin(index)
			var band := stage.room_band(index)
			for x in range(int(shaft[0]), int(shaft[0]) + int(shaft[1])):
				var cell := origin + x
				assert_false(_solid(stage, Vector2i(cell,
						stage.band_deck_row(band - 1))),
					"%s room %s: the deck above the shaft_up is solid"
						% [name, spec["name"]])
				assert_true(_solid(stage, Vector2i(cell,
						stage.band_deck_row(band))),
					"%s room %s: a shaft_up holed its own floor"
						% [name, spec["name"]])
		await _drop(stage)


func test_a_shaft_holes_its_own_deck() -> void:
	for name in STAGES:
		var stage: AuthoredStage = await _build(name)
		var table := stage.room_table()
		for index in table.size():
			var spec: Dictionary = table[index]
			if not spec.has("shaft"):
				continue
			var shaft: Array = spec["shaft"]
			var origin := stage.room_origin(index)
			for x in range(int(shaft[0]), int(shaft[0]) + int(shaft[1])):
				assert_false(_solid(stage, Vector2i(origin + x,
						stage.room_deck_row(index))),
					"%s room %s: a shaft did not open its own deck"
						% [name, spec["name"]])
		await _drop(stage)


func test_a_shaft_leaves_room_to_stand_on_the_far_side() -> void:
	# The regression that the fix above caused, pinned so it cannot come back.
	# A ladder that delivers the player onto the hole they climbed through is a
	# ladder they fall back down -- the bot did it 147 times in one run.
	for name in STAGES:
		var stage: AuthoredStage = await _build(name)
		var table := stage.room_table()
		for index in table.size():
			var spec: Dictionary = table[index]
			# `shaft_up` only: a downward shaft is the room's exit and is meant
			# to sit at the far end with nothing past it.
			if not spec.has("shaft_up"):
				continue
			for key in ["shaft_up"]:
				var shaft: Array = spec[key]
				var far := int(shaft[0]) + int(shaft[1])
				var room_end := AuthoredStage.ROOM_WIDTH
				assert_true(room_end - far >= AuthoredStage.SHAFT_LANDING_CELLS,
					"%s room %s: a %s at cell %d leaves only %d cells of deck "
						% [name, spec["name"], key, int(shaft[0]), room_end - far]
						+ "before the room's far edge")
		await _drop(stage)


func test_no_shaft_swallows_the_boss_door() -> void:
	# Stage 1's failure exactly: the hole landed on the cell the run through the
	# stage is measured to.
	for name in STAGES:
		var stage: AuthoredStage = await _build(name)
		var door := int(stage.boss_door_position().x / stage.tile_size())
		assert_true(_solid(stage, Vector2i(door, stage.room_deck_row(
				stage.boss_door_room_index()))),
			"%s: the boss door at cell %d stands over a hole" % [name, door])
		await _drop(stage)


func test_every_stage_is_registered_here() -> void:
	# Same guard as test_stage_authoring's: a stage nobody added is a stage none
	# of this checks.
	var found := 0
	var dir := DirAccess.open("res://scenes/stages")
	for folder in dir.get_directories():
		# `test_room` is the M1 tuning room, and `fortress` holds the backdrop
		# the four fortress stages share rather than a stage of its own -- it has
		# no `<name>/<name>.tscn`, which is what makes a folder here a stage.
		if folder == "test_room":
			continue
		if not ResourceLoader.exists("res://scenes/stages/%s/%s.tscn"
				% [folder, folder]):
			continue
		found += 1
		assert_has(STAGES, folder, "%s is not in this test's STAGES" % folder)
	assert_eq(found, STAGES.size(), "stage folders on disk vs stages under test")


# --- Plumbing --------------------------------------------------------------------

func _build(name: String) -> AuthoredStage:
	var stage: Node = (load(STAGES[name]) as PackedScene).instantiate()
	tree.root.add_child(stage)
	for i in SETTLE_FRAMES:
		await tree.physics_frame
	return stage as AuthoredStage


func _drop(stage: Node) -> void:
	stage.queue_free()
	await tree.physics_frame


func _ladders(stage: Node) -> Array[Ladder]:
	var out: Array[Ladder] = []
	for child in stage.get_children():
		if child is Ladder:
			out.append(child as Ladder)
	return out


## The ladder is placed on a cell centre, so its cell is the floor of x - 0.5.
func _cell_of(stage: AuthoredStage, ladder: Ladder) -> int:
	return int(round(ladder.position.x / stage.tile_size() - 0.5))


func _solid(stage: Node, cell: Vector2i) -> bool:
	var deck: TileMapLayer = stage.get_node_or_null(^"Terrain")
	if deck == null:
		return false
	return deck.get_cell_source_id(cell) != -1


## The deck's walkable surface is half a tile below its tile row, because the
## tilesets are Wang corner sets. Pinned because everything the stage places is
## measured from it, and the number is read out of the tile rather than written
## down -- a tileset that changed shape would move it silently otherwise.
func test_the_deck_surface_is_measured_from_the_tiles() -> void:
	for name in STAGES:
		var stage: AuthoredStage = await _build(name)
		var offset := stage.deck_surface_offset()
		assert_between(offset, 0.0, 0.9,
			"%s: a surface offset of %.2f tiles is not a surface" % [name, offset])
		assert_almost_eq(offset, 0.5, 0.001,
			"%s: corner terrain should put the surface half a tile down" % name)
		await _drop(stage)


## **Every arena in every stage**, not the stage's own one.
##
## The arena used to hand the boss `band_deck_row * tile`, which is half a tile
## above the collision surface: the boss finished its entrance in the air and
## dropped 36 px the moment gravity started at the bar fill.
##
## This asked `stage.arena()` until the fortress arrived, which was the same
## thing right up until a stage had more than one. Switchgear has eight and no
## `arena()` at all -- the test read as "switchgear has no arena", which is true
## and is not a fault -- and Caisson's duel is a second sealed room in a stage
## that also has a first. Walking the built nodes asks the question that was
## always meant: wherever a boss is going to land, is there floor at that line.
func test_every_arena_stands_on_the_deck_surface() -> void:
	for name in STAGES:
		var stage: AuthoredStage = await _build(name)
		var found := 0
		for child in stage.get_children():
			if not (child is BossArena):
				continue
			var arena := child as BossArena
			found += 1
			var arena_room := stage.get_node_or_null(arena.arena_room) as Room
			assert_not_null(arena_room,
				"%s: %s names no room" % [name, arena.name])
			if arena_room == null:
				continue
			var index := stage.rooms().find(arena_room)
			assert_true(index >= 0,
				"%s: %s names a room that is not in the stage" % [name, arena.name])
			var row := stage.band_surface_row(stage.room_band(index))
			assert_almost_eq(arena.global_position.y, row * stage.tile_size(), 0.5,
				"%s: %s is not on the deck surface" % [name, arena.name])
		assert_true(found > 0, "%s builds no arena at all" % name)
		await _drop(stage)
