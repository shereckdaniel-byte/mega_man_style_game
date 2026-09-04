## The rules every authored stage has to obey, checked against every stage.
##
## **Per-stage authoring tests do not scale, and worse, they do not transfer.**
## `test_dawn_boardwalk.gd` has caught real faults in stage 1 since M4 -- a step
## the jump cannot clear, a gap wider than the arc -- and every one of those
## rules is about the player, not about the boardwalk. Stage 2 was authored
## against none of them, because they lived in a file named after stage 1.
##
## So the rules that are about the *player* live here and loop over the roster.
## A stage added to STAGES is a stage held to all of them.
##
## Three of these were written the expensive way, by the playthrough bot dying
## on stage 2 and the fault turning out to be in stage 1 as well:
##
##   * a gap in a column that has another band beneath it is not a pit, it is a
##     hole into a room the stage does not know you are in;
##   * a spiked tunnel narrower than the slide's reach plus its approach is
##     cleared or not depending on which pixel the slide began at;
##   * a ceiling over a shaft hangs its teeth in the space the ladder delivers
##     the player to.
extends TestCase

const STAGES := {
	"dawn_boardwalk": preload("res://scenes/stages/dawn_boardwalk/dawn_boardwalk.gd"),
	"substation": preload("res://scenes/stages/substation/substation.gd"),
	"breakers": preload("res://scenes/stages/breakers/breakers.gd"),
}

## A spiked slide tunnel is at most this wide, in cells.
##
## A slide covers 4.06 tiles from where it starts, and both the bot and a player
## commit up to two cells before the lip -- so three cells of tunnel leaves about
## one of slack and comes down to timing. Two leaves two.
const MAX_SPIKED_TUNNEL_TILES := 2


func test_every_stage_is_registered_here() -> void:
	# A stage that exists and is not in STAGES is a stage none of this checks.
	var found := 0
	for path in _stage_scripts():
		found += 1
		assert_true(_is_registered(path), "%s is not in this test's STAGES" % path)
	assert_eq(found, STAGES.size(), "stage scripts on disk vs stages under test")


## A block the jump cannot clear is a wall the level does not look like it has.
##
## The rule is the **rise between successive levels**, not the height above the
## deck: the Tide room is a 2/4/6 staircase climbed ahead of the water, and every
## step of it is two tiles. Checking absolute height would call that unclimbable
## and it is the best-designed room in stage 1.
func test_no_step_is_taller_than_the_jump() -> void:
	for name in STAGES:
		var script: GDScript = STAGES[name]
		for spec in script.ROOMS:
			var heights: Array[int] = [0]  # the deck itself
			for block in spec.get("blocks", []):
				var h := int(block[1])
				if not heights.has(h):
					heights.append(h)
			heights.sort()
			for i in range(1, heights.size()):
				var rise: int = heights[i] - heights[i - 1]
				assert_true(rise <= AuthoredStage.MAX_STEP_TILES,
					"%s/%s: a %d-tile rise from %d to %d, and the jump clears %d"
						% [name, spec["name"], rise, heights[i - 1], heights[i],
							AuthoredStage.MAX_STEP_TILES])


## A gap wider than the arc has to be crossed by something.
func test_a_gap_past_the_jump_has_a_platform_over_it() -> void:
	for name in STAGES:
		var script: GDScript = STAGES[name]
		for spec in script.ROOMS:
			for gap in spec.get("gaps", []):
				var width := int(gap[1]) - int(gap[0])
				if width <= AuthoredStage.MAX_GAP_TILES:
					continue
				assert_false(spec.get("movers", []).is_empty(),
					"%s/%s: a %d-cell gap with nothing to cross it"
						% [name, spec["name"], width])


## **A gap is only a pit if there is nothing underneath.**
##
## In a column that carries another band below it, a hole in the deck drops the
## player into the room beneath without passing through its door: the camera, the
## room's enemies and anything hung off `room_changed` all stay behind. The
## player is then standing in a room the stage does not think they are in, which
## on stage 2 read as a soft lock at the far wall.
func test_a_gap_is_never_cut_over_another_room() -> void:
	for name in STAGES:
		var script: GDScript = STAGES[name]
		var deepest := _deepest_band_per_column(script)
		for index in script.ROOMS.size():
			var spec: Dictionary = script.ROOMS[index]
			if spec.get("gaps", []).is_empty():
				continue
			var col := int(spec["col"])
			assert_eq(int(spec["band"]), int(deepest[col]),
				"%s/%s: gaps in band %d, but column %d goes down to band %d"
					% [name, spec["name"], int(spec["band"]), col, int(deepest[col])])


