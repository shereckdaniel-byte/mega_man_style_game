## Stage 7, "Cold Store" -- the refrigerated docks, and Frost's stage.
##
## Nineteen rooms across **two** bands, crossed **five times**. Stage 1 is a W,
## stage 2 a long J, stage 3 a staircase that only climbs, stage 4 fourteen flat
## rooms and one turn, stage 5 a V, stage 6 a descent. This one is a zigzag: the
## fewest bands of any stage since the first and the most changes between them,
## which is what two decks of cold rooms stacked on each other actually is. The
## player is never more than four rooms from a ladder.
##
##   col   0    1     2      3     4     5      6     7    8      9    10    11    12   13
##  band 0 Dock-Cold--Rail        Freezr-Conden-DownP           Loft--ColdL-HeadH
##                   |              ^          |                 ^          |
##  band 1          SubZero-Brine-Rack--Upper       Chill-Glaze-Blast-Riser      Gate-Arena
##
## ### The gimmick: ice
##
## `IceFloor` carries the grammar and the three fairness rules. What belongs
## here is the order the rooms teach it in, and the sentence that separates this
## stage from the two before it:
##
## **The wind is a cycle you time. The belt is a constant you fight. Ice is
## neither -- it moves nobody.**
##
## Stages 5 and 6 both push the player, and a third push would be one lesson
## taught three times however differently it was dressed. Ice takes away the
## thing the controller has always guaranteed instead: that letting go stops
## you. Nothing carries the player anywhere they did not ask to go; they simply
## arrive after they stopped asking.
##
##   * **Cold Room** -- a sheet over solid deck with nothing to fall into. Free,
##     as every gimmick's first appearance has been since stage 2's Riser, and
##     what it teaches is that the floor no longer answers immediately.
##   * **Brine Line** -- the first paid one: a sheet that ends before a hole,
##     with `STOP_MARGIN_CELLS` of grippy deck to stop on. That margin is the
##     stage's whole safety argument and it is checked, not eyeballed.
##   * **Racking** -- a slide tunnel that ends on ice. A slide covers a fixed
##     distance and cannot be cancelled; ending it on a floor that will not stop
##     you is the one place the two ideas multiply.
##   * **Glaze** -- the exam: alternating sheets and bare deck, so every landing
##     is either a place you can stop or a place you cannot, and telling them
##     apart is the room.
##
## ### Rule 3 is the one that matters
##
## **An ice run ends at least `STOP_MARGIN_CELLS` before any hole.** Stage 5
## paid a lot to learn that a force which reaches the take-off can make authored
## gaps uncrossable and that no retuning fixes it. Ice does not reach the jump
## -- it is grounded only -- but it absolutely reaches the *approach*, so the
## same care applies: `tests/test_cold_store.gd` computes the stopping distance
## from `PlayerTuning` and checks every sheet against every gap, rather than
## trusting this paragraph.
##
## ### Two things this stage deliberately does not contain
##
## **No belts and no wind.** Both push, and a player being moved sideways by
## something they cannot see cannot tell which of the three they are standing
## on. Ice's claim is that it is not a push at all, and that claim only survives
## if nothing next to it is one.
extends AuthoredStage

const BACKGROUND := preload("res://scenes/stages/cold_store/parallax_background.gd")
## Its own terrain: insulated panel wall with frost blooming in the corners.
##
## Generated at M8e from the description in this stage's own docstring,
## once `backblaze.pixellab.ai` was opened. Greyboxed against stage 3's
## tiles until then -- layout first, art second, which is PLAN.md's rule
## and the reason a two-milestone wait for a host cost this stage nothing.
const TILESET := preload("res://resources/tilesets/cold_store.tres")
const FROST := preload("res://scenes/actors/bosses/frost.gd")
const ICE := preload("res://scenes/level/ice_floor.gd")
const BOSS_FRAMES_PATH := "res://resources/sprite_frames/frost.tres"

const WALKER := preload("res://scenes/actors/enemies/walker.gd")
const HOPPER := preload("res://scenes/actors/enemies/hopper.gd")
const TURRET := preload("res://scenes/actors/enemies/turret.gd")
const FLYER := preload("res://scenes/actors/enemies/flyer.gd")
const SPAWNER := preload("res://scenes/actors/enemies/spawner.gd")
const CRAWLER := preload("res://scenes/actors/enemies/wall_crawler.gd")

## Two decks of cold rooms. The stage crosses between them five times.
const BAND_UPPER := 0
const BAND_LOWER := 1

