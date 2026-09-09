## Turbine Row: the shape of the stage, and the order its gimmick is taught in.
##
## The rules that are about the *player* live in `test_stage_authoring.gd` and
## are applied to every stage, this one included. What is here is what is true of
## stage 5 in particular: that it is a V, that the wind is introduced free before
## it is paid for, that **no crossing in the stage requires it**, and the two
## things the stage deliberately does not contain.
##
## The last tests build the stage for real and count the nodes, which is the M6i
## lesson restated: every check that reads the room table is a check on a table
## that was right. The shaft bug shipped in three stages because the table said
## the correct thing and the translation into tiles did not, and a zone handed
## the wrong direction would be exactly the same kind of fault -- a table that
## reads as a headwind and a room that is a tailwind.
extends TestCase

const TurbineRow := preload("res://scenes/stages/turbine_row/turbine_row.gd")
const Zone := preload("res://scenes/level/wind_zone.gd")
const SCENE := "res://scenes/stages/turbine_row/turbine_row.tscn"

## Frames to let the stage build its deck, rooms and elements.
const SETTLE_FRAMES := 6


func is_async() -> bool:
	return true


# --- Shape ------------------------------------------------------------------------

func test_the_stage_is_a_V() -> void:
	# Stage 1 is a W, stage 2 a J, stage 3 a staircase that only climbs, stage 4
	# an L. This one descends once and climbs twice, and finishes above where it
	# started -- which is what "V" means here.
	var down := 0
	var up := 0
	for i in range(1, TurbineRow.ROOMS.size()):
		var step := int(TurbineRow.ROOMS[i]["band"]) - int(TurbineRow.ROOMS[i - 1]["band"])
		if step > 0:
			down += 1
		elif step < 0:
			up += 1
	assert_eq(down, 1, "a V drops once")
	assert_eq(up, 2, "a V climbs twice: back to the causeway, then up the tower")
	var first := int(TurbineRow.ROOMS[0]["band"])
	var last := int(TurbineRow.ROOMS[TurbineRow.ROOMS.size() - 1]["band"])
	assert_true(last < first,
		"the stage should finish above where it starts (band %d -> %d)" % [first, last])
	# And the bottom of the V is the bulk of it: the sea deck is where the
	# gimmick's hardest rooms are, and a descent the player passes through in two
	# rooms is a detour rather than a shape.
	var deepest := 0
	for spec in TurbineRow.ROOMS:
		if int(spec["band"]) == TurbineRow.BAND_SEA:
			deepest += 1
	assert_true(deepest >= 6,
		"only %d rooms at sea level; the descent is the middle of the stage" % deepest)


func test_every_room_is_reachable_from_the_one_before_it() -> void:
	# Either the next room is the column next door in the same band, or the
	# current room has a ladder into it. A room that is neither is a room the
	# player arrives at by falling.
	for i in range(1, TurbineRow.ROOMS.size()):
		var here: Dictionary = TurbineRow.ROOMS[i - 1]
		var there: Dictionary = TurbineRow.ROOMS[i]
		var same_band := int(here["band"]) == int(there["band"])
		var adjacent := absi(int(here["col"]) - int(there["col"])) == 1
		var climbs := here.has("shaft_up") and int(here["col"]) == int(there["col"]) \
			and int(there["band"]) == int(here["band"]) - 1
		var drops := here.has("shaft") and int(here["col"]) == int(there["col"]) \
			and int(there["band"]) == int(here["band"]) + 1
		assert_true((same_band and adjacent) or climbs or drops,
			"%s -> %s is not a walk or a ladder" % [here["name"], there["name"]])


# --- The wind, and the order it is taught in --------------------------------------

func test_the_first_room_has_no_wind() -> void:
	# Every stage owes the player one room that is only walking.
	assert_false(TurbineRow.ROOMS[0].has("wind"),
		"%s blows at a player who has not moved yet" % TurbineRow.ROOMS[0]["name"])


## **The wind is taught over solid ground.** The room that introduces it has no
## hole in it, so the first thing the player learns costs nothing -- the house
## pattern since stage 2's Riser.
func test_the_wind_is_taught_over_solid_ground() -> void:
	var index := _first_room_with_wind()
	assert_true(index > 0, "no room in the stage has wind")
	var spec: Dictionary = TurbineRow.ROOMS[index]
	assert_true((spec.get("gaps", []) as Array).is_empty(),
		"%s introduces the wind over a hole" % spec["name"])
	assert_true((spec.get("pit_spikes", []) as Array).is_empty(),
		"%s introduces the wind over spikes" % spec["name"])


