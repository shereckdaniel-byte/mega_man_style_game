## Mirror Field: the shape of the stage, and the order its gimmick is taught in.
##
## The rules that are about the *player* live in `test_stage_authoring.gd` and
## are applied to every stage, this one included -- including the two that grew
## there when this stage landed, because a panel path is a way of crossing a gap
## and the rule about crossing gaps had only ever heard of movers.
##
## What is here is what is true of stage 4 in particular: that it is an L, that
## the panels are introduced one idea at a time and free before they are paid
## for, and the two things the stage deliberately does not contain.
##
## The last two tests build the stage for real and count the nodes. That is the
## M6i lesson and it is worth restating: **every check that reads the room table
## is a check on a table that was right.** The shaft bug shipped in three stages
## because the table said the correct thing and the translation into tiles did
## not, and a set of panels handed the wrong beat index would be exactly the same
## kind of fault -- a table that reads as a route and a room that is not one.
extends TestCase

const MirrorField := preload("res://scenes/stages/mirror_field/mirror_field.gd")
const PanelBlock := preload("res://scenes/level/phase_block.gd")
const SCENE := "res://scenes/stages/mirror_field/mirror_field.tscn"

## Frames to let the stage build its deck, rooms and elements.
const SETTLE_FRAMES := 6


func is_async() -> bool:
	return true


# --- Shape ------------------------------------------------------------------------

func test_the_stage_is_an_L() -> void:
	# Stage 1 is a U, stage 2 a J, stage 3 a staircase that climbs the whole way.
	# This one runs flat across a band and then turns up once and stays there,
	# which is what "L" means here: exactly one change of band, late.
	var changes := 0
	for i in range(1, MirrorField.ROOMS.size()):
		if int(MirrorField.ROOMS[i]["band"]) != int(MirrorField.ROOMS[i - 1]["band"]):
			changes += 1
	assert_eq(changes, 1, "an L changes band once")
	var first := int(MirrorField.ROOMS[0]["band"])
	var last := int(MirrorField.ROOMS[MirrorField.ROOMS.size() - 1]["band"])
	assert_true(first > last,
		"the stage should finish in a higher band than it starts (%d -> %d)"
			% [first, last])
	# And the turn is late: the flat run is the bulk of the stage, which is the
	# thing that makes it read as a field rather than as a climb.
	var flat := 0
	for spec in MirrorField.ROOMS:
		if int(spec["band"]) == first:
			flat += 1
	assert_true(flat >= MirrorField.ROOMS.size() / 2,
		"only %d of %d rooms are on the field; the flatness is the design"
			% [flat, MirrorField.ROOMS.size()])


func test_every_room_is_reachable_from_the_one_before_it() -> void:
	# Either the next room is the column next door in the same band, or the
	# current room has a shaft into it. A room that is neither is a room the
	# player arrives at by falling, which is the bug the gap rule exists for.
	for i in range(1, MirrorField.ROOMS.size()):
		var here: Dictionary = MirrorField.ROOMS[i - 1]
		var there: Dictionary = MirrorField.ROOMS[i]
		var same_band := int(here["band"]) == int(there["band"])
		var adjacent := absi(int(here["col"]) - int(there["col"])) == 1
		var climbs := here.has("shaft_up") and int(here["col"]) == int(there["col"]) \
			and int(there["band"]) == int(here["band"]) - 1
		var drops := here.has("shaft") and int(here["col"]) == int(there["col"]) \
			and int(there["band"]) == int(here["band"]) + 1
		assert_true((same_band and adjacent) or climbs or drops,
			"%s -> %s is not a walk or a ladder" % [here["name"], there["name"]])


# --- The panels, and the order they are taught in ---------------------------------

func test_the_first_room_has_no_panels() -> void:
	# Every stage owes the player one room that is only walking.
	assert_false(MirrorField.ROOMS[0].has("mirrors"),
		"the stage opens with the gimmick in the first room")


