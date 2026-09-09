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
	"mirror_field": preload("res://scenes/stages/mirror_field/mirror_field.gd"),
	"turbine_row": preload("res://scenes/stages/turbine_row/turbine_row.gd"),
	"stack": preload("res://scenes/stages/stack/stack.gd"),
	"cold_store": preload("res://scenes/stages/cold_store/cold_store.gd"),
	"sinkhole": preload("res://scenes/stages/sinkhole/sinkhole.gd"),
	# The fortress. Held to every rule above: a gap the jump cannot clear is a
	# gap the jump cannot clear, and the last quarter of the game is not where
	# the fairness rules get to relax.
	"outfall": preload("res://scenes/stages/outfall/outfall.gd"),
	"caisson": preload("res://scenes/stages/caisson/caisson.gd"),
	"switchgear": preload("res://scenes/stages/switchgear/switchgear.gd"),
	"keep": preload("res://scenes/stages/keep/keep.gd"),
}

## A spiked slide tunnel is at most this wide, in cells.
##
## A slide covers 4.06 tiles from where it starts, and both the bot and a player
## commit up to two cells before the lip -- so three cells of tunnel leaves about
## one of slack and comes down to timing. Two leaves two.
const MAX_SPIKED_TUNNEL_TILES := 2

## Cells a panel path's ends may sit from the lips of the gap it crosses.
##
## Two, which is the jump's comfortable reach -- the same number
## `AuthoredStage.MAX_GAP_TILES` is, arrived at from the other side. Three is the
## frame-perfect distance and a path should not open or close on one.
const MAX_LIP_REACH_CELLS := 2


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
##
## **"Something" grew a second member at stage 4** and the rule did not notice.
## Until Mirror Field the only thing in the kit that crossed a wide gap was a
## moving platform, so this asked for a mover by name -- and a stage whose
## crossings are all panel paths would have failed it on every one of them while
## being perfectly crossable. A rule that names one implementation is a rule
## about the kit rather than about the player, which is the mistake this whole
## file exists to stop.
func test_a_gap_past_the_jump_has_a_platform_over_it() -> void:
	for name in STAGES:
		var script: GDScript = STAGES[name]
		for spec in script.ROOMS:
			for gap in spec.get("gaps", []):
				var width := int(gap[1]) - int(gap[0])
				if width <= AuthoredStage.MAX_GAP_TILES:
					continue
				var crossed: bool = not spec.get("movers", []).is_empty() \
					or _panels_span(spec, int(gap[0]), int(gap[1]))
				assert_true(crossed,
					"%s/%s: a %d-cell gap with nothing to cross it"
						% [name, spec["name"], width])


## **A panel path has to be crossable one panel at a time.**
##
## The same two numbers every other piece of geometry is held to, applied to the
## thing that is *made* of geometry: consecutive panels no further apart than the
## jump covers and no higher than it reaches. A path that breaks either is a path
## that looks like a route and is a dead end in the middle of a pit, and nothing
## about it reads wrong from a screenshot -- the panels are all there, they are
## just never both there at a distance a player can cross.
##
## Checked between *successive* entries, because the list order is the beat order
## (see `PhaseBlock`): panel 3 is only ever reached from panel 2.
func test_every_panel_in_a_path_is_within_a_jump_of_the_last() -> void:
	for name in STAGES:
		var script: GDScript = STAGES[name]
		for spec in script.ROOMS:
			for set_entry in spec.get("mirrors", []):
				var path: Array = set_entry["path"]
				for i in range(1, path.size()):
					var across: int = absi(int(path[i][0]) - int(path[i - 1][0]))
					var rise: int = int(path[i][1]) - int(path[i - 1][1])
					assert_true(across <= AuthoredStage.MAX_GAP_TILES + 1,
						"%s/%s: %d cells between panel %d and %d, and the jump covers about %d"
							% [name, spec["name"], across, i - 1, i,
								AuthoredStage.MAX_GAP_TILES + 1])
					assert_true(rise <= AuthoredStage.MAX_STEP_TILES,
						"%s/%s: a %d-tile rise between panel %d and %d, and the jump clears %d"
							% [name, spec["name"], rise, i - 1, i,
								AuthoredStage.MAX_STEP_TILES])