## **The rule the whole stage is built on.** The wind is weaker than a walk and
## its lull outlasts a full jump, so it cannot be load-bearing -- and this is the
## check that says so in numbers rather than in the stage's docstring.
##
## Both halves matter and they fail differently. A wind at or above the walk
## speed can hold a player still, so a headwind crossing becomes impossible. A
## lull shorter than a jump means there is no moment at which a crossing can be
## started in still air, so a *tailwind* crossing becomes compulsory-gust, which
## is the same fault wearing the friendlier face.
func test_no_crossing_in_the_stage_needs_the_wind() -> void:
	var t := PlayerTuning.new()
	var zone := Zone.new() as WindZone
	var airtime := _jump_airtime_frames(t)

	# Measured against **this stage's widest jumped gap**, not against the
	# grammar's limit -- `tests/test_wind_zone.gd` holds the element to
	# `MAX_GAP_TILES` in general, and what matters here is the rooms that were
	# actually authored.
	#
	# "Jumped" is the word doing the work, and getting it wrong is how this test
	# first failed: it took the widest gap in the stage, which is Kite's eight
	# cells, and Kite is crossed on a moving platform. A gap with a mover over it
	# is not a jump the wind can shorten -- it is a ride, and the wind's argument
	# with it is the step on and the step off, which are not gap-width jumps.
	var widest := 0
	for spec in TurbineRow.ROOMS:
		if not (spec.get("movers", []) as Array).is_empty():
			continue
		for gap in spec.get("gaps", []):
			widest = maxi(widest, int(gap[1]) - int(gap[0]))
	assert_true(widest > 0, "no jumped gap in the stage; this test is checking nothing")
	var into_it := (t.walk_speed_pf - zone.speed_pf) * airtime
	assert_true(into_it > float(widest) * PlayerTuning.NES_TILE,
		"a full-gust jump reaches %.1f px and this stage's widest jumped gap is %d cells (%.0f px)"
			% [into_it, widest, float(widest) * PlayerTuning.NES_TILE])

	assert_true(float(zone.lull_frames) > airtime,
		"the lull is %d frames and a jump lasts %.1f; there is no still moment to leave in"
			% [zone.lull_frames, airtime])
	zone.free()


## **A gap must not sit in a headwind the player entered from a tailwind.**
##
## The narrowest rule the evidence supports, and the evidence was expensive.
## When the wind began reaching a walking player, Crosscut went from zero deaths
## to the bot dying five and six times and never once reaching the far lip. Two
## fixes were tried and measured before this one: moving the seam off the gap
## changed nothing at all, and pointing both zones downwind fixed it outright.
##
## The mechanism is the flip, not the headwind alone -- Anemometer is a two-cell
## gap under a headwind for the whole room and the bot crosses it every run,
## because the run-up and the jump are in the same wind. Crosscut walked the
## player up to the lip on a tailwind and then reversed it in the last stride
## before the jump, which is a run-up whose speed the player cannot read.
##
## So a single-zone headwind gap is allowed and a mixed-zone one is not.
func test_no_gap_sits_in_a_headwind_the_player_walked_into() -> void:
	for spec in TurbineRow.ROOMS:
		var zones: Array = spec.get("wind", [])
		if zones.size() < 2:
			continue  # a single wind over the whole room is Anemometer's case
		for gap in spec.get("gaps", []):
			var from := int(gap[0])
			var to := int(gap[1])
			for entry in zones:
				if int(entry.get("dir", TurbineRow.DOWNWIND)) != TurbineRow.UPWIND:
					continue
				var w_from := int(entry.get("from", 0))
				var w_to := int(entry.get("to", AuthoredStage.ROOM_WIDTH))
				assert_true(to <= w_from or from >= w_to,
					"%s: the gap at %d-%d is inside a headwind at %d-%d, and the player reaches it on a tailwind"
						% [spec["name"], from, to, w_from, w_to])


## Slipstream and Backdraft are **the same room twice with the wind reversed**,
## and the pair is the lesson. A second difference between them would make the
## comparison say nothing, so there is not allowed to be one.
func test_the_paired_rooms_differ_only_in_which_way_the_air_goes() -> void:
	var with_it := _room("Slipstream")
	var against := _room("Backdraft")
	assert_false(with_it.is_empty(), "Slipstream is gone")
	assert_false(against.is_empty(), "Backdraft is gone")
	for key in ["gaps", "movers", "pit_spikes", "blocks"]:
		assert_eq(str(with_it.get(key, [])), str(against.get(key, [])),
			"the pair disagree on %s, so they are two rooms and not one question" % key)
	var a: Array = with_it["wind"]
	var b: Array = against["wind"]
	assert_eq(a.size(), 1, "Slipstream has more than one zone")
	assert_eq(b.size(), 1, "Backdraft has more than one zone")
	assert_eq(int(a[0]["dir"]), TurbineRow.DOWNWIND, "Slipstream does not blow with the player")
	assert_eq(int(b[0]["dir"]), TurbineRow.UPWIND, "Backdraft does not blow against them")