## **The first path costs nothing to fail.** Bilge teaches the press over flat
## deck for the same reason: a mechanic learned over a pit is learned once, by
## dying, which is the version of a disappearing block everyone remembers hating.
func test_the_panel_is_taught_over_solid_ground() -> void:
	var first := _first_room_with_panels()
	assert_true(first >= 0, "no room has panels")
	var room: Dictionary = MirrorField.ROOMS[first]
	assert_eq((room["gaps"] as Array).size(), 0,
		"%s teaches the panels over a gap" % room["name"])
	assert_false(room.has("pit_spikes"),
		"%s teaches the panels over spikes" % room["name"])
	assert_eq((room["mirrors"] as Array).size(), 1,
		"%s teaches the panels with more than one path" % room["name"])


## And it is optional: the room has terrain that reaches the same place. Stage
## 2's Riser and stage 3's Ribs both extend the same courtesy to the crumbling
## planks, and a panel is an offer where a press is a threat.
func test_the_first_path_has_a_way_round_it() -> void:
	var room: Dictionary = MirrorField.ROOMS[_first_room_with_panels()]
	assert_true((room["blocks"] as Array).size() >= 2,
		"%s has no terrain route past its panels, so the first path is compulsory"
			% room["name"])


## The second path is the same object over a gap: the idea is that nothing about
## the panel changed, only what a miss costs.
func test_the_second_path_is_the_first_one_over_a_gap() -> void:
	var rooms := _rooms_with_panels()
	assert_true(rooms.size() >= 2, "the stage teaches the panels in one room")
	var first: Dictionary = MirrorField.ROOMS[rooms[0]]
	var second: Dictionary = MirrorField.ROOMS[rooms[1]]
	assert_false((second["gaps"] as Array).is_empty(),
		"%s does not put the panels over anything" % second["name"])
	assert_eq((second["mirrors"][0]["path"] as Array).size(),
		(first["mirrors"][0]["path"] as Array).size(),
		"the paid crossing is a different length from the free one it teaches")


## Two paths in one room must run out of step, or the second one is decoration:
## a set at the same phase as its neighbour is the same set drawn twice.
func test_two_paths_in_a_room_are_out_of_phase() -> void:
	var found := false
	for spec in MirrorField.ROOMS:
		var sets: Array = spec.get("mirrors", [])
		if sets.size() < 2:
			continue
		found = true
		var phases := {}
		for set_entry in sets:
			var phase := int(set_entry.get("phase", 0))
			assert_false(phases.has(phase),
				"%s has two paths at phase %d, which is one path drawn twice"
					% [spec["name"], phase])
			phases[phase] = true
	assert_true(found, "no room pairs two paths, so the rhythm idea is untaught")


## After two rooms of panels the stage owes the player one that is only
## platforming, or the gimmick stops being an event and becomes the floor. Ribs
## makes the same argument in Breakers.
func test_the_stage_takes_a_breath_between_the_panels_and_the_exam() -> void:
	var rooms := _rooms_with_panels()
	assert_true(rooms.size() >= 4, "the stage does not have enough panel rooms to pace")
	var gaps := 0
	for i in range(1, rooms.size()):
		if rooms[i] - rooms[i - 1] > 1:
			gaps += 1
	assert_true(gaps >= 1,
		"every panel room is adjacent to the next; the stage never puts the gimmick down")


# --- The two things this stage does not contain -----------------------------------

## **No crumbling blocks.** They are the other piece of timed geometry in the kit
## and they look like what a panel is under a different rule. One stage may not
## contain both, or the player cannot tell from looking which rule governs which
## block.
func test_the_stage_contains_no_crumbling_blocks() -> void:
	for spec in MirrorField.ROOMS:
		assert_true(spec.get("crumbles", []).is_empty(),
			"%s mixes crumbling blocks with panels" % spec["name"])


## **No moving platforms.** A mover and a panel path are two answers to "this gap
## is wider than the jump", and a stage that offers both makes neither mean
## anything. The crossings here are panels, which is what makes them the stage.
func test_the_stage_contains_no_moving_platforms() -> void:
	for spec in MirrorField.ROOMS:
		assert_true(spec.get("movers", []).is_empty(),
			"%s crosses with a mover in the stage whose crossings are panels"
				% spec["name"])