## **A path is only a path if it is longer than two.**
##
## Structural rather than a taste: a panel is solid for `SOLID_BEATS` beats and a
## set's cycle is one beat per panel, so with two panels every panel is solid all
## the time. The room would ship a permanent staircase that the table describes
## as a disappearing one, and it would look completely correct in a screenshot.
func test_no_panel_path_is_shorter_than_the_gimmick_needs() -> void:
	for name in STAGES:
		var script: GDScript = STAGES[name]
		for spec in script.ROOMS:
			for set_entry in spec.get("mirrors", []):
				assert_true((set_entry["path"] as Array).size() > PhaseBlock.SOLID_BEATS,
					"%s/%s: a %d-panel path never disappears"
						% [name, spec["name"], (set_entry["path"] as Array).size()])


## The first panel of a path must be reachable from the deck the player is
## standing on, and the last must land them back on it.
##
## A path that starts two cells inside a gap is a path whose first panel is a
## jump into a pit, and one that ends two cells short of the far lip is worse:
## the player crosses the whole thing correctly and falls off the end.
func test_a_panel_path_reaches_both_lips_of_its_gap() -> void:
	for name in STAGES:
		var script: GDScript = STAGES[name]
		for spec in script.ROOMS:
			for gap in spec.get("gaps", []):
				if int(gap[1]) - int(gap[0]) <= AuthoredStage.MAX_GAP_TILES:
					continue
				if not _panels_span(spec, int(gap[0]), int(gap[1])):
					continue  # crossed by a mover; not this rule's business
				for set_entry in spec.get("mirrors", []):
					var path: Array = set_entry["path"]
					var first := int(path[0][0])
					var last := int(path[path.size() - 1][0])
					if last < int(gap[0]) or first >= int(gap[1]):
						continue  # this set is not over this gap
					# The near lip is the last solid cell before the gap, the far
					# lip the first solid cell after it.
					assert_true(first - (int(gap[0]) - 1) <= MAX_LIP_REACH_CELLS,
						"%s/%s: the first panel is %d cells from the near lip"
							% [name, spec["name"], first - int(gap[0]) + 1])
					assert_true(int(gap[1]) - last <= MAX_LIP_REACH_CELLS,
						"%s/%s: the last panel is %d cells from the far lip"
							% [name, spec["name"], int(gap[1]) - last])


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


## **A gap must not start within a jump of whatever stands before it.**
##
## Anything the player can be on top of -- a block, a one-way platform, the roof
## of a slide tunnel -- is something they can jump off, and a jump taken from up
## there starts with height already spent and carries further than one from the
## ground. Put a hole inside that reach and the level has built a leap into a
## pit that looks, from a screenshot, like a generous run-up.
##
## This has cost three rooms across two milestones, twice in the same stage.
## Stage 1's Pilings records the first in a comment -- a slide overhang at cell 6
## "sets the player down at 10, which is the lip of the gap. The bot fell in
## fourteen times running before this moved." Boardwalk then hit it twice while
## being authored: once with two cells of run-up (four deaths, the whole life
## counter, in one room) and again with **four**, which reads like plenty and is
## not, because the jump came off a two-tile step.
##
## So the clearance is measured rather than guessed: `RUN_UP_CELLS` of flat deck
## for every gap, **plus one cell per tile of height for a block**, because a
## block is the one of these the route goes over rather than under.
##
## That distinction is not a loophole, it is the reason two shipped rooms are
## fine. Pilings has a tunnel roof three cells from a gap and Under West a
## one-way platform three cells from one, and neither has ever dropped anybody
## in: the player slides *under* the first and walks *under* the second, so
## neither is a place they jump from. A block on the deck is the floor -- the
## route crosses its top, and the height it adds to a jump is height the level
## chose to give. A player who climbs a one-way and leaps off it has taken a
## route the room did not ask for, and the low road is still there.
const RUN_UP_CELLS := 3