## **Two zones in a room are never gusting at once.** Crosscut's whole answer is
## that the seam between the two halves is crossable, and it is only crossable
## because the halves take turns -- which follows from `HALF_CYCLE` and from the
## gust being under half the cycle, not from the numbers looking sensible.
##
## Walked frame by frame over a whole cycle rather than argued.
func test_two_zones_in_a_room_never_gust_together() -> void:
	for spec in TurbineRow.ROOMS:
		var zones: Array = spec.get("wind", [])
		if zones.size() < 2:
			continue
		var probes: Array[WindZone] = []
		for entry in zones:
			var zone := Zone.new() as WindZone
			zone.direction = int(entry.get("dir", 1))
			zone.phase_frames = int(entry.get("phase", 0))
			probes.append(zone)
		var period: int = probes[0].cycle_frames()
		for frame in period:
			var blowing := 0
			for zone in probes:
				zone.phase_frames = int(zone.phase_frames)
				if _phase_at(zone, frame) == WindZone.Phase.GUST:
					blowing += 1
			assert_true(blowing <= 1,
				"%s: %d zones gust together at frame %d of the cycle"
					% [spec["name"], blowing, frame])
		for zone in probes:
			zone.free()


## And the stage takes a breath. A stage whose every room is the gimmick has no
## gimmick, only weather -- the rule stage 4 writes on Foot.
func test_the_stage_does_not_blow_in_every_room() -> void:
	var still := 0
	var run := 0
	var longest := 0
	for spec in TurbineRow.ROOMS:
		if spec.has("wind"):
			run += 1
			longest = maxi(longest, run)
		else:
			run = 0
			still += 1
	assert_true(still >= 5,
		"only %d of %d rooms are calm" % [still, TurbineRow.ROOMS.size()])
	assert_true(longest <= 3,
		"%d wind rooms in a row; the gust stops being an event" % longest)


## **Nothing blows over a ladder.** A player being pushed while they reach for a
## rung is a player who misses it, and there is no version of that which reads as
## anything but a bug. Both shafts are checked against the zone's own span rather
## than against the room having no wind at all -- Pier Head and Tower Foot both
## blow, on the half the ladder is not on.
func test_no_wind_reaches_a_ladder() -> void:
	for spec in TurbineRow.ROOMS:
		var shaft: Array = spec.get("shaft", spec.get("shaft_up", []))
		if shaft.is_empty():
			continue
		var from := int(shaft[0])
		var to := from + int(shaft[1])
		for entry in spec.get("wind", []):
			var w_from := int(entry.get("from", 0))
			var w_to := int(entry.get("to", AuthoredStage.ROOM_WIDTH))
			assert_true(w_to <= from or w_from >= to,
				"%s: a zone at %d-%d covers the ladder at %d-%d"
					% [spec["name"], w_from, w_to, from, to])


# --- The two things the stage does not contain ------------------------------------

## No phase blocks. One takes the floor away on a timer and a gust takes your
## footing away on a timer; a room with both asks the player to read two
## invisible clocks against each other.
func test_the_stage_contains_no_phase_blocks() -> void:
	for spec in TurbineRow.ROOMS:
		assert_false(spec.has("mirrors"),
			"%s has a panel path; stage 4 owns timed geometry" % spec["name"])
		assert_true((spec.get("crumbles", []) as Array).is_empty(),
			"%s has crumbling blocks" % spec["name"])


## No crushers. A press is a thing that takes a column of space away on a cycle
## and a zone is a thing that takes control of a column of space on a cycle --
## same sentence, and a room with both has two tells the player cannot tell
## apart.
func test_the_stage_contains_no_crushers() -> void:
	for spec in TurbineRow.ROOMS:
		assert_false(spec.has("crushers"),
			"%s has a press; stage 3 owns the cycle that closes a column" % spec["name"])