func test_the_arena_has_no_panels() -> void:
	var arena: Dictionary = MirrorField.ROOMS[MirrorField.ROOMS.size() - 1]
	assert_false(arena.has("mirrors"),
		"Prism's Sweep already takes the floor away; the arena must not as well")


# --- Built, not tabulated ---------------------------------------------------------

## **Every authored panel is built where the table puts it, carrying the beat its
## place in the list orders.** This is the check the table cannot make.
##
## Two faults it would catch, both of which read as a correct table from the
## outside. A stage that handed every panel of a set beat 0 would build a
## blinking staircase rather than a route. And a panel placed against the wrong
## room origin would be a path in mid-air over the next room along -- which is
## exactly the shape of the M6i shaft bug, where every existing check read the
## table and the table was right.
func test_every_authored_panel_is_built_with_the_beat_its_place_orders() -> void:
	var stage: AuthoredStage = await _build()
	var tile := stage.tile_size()
	var matched := 0
	for index in MirrorField.ROOMS.size():
		var spec: Dictionary = MirrorField.ROOMS[index]
		var origin := stage.room_origin(index)
		var deck := stage.room_deck_row(index)
		for set_entry in spec.get("mirrors", []):
			var path: Array = set_entry["path"]
			for beat in path.size():
				var at: Array = path[beat]
				# Against the deck's *surface*, which is where a thing the
				# player stands on goes -- half a tile below the tile row on a
				# corner tileset. See AuthoredStage.deck_surface_offset.
				var want := Vector2(float(origin + int(at[0])),
					float(deck) + stage.deck_surface_offset() - float(at[1])) * tile
				var panel := _panel_at(stage, want)
				assert_true(panel != null,
					"%s: no panel at cell %d, %d rows up"
						% [spec["name"], int(at[0]), int(at[1])])
				if panel == null:
					continue
				matched += 1
				assert_eq(panel.beat_index, beat,
					"%s: the panel at cell %d is beat %d, and it is %d places along its path"
						% [spec["name"], int(at[0]), panel.beat_index, beat])
				assert_eq(panel.path_length, path.size(),
					"%s: the panel at cell %d thinks its path is %d long, not %d"
						% [spec["name"], int(at[0]), panel.path_length, path.size()])
				assert_eq(panel.phase_frames, int(set_entry.get("phase", 0)),
					"%s: the panel at cell %d carries the wrong set phase"
						% [spec["name"], int(at[0])])
	# And nothing else: a stage that built a panel the table never asked for is
	# as wrong as one that missed one.
	assert_eq(stage.panels().size(), matched,
		"%d panels built, %d authored" % [stage.panels().size(), matched])
	await _drop(stage)


func test_the_stage_brings_prism_its_tileset_and_its_backdrop() -> void:
	var stage: AuthoredStage = await _build()
	assert_eq(stage.boss_name(), "Prism")
	assert_true(stage.boss_script() != null, "no boss script")
	assert_true(stage.stage_tile_set() != null, "no tileset")
	assert_true(stage.backdrop_script() != null, "no backdrop")
	assert_true(ResourceLoader.exists(stage.boss_frames_path()),
		"Prism's sprite frames are missing")
	await _drop(stage)


func test_the_roster_points_at_this_stage() -> void:
	var row := StageRoster.entry(Prism.INDEX)
	assert_eq(String(row["stage"]), "Mirror Field")
	assert_eq(String(row["boss"]), "Prism")
	assert_eq(String(row["scene"]), SCENE)
	assert_true(StageRoster.is_built(Prism.INDEX),
		"the select screen still shows Mirror Field as unbuilt")


# --- Helpers ---------------------------------------------------------------------

func _first_room_with_panels() -> int:
	for i in MirrorField.ROOMS.size():
		if MirrorField.ROOMS[i].has("mirrors"):
			return i
	return -1


func _rooms_with_panels() -> Array[int]:
	var out: Array[int] = []
	for i in MirrorField.ROOMS.size():
		if MirrorField.ROOMS[i].has("mirrors"):
			out.append(i)
	return out


func _panel_at(stage: AuthoredStage, at: Vector2) -> PhaseBlock:
	for panel in stage.panels():
		if panel.position.distance_to(at) < 1.0:
			return panel
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
