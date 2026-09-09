## Fortress 1, "Outfall" -- the drain the sea comes back through.
##
## Thirteen rooms where a master stage has nineteen, and that is deliberate
## rather than unfinished: the fortress is four stages played back to back with
## no stage select in between, so its stages are measured against each other's
## company rather than against a stage the player chose and can leave.
##
##   col   0     1      2      3     4      5      6      7     8
##  band 0 Grate-Race---Screen                    Crown--Door--Arena
##                       |                          ^
##  band 1              Culvert-Weir--Drop   Rise--Head
##                                     |      ^
##  band 2                            Sump---Backwash
##
## Down through the wall, along the bottom of it, and back up the far side. It
## is the only stage in the game whose route reverses: every master stage runs
## one way and ends where it was going, and the fortress's first room is a
## descent that turns into a climb, because what the player is walking into is
## a drain and the thing coming the other way is the sea.
##
## ### It has no gimmick of its own, and that is the design
##
## Every master stage contains exactly one idea and deliberately none of the
## others -- Sinkhole's docstring says so outright: "wind, belts and ice all act
## horizontally and water acts vertically, so mixing them would not even be
## confusing, it would just be two stages at once." That rule exists because a
## stage that mixes two ideas teaches neither.
##
## **The fortress can mix, because there is nothing left to teach.** By the time
## the centre cell opens the player has been taught eight things and examined on
## each of them once, in the room that introduced it, against a boss who does
## not use it. This stage is the second examination, and the only new thing in
## it is that two answers are wanted at once.
##
## Outfall takes the two that are the same substance: **the pool that helps and
## the tide that kills.** Stage 8's water makes a jump longer, and it is the one
## gimmick in the game that only ever gives. Stage 1's tide takes everything,
## instantly, on touch. A player who has beaten both stages knows each rule
## cold; nobody has ever had to hold both at once, and holding both at once is
## the whole exam.
##
## ### The rule that makes it fair: never in the same room
##
## A pool and a tide are the same colour, drawn the same way, at the same kind
## of horizontal line -- and one of them is a floor and the other is death. Put
## both in one room and the player is reading a waterline to decide which of two
## opposite things it means, which is not difficulty, it is a legibility fault
## wearing difficulty's clothes.
##
## So they alternate room to room and never share one, and the tell is motion:
## **if the line is moving, it kills.** `tests/test_outfall.gd` holds the table
## to it.
##
## ### The boss: Tide, rebuilt
##
## The first fortress fight is the first fight in the game, faster. Two reasons,
## and the second is the load-bearing one.
##
## The first is what a callback is for. Tide is the boss a player meets when
## they know nothing, and meeting it again at the far end tells them how far
## they have come more precisely than any number the game could show them.
##
## The second is ammunition. Four stages in a chain with no stage select in
## between means no refill between them, so a player can arrive at Outfall's
## arena dry -- and the roster already names Tide as **the** boss that must be
## beatable buster-only (docs/PLAN.md section 4: "something has to be beatable
## with no weapons at all"). It is the only one of the eight that can be the
## fortress's first fight without the fortress needing a shop.
##
## It is faster and it drops nothing: `FortressStage.as_reprise` sets
## `aggression`, which shortens recovery and leaves every tell alone, so it is
## the same fight with half the openings rather than a different fight wearing
## Tide's sprite. See `Boss.aggression`.
extends FortressStage

const BACKGROUND := preload("res://scenes/stages/fortress/parallax_background.gd")
## TODO(art): the fortress wants its own tileset -- wet concrete, not scrap
## steel. Greyboxed against stage 3's tiles, as stages 4-8 were.
const TILESET := preload("res://resources/tilesets/breakers.tres")
const TIDE_BOSS := preload("res://scenes/actors/bosses/tide.gd")
const WATER := preload("res://scenes/level/water_volume.gd")
const BOSS_FRAMES_PATH := "res://resources/sprite_frames/wave_man.tres"

const WALKER := preload("res://scenes/actors/enemies/walker.gd")
const HOPPER := preload("res://scenes/actors/enemies/hopper.gd")
const TURRET := preload("res://scenes/actors/enemies/turret.gd")
const FLYER := preload("res://scenes/actors/enemies/flyer.gd")
const SPAWNER := preload("res://scenes/actors/enemies/spawner.gd")
const CRAWLER := preload("res://scenes/actors/enemies/wall_crawler.gd")

## Outside the wall, inside it, and the flooded bottom.
const BAND_OUTSIDE := 0
const BAND_WORKS := 1
const BAND_FLOOD := 2

