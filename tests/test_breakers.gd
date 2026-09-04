## Breakers: the shape of the stage, and the one number its gimmick turns on.
##
## The rules that are about the *player* live in `test_stage_authoring.gd` and
## are applied to every stage, this one included. What is here is what is true of
## stage 3 in particular: that it climbs, that its presses are introduced one
## idea at a time, and — the assertion this file exists for — that
## `CLEARANCE_SLIDE` really does leave a sliding player room and a standing one
## none.
##
## That last one is checked against `PlayerTuning`'s real hitboxes and
## `CrusherPress`'s real teeth rather than against the arithmetic in the stage's
## comment. Stage 2 shipped a spiked tunnel whose comment was right and whose
## geometry was not, and the only thing that caught it was a bot dying in it.
extends TestCase

const Breakers := preload("res://scenes/stages/breakers/breakers.gd")
const Press := preload("res://scenes/level/crusher_press.gd")
const Authored := preload("res://scenes/level/authored_stage.gd")

## One tile is 16 NES px, which is the unit the clearance arithmetic is in.
const NES_TILE := 16.0


# --- Shape ------------------------------------------------------------------------

func test_the_stage_climbs_through_three_bands() -> void:
	# Stage 1 is a U and stage 2 is a J; both end roughly where they started.
	# This one is the ascent, and three bands is what makes it one.
	var bands := {}
	for room in Breakers.ROOMS:
		bands[int(room["band"])] = true
	assert_eq(bands.size(), 3, "Breakers is meant to use three bands")
	var first := int(Breakers.ROOMS[0]["band"])
	var last := int(Breakers.ROOMS[Breakers.ROOMS.size() - 1]["band"])
	assert_true(first > last,
		"the stage should finish in a higher band than it starts (%d -> %d)"
			% [first, last])


func test_every_room_is_reachable_from_the_one_before_it() -> void:
	# Either the next room is the column next door in the same band, or the
	# current room has a shaft into it. A room that is neither is a room the
	# player arrives at by falling, which is the bug the gap rule exists for.
	for i in range(1, Breakers.ROOMS.size()):
		var here: Dictionary = Breakers.ROOMS[i - 1]
		var there: Dictionary = Breakers.ROOMS[i]
		var same_band := int(here["band"]) == int(there["band"])
		var adjacent := absi(int(here["col"]) - int(there["col"])) == 1
		var climbs := here.has("shaft_up") and int(here["col"]) == int(there["col"]) \
			and int(there["band"]) == int(here["band"]) - 1
		var drops := here.has("shaft") and int(here["col"]) == int(there["col"]) \
			and int(there["band"]) == int(here["band"]) + 1
		assert_true((same_band and adjacent) or climbs or drops,
			"%s -> %s is not a walk or a ladder"
				% [here["name"], there["name"]])


# --- The presses ------------------------------------------------------------------

func test_the_first_room_has_no_press() -> void:
	# Every stage owes the player one room that cannot kill them.
	assert_false(Breakers.ROOMS[0].has("crushers"),
		"the stage opens with a press in the first room")


func test_the_press_is_introduced_alone() -> void:
	var first := -1
	for i in Breakers.ROOMS.size():
		if Breakers.ROOMS[i].has("crushers"):
			first = i
			break
	assert_true(first >= 0, "no room has a press")
	var room: Dictionary = Breakers.ROOMS[first]
	assert_eq((room["crushers"] as Array).size(), 1,
		"%s teaches the press with more than one of them" % room["name"])
	assert_eq((room["gaps"] as Array).size(), 0,
		"%s teaches the press over a gap" % room["name"])
	assert_false(room.has("pit_spikes"),
		"%s teaches the press over spikes" % room["name"])
	assert_false(room.has("movers"),
		"%s teaches the press and a crossing at once" % room["name"])


func test_the_arena_has_no_press() -> void:
	var arena: Dictionary = Breakers.ROOMS[Breakers.ROOMS.size() - 1]
	assert_false(arena.has("crushers"),
		"Rust's Bloom already takes floor away; a press as well is two space "
			+ "problems whose answers conflict")


func test_two_presses_in_a_room_are_out_of_phase() -> void:
	# Two presses in step are one wide press, which is a different room from the
	# one the table describes.
	for room in Breakers.ROOMS:
		var list: Array = room.get("crushers", [])
		if list.size() < 2:
			continue
		var phases := {}
		for entry in list:
			phases[int(entry[4])] = true
		assert_eq(phases.size(), list.size(),
			"%s has presses sharing a phase" % room["name"])


