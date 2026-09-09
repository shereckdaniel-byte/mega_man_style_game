## Stack: the shape of the stage, and the order its gimmick is taught in.
##
## The rules about the *player* live in `test_stage_authoring.gd` and apply to
## every stage. What is here is what is true of stage 6 in particular: that it
## only ever goes down, that the belts are introduced free before they are paid
## for, and the one claim the whole stage rests on -- that a belt is a constant
## and not a cycle.
extends TestCase

const Stack := preload("res://scenes/stages/stack/stack.gd")
const Belt := preload("res://scenes/level/conveyor_belt.gd")
const SCENE := "res://scenes/stages/stack/stack.tscn"

const SETTLE_FRAMES := 6


func is_async() -> bool:
	return true


# --- Shape ------------------------------------------------------------------------

## **It only ever goes down**, which no other stage does. Stage 3 is a staircase
## that only climbs and this is that read backwards -- the shape an incinerator
## wants, because you are not exploring it, you are being fed into it.
func test_the_stage_only_ever_descends() -> void:
	var down := 0
	for i in range(1, Stack.ROOMS.size()):
		var step := int(Stack.ROOMS[i]["band"]) - int(Stack.ROOMS[i - 1]["band"])
		assert_true(step >= 0,
			"%s climbs back up to band %d" % [Stack.ROOMS[i]["name"], int(Stack.ROOMS[i]["band"])])
		if step > 0:
			down += 1
	assert_eq(down, 2, "three bands means two drops")
	var first := int(Stack.ROOMS[0]["band"])
	var last := int(Stack.ROOMS[Stack.ROOMS.size() - 1]["band"])
	assert_true(last > first,
		"the stage should finish below where it starts (band %d -> %d)" % [first, last])


func test_every_room_is_reachable_from_the_one_before_it() -> void:
	for i in range(1, Stack.ROOMS.size()):
		var here: Dictionary = Stack.ROOMS[i - 1]
		var there: Dictionary = Stack.ROOMS[i]
		var same_band := int(here["band"]) == int(there["band"])
		var adjacent := absi(int(here["col"]) - int(there["col"])) == 1
		var drops := here.has("shaft") and int(here["col"]) == int(there["col"]) \
			and int(there["band"]) == int(here["band"]) + 1
		assert_true((same_band and adjacent) or drops,
			"%s -> %s is not a walk or a ladder" % [here["name"], there["name"]])


# --- The belts, and the order they are taught in ----------------------------------

func test_the_first_room_has_no_belt() -> void:
	assert_false(Stack.ROOMS[0].has("belts"),
		"%s moves the floor before the player has moved" % Stack.ROOMS[0]["name"])


## **The belt is taught over solid ground.** The room that introduces it has no
## hole and no spikes, so the first thing learned costs nothing -- the house
## pattern since stage 2's Riser.
func test_the_belt_is_taught_over_solid_ground() -> void:
	var index := _first_room_with_belts()
	assert_true(index > 0, "no room in the stage has a belt")
	var spec: Dictionary = Stack.ROOMS[index]
	assert_true((spec.get("gaps", []) as Array).is_empty(),
		"%s introduces the belt over a hole" % spec["name"])
	assert_true((spec.get("pit_spikes", []) as Array).is_empty()
		and (spec.get("spikes", []) as Array).is_empty(),
		"%s introduces the belt over spikes" % spec["name"])


## **Charge Floor and Sorter are the same idea run each way**, and the pair is
## the lesson. A second difference between them would make the comparison say
## nothing -- the rule stage 5's Slipstream and Backdraft are held to.
func test_the_first_two_belts_are_one_idea_run_both_ways() -> void:
	var with_it := _room("Charge Floor")
	var against := _room("Sorter")
	assert_false(with_it.is_empty(), "Charge Floor is gone")
	assert_false(against.is_empty(), "Sorter is gone")
	assert_eq(int((with_it["belts"] as Array)[0]["dir"]), Stack.WITH_YOU)
	assert_eq(int((against["belts"] as Array)[0]["dir"]), Stack.AGAINST_YOU)
	for spec in [with_it, against]:
		assert_true((spec.get("gaps", []) as Array).is_empty(),
			"%s has a hole; the free pair must stay free" % spec["name"])


## Feed and Return are the same slide tunnel with the belt reversed under it --
## the stage's other pair, and the only place in the game where a move the
## player has fully learned measures differently.
func test_the_slide_pair_differs_only_in_the_belt() -> void:
	var feed := _room("Feed")
	var ret := _room("Return")
	assert_false(feed.is_empty() or ret.is_empty(), "the slide pair is gone")
	for key in ["gaps", "ceilings", "pit_spikes", "blocks"]:
		assert_eq(str(feed.get(key, [])), str(ret.get(key, [])),
			"the pair disagree on %s, so they are two rooms and not one question" % key)
	assert_eq(int((feed["belts"] as Array)[0]["dir"]), Stack.WITH_YOU)
	assert_eq(int((ret["belts"] as Array)[0]["dir"]), Stack.AGAINST_YOU)


## **Nothing runs across a ladder.** A player being carried while they reach for
## a rung is a player who misses it -- the rule Turbine Row's Pier Head and
## Tower Foot are built on.
func test_no_belt_reaches_a_ladder() -> void:
	for spec in Stack.ROOMS:
		var shaft: Array = spec.get("shaft", spec.get("shaft_up", []))
		if shaft.is_empty():
			continue
		var from := int(shaft[0])
		var to := from + int(shaft[1])
		for entry in spec.get("belts", []):
			var b_from := int(entry["from"])
			var b_to := int(entry["to"])
			assert_true(b_to <= from or b_from >= to,
				"%s: a belt at %d-%d covers the ladder at %d-%d"
					% [spec["name"], b_from, b_to, from, to])


