## Sinkhole: the shape of the last stage, the order its gimmick is taught in,
## and the one rule a helpful gimmick still needs.
extends TestCase

const Sinkhole := preload("res://scenes/stages/sinkhole/sinkhole.gd")
const Water := preload("res://scenes/level/water_volume.gd")
const SCENE := "res://scenes/stages/sinkhole/sinkhole.tscn"

const SETTLE_FRAMES := 6


func is_async() -> bool:
	return true


# --- Shape ------------------------------------------------------------------------

## **The false bottom.** The stage descends, climbs back to a band it has
## already left, and then goes deeper than before -- the only stage in the game
## that returns to a band and leaves it again.
func test_the_stage_has_a_false_bottom() -> void:
	var visits: Array[int] = []
	for spec in Sinkhole.ROOMS:
		var band := int(spec["band"])
		if visits.is_empty() or visits[visits.size() - 1] != band:
			visits.append(band)
	# A descent with a false bottom looks like 0,1,2,1,2 -- a band appearing
	# twice with something else in between.
	var seen := {}
	var revisited := false
	for i in visits.size():
		if seen.has(visits[i]):
			revisited = true
		seen[visits[i]] = true
	assert_true(revisited,
		"no band is revisited; the stage is a plain descent and stage 6 is that")
	assert_true(visits.size() >= 5,
		"only %d band stretches; the turn needs somewhere to turn from"
			% visits.size())
	assert_eq(visits[0], Sinkhole.BAND_SURFACE, "the stage starts at the surface")
	assert_eq(visits[visits.size() - 1], Sinkhole.BAND_SUMP,
		"the stage ends in the sump")


func test_every_room_is_reachable_from_the_one_before_it() -> void:
	for i in range(1, Sinkhole.ROOMS.size()):
		var here: Dictionary = Sinkhole.ROOMS[i - 1]
		var there: Dictionary = Sinkhole.ROOMS[i]
		var same_band := int(here["band"]) == int(there["band"])
		var adjacent := absi(int(here["col"]) - int(there["col"])) == 1
		var climbs := here.has("shaft_up") and int(here["col"]) == int(there["col"]) \
			and int(there["band"]) == int(here["band"]) - 1
		var drops := here.has("shaft") and int(here["col"]) == int(there["col"]) \
			and int(there["band"]) == int(here["band"]) + 1
		assert_true((same_band and adjacent) or climbs or drops,
			"%s -> %s is not a walk or a ladder" % [here["name"], there["name"]])


# --- The water, and the order it is taught in -------------------------------------

func test_the_first_room_is_dry() -> void:
	assert_false(Sinkhole.ROOMS[0].has("water"),
		"%s changes the player's jump before they have used it"
			% Sinkhole.ROOMS[0]["name"])


## Water is taught over solid ground: no hole and no spikes in the room that
## introduces it, so the first thing learned costs nothing.
func test_water_is_taught_over_solid_ground() -> void:
	var index := _first_room_with_water()
	assert_true(index > 0, "no room in the stage has water")
	var spec: Dictionary = Sinkhole.ROOMS[index]
	assert_true((spec.get("gaps", []) as Array).is_empty(),
		"%s introduces water over a hole" % spec["name"])
	assert_true((spec.get("pit_spikes", []) as Array).is_empty(),
		"%s introduces water over spikes" % spec["name"])


## **Rule 2, and the only one water needs: nothing lethal hangs over it.**
##
## A submerged jump reaches ceilings the player has spent seven stages learning
## they cannot reach, so teeth that were safely out of range on land are not out
## of range here. Measured against the **full-hold** submerged apex, computed
## from `PlayerTuning` and `WaterVolume.DEFAULT_BUOYANCY` -- the highest the
## player can possibly get, so a ceiling cleared by this is cleared by any jump.
func test_nothing_lethal_hangs_over_water() -> void:
	var t := PlayerTuning.new()
	var apex_tiles := Water.jump_apex_in_water(t.jump_apex_nes_px(),
		Water.DEFAULT_BUOYANCY) / PlayerTuning.NES_TILE
	for spec in Sinkhole.ROOMS:
		if not spec.has("water"):
			continue
		for entry in spec["water"]:
			var w_from := int(entry["from"])
			var w_to := int(entry["to"])
			for teeth in spec.get("ceiling_spikes", []):
				var t_from := int(teeth[0])
				var t_to := t_from + int(teeth[2])
				var clear: bool = t_to <= w_from or t_from >= w_to
				assert_true(clear,
					"%s: ceiling spikes at %d-%d hang over water at %d-%d, and a submerged jump reaches %.1f tiles"
						% [spec["name"], t_from, t_to, w_from, w_to, apex_tiles])