func test_no_press_is_wider_than_the_tell_allows() -> void:
	for room in Breakers.ROOMS:
		for entry in room.get("crushers", []):
			assert_true(float(entry[1]) <= Press.MAX_PRESS_TILES,
				"%s: a %s-tile press outruns its own tell"
					% [room["name"], entry[1]])


func test_a_press_shares_no_column_with_a_mover() -> void:
	# A press over a moving platform is two cycles to solve at once with no way
	# to wait out either, which is arithmetic rather than difficulty.
	for room in Breakers.ROOMS:
		for press in room.get("crushers", []):
			var p_from := float(press[0])
			var p_to := p_from + float(press[1])
			for mover in room.get("movers", []):
				var m_from := float(mover[0])
				var m_to := m_from + float(mover[2]) + absf(float(mover[3]))
				assert_true(p_to <= m_from or p_from >= m_to,
					"%s: press at %s overlaps the mover at %s"
						% [room["name"], press[0], mover[0]])


# --- The clearance, against the real boxes ---------------------------------------

func test_a_sealed_press_reaches_the_deck() -> void:
	var stage := Breakers.new()
	var drop := stage.press_drop_rows(float(Breakers.PRESS_ROWS),
		Breakers.CLEARANCE_SEALED)
	assert_almost_eq(drop + float(Breakers.PRESS_ROWS),
		float(stage.ceiling_to_deck_rows()), 0.001,
		"a sealed press should finish with its underside on the deck")
	stage.free()


func test_a_slide_fits_under_a_slide_press_and_standing_does_not() -> void:
	# The assertion this file exists for, and it is deliberately made from the
	# same three numbers the game uses rather than from the stage's comment.
	var tuning := PlayerTuning.new()
	var opening := Breakers.CLEARANCE_SLIDE * NES_TILE
	var teeth := Press.TEETH_TILES * NES_TILE
	var usable := opening - teeth

	assert_true(usable > tuning.NES_SLIDE_HITBOX.y,
		"a %.1f px opening less %.1f px of teeth leaves %.1f px, and a slide is %.1f"
			% [opening, teeth, usable, tuning.NES_SLIDE_HITBOX.y])
	assert_true(usable < tuning.NES_HITBOX.y,
		"a %.1f px opening lets a standing player (%.1f px) walk through, so the "
			% [usable, tuning.NES_HITBOX.y] + "press is not asking for a slide")


func test_neither_whole_number_of_rows_would_have_worked() -> void:
	# Recorded as a test rather than as a comment, because between them these
	# two are the entire reason CLEARANCE_SLIDE is a fraction. The next person to
	# "tidy" it to a round number should get a failure rather than a shipped
	# stage that is either impassable or free.
	var tuning := PlayerTuning.new()
	var teeth := Press.TEETH_TILES * NES_TILE

	var tight := 1.0 * NES_TILE - teeth
	assert_true(tight < tuning.NES_SLIDE_HITBOX.y,
		"one row leaves %.1f px, which a %.1f px slide fits after all"
			% [tight, tuning.NES_SLIDE_HITBOX.y])

	var loose := 2.0 * NES_TILE - teeth
	assert_true(loose > tuning.NES_HITBOX.y,
		"two rows leaves %.1f px, which a %.1f px standing player does not fit"
			% [loose, tuning.NES_HITBOX.y] + " -- the fraction may be unnecessary")


func test_both_clearances_are_actually_used() -> void:
	# Two constants and one of them unused would mean the stage only ever asks
	# one of the two questions the docstring claims it asks.
	var used := {}
	for room in Breakers.ROOMS:
		for entry in room.get("crushers", []):
			used[float(entry[3])] = true
	assert_has(used, Breakers.CLEARANCE_SEALED, "no press is sealed")
	assert_has(used, Breakers.CLEARANCE_SLIDE, "no press can be slid under")


# --- Identity ---------------------------------------------------------------------

func test_the_stage_brings_rust_its_tileset_and_its_backdrop() -> void:
	var stage := Breakers.new()
	assert_not_null(stage.stage_tile_set(), "no tileset")
	assert_not_null(stage.backdrop_script(), "no backdrop")
	assert_not_null(stage.boss_script(), "no boss")
	assert_eq(stage.boss_name(), "Rust")
	assert_true(ResourceLoader.exists(stage.boss_frames_path()),
		"Rust's frames are missing: %s" % stage.boss_frames_path())
	stage.free()


func test_the_roster_points_at_this_stage() -> void:
	# The roster is the one place the eight live; a stage that is built and not
	# registered is a stage the select screen refuses by name.
	assert_true(StageRoster.is_built(Rust.INDEX),
		"Breakers is built but the roster still calls it unbuilt")
	assert_eq(String(StageRoster.entry(Rust.INDEX)["stage"]), "Breakers")