## And the arena is still air. Gale's Crosswind writes the player's drift every
## frame; a room zone writing it as well is two authorities on one number.
func test_the_arena_has_no_wind() -> void:
	var arena: Dictionary = TurbineRow.ROOMS[TurbineRow.ROOMS.size() - 1]
	var gate: Dictionary = TurbineRow.ROOMS[TurbineRow.ROOMS.size() - 2]
	assert_false(arena.has("wind"), "the arena blows as well as the boss")
	assert_false(gate.has("wind"), "the run-up to the fight blows")


# --- Built, not just authored -----------------------------------------------------

## The stage is built and the zones are counted. Every check above reads the room
## table, and the M6i shaft bug shipped in three stages with a table that was
## right -- so this one measures where the boxes actually landed.
func test_every_authored_zone_is_built_where_its_room_puts_it() -> void:
	var stage: AuthoredStage = await _build()
	var tile := stage.tile_size()
	var matched := 0
	for index in TurbineRow.ROOMS.size():
		var spec: Dictionary = TurbineRow.ROOMS[index]
		var origin := stage.room_origin(index)
		var deck := stage.room_deck_row(index)
		for entry in spec.get("wind", []):
			var from := int(entry.get("from", 0))
			var to := int(entry.get("to", AuthoredStage.ROOM_WIDTH))
			# The zone's origin is its top-left corner, which is the room's own
			# top-left -- see WindZone._ready, which anchors its box there rather
			# than centring it on the node.
			var want := Vector2(float(origin + from),
				float(deck) - float(AuthoredStage.DECK_ROW - AuthoredStage.ROOM_TOP)) * tile
			var zone := _zone_at(stage, want)
			assert_true(zone != null,
				"%s: no wind zone at cell %d" % [spec["name"], from])
			if zone == null:
				continue
			matched += 1
			assert_eq(zone.direction, int(entry.get("dir", 1)),
				"%s: the zone at cell %d blows the wrong way" % [spec["name"], from])
			assert_eq(zone.phase_frames, int(entry.get("phase", 0)),
				"%s: the zone at cell %d carries the wrong phase" % [spec["name"], from])
			assert_almost_eq(zone.width_tiles, float(to - from), 0.01,
				"%s: the zone at cell %d is the wrong width" % [spec["name"], from])
	# And nothing else: a stage that built a zone the table never asked for is as
	# wrong as one that missed one.
	assert_eq(stage.wind_zones().size(), matched,
		"%d zones built, %d authored" % [stage.wind_zones().size(), matched])
	await _drop(stage)


func test_the_stage_brings_gale_its_tileset_and_its_backdrop() -> void:
	var stage: AuthoredStage = await _build()
	assert_eq(stage.boss_name(), "Gale")
	assert_true(stage.boss_script() != null, "no boss script")
	assert_true(stage.stage_tile_set() != null, "no tileset")
	assert_true(stage.backdrop_script() != null, "no backdrop")
	assert_true(ResourceLoader.exists(stage.boss_frames_path()),
		"Gale's sprite frames are missing")
	await _drop(stage)


func test_the_roster_points_at_this_stage() -> void:
	var row := StageRoster.entry(Gale.INDEX)
	assert_eq(String(row["stage"]), "Turbine Row")
	assert_eq(String(row["boss"]), "Gale")
	assert_eq(String(row["scene"]), SCENE)
	assert_true(StageRoster.is_built(Gale.INDEX),
		"the select screen still shows Turbine Row as unbuilt")


# --- Helpers ---------------------------------------------------------------------

func _jump_airtime_frames(t: PlayerTuning) -> float:
	var v := -t.jump_velocity_pf
	var y := 0.0
	var frames := 0
	while true:
		v += t.gravity_pf
		y += v
		frames += 1
		if y >= 0.0:
			break
	return float(frames)


## Which phase a zone would be in at a given frame of the cycle. Computed rather
## than driven, because a zone outside the tree never ticks.
func _phase_at(zone: WindZone, frame: int) -> WindZone.Phase:
	var at := (frame + zone.phase_frames) % zone.cycle_frames()
	if at < zone.lull_frames:
		return WindZone.Phase.LULL
	if at < zone.lull_frames + zone.tell_frames:
		return WindZone.Phase.TELL
	return WindZone.Phase.GUST


func _first_room_with_wind() -> int:
	for i in TurbineRow.ROOMS.size():
		if TurbineRow.ROOMS[i].has("wind"):
			return i
	return -1


func _room(name: String) -> Dictionary:
	for spec in TurbineRow.ROOMS:
		if String(spec["name"]) == name:
			return spec
	return {}


func _zone_at(stage: AuthoredStage, at: Vector2) -> WindZone:
	for zone in stage.wind_zones():
		if zone.position.distance_to(at) < 1.0:
			return zone
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