func test_a_gap_does_not_start_within_a_jump_of_a_drop() -> void:
	for name in STAGES:
		var script: GDScript = STAGES[name]
		for spec in script.ROOMS:
			for gap in spec.get("gaps", []):
				var start := int(gap[0])
				# All three read [x, rise, w, ...]; only a block gets the height
				# term, for the reason above.
				for key in ["blocks", "one_ways", "ceilings"]:
					for entry in spec.get(key, []):
						var ends: int = int(entry[0]) + int(entry[2])
						var rise: int = int(entry[1]) if key == "blocks" else 0
						var needed: int = RUN_UP_CELLS + rise
						if ends <= start - needed or ends > start:
							continue
						assert_true(false,
							"%s/%s: a %s ending at %d leaves %d cells before the gap at %d, and a jump off it needs %d"
								% [name, spec["name"], key.trim_suffix("s"),
									ends, start - ends, start, needed])


## **A floor-spike bed is a gap you cannot fall into, so it is bounded like one.**
##
## The route goes *over* a bed of spikes, which means its width is limited by
## what a jump covers -- exactly as a hole is by `MAX_GAP_TILES` -- and it needs
## the same `RUN_UP_CELLS` of still deck to leave from.
##
## Stack shipped the game's first floor-spike bed at four cells wide with a
## conveyor running into it. Nothing here knew about floor spikes, so nothing
## objected: the room had no gap, no step and no tunnel, and every existing rule
## passed it. The bot walked into the teeth five times a run and never got past.
## A hole that wide would have been caught by the rule directly above this one.
func test_a_spike_bed_is_no_wider_than_a_jump_and_has_a_run_up() -> void:
	for name in STAGES:
		var script: GDScript = STAGES[name]
		for spec in script.ROOMS:
			for bed in spec.get("spikes", []):
				var from := int(bed[0])
				var width := int(bed[2])
				assert_true(width <= AuthoredStage.MAX_GAP_TILES,
					"%s/%s: a %d-cell spike bed, and a jump clears %d"
						% [name, spec["name"], width, AuthoredStage.MAX_GAP_TILES])
				# The same clearance a gap gets, measured against the same things
				# a gap is measured against.
				for key in ["blocks", "one_ways", "ceilings"]:
					for entry in spec.get(key, []):
						var ends: int = int(entry[0]) + int(entry[2])
						var rise: int = int(entry[1]) if key == "blocks" else 0
						var needed: int = RUN_UP_CELLS + rise
						if ends <= from - needed or ends > from:
							continue
						assert_true(false,
							"%s/%s: a %s ending at %d leaves %d cells before the spikes at %d, and a jump off it needs %d"
								% [name, spec["name"], key.trim_suffix("s"),
									ends, from - ends, from, needed])


