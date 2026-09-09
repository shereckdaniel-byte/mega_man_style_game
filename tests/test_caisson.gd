## Caisson: the fortress's second stage, and the arithmetic that lets a belt and
## a press share a room.
##
## The rule this file exists for is that **they never share cells**. It is not a
## matter of taste and it is not a rule about the look of a room: the press's
## tell is sized from the walk, a belt eats most of that walk, and a room that
## broke the rule would show the player a warning they cannot act on. Every
## number here is computed from `CrusherPress` and `ConveyorBelt` rather than
## restated, so changing either constant fails this stage instead of quietly
## making a room unfair.
extends TestCase

const Caisson := preload("res://scenes/stages/caisson/caisson.gd")
const Press := preload("res://scenes/level/crusher_press.gd")
const Belt := preload("res://scenes/level/conveyor_belt.gd")
const SCENE := "res://scenes/stages/caisson/caisson.tscn"

const SETTLE_FRAMES := 6


func is_async() -> bool:
	return true


# --- Shape ----------------------------------------------------------------------

## Straight down. Outfall reversed and came back; this one only ever descends.
func test_the_route_only_ever_descends() -> void:
	var bands: Array[int] = []
	for spec in Caisson.ROOMS:
		var band := int(spec["band"])
		if bands.is_empty() or bands[bands.size() - 1] != band:
			bands.append(band)
	assert_eq(bands, [0, 1, 2] as Array[int],
		"the route is %s" % str(bands))


func test_it_knows_which_fortress_stage_it_is() -> void:
	assert_eq(Caisson.new().fortress_index(), 1)
	assert_eq(String(StageRoster.fortress_entry(1)["name"]), "Caisson")
	assert_eq(String(StageRoster.fortress_entry(1)["scene"]), SCENE)


# --- The rule ---------------------------------------------------------------------

## **A belt never overlaps a press's column, and stops clear of it.**
##
## The press's tell is a walking budget: `TELL_FRAMES` at `walk_speed_pf` is how
## far a standing player gets, and `MAX_PRESS_TILES` is set so that budget
## covers the widest legal column. A belt under the press spends most of that
## budget pushing back, and the warning stops being one.
func test_no_belt_runs_under_a_press() -> void:
	for spec in Caisson.ROOMS:
		for belt in spec.get("belts", []):
			var b_from := int(belt["from"])
			var b_to := int(belt["to"])
			for press in spec.get("crushers", []):
				var p_from := int(press[0])
				var p_to := p_from + int(press[1])
				var clear: bool = b_to + Caisson.BELT_MARGIN_CELLS <= p_from \
					or b_from >= p_to + Caisson.BELT_MARGIN_CELLS
				assert_true(clear,
					"%s: a belt at %d-%d and a press at %d-%d, and the rule wants %d cells between them"
						% [spec["name"], b_from, b_to, p_from, p_to,
							Caisson.BELT_MARGIN_CELLS])


## The margin the rule uses is the one the arithmetic actually needs, and this
## is the assertion that ties the constant to the numbers it came from: **a
## player walking out of a press against a belt does not clear the widest legal
## column inside the tell.** If that ever stops being true, the margin is
## unnecessary and this test should be the thing that says so.
func test_the_margin_is_needed_and_not_a_habit() -> void:
	var t := PlayerTuning.new()
	var against := t.walk_speed_pf - Belt.DEFAULT_SPEED_PF
	var reach_on_a_belt := against * float(Press.TELL_FRAMES) / PlayerTuning.NES_TILE
	var reach_on_the_floor := t.walk_speed_pf * float(Press.TELL_FRAMES) \
		/ PlayerTuning.NES_TILE
	assert_true(reach_on_the_floor >= Press.MAX_PRESS_TILES,
		"the tell does not cover the widest press even on still ground: %.2f of %.1f tiles"
			% [reach_on_the_floor, Press.MAX_PRESS_TILES])
	assert_true(reach_on_a_belt < Press.MAX_PRESS_TILES,
		"a belt no longer eats the tell (%.2f tiles of %.1f), so the margin is a habit"
			% [reach_on_a_belt, Press.MAX_PRESS_TILES])
	assert_true(Caisson.BELT_MARGIN_CELLS >= 1,
		"a zero margin is no margin")


## No press is wider than the tell was sized for. Stage 3 holds itself to this
## and so does the fortress -- the last quarter of the game is not where the
## fairness rules relax.
func test_no_press_is_wider_than_the_tell_allows() -> void:
	for spec in Caisson.ROOMS:
		for press in spec.get("crushers", []):
			assert_true(float(press[1]) <= Press.MAX_PRESS_TILES,
				"%s: a %d-tile press against a %.0f-tile tell"
					% [spec["name"], int(press[1]), Press.MAX_PRESS_TILES])


## A belt stops clear of a hole for the same reason it stops clear of a press:
## the jump has to be taken from ground that is not moving.
func test_no_belt_runs_up_to_a_hole() -> void:
	for spec in Caisson.ROOMS:
		for belt in spec.get("belts", []):
			var b_from := int(belt["from"])
			var b_to := int(belt["to"])
			for gap in spec.get("gaps", []):
				var g_from := int(gap[0])
				var g_to := int(gap[1])
				var clear: bool = b_to + Caisson.BELT_MARGIN_CELLS <= g_from \
					or b_from >= g_to
				assert_true(clear,
					"%s: a belt at %d-%d runs into the hole at %d-%d"
						% [spec["name"], b_from, b_to, g_from, g_to])