## How hard Tide comes back.
##
## Tide's three recoveries are 44 (crest), 30 (spout) and 34 (volley) frames.
## At 1.5 they become 29, 20 and 23 -- two thirds of the shooting time, every
## one of them still several tapped pellets long, and none of them anywhere near
## the `MIN_RECOVER_FRAMES` floor. That last part matters: a pattern pinned at
## the floor is a knob that has stopped being a knob, and the fight would keep
## getting harder on paper while nothing changed on screen.
##
## **The number is chosen from the fight's own frame counts, not from the bot,
## because the bot cannot measure this one.** Ten runs went into trying: the bot
## loses Outfall's fight at 1.6, at 1.35, at 1.25, at 1.15 and at 1.0 -- and it
## loses *stage 1's* Tide fight, the un-reprised one, on both seeds it was asked
## for. Its death frame moves by about 4% across a 60% change in aggression,
## which is the shape of a measurement with no headroom in it: the bot is at the
## edge of beating plain Tide with the buster, so it has nothing left with which
## to register a harder version.
##
## That is a fact about **stage 1**, not about this stage, and it is the sharpest
## thing anyone has learned about the difficulty question docs/PLAN.md M5b left
## open. It is written down in the README where the playtest debt is listed. What
## it means here is that the design rule this fight rests on -- that the
## fortress's first boss is winnable with the buster alone -- is still a rule
## about a human being, and no run of the bot has confirmed or refuted it.
const REPRISE_AGGRESSION := 1.5

## How far above the deck the tide may climb in Backwash, in rows.
##
## The same number stage 1 uses, and it means the same thing: the staircase goes
## under and the ladder does not. See `DawnBoardwalk.TIDE_CEILING_ABOVE_DECK`,
## which spells out why a player who climbs the blocks and stops has done half
## of what the room is asking.
const TIDE_CEILING_ABOVE_DECK := 8

## TODO(art): the fortress wants its own six. These are stage 3's skins, which
## is what greyboxing against stage 3's tileset implies; the behaviour is the
## archetype and the art is the theme (docs/PLAN.md section 4), and
## `tests/test_stage_authoring.gd` requires every named enemy to have art on
## disk, so a stage cannot be greyboxed with names that do not exist yet.
##
## The six this stage wants: **Sluicer** (walks the apron), **Bilge** (hops the
## sumps), **Portcullis** (a wall gun over the race), **Spindrift** (blown in
## off the sea), **Weephole** (a drain that releases crawlers), and **Wrack**
## (the crawler, walking a wet face).
const SKIN_WALKER := "cutter"
const SKIN_HOPPER := "jack"
const SKIN_TURRET := "rivetgun"
const SKIN_FLYER := "slag"
const SKIN_SPAWNER := "skip"
const SKIN_CRAWLER := "seam"


