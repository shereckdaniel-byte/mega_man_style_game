## Outfall: the fortress's first stage, and the one rule that mixing gimmicks
## needs.
##
## The shape checks are the same kind stages 1-8 get. The rule that is new here
## -- and the reason this file is not just another copy of `test_sinkhole` -- is
## **the two waters never share a room**. That is the whole safety argument for
## a stage that mixes gimmicks at all, and it is exactly the sort of thing that
## is true when a table is written and false three rooms later.
extends TestCase

const Outfall := preload("res://scenes/stages/outfall/outfall.gd")
const Water := preload("res://scenes/level/water_volume.gd")
const SCENE := "res://scenes/stages/outfall/outfall.tscn"

const SETTLE_FRAMES := 6


func is_async() -> bool:
	return true


# --- Shape --------------------------------------------------------------------

## **The route reverses.** Down through the wall, along the bottom, and back up
## the far side -- the only stage in the game that returns to the band it
## started in. Stage 8 revisits a band; this one ends where it began.
func test_the_route_goes_down_and_comes_back_up() -> void:
	var bands: Array[int] = []
	for spec in Outfall.ROOMS:
		var band := int(spec["band"])
		if bands.is_empty() or bands[bands.size() - 1] != band:
			bands.append(band)
	assert_eq(bands, [0, 1, 2, 1, 0] as Array[int],
		"the route is %s, and Outfall descends and climbs back out" % str(bands))


## It is shorter than a master stage, deliberately: the fortress is four stages
## back to back with no select screen between them.
func test_it_is_shorter_than_a_master_stage() -> void:
	assert_true(Outfall.ROOMS.size() < 19,
		"a fortress stage with %d rooms is a master stage" % Outfall.ROOMS.size())
	assert_true(Outfall.ROOMS.size() >= 10,
		"only %d rooms" % Outfall.ROOMS.size())


func test_it_knows_which_fortress_stage_it_is() -> void:
	var stage := Outfall.new()
	assert_eq(stage.fortress_index(), 0)
	assert_eq(String(StageRoster.fortress_entry(0)["name"]), "Outfall",
		"the roster and the stage disagree about which one this is")
	assert_eq(String(StageRoster.fortress_entry(0)["scene"]), SCENE)


# --- The rule that lets it mix -------------------------------------------------

## **A pool and a tide never share a room.**
##
## They are the same substance drawn the same way at the same kind of
## horizontal line, and one of them is a floor while the other is instant death.
## A room with both asks the player to read a waterline to decide which of two
## opposite things it means, which is not difficulty -- it is a legibility fault
## wearing difficulty's clothes.
func test_no_room_holds_both_waters() -> void:
	for spec in Outfall.ROOMS:
		var pooled: bool = not (spec.get("water", []) as Array).is_empty()
		var rising: bool = bool(spec.get("tide", false))
		assert_false(pooled and rising,
			"%s has a pool and a tide in the same room" % spec["name"])


## Both are actually used, or the rule above is guarding nothing. This is the
## stage's whole reason to exist: two gimmicks the player already knows, in one
## place, for the first time.
func test_both_waters_are_in_the_stage() -> void:
	var pools := 0
	var tides := 0
	for spec in Outfall.ROOMS:
		if not (spec.get("water", []) as Array).is_empty():
			pools += 1
		if bool(spec.get("tide", false)):
			tides += 1
	assert_true(pools >= 3, "only %d rooms have a pool" % pools)
	assert_eq(tides, 1, "%d tide rooms; the tide is the exam and there is one" % tides)


## And the first pool is free, as every gimmick's first appearance has been
## since stage 2's Riser: nothing to fall into, in the room that introduces it.
func test_the_first_pool_is_free() -> void:
	for spec in Outfall.ROOMS:
		if (spec.get("water", []) as Array).is_empty():
			continue
		assert_true((spec.get("gaps", []) as Array).is_empty(),
			"%s introduces the pool over a hole" % spec["name"])
		assert_true((spec.get("pit_spikes", []) as Array).is_empty(),
			"%s introduces the pool over spikes" % spec["name"])
		return
	assert_true(false, "the stage has no pool at all")


## Stage 8's rule 2, and it applies here for the same reason: a submerged jump
## reaches ceilings the player has spent eight stages learning they cannot
## reach, so teeth that are out of range on land are not out of range over
## water. Measured against the full-hold submerged apex.
func test_nothing_lethal_hangs_over_a_pool() -> void:
	var t := PlayerTuning.new()
	var apex_tiles := Water.jump_apex_in_water(t.jump_apex_nes_px(),
		Water.DEFAULT_BUOYANCY) / PlayerTuning.NES_TILE
	for spec in Outfall.ROOMS:
		for entry in spec.get("water", []):
			var w_from := int(entry["from"])
			var w_to := int(entry["to"])
			for teeth in spec.get("ceiling_spikes", []):
				var t_from := int(teeth[0])
				var t_to := t_from + int(teeth[2])
				assert_true(t_to <= w_from or t_from >= w_to,
					"%s: ceiling spikes at %d-%d hang over water at %d-%d, and a submerged jump reaches %.1f tiles"
						% [spec["name"], t_from, t_to, w_from, w_to, apex_tiles])