## Cells of grippy deck an ice run must leave before a hole.
##
## **Derived, not chosen.** The player slides `walk_speed_pf / grip` NES px
## after letting go -- about 1.4 tiles at the default grip -- so two cells is
## that distance plus most of a tile of slack. `tests/test_cold_store.gd`
## recomputes it from `PlayerTuning` and `IceFloor.DEFAULT_GRIP` and fails if
## the margin ever stops covering the slide.
const STOP_MARGIN_CELLS := 2

## The plant's six, one per archetype.
##
## **TODO(art): these are stage 3's skins, not stage 7's.** The behaviour is the
## archetype and the art is the theme (docs/PLAN.md section 4), and
## `tests/test_stage_authoring.gd` requires every named enemy to have art on
## disk -- so a stage cannot be greyboxed with names that do not exist yet.
##
## The six this stage wants: **Palletjack** (the truck that walks the aisles),
## **Chock** (a wheel block that hops the dock), **Sprinkler** (a ceiling head
## that pivots and fires), **Vapour** (condensate riding the cold air),
## **Icebox** (a chest unit that opens and releases crawlers), and **Rime** (the
## crawler that walks a coil).
const SKIN_WALKER := "cutter"
const SKIN_HOPPER := "jack"
const SKIN_TURRET := "rivetgun"
const SKIN_FLYER := "slag"
const SKIN_SPAWNER := "skip"
const SKIN_CRAWLER := "seam"