## **A room that changes band needs a ladder, and this is the third time.**
##
## The room table is a sequence: room *i* and room *i+1* are consecutive rooms
## the player walks between. Two of them in the same band and adjacent columns
## are joined by a door, which `AuthoredStage` hangs automatically. Two of them
## in the same column and adjacent bands are joined by a **ladder**, which it
## does not -- a `shaft` on the upper room or a `shaft_up` on the lower one, and
## if the table does not say so there is nothing there.
##
## What that looks like in play is the room simply ending. The player walks to
## the far side of the last room in the band and falls off the deck into the
## pit plane, over and over, and the stage is unfinishable from that room on.
##
## Cold Store shipped it at M6 -- Rail had no `shaft` and stage 7 stopped at
## room 3 -- and Outfall shipped it again in the first hour of M7, with Head
## missing the `shaft_up` out of the works. Both were found by running the bot,
## which is the wrong way round: the bot tells you *a* room is broken, and only
## after a full run. This asks the table directly, for every stage at once, and
## it would have caught both before either was ever built.
func test_every_change_of_band_has_a_ladder() -> void:
	for name in STAGES:
		var script: GDScript = STAGES[name]
		for i in range(script.ROOMS.size() - 1):
			var here: Dictionary = script.ROOMS[i]
			var next: Dictionary = script.ROOMS[i + 1]
			if String(here.get("exit", "door")) == "teleport":
				# Nobody walks this link, so there is nothing to walk it with.
				# Switchgear's eight arenas have no connection to each other or
				# to anything else -- see `AuthoredStage.is_teleport_link`.
				continue
			var d_band := int(next["band"]) - int(here["band"])
			var d_col := int(next["col"]) - int(here["col"])
			if d_band == 0:
				assert_eq(absi(d_col), 1,
					"%s: %s -> %s stays in band %d and jumps %d columns"
						% [name, here["name"], next["name"], int(here["band"]), d_col])
				continue
			# A change of band is a change of band only: the ladder is vertical.
			assert_eq(d_col, 0,
				"%s: %s -> %s changes band and column at once"
					% [name, here["name"], next["name"]])
			assert_eq(absi(d_band), 1,
				"%s: %s -> %s skips %d bands"
					% [name, here["name"], next["name"], absi(d_band)])
			# Down is a `shaft` on the room being left; up is a `shaft_up` on it.
			# The other spelling is not a near miss -- it holes the wrong deck.
			var key := "shaft" if d_band > 0 else "shaft_up"
			assert_true(here.has(key),
				"%s: %s goes %s into %s and has no `%s`"
					% [name, here["name"], "down" if d_band > 0 else "up",
						next["name"], key])


## **A crumbling block is a floor, and a floor is in the deck.**
##
## `crumbles` is `[x, rows_above_deck]`, and every one of the fifty-odd in the
## game is at 0 -- they *are* the deck across a hole, which is the only thing
## they have ever been used for. Authored at rise 2 they become one-tile blocks
## floating two rows up, and the gap they leave under themselves is one tile
## against a standing player who is a tile and a half: a ceiling nothing can
## walk under and nothing marked as a ceiling.
##
## Keep shipped three of them that way and the bot stood in front of the first
## for 900 frames. Nothing objected, because a crumble is not a `block`, not a
## `ceiling` and not a `gap`, so every existing rule looked straight past it.
func test_every_crumble_is_in_the_deck() -> void:
	for name in STAGES:
		var script: GDScript = STAGES[name]
		for spec in script.ROOMS:
			for block in spec.get("crumbles", []):
				assert_eq(block.size(), 2,
					"%s/%s: a crumble is [x, rows_above_deck] and this has %d entries"
						% [name, spec["name"], block.size()])
				assert_eq(int(block[1]), 0,
					"%s/%s: a crumble %d rows above the deck is a low ceiling"
						% [name, spec["name"], int(block[1])])


## **A moving platform the jump cannot reach is a ride you watch go past.**
##
## `movers` is `[x, rows_above_deck, dx, dy, frames]`, and a jump clears 2.89
## tiles. Keep authored one at four rows up: the bot walked to the lip of the
## hole it was meant to cross and waited there for 900 frames for a platform it
## could never board, which from the outside looks exactly like a bot that has
## stopped working.
##
## Measured against the real apex rather than a number, so a change to the jump
## fails the stages rather than quietly stranding one.
func test_every_mover_is_within_a_jump_of_the_deck() -> void:
	var reach := PlayerTuning.new().jump_apex_tiles()
	for name in STAGES:
		var script: GDScript = STAGES[name]
		for spec in script.ROOMS:
			for mover in spec.get("movers", []):
				var rows := float(mover[1])
				assert_true(rows <= reach,
					"%s/%s: a mover %.0f rows up, and a jump reaches %.2f tiles"
						% [name, spec["name"], rows, reach])


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