## Both gimmicks are actually in the stage, or the rule above guards nothing.
func test_both_machines_are_used_and_taught_alone_first() -> void:
	var belted := 0
	var pressed := 0
	var together := 0
	for spec in Caisson.ROOMS:
		var has_belt: bool = not (spec.get("belts", []) as Array).is_empty()
		var has_press: bool = not (spec.get("crushers", []) as Array).is_empty()
		if has_belt:
			belted += 1
		if has_press:
			pressed += 1
		if has_belt and has_press:
			together += 1
	assert_true(belted >= 3, "only %d rooms have a belt" % belted)
	assert_true(pressed >= 4, "only %d rooms have a press" % pressed)
	assert_true(together >= 2,
		"only %d rooms put the two together, which is the stage's whole idea"
			% together)

	# And each is met alone before it is met with the other.
	var first_belt := -1
	var first_press := -1
	var first_together := -1
	for i in Caisson.ROOMS.size():
		var has_belt: bool = not (Caisson.ROOMS[i].get("belts", []) as Array).is_empty()
		var has_press: bool = not (Caisson.ROOMS[i].get("crushers", []) as Array).is_empty()
		if has_belt and first_belt < 0:
			first_belt = i
		if has_press and first_press < 0:
			first_press = i
		if has_belt and has_press and first_together < 0:
			first_together = i
	assert_true(first_belt < first_together,
		"the belt's first appearance is already the combination")
	assert_true(first_press < first_together,
		"the press's first appearance is already the combination")


## And there is a room with neither, because stage 4's Foot writes the rule
## every stage has kept: a gimmick met in every room stops being an event.
func test_the_stage_takes_a_breath() -> void:
	var plain := 0
	for spec in Caisson.ROOMS:
		if (spec.get("belts", []) as Array).is_empty() \
				and (spec.get("crushers", []) as Array).is_empty():
			plain += 1
	assert_true(plain >= 4,
		"only %d of %d rooms are free of both" % [plain, Caisson.ROOMS.size()])


# --- Built, not just tabled --------------------------------------------------------

## The M6i lesson: a table that is right and a translation that is not.
func test_the_stage_builds_the_machines_the_table_names() -> void:
	var stage: AuthoredStage = (load(SCENE) as PackedScene).instantiate()
	tree.root.add_child(stage)
	for _i in SETTLE_FRAMES:
		await tree.physics_frame

	var belts := 0
	var presses := 0
	for spec in Caisson.ROOMS:
		belts += (spec.get("belts", []) as Array).size()
		presses += (spec.get("crushers", []) as Array).size()
	assert_eq(stage.belts().size(), belts,
		"the table names %d belts and the stage built %d" % [belts, stage.belts().size()])
	assert_eq(stage.presses().size(), presses,
		"the table names %d presses and the stage built %d"
			% [presses, stage.presses().size()])

	stage.queue_free()
	await tree.physics_frame


## Every press hangs from the room's ceiling and stops where the table said, so
## a press that rests clear of the deck really can be slid under.
func test_every_press_travels_the_distance_the_table_asked_for() -> void:
	var stage: AuthoredStage = (load(SCENE) as PackedScene).instantiate()
	tree.root.add_child(stage)
	for _i in SETTLE_FRAMES:
		await tree.physics_frame

	for press in stage.presses():
		assert_true(press.drop_tiles > 0.0,
			"%s does not travel at all" % press.name)
		var reach: float = press.drop_tiles + press.size_tiles.y
		assert_true(reach <= float(stage.ceiling_to_deck_rows()) + 0.001,
			"%s reaches %.2f rows into a %d-row room"
				% [press.name, reach, stage.ceiling_to_deck_rows()])

	stage.queue_free()
	await tree.physics_frame


# --- The duel at the end -------------------------------------------------------------

## **The boss door opens onto someone who is not a boss.** Eight stages have
## taught the player exactly what that door means.
func test_the_stages_boss_is_the_rival() -> void:
	var stage := Caisson.new()
	assert_eq(stage.boss_script(), load("res://scenes/actors/bosses/rival.gd"))
	assert_eq(stage.boss_name(), "Ward")


## And clearing it is clearing a fortress stage: no weapon, no boss bit, and the
## fortress moves on by one.
func test_beating_him_awards_nothing_and_advances_the_fortress() -> void:
	var stage := Caisson.new()
	var ward := (load("res://scenes/actors/bosses/rival.gd") as GDScript).new() as Rival
	tree.root.add_child(ward)
	await tree.physics_frame
	stage.configure_boss(ward)
	assert_eq(ward.boss_index, -1, "the duel claims a Robot Master")
	assert_eq(ward.weapon_id, &"", "the duel awards a weapon")
	assert_eq(stage.fortress_index(), 1)
	ward.queue_free()
	await tree.physics_frame