## And the stage takes a breath. A stage whose every room is the gimmick has no
## gimmick, only a floor -- the rule stage 4 writes on Foot and stage 5's bot
## caught on the first run.
func test_the_stage_does_not_move_the_floor_in_every_room() -> void:
	var still := 0
	var run := 0
	var longest := 0
	for spec in Stack.ROOMS:
		if spec.has("belts"):
			run += 1
			longest = maxi(longest, run)
		else:
			run = 0
			still += 1
	assert_true(still >= 5, "only %d of %d rooms are still floor"
		% [still, Stack.ROOMS.size()])
	assert_true(longest <= 3,
		"%d belt rooms in a row; the belt stops being an event" % longest)


# --- The claim the stage rests on -------------------------------------------------

## **A belt is a constant, and stage 6 is not stage 5.**
##
## The table may say where a belt is and which way it runs, and nothing else. If
## a room ever authors a period, a phase or a reversal, this stage has become a
## second cyclic horizontal force and the player learns one skill twice.
func test_no_room_authors_a_belt_cycle() -> void:
	const ALLOWED := ["dir", "from", "to", "speed"]
	for spec in Stack.ROOMS:
		for entry in spec.get("belts", []):
			for key in (entry as Dictionary).keys():
				assert_has(ALLOWED, String(key),
					"%s: a belt authors '%s'; a belt has no cycle to author"
						% [spec["name"], key])


## No timed geometry from the other stages, for the same reason: stage 3 owns
## the cycle that closes a column and stage 4 owns geometry that comes and goes.
func test_the_stage_contains_no_presses_or_panels() -> void:
	for spec in Stack.ROOMS:
		assert_false(spec.has("crushers"), "%s has a press" % spec["name"])
		assert_false(spec.has("mirrors"), "%s has a panel path" % spec["name"])
		assert_false(spec.has("wind"), "%s has wind; stage 5 owns moving air"
			% spec["name"])


## And the arena's floor is still. Cinder's Flue already writes the player's
## carry every frame, and a room belt writing it as well is two authorities on
## one number.
func test_the_arena_floor_does_not_move() -> void:
	var arena: Dictionary = Stack.ROOMS[Stack.ROOMS.size() - 1]
	var gate: Dictionary = Stack.ROOMS[Stack.ROOMS.size() - 2]
	assert_false(arena.has("belts"), "the arena floor moves as well as the boss")
	assert_false(gate.has("belts"), "the run-up to the fight moves")


# --- Built, not just authored -----------------------------------------------------

func test_every_authored_belt_is_built_where_its_room_puts_it() -> void:
	var stage: AuthoredStage = await _build()
	var tile := stage.tile_size()
	var matched := 0
	for index in Stack.ROOMS.size():
		var spec: Dictionary = Stack.ROOMS[index]
		var origin := stage.room_origin(index)
		var deck := stage.room_deck_row(index)
		for entry in spec.get("belts", []):
			var from := int(entry["from"])
			var to := int(entry["to"])
			# On the deck's **surface**, which is where a thing the player stands
			# on goes -- half a tile below the tile row on a corner tileset.
			var want := Vector2(float(origin + from),
				float(deck) + stage.deck_surface_offset()) * tile
			var belt := _belt_at(stage, want)
			assert_true(belt != null,
				"%s: no belt at cell %d" % [spec["name"], from])
			if belt == null:
				continue
			matched += 1
			assert_eq(belt.direction, int(entry.get("dir", 1)),
				"%s: the belt at cell %d runs the wrong way" % [spec["name"], from])
			assert_almost_eq(belt.width_tiles, float(to - from), 0.01,
				"%s: the belt at cell %d is the wrong length" % [spec["name"], from])
	assert_eq(stage.belts().size(), matched,
		"%d belts built, %d authored" % [stage.belts().size(), matched])
	await _drop(stage)


func test_the_stage_brings_cinder_its_tileset_and_its_backdrop() -> void:
	var stage: AuthoredStage = await _build()
	assert_eq(stage.boss_name(), "Cinder")
	assert_true(stage.boss_script() != null, "no boss script")
	assert_true(stage.stage_tile_set() != null, "no tileset")
	assert_true(stage.backdrop_script() != null, "no backdrop")
	assert_true(ResourceLoader.exists(stage.boss_frames_path()),
		"Cinder's sprite frames are missing")
	await _drop(stage)


func test_the_roster_points_at_this_stage() -> void:
	var row := StageRoster.entry(Cinder.INDEX)
	assert_eq(String(row["stage"]), "Stack")
	assert_eq(String(row["boss"]), "Cinder")
	assert_eq(String(row["scene"]), SCENE)
	assert_true(StageRoster.is_built(Cinder.INDEX),
		"the select screen still shows Stack as unbuilt")


# --- Helpers ---------------------------------------------------------------------

func _first_room_with_belts() -> int:
	for i in Stack.ROOMS.size():
		if Stack.ROOMS[i].has("belts"):
			return i
	return -1


func _room(name: String) -> Dictionary:
	for spec in Stack.ROOMS:
		if String(spec["name"]) == name:
			return spec
	return {}


func _belt_at(stage: AuthoredStage, at: Vector2) -> ConveyorBelt:
	for belt in stage.belts():
		if belt.position.distance_to(at) < 1.0:
			return belt
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