## And the stage takes a breath: the dry rooms are the hard ones, so there have
## to be plenty of them.
func test_the_dry_rooms_outnumber_the_wet_ones() -> void:
	var wet := 0
	for spec in Sinkhole.ROOMS:
		if spec.has("water"):
			wet += 1
	var dry := Sinkhole.ROOMS.size() - wet
	assert_true(dry > wet,
		"%d wet rooms against %d dry; the dry ones are supposed to be the stage"
			% [wet, dry])
	assert_true(wet >= 4, "only %d rooms use the gimmick at all" % wet)


## **Nothing that pushes.** Wind, belts and ice all act horizontally and water
## acts vertically; mixing them would not be confusing so much as two stages at
## once, and the last stage should be its own idea played out.
func test_the_stage_contains_no_other_gimmick() -> void:
	for spec in Sinkhole.ROOMS:
		for key in ["wind", "belts", "ice", "crushers", "mirrors"]:
			assert_false(spec.has(key),
				"%s has '%s'; another stage owns that" % [spec["name"], key])


## **Every stage keeps its gimmick out of its boss's room**, and this is the
## eighth and last of them. Quarry's Flood raises its own water and the whole
## pattern is the player's jump changing under them; an already-flooded arena
## would make it do nothing.
func test_the_arena_is_dry() -> void:
	var arena: Dictionary = Sinkhole.ROOMS[Sinkhole.ROOMS.size() - 1]
	var gate: Dictionary = Sinkhole.ROOMS[Sinkhole.ROOMS.size() - 2]
	assert_false(arena.has("water"), "the arena is flooded before the boss floods it")
	assert_false(gate.has("water"), "the run-up to the fight is flooded")


# --- Built, not just authored -----------------------------------------------------

func test_every_authored_pool_is_built_where_its_room_puts_it() -> void:
	var stage: AuthoredStage = await _build()
	var tile := stage.tile_size()
	var matched := 0
	for index in Sinkhole.ROOMS.size():
		var spec: Dictionary = Sinkhole.ROOMS[index]
		var origin := stage.room_origin(index)
		var deck := stage.room_deck_row(index)
		for entry in spec.get("water", []):
			var from := int(entry["from"])
			var to := int(entry["to"])
			var want := Vector2(float(origin + from),
				float(deck) + stage.deck_surface_offset()
					- float(entry.get("surface", 0))) * tile
			var pool := _pool_at(stage, want)
			assert_true(pool != null, "%s: no pool at cell %d" % [spec["name"], from])
			if pool == null:
				continue
			matched += 1
			assert_almost_eq(pool.width_tiles, float(to - from), 0.01,
				"%s: the pool at cell %d is the wrong width" % [spec["name"], from])
			assert_true(pool.buoyancy > 0.0 and pool.buoyancy < 1.0,
				"%s: a pool that does not weaken gravity is not water"
					% spec["name"])
	assert_eq(stage.pools().size(), matched,
		"%d pools built, %d authored" % [stage.pools().size(), matched])
	await _drop(stage)


func test_the_stage_brings_quarry_its_tileset_and_its_backdrop() -> void:
	var stage: AuthoredStage = await _build()
	assert_eq(stage.boss_name(), "Quarry")
	assert_true(stage.boss_script() != null, "no boss script")
	assert_true(stage.stage_tile_set() != null, "no tileset")
	assert_true(stage.backdrop_script() != null, "no backdrop")
	assert_true(ResourceLoader.exists(stage.boss_frames_path()),
		"Quarry's sprite frames are missing")
	await _drop(stage)


func test_the_roster_points_at_this_stage() -> void:
	var row := StageRoster.entry(Quarry.INDEX)
	assert_eq(String(row["stage"]), "Sinkhole")
	assert_eq(String(row["boss"]), "Quarry")
	assert_eq(String(row["scene"]), SCENE)
	assert_true(StageRoster.is_built(Quarry.INDEX),
		"the select screen still shows Sinkhole as unbuilt")


## **And with this one, every stage in the roster is built.** The check that
## says so belongs here because this is the stage that finishes it.
func test_every_stage_in_the_roster_is_built() -> void:
	assert_eq(StageRoster.built().size(), StageRoster.ENTRIES.size(),
		"%d of %d stages are built" % [StageRoster.built().size(),
			StageRoster.ENTRIES.size()])


# --- Helpers ---------------------------------------------------------------------

func _first_room_with_water() -> int:
	for i in Sinkhole.ROOMS.size():
		if Sinkhole.ROOMS[i].has("water"):
			return i
	return -1


func _pool_at(stage: AuthoredStage, at: Vector2) -> WaterVolume:
	for pool in stage.pools():
		if pool.position.distance_to(at) < 1.0:
			return pool
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