## **Nothing may be built on the spot a ladder delivers to.**
##
## `SHAFT_LANDING_CELLS` promises solid *deck* past an upward shaft, and every
## check so far has read that as "not a hole". It is also "not a wall": a block
## reaching across the landing spawns the player inside solid terrain, and Godot
## resolves that by shoving them out sideways.
##
## The shove is the interesting part, because it is not what it looks like. On
## Mirror Field it moved the player the last few pixels into the *next* room's
## door while the climb was still running -- `Stage.begin_transition` refused it
## as re-entrant and, until this was found, spent the door permanently. The stage
## then ran Tower -> Gate with Focus never entered: its enemies never spawned,
## its row in the ledger stayed blank, and the bot walked the whole room while
## the game believed it was somewhere else. Nothing errored.
##
## The landing belongs to the band **above** the room that declares the shaft,
## which is the same distinction the M6i shaft bug turned on.
func test_nothing_is_built_on_a_shafts_landing() -> void:
	for name in STAGES:
		var script: GDScript = STAGES[name]
		for spec in script.ROOMS:
			if not spec.has("shaft_up"):
				continue
			var shaft: Array = spec["shaft_up"]
			var from := int(shaft[0])
			var to := from + int(shaft[1]) + AuthoredStage.SHAFT_LANDING_CELLS
			var above := _room_at(script, int(spec["col"]), int(spec["band"]) - 1)
			assert_false(above.is_empty(),
				"%s/%s: a shaft_up into no room" % [name, spec["name"]])
			if above.is_empty():
				continue
			for key in ["blocks", "ceilings"]:
				for entry in above.get(key, []):
					var b_from := int(entry[0])
					var b_to := b_from + int(entry[2])
					assert_true(b_to <= from or b_from >= to,
						"%s/%s: a %s at %d-%d stands on %s's landing at %d-%d"
							% [name, above["name"], key, b_from, b_to,
								spec["name"], from, to])


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
			# Timed geometry belongs to the walk, not to the fight. A panel in
			# the arena asks the player to solve the floor and the boss at once,
			# which is the argument Breakers keeps the press out of Rust's room
			# on.
			assert_true(spec.get("mirrors", []).is_empty(),
				"%s/%s: a panel path in the run-up to the boss"
					% [name, spec["name"]])
		assert_true(is_equal_approx(float(rooms[rooms.size() - 1]["checkpoint"]),
				AuthoredStage.NO_CHECKPOINT),
			"%s: a checkpoint inside the arena would let a dead player respawn past the seal"
				% name)


# --- Helpers -------------------------------------------------------------------

## Does some panel path in this room actually reach across `[from, to)`?
##
## "There is a `mirrors` key in the room" is not the question -- Pylons has one
## over solid deck and it crosses nothing. What counts is a set with a panel at
## or before the near lip and one at or after the far one.
func _panels_span(spec: Dictionary, from: int, to: int) -> bool:
	for set_entry in spec.get("mirrors", []):
		var path: Array = set_entry["path"]
		if path.is_empty():
			continue
		var lowest := int(path[0][0])
		var highest := int(path[0][0])
		for at in path:
			lowest = mini(lowest, int(at[0]))
			highest = maxi(highest, int(at[0]))
		if lowest <= from + MAX_LIP_REACH_CELLS - 1 \
				and highest >= to - MAX_LIP_REACH_CELLS:
			return true
	return false


## The room at a grid position, or {} when the stage has none there.
func _room_at(script: GDScript, col: int, band: int) -> Dictionary:
	for spec in script.ROOMS:
		if int(spec["col"]) == col and int(spec["band"]) == band:
			return spec
	return {}


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