## A ceiling in a shaft's column hangs over the spot the ladder delivers to.
func test_no_ceiling_stands_in_a_shaft() -> void:
	for name in STAGES:
		var script: GDScript = STAGES[name]
		for spec in script.ROOMS:
			var shaft: Array = spec.get("shaft", spec.get("shaft_up", []))
			if shaft.is_empty():
				continue
			var from := int(shaft[0])
			var to := from + int(shaft[1])
			for ceiling in spec.get("ceilings", []):
				var c_from := int(ceiling[0])
				var c_to := c_from + int(ceiling[2])
				assert_true(c_to <= from or c_from >= to,
					"%s/%s: a ceiling at %d-%d sits over the shaft at %d-%d"
						% [name, spec["name"], c_from, c_to, from, to])


## Teeth mean the tunnel has to be the wider kind, or the slide has nowhere to go.
func test_a_spiked_tunnel_has_the_spiked_clearance() -> void:
	for name in STAGES:
		var script: GDScript = STAGES[name]
		for spec in script.ROOMS:
			for teeth in spec.get("ceiling_spikes", []):
				assert_eq(int(teeth[1]), AuthoredStage.SPIKED_CLEARANCE,
					"%s/%s: spiked tunnel at %d has %d rows of clearance, needs %d"
						% [name, spec["name"], int(teeth[0]), int(teeth[1]),
							AuthoredStage.SPIKED_CLEARANCE])
				assert_true(int(teeth[2]) <= MAX_SPIKED_TUNNEL_TILES,
					"%s/%s: a %d-cell spiked tunnel is past the %d-cell limit"
						% [name, spec["name"], int(teeth[2]),
							MAX_SPIKED_TUNNEL_TILES])


## Every spiked tunnel must have a ceiling to hang from, and it must line up.
func test_ceiling_spikes_hang_from_a_real_ceiling() -> void:
	for name in STAGES:
		var script: GDScript = STAGES[name]
		for spec in script.ROOMS:
			for teeth in spec.get("ceiling_spikes", []):
				var matched := false
				for ceiling in spec.get("ceilings", []):
					if int(ceiling[0]) == int(teeth[0]) \
							and int(ceiling[1]) == int(teeth[1]) \
							and int(ceiling[2]) == int(teeth[2]):
						matched = true
				assert_true(matched,
					"%s/%s: spikes at %d have no matching ceiling"
						% [name, spec["name"], int(teeth[0])])


## **The arithmetic the tunnel stands on**: a sliding player fits under the teeth
## and a standing one does not.
##
## Against the real hitboxes and the real constants rather than against the
## numbers in the comment, so that changing either hitbox, the clearance or the
## spike depth fails here instead of quietly closing every tunnel in the game --
## which is what happened, and went unnoticed for two milestones.
func test_a_slide_fits_under_the_teeth_and_standing_does_not() -> void:
	var t := PlayerTuning.new()
	var tile := t.tile_size()
	# Deck surface at y = 0 for the arithmetic; the opening is above it.
	var opening_top := -float(AuthoredStage.SPIKED_CLEARANCE) * tile
	var teeth_bottom := opening_top + AuthoredStage.CEILING_SPIKE_DEPTH * tile
	var standing_head := -t.hitbox_size().y
	var sliding_head := -t.slide_hitbox_size().y

	assert_true(standing_head < teeth_bottom,
		"a standing head (%.0f) clears the teeth (%.0f) -- the tunnel warns nobody"
			% [standing_head, teeth_bottom])
	assert_true(sliding_head > teeth_bottom,
		"a sliding head (%.0f) is inside the teeth (%.0f) -- the tunnel is shut"
			% [sliding_head, teeth_bottom])
	# And with margin at both ends, rather than to the pixel.
	assert_true(sliding_head - teeth_bottom >= tile * 0.15,
		"only %.0f px of slide clearance" % [sliding_head - teeth_bottom])