## One row per room, in the order the player meets them. The key reference is in
## AuthoredStage's docstring. Two stage keys, both borrowed rather than new:
##
##   `water`  {"from", "to", "surface", "depth"}  -- stage 8's pool
##   `tide`   true                                -- stage 1's rising water
##
## Borrowed literally, not reimplemented: `place_stage_elements` below builds a
## `WaterVolume` and a `RisingTide` with the same arguments those stages pass.
## A fortress that re-authored the gimmicks it is examining would be examining
## something else.
const ROOMS := [
	{
		"name": "Grate", "col": 0, "band": BAND_OUTSIDE,
		# Nothing but deck and two walkers. The fortress's first room is a
		# breath: the player has just come off a stage select and a load, and
		# the first thing it should establish is that the controls are the
		# controls.
		"gaps": [], "blocks": [],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 13.0, 0.0],
			[WALKER, SKIN_WALKER, &"walk", 22.0, 0.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Race", "col": 1, "band": BAND_OUTSIDE,
		# **The first pool, and it is free.** Every gimmick in the game gets a
		# free first appearance -- stage 2's Riser, stage 8's Seep -- and a
		# gimmick the player already knows still gets one here, because what is
		# being re-established is that *this stage has it*, which is new
		# information even when the pool is not.
		#
		# Water over solid deck, nothing to fall into, one turret to make the
		# longer jump worth taking.
		"gaps": [], "blocks": [[20, 2, 4, 2]],
		"enemies": [
			[TURRET, SKIN_TURRET, &"idle", 24.0, 2.0],
		],
		"checkpoint": 2.0,
		"water": [{"from": 6, "to": 16, "depth": 3.0}],
	},
	{
		"name": "Screen", "col": 2, "band": BAND_OUTSIDE,
		# No gaps -- band 1 runs under this column -- and the shaft down is the
		# room's exit. Dry: the room where the route changes direction should
		# not also be the room where the floor changes rules.
		"gaps": [], "blocks": [[7, 2, 3, 2]],
		"ceilings": [[13, SLIDE_CLEARANCE, 3, 3]],
		"enemies": [
			[CRAWLER, SKIN_CRAWLER, &"crawl", 18.0, 0.0],
		],
		"checkpoint": 2.0,
		"shaft": [23, 2],
	},
	{
		"name": "Culvert", "col": 2, "band": BAND_WORKS,
		# Arrival inside the wall, and the backdrop changes with it. Grippy,
		# empty deck under the ladder: a room that also took the floor away
		# would be a room the player reads none of. The same call Turbine Row's
		# Pontoon, Stack's Hall Floor and Cold Store's Sub Zero all make.
		#
		# The shaft lands at cells 23-24, so nothing is built east of 20.
		"gaps": [[8, 10]], "blocks": [],
		"enemies": [
			[FLYER, SKIN_FLYER, &"fly", 15.0, 4.0],
		],
		"pit_spikes": [[8, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Weir", "col": 3, "band": BAND_WORKS,
		# **The first paid pool**: the hole is two cells and the water covers
		# it, so the crossing is the one stage 8's Cistern taught -- the pool is
		# the route rather than the toll. Dry, it is still a jump the player can
		# make; wet, it is a jump they cannot miss. That is the gimmick being
		# generous, which is the only thing it ever does.
		"gaps": [[13, 15]], "blocks": [],
		"enemies": [
			[HOPPER, SKIN_HOPPER, &"hop", 6.0, 0.0],
			[WALKER, SKIN_WALKER, &"walk", 22.0, 0.0],
		],
		"checkpoint": 2.0,
		"water": [{"from": 9, "to": 19, "depth": 5.0}],
	},
	{
		"name": "Drop", "col": 4, "band": BAND_WORKS,
		# No gaps -- band 2 runs under this column. Dry, and a spiked tunnel to
		# slide: the last dry room before the bottom, and the last room where
		# what kills you is something you can see standing still.
		"gaps": [], "blocks": [[6, 2, 4, 2]],
		"ceilings": [[13, SPIKED_CLEARANCE, 2, 3]],
		"ceiling_spikes": [[13, SPIKED_CLEARANCE, 2]],
		"enemies": [
			[TURRET, SKIN_TURRET, &"idle", 9.0, 2.0],
		],
		"checkpoint": 2.0,
		"shaft": [22, 2],
	},
	{
		"name": "Sump", "col": 4, "band": BAND_FLOOD,
		# The bottom. Deep water over most of the room, and the pool is doing
		# what it does best: the two-cell hole under it is a crossing the player
		# barely has to aim.
		#
		# It is the last help they get. The next room is the same water with the
		# opposite meaning.
		"gaps": [[17, 19]], "blocks": [],
		"enemies": [
			[SPAWNER, SKIN_SPAWNER, &"idle", 8.0, 0.0],
			[FLYER, SKIN_FLYER, &"fly", 22.0, 5.0],
		],
		"checkpoint": 2.0,
		"water": [{"from": 12, "to": 24, "depth": 6.0}],
	},
	{
		"name": "Backwash", "col": 5, "band": BAND_FLOOD,
		# **The exam.** The sea comes back up the drain, and the way out is the
		# ladder at cell 23.
		#
		# The staircase is stage 1's, at 2/4/6, and it is a route to the ladder
		# rather than a refuge -- the water tops out two rows above the highest
		# of them. A player who climbs it and waits drowns on the top step,
		# which is the same lesson stage 1's Tide room teaches and the reason
		# `TIDE_CEILING_ABOVE_DECK` is 8 rather than 4.
		#
		# **No pool**, and no gaps either. The room has one thing in it that can
		# kill and it is moving; a hole in the floor would be a second, and a
		# player watching a waterline should not also be watching their feet.
		"gaps": [], "blocks": [[8, 2, 3, 2], [13, 4, 3, 2], [18, 6, 3, 2]],
		"enemies": [
			[CRAWLER, SKIN_CRAWLER, &"crawl", 5.0, 0.0],
		],
		"checkpoint": 2.0,
		"tide": true,
		"shaft_up": [23, 2],
	},
	{
		"name": "Rise", "col": 5, "band": BAND_WORKS,
		# Out of the water, and no gaps -- band 2 runs under this column, and
		# Backwash's ladder holes this room's deck at 23-24, so nothing is built
		# east of 20 either.
		#
		# Dry and quiet on purpose. The player has just come off the only room
		# in the stage with a clock in it, and stage 4's Foot writes the rule:
		# a room of plain platforming has to come between, or the gimmick stops
		# being an event and becomes the floor.
		"gaps": [], "blocks": [[9, 2, 4, 2]],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 15.0, 0.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Head", "col": 6, "band": BAND_WORKS,
		# The last pool, and the only one the player crosses going up rather
		# than along: the deep water sits under a two-cell hole with the ladder
		# out of the works beyond it. Everything east of 20 is clear for the
		# climb.
		#
		# **This room shipped without its `shaft_up` for about an hour.** The
		# stage simply ended here: the bot walked to the far side of the deck,
		# fell into the pit plane and did it again, three times, and the last
		# three rooms were unreachable. Cold Store's Rail did the identical
		# thing at M6. `test_every_change_of_band_has_a_ladder` now asks the
		# table directly, for every stage, which is a question that could have
		# been asked before either stage was ever built.
		"gaps": [[12, 14]], "blocks": [],
		"enemies": [
			[HOPPER, SKIN_HOPPER, &"hop", 7.0, 0.0],
			[FLYER, SKIN_FLYER, &"fly", 17.0, 4.0],
		],
		"checkpoint": 2.0,
		"water": [{"from": 8, "to": 18, "depth": 5.0}],
		"shaft_up": [23, 2],
	},
	{
		"name": "Crown", "col": 6, "band": BAND_OUTSIDE,
		# Back on top of the wall, in daylight, with the sea behind you and the
		# fortress ahead. No gaps -- band 1 runs under this column -- and
		# nothing east of 20, where Head's ladder delivers.
		#
		# The last room with anything in it. What it is for is the view.
		"gaps": [], "blocks": [[6, 2, 3, 2], [11, 4, 3, 2]],
		"enemies": [
			[TURRET, SKIN_TURRET, &"idle", 16.0, 4.0],
			[WALKER, SKIN_WALKER, &"walk", 19.0, 0.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Boss Door", "col": 7, "band": BAND_OUTSIDE,
		# Deliberately empty. The run-up to a boss is a breath, not a fight.
		"gaps": [], "blocks": [],
		"enemies": [],
		"checkpoint": 2.0,
	},
	{
		"name": "Arena", "col": 8, "band": BAND_OUTSIDE,
		# Flat, empty, and no checkpoint -- a checkpoint inside the seal would
		# let a player who died mid-fight respawn past it with the boss gone.
		"gaps": [], "blocks": [],
		"enemies": [],
		"checkpoint": NO_CHECKPOINT,
	},
]


func fortress_index() -> int:
	return 0


func room_table() -> Array:
	return ROOMS


func stage_tile_set() -> TileSet:
	return TILESET


func backdrop_script() -> GDScript:
	return BACKGROUND


func boss_script() -> GDScript:
	return TIDE_BOSS


func boss_frames_path() -> String:
	return BOSS_FRAMES_PATH


func boss_name() -> String:
	return "Tide"


## Tide's script, Tide's patterns, Tide's art -- and no weapon, no boss bit, and
## two thirds of the openings. See the class docstring for why it is Tide.
func configure_boss(boss: Boss) -> void:
	as_reprise(boss, REPRISE_AGGRESSION, "Tide (Rebuilt)")


## The two waters. Borrowed from stages 8 and 1 rather than reimplemented -- see
## the note on the room table.
func place_stage_elements(spec: Dictionary, index: int, origin: int, deck: int,
		tile: float) -> void:
	var surface_row := float(deck) + deck_surface_offset()
	for entry in spec.get("water", []) as Array:
		var from := int(entry["from"])
		var to := int(entry["to"])
		var pool := WATER.new() as WaterVolume
		pool.name = "Water_%d_%d" % [origin + from, deck]
		pool.width_tiles = float(to - from)
		pool.depth_tiles = float(entry.get("depth", 4.0))
		pool.position = Vector2(float(origin + from),
			surface_row - float(entry.get("surface", 0))) * tile
		add_child(pool)

	if spec.get("tide", false):
		var water := RisingTide.new()
		water.name = "RisingTide"
		water.width_tiles = float(ROOM_WIDTH)
		water.start_row = float(deck) + 3.0
		water.ceiling_row = float(deck) - float(TIDE_CEILING_ABOVE_DECK)
		water.position = Vector2(float(origin), 0.0) * tile
		add_child(water)
		register_tide(index, water)


## Every pool in the stage, in placement order. For `tests/test_outfall.gd`,
## which checks the built nodes rather than only the table -- the M6i shaft bug
## was a table that was right and a translation that was not.
func pools() -> Array[WaterVolume]:
	var out: Array[WaterVolume] = []
	for child in get_children():
		if child is WaterVolume:
			out.append(child as WaterVolume)
	return out