## **The tide room has one thing in it that can kill.** The player is watching a
## waterline and climbing; a hole in the floor would be a second clock running
## on the same attention.
func test_the_tide_room_has_nothing_else_to_fall_into() -> void:
	for spec in Outfall.ROOMS:
		if not bool(spec.get("tide", false)):
			continue
		assert_true((spec.get("gaps", []) as Array).is_empty(),
			"%s: a hole in the tide room" % spec["name"])
		assert_true((spec.get("spikes", []) as Array).is_empty(),
			"%s: spikes in the tide room" % spec["name"])
		assert_true((spec.get("pit_spikes", []) as Array).is_empty(),
			"%s: pit spikes in the tide room" % spec["name"])


## And it has a ladder, which is the only footing the water does not cover. A
## tide room whose exit is a door at deck level is a room that seals itself.
func test_the_tide_room_leaves_by_a_ladder() -> void:
	for spec in Outfall.ROOMS:
		if not bool(spec.get("tide", false)):
			continue
		assert_true(spec.has("shaft_up") or spec.has("shaft"),
			"%s: the tide room's only exit is at deck level" % spec["name"])


# --- Built, not just tabled -----------------------------------------------------

## The M6i lesson: every check that reads only the room table is checking the
## author's intent, and the shaft bug shipped in three stages with a table that
## was right and a translation that was not.
func test_the_stage_builds_the_waters_the_table_names() -> void:
	var stage: AuthoredStage = (load(SCENE) as PackedScene).instantiate()
	tree.root.add_child(stage)
	for _i in SETTLE_FRAMES:
		await tree.physics_frame

	var wanted := 0
	for spec in Outfall.ROOMS:
		wanted += (spec.get("water", []) as Array).size()
	assert_eq(stage.pools().size(), wanted,
		"the table names %d pools and the stage built %d"
			% [wanted, stage.pools().size()])
	assert_eq(stage.tides().size(), 1,
		"the table names one tide and the stage built %d" % stage.tides().size())

	stage.queue_free()
	await tree.physics_frame


## The tide is registered against the room it is actually in, or entering that
## room will not start it -- which is the fault that left stage 1's gimmick
## inert for two milestones.
func test_the_tide_is_registered_against_its_own_room() -> void:
	var stage: AuthoredStage = (load(SCENE) as PackedScene).instantiate()
	tree.root.add_child(stage)
	for _i in SETTLE_FRAMES:
		await tree.physics_frame

	var expected := -1
	for i in Outfall.ROOMS.size():
		if bool(Outfall.ROOMS[i].get("tide", false)):
			expected = i
	assert_true(stage.tides().has(expected),
		"the tide is registered against %s and the table puts it in room %d"
			% [str(stage.tides().keys()), expected])

	stage.queue_free()
	await tree.physics_frame


# --- The boss --------------------------------------------------------------------

## **A reprise drops nothing and claims nobody.** It is not one of the eight, so
## it must not set a boss bit -- and there is no ninth weapon for it to award.
func test_the_boss_is_a_reprise_and_not_a_ninth_master() -> void:
	var stage := Outfall.new()
	var boss := (load("res://scenes/actors/bosses/tide.gd") as GDScript).new() as Boss
	# The arena configures a boss that is already in the tree and has already
	# run `_ready`, which is when a boss sets its own index and weapon.
	tree.root.add_child(boss)
	await tree.physics_frame
	assert_eq(boss.boss_index, 0, "Tide is boss 0 before the fortress touches it")
	assert_eq(boss.weapon_id, &"tide_crawler")

	stage.configure_boss(boss)
	assert_eq(boss.boss_index, -1, "the reprise claims a Robot Master")
	assert_eq(boss.weapon_id, &"", "the reprise awards a weapon")
	assert_true(boss.display_name.contains("Tide"),
		"the reprise does not say who it is: %s" % boss.display_name)
	boss.queue_free()
	await tree.physics_frame


## **Faster, and still a fight.** Aggression only ever shortens recovery, and it
## must not shorten it onto the floor -- a pattern pinned at
## `MIN_RECOVER_FRAMES` is a knob that has stopped being a knob.
func test_the_reprise_is_faster_but_still_leaves_a_turn() -> void:
	var plain := (load("res://scenes/actors/bosses/tide.gd") as GDScript).new() as Boss
	var rebuilt := (load("res://scenes/actors/bosses/tide.gd") as GDScript).new() as Boss
	tree.root.add_child(plain)
	tree.root.add_child(rebuilt)
	await tree.physics_frame
	Outfall.new().configure_boss(rebuilt)

	for i in plain.patterns().size():
		var was := plain.patterns()[i].recover_frames
		var now := rebuilt.patterns()[i].recover_frames
		assert_true(now < was,
			"%s did not speed up" % plain.patterns()[i].id)
		assert_true(now > Boss.MIN_RECOVER_FRAMES,
			"%s is pinned at the floor (%d frames), so the aggression is doing more than it says"
				% [plain.patterns()[i].id, now])
		# And the tell is untouched: that is the fairness contract.
		assert_eq(rebuilt.patterns()[i].tell_frames, plain.patterns()[i].tell_frames)
	plain.queue_free()
	rebuilt.queue_free()
	await tree.physics_frame


## The fortress has no shop and no way back to the stage select between its
## stages, so its first fight has to be winnable with nothing. Tide is the boss
## the roster already names as the buster-only one (docs/PLAN.md section 4).
func test_the_first_fortress_fight_is_the_buster_only_boss() -> void:
	assert_eq(Outfall.new().boss_script(),
		load("res://scenes/actors/bosses/tide.gd"),
		"the fortress opens on a boss that may need a weapon the player is out of")