## **Every skin a stage names has to exist.**
##
## A missing one is silent by construction: `AuthoredStage._add_marker` skips a
## marker whose `SpriteFrames` are not on disk, which is right at runtime -- a
## stage mid-regeneration should still open -- and means a typo in the skin
## column deletes an enemy rather than erroring. Stage 1 has had this rule since
## M4 and stage 2 was never held to it, because it lived in a file named after
## stage 1.
func test_every_enemy_a_stage_names_has_art() -> void:
	for name in STAGES:
		var script: GDScript = STAGES[name]
		for spec in script.ROOMS:
			for entry in spec.get("enemies", []):
				var path := "res://resources/sprite_frames/%s.tres" % entry[1]
				assert_true(ResourceLoader.exists(path),
					"%s/%s: no art for %s -- the marker would be skipped in silence"
						% [name, spec["name"], entry[1]])


## And the art must carry the animation the table asks it to play. `Enemy` falls
## back to the first animation in the resource, so a wrong name here is a walker
## playing its death clip on a loop rather than an error.
func test_every_enemy_has_the_animation_its_table_names() -> void:
	for name in STAGES:
		var script: GDScript = STAGES[name]
		for spec in script.ROOMS:
			for entry in spec.get("enemies", []):
				var path := "res://resources/sprite_frames/%s.tres" % entry[1]
				if not ResourceLoader.exists(path):
					continue
				var frames := load(path) as SpriteFrames
				assert_true(frames.has_animation(entry[2]),
					"%s: %s has no '%s' animation (it has %s)"
						% [name, entry[1], entry[2],
							", ".join(frames.get_animation_names())])


## A checkpoint over a gap respawns the player into the pit, forever.
func test_every_checkpoint_stands_on_solid_deck() -> void:
	for name in STAGES:
		var script: GDScript = STAGES[name]
		for spec in script.ROOMS:
			var cell := float(spec["checkpoint"])
			if is_equal_approx(cell, AuthoredStage.NO_CHECKPOINT):
				continue
			for gap in spec.get("gaps", []):
				assert_false(cell >= float(gap[0]) and cell < float(gap[1]),
					"%s/%s: the checkpoint at %.0f is over a gap"
						% [name, spec["name"], cell])


## The last room is the arena and the one before it is the run-up. Both derived
## by AuthoredStage from the table's length, so a table that puts content in
## either breaks the fight rather than the walk.
func test_the_last_two_rooms_are_clear_for_the_boss() -> void:
	for name in STAGES:
		var script: GDScript = STAGES[name]
		var rooms: Array = script.ROOMS
		for index in [rooms.size() - 2, rooms.size() - 1]:
			var spec: Dictionary = rooms[index]
			assert_true(spec.get("gaps", []).is_empty(),
				"%s/%s: a gap in the run-up to the boss" % [name, spec["name"]])
			assert_true(spec.get("enemies", []).is_empty(),
				"%s/%s: enemies in the run-up to the boss" % [name, spec["name"]])
		assert_true(is_equal_approx(float(rooms[rooms.size() - 1]["checkpoint"]),
				AuthoredStage.NO_CHECKPOINT),
			"%s: a checkpoint inside the arena would let a dead player respawn past the seal"
				% name)


# --- Helpers -------------------------------------------------------------------

func _deepest_band_per_column(script: GDScript) -> Dictionary:
	var deepest: Dictionary = {}
	for spec in script.ROOMS:
		var col := int(spec["col"])
		var band := int(spec["band"])
		deepest[col] = maxi(int(deepest.get(col, band)), band)
	return deepest


## Stage scripts on disk: one `<name>/<name>.gd` per directory under scenes/stages,
## minus the harnesses that are not stages.
func _stage_scripts() -> PackedStringArray:
	const NOT_STAGES := ["test_room"]
	var out := PackedStringArray()
	var dir := DirAccess.open("res://scenes/stages")
	if dir == null:
		return out
	for name in dir.get_directories():
		if NOT_STAGES.has(name):
			continue
		var path := "res://scenes/stages/%s/%s.gd" % [name, name]
		if ResourceLoader.exists(path):
			out.append(path)
	return out


func _is_registered(path: String) -> bool:
	for name in STAGES:
		if (STAGES[name] as GDScript).resource_path == path:
			return true
	return false