## One row per room, in the order the player meets them. The key reference is in
## AuthoredStage's docstring; `ice` is this stage's own:
##
##   {"from": cell, "to": cell, "grip": 0..1}
##
## `grip` is optional and defaults to `IceFloor.DEFAULT_GRIP`. There is no
## direction and no period, because ice has neither -- which is the whole of
## what makes it a third idea rather than a third push.
const ROOMS := [
	{
		"name": "Dock Face", "col": 0, "band": BAND_UPPER,
		# The room with nothing in it that can kill you, and no ice: the first
		# thing the stage teaches is its own controls on a floor that answers.
		"gaps": [[18, 20]], "blocks": [],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 12.0, 0.0],
			[WALKER, SKIN_WALKER, &"walk", 23.0, 0.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Cold Room", "col": 1, "band": BAND_UPPER,
		# **Ice, taught alone and taught free.** A long sheet over solid deck
		# with nothing to fall into. Walk onto it, let go, and arrive somewhere
		# later than you meant to -- the whole lesson, and it costs nothing to
		# get wrong.
		"gaps": [], "blocks": [[21, 2, 4, 2]],
		"enemies": [
			[HOPPER, SKIN_HOPPER, &"hop", 6.0, 0.0],
		],
		"checkpoint": 2.0,
		"ice": [{"from": 8, "to": 18}],
	},
	{
		"name": "Rail", "col": 2, "band": BAND_UPPER,
		# **No gaps** -- the lower deck is under this column -- and the sheet
		# stops well short of the ladder. A player sliding past a rung is a
		# player who misses it, which is the rule Turbine Row's Pier Head and
		# Stack's Tip Head are both built on.
		"gaps": [], "blocks": [[6, 2, 3, 2]],
		"enemies": [
			[TURRET, SKIN_TURRET, &"idle", 14.0, 2.0],
		],
		"checkpoint": 2.0,
		"ice": [{"from": 9, "to": 17}],
		"shaft": [22, 2],
	},
	{
		"name": "Sub Zero", "col": 2, "band": BAND_LOWER,
		# Arrival on the lower deck, and grippy floor. The player has just
		# changed bands and the backdrop has changed with them; a room that also
		# took the floor away would be a room they read none of. The same call
		# Turbine Row's Pontoon and Stack's Hall Floor make.
		"gaps": [[16, 18]], "blocks": [],
		"enemies": [
			[FLYER, SKIN_FLYER, &"fly", 9.0, 4.0],
			[CRAWLER, SKIN_CRAWLER, &"crawl", 24.0, 0.0],
		],
		"pit_spikes": [[16, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Brine Line", "col": 3, "band": BAND_LOWER,
		# **The first paid sheet**, and the room the stage's safety rule is
		# named after: the ice ends `STOP_MARGIN_CELLS` before the hole, so
		# there is always grippy deck to stop and take off from.
		#
		# That margin is the whole argument and it is computed rather than
		# eyeballed -- see the note on the constant.
		"gaps": [[18, 20]], "blocks": [],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 24.0, 0.0],
		],
		"pit_spikes": [[18, 3, 2]],
		"checkpoint": 2.0,
		"ice": [{"from": 6, "to": 16}],
	},
	{
		"name": "Racking", "col": 4, "band": BAND_LOWER,
		# **A slide that ends on ice.** A slide covers 4.06 tiles, cannot be
		# steered and cannot be cancelled; ending one on a floor that will not
		# stop you is the only place in the stage where two committed things
		# multiply rather than add.
		#
		# No hole in the room. The idea is worth one room on its own and the
		# stage should not charge for two ideas at once -- Stack's Feed makes
		# the same call about its tunnel.
		"gaps": [], "blocks": [[22, 2, 4, 2]],
		"ceilings": [[8, SLIDE_CLEARANCE, 3, 4]],
		"enemies": [
			[HOPPER, SKIN_HOPPER, &"hop", 17.0, 0.0],
		],
		"checkpoint": 2.0,
		"ice": [{"from": 12, "to": 20}],
	},
	{
		"name": "Freezer Floor", "col": 5, "band": BAND_LOWER,
		# No ice: the stage's first breath, and the way back up. Stage 4 writes
		# the rule on Foot -- a room of plain platforming has to come between, or
		# the sheets stop being an event and become the floor.
		"gaps": [[7, 9]], "blocks": [[14, 2, 4, 2]],
		"enemies": [
			[TURRET, SKIN_TURRET, &"idle", 12.0, 2.0],
			[FLYER, SKIN_FLYER, &"fly", 19.0, 5.0],
		],
		"pit_spikes": [[7, 3, 2]],
		"checkpoint": 2.0,
		"shaft_up": [23, 2],
	},
	{
		"name": "Upper Rail", "col": 5, "band": BAND_UPPER,
		# **No gaps** -- the lower deck is under this column -- and nothing at
		# all in cells 23-27, which is where Freezer Floor's ladder delivers.
		# Building on a landing spawns the player inside terrain and Godot shoves
		# them out sideways; on stage 4 that shove walked them into the next
		# room's door and spent it.
		"gaps": [], "blocks": [[5, 2, 4, 2]],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 15.0, 0.0],
		],
		"checkpoint": 2.0,
		"ice": [{"from": 10, "to": 20}],
	},
	{
		"name": "Condenser", "col": 6, "band": BAND_UPPER,
		# Ice with the room's fighting on it. Every shot is taken from a floor
		# that will not let you reposition promptly, which is what the gimmick
		# does to combat rather than to platforming.
		"gaps": [[19, 21]], "blocks": [],
		"enemies": [
			[TURRET, SKIN_TURRET, &"idle", 25.0, 2.0],
			[CRAWLER, SKIN_CRAWLER, &"crawl", 4.0, 0.0],
		],
		"pit_spikes": [[19, 3, 2]],
		"checkpoint": 2.0,
		"ice": [{"from": 8, "to": 17}],
	},
	{
		"name": "Down Pipe", "col": 7, "band": BAND_UPPER,
		# **No gaps** -- the lower deck is under this column -- and grippy floor
		# around the shaft.
		"gaps": [], "blocks": [[8, 2, 3, 2]],
		"enemies": [
			[HOPPER, SKIN_HOPPER, &"hop", 14.0, 0.0],
		],
		"checkpoint": 2.0,
		"shaft": [22, 2],
	},
	{
		"name": "Chill Store", "col": 7, "band": BAND_LOWER,
		# Arrival again, and grippy again. Five band changes means five arrivals,
		# and a stage that made every one of them a puzzle would be a stage of
		# nothing but transitions.
		"gaps": [[15, 17]], "blocks": [],
		"enemies": [
			[FLYER, SKIN_FLYER, &"fly", 22.0, 4.0],
			[WALKER, SKIN_WALKER, &"walk", 6.0, 0.0],
		],
		"pit_spikes": [[15, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Glaze", "col": 8, "band": BAND_LOWER,
		# **The exam: sheets and bare deck alternating.** Every landing is
		# either a place you can stop or a place you cannot, and telling them
		# apart at a glance is the room.
		#
		# The holes sit in the bare stretches, never in the ice -- rule 3, and
		# the reason the room is an exam rather than a trap.
		"gaps": [[13, 15]], "blocks": [],
		"enemies": [
			[CRAWLER, SKIN_CRAWLER, &"crawl", 25.0, 0.0],
		],
		"pit_spikes": [[13, 3, 2]],
		"checkpoint": 2.0,
		"ice": [{"from": 4, "to": 11}, {"from": 17, "to": 24}],
	},
	{
		"name": "Blast", "col": 9, "band": BAND_LOWER,
		# No ice: the second breath, placed where stage 5 puts Bilge and stage 6
		# puts Clinker -- after the exam, before the last stretch.
		#
		# The wide gap is on a moving platform and starts **six cells in**, which
		# is where all five shipped mover rooms put theirs. A mover's cycle runs
		# from when the room is built, so where the gap sits decides what phase
		# the player meets it at; stage 5's Kite was a room with no solution
		# until it was moved.
		"gaps": [[6, 14]], "blocks": [],
		"movers": [[6, 0, 8.0, 0.0, 150]],
		"enemies": [
			[TURRET, SKIN_TURRET, &"idle", 24.0, 2.0],
		],
		"pit_spikes": [[6, 3, 8]],
		"checkpoint": 2.0,
	},
	{
		"name": "Riser", "col": 10, "band": BAND_LOWER,
		# The last climb. Grippy floor around the ladder, and nothing built on
		# the landing above it.
		"gaps": [], "blocks": [[6, 2, 4, 2]],
		"enemies": [
			[SPAWNER, SKIN_SPAWNER, &"idle", 3.0, 3.0],
			[WALKER, SKIN_WALKER, &"walk", 14.0, 0.0],
		],
		"checkpoint": 2.0,
		"shaft_up": [23, 2],
	},
	{
		"name": "Loft", "col": 10, "band": BAND_UPPER,
		# **No gaps**, and nothing in 23-27: Riser's landing.
		"gaps": [], "blocks": [[4, 2, 4, 2], [12, 4, 4, 4]],
		"enemies": [
			[FLYER, SKIN_FLYER, &"fly", 19.0, 5.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Cold Line", "col": 11, "band": BAND_UPPER,
		# The stage's vocabulary spoken once more: a sheet, a hole, and the
		# margin between them.
		"gaps": [[19, 21]], "blocks": [],
		"enemies": [
			[HOPPER, SKIN_HOPPER, &"hop", 5.0, 0.0],
			[CRAWLER, SKIN_CRAWLER, &"crawl", 25.0, 0.0],
		],
		"pit_spikes": [[19, 3, 2]],
		"checkpoint": 2.0,
		"ice": [{"from": 8, "to": 17}],
	},
	{
		"name": "Head House", "col": 12, "band": BAND_UPPER,
		# **No gaps** -- the lower deck is under this column -- and the last
		# ladder, on grippy floor.
		"gaps": [], "blocks": [],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 10.0, 0.0],
		],
		"checkpoint": 2.0,
		"shaft": [22, 2],
	},
	{
		"name": "Gate", "col": 12, "band": BAND_LOWER,
		# Deliberately empty. The run-up to a boss is a breath, and
		# `tests/test_stage_authoring.gd` holds every stage to it.
		"gaps": [], "blocks": [],
		"enemies": [],
		"checkpoint": 2.0,
	},
	{
		"name": "Arena", "col": 13, "band": BAND_LOWER,
		# Flat, empty, no checkpoint and **no ice**. Frost's Rime lays its own
		# sheets and the whole fight turns on which parts of the floor are
		# frozen; a room sheet would make that unreadable, and it is the same
		# call Breakers makes about the press and Turbine Row about the wind.
		"gaps": [], "blocks": [],
		"enemies": [],
		"checkpoint": NO_CHECKPOINT,
	},
]


func room_table() -> Array:
	return ROOMS


func stage_tile_set() -> TileSet:
	return TILESET


func backdrop_script() -> GDScript:
	return BACKGROUND


func boss_script() -> GDScript:
	return FROST


func boss_frames_path() -> String:
	return BOSS_FRAMES_PATH


func boss_name() -> String:
	return "Frost"


## The ice. This stage's own key, for the same reason stage 1's tide, stage 3's
## presses, stage 4's panels, stage 5's wind and stage 6's belts are.
##
## **A sheet is told where it is and how slippery, and nothing about time or
## direction.** It has neither, which is what makes it a third idea rather than
## a third push.
func place_stage_elements(spec: Dictionary, _index: int, origin: int, deck: int,
		tile: float) -> void:
	# On the deck's **surface**, not its tile row: a sheet is the top of the
	# floor and the player stands on it, and the two are half a tile apart on a
	# corner tileset -- the alignment bug that made every kit element float at
	# M6j.
	var surface := float(deck) + deck_surface_offset()
	for entry in spec.get("ice", []) as Array:
		var from := int(entry["from"])
		var to := int(entry["to"])
		var sheet := ICE.new() as IceFloor
		sheet.name = "Ice_%d_%d" % [origin + from, deck]
		sheet.grip = float(entry.get("grip", IceFloor.DEFAULT_GRIP))
		sheet.width_tiles = float(to - from)
		sheet.position = Vector2(float(origin + from), surface) * tile
		add_child(sheet)


## Every sheet in the stage, in placement order. For the playtest tools and for
## `tests/test_cold_store.gd`, which checks the built nodes rather than only the
## table -- the shaft bug at M6i was a table that was right and a translation
## that was not.
func sheets() -> Array[IceFloor]:
	var out: Array[IceFloor] = []
	for child in get_children():
		if child is IceFloor:
			out.append(child as IceFloor)
	return out
