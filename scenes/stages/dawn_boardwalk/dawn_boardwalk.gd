## Stage 1, "Dawn Boardwalk", authored end to end.
##
## Eight rooms of drowned boardwalk, laid out as a **U**: along the deck, down
## under it, back along the pilings, up again, and into the arena.
##
##      col 0     1        2                4        5
##  band 0  Arrival - Pilings - Descent    BossDoor - Arena
##                              |             ^
##  band 1                    Under W - Under E - Tide
##
## The shape is the point. Four rooms in a straight line was ~19 s of traversal
## against MM3's 90-150, and more importantly it was four rooms of the same two
## ideas -- a gap, and a block. Going down and coming back up is what lets the
## stage use ladders, one-way platforms, moving platforms, crumbling planks and
## the rising tide, which is the vocabulary M5a exists to provide.
##
## This is the stage the game boots into; `art_preview.tscn` stays as the bare
## art harness.
##
## **Everything structural lives in `AuthoredStage`** -- the deck, the rooms, the
## doors, the pit sensors, the HUD, the ledger. What is left here is what makes
## this stage this stage: its table, its art, its boss, and its tide. That split
## was made before stage 2 was authored, on M5a's argument one level up: stage 2
## copies whatever stage 1 is, and copying 850 lines of shared machinery sets the
## ceiling for the whole game.
##
## The pit is handled per band by the base class rather than per gap here, so
## adding a gap needs no matching edit. Checkpoints must sit on solid deck --
## one over a gap respawns the player into the pit forever, which is how the
## first draft of the preview ate a whole life counter.
extends AuthoredStage

const BACKGROUND := preload("res://scenes/stages/dawn_boardwalk/parallax_background.gd")
const TILESET := preload("res://resources/tilesets/dawn_boardwalk.tres")
const TIDE := preload("res://scenes/actors/bosses/tide.gd")
## Tide's art, for the award screen. Loaded by path rather than preloaded so the
## stage still opens if the sprite frames are mid-regeneration.
const BOSS_FRAMES_PATH := "res://resources/sprite_frames/wave_man.tres"

const WALKER := preload("res://scenes/actors/enemies/walker.gd")
const HOPPER := preload("res://scenes/actors/enemies/hopper.gd")
const TURRET := preload("res://scenes/actors/enemies/turret.gd")
const FLYER := preload("res://scenes/actors/enemies/flyer.gd")
const SPAWNER := preload("res://scenes/actors/enemies/spawner.gd")
const CRAWLER := preload("res://scenes/actors/enemies/wall_crawler.gd")

## Rooms sit in one of two horizontal bands: the boardwalk, and the pilings a
## screen beneath it.
const BAND_DECK := 0
const BAND_UNDER := 1

## How far above the under-deck the tide is allowed to climb, in rows. The
## highest block in the Tide room stands 6 above the deck, so 8 leaves the top
## of it dry with a tile to spare.
const TIDE_CEILING_ABOVE_DECK := 8

## One row per room, in the order the player meets them.
##
## `col` and `band` place the room on the grid; everything else is relative to
## that room's own left edge and its band's deck row, so a room can be moved by
## changing two numbers. The key reference is in AuthoredStage's docstring.
##
## Two authoring limits, both enforced by tests/test_dawn_boardwalk.gd because
## breaking either produces a stage that looks fine and cannot be finished:
## a block rises at most MAX_STEP_TILES above the deck, and a gap is at most
## MAX_GAP_TILES wide. Neither applies to a gap a ladder or a platform crosses.
const ROOMS := [
	{
		"name": "Arrival", "col": 0, "band": BAND_DECK,
		# Nothing to do but walk. The first screen of a stage teaches the
		# controls, and it cannot do that while also asking for anything.
		"gaps": [], "blocks": [],
		"enemies": [
			[WALKER, "dockrat", &"walk", 14.0, 0.0],
			[WALKER, "dockrat", &"walk", 22.0, 0.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Pilings", "col": 1, "band": BAND_DECK,
		"gaps": [[10, 12]], "blocks": [[18, 2, 4, 2]],
		"enemies": [
			[HOPPER, "bollard", &"hop", 16.0, 0.0],
			[TURRET, "lampjack", &"idle", 23.0, 2.0],
			[FLYER, "gullbot", &"fly", 8.0, 3.0],
		],
		"checkpoint": 2.0,
		# The slide's first appearance, and it is genuinely **optional**: one row
		# thick, so its top sits two tiles up and a jump reaches it. Go over or
		# go under, both work. Introducing a mechanic and requiring it in the
		# same breath is how a stage reads as unfair, so the player meets the
		# move here with nothing riding on it, two rooms before Under West
		# insists on it.
		#
		# At cell 4, not 6. A slide covers four tiles, so an overhang at 6 sets
		# the player down at 10 -- which is the lip of the gap. The bot fell in
		# fourteen times running before this moved.
		"ceilings": [[4, SLIDE_CLEARANCE, 3, 1]],
		# **No spikes here, deliberately.** A first draft put them at cell 13,
		# one cell past a gap ending at 12 -- which is the landing. Spikes are
		# instant death (Hazard), so that made the second room of the game an
		# unavoidable kill: the bot died twelve times without once getting past
		# it. Spikes belong where a player can choose not to be, and they belong
		# later than the second screen.
	},
	{
		"name": "Descent", "col": 2, "band": BAND_DECK,
		# The deck opens and the stage goes down. No gaps: the hole *is* the
		# feature, and a second one would make it ambiguous which to take.
		"gaps": [], "blocks": [[6, 2, 3, 2]],
		"enemies": [
			[WALKER, "dockrat", &"walk", 10.0, 0.0],
			[TURRET, "lampjack", &"idle", 20.0, 2.0],
		],
		"checkpoint": 2.0,
		# The shaft: a hole in the deck and a ladder through it, spanning the
		# boundary into the room below (see door.gd on why it must span).
		"shaft": [14, 2],
	},
	{
		"name": "Under West", "col": 2, "band": BAND_UNDER,
		# Tight and low. The ceiling is the deck the player was just walking on.
		"gaps": [[8, 10], [18, 20]], "blocks": [],
		"enemies": [
			[CRAWLER, "limpet", &"crawl", 6.0, 0.0],
			[CRAWLER, "limpet", &"crawl", 22.0, 0.0],
			[SPAWNER, "barnacle_hive", &"idle", 14.0, 4.0],
		],
		"checkpoint": 2.0,
		"one_ways": [[11, 3, 4]],
		# The tunnel the room was always described as having. One row of
		# clearance: a slide fits, standing does not, and the spikes on its
		# underside are what say so before you try.
		"ceilings": [[13, SLIDE_CLEARANCE, 3]],
		"ceiling_spikes": [[13, SLIDE_CLEARANCE, 3]],
		# Clear of both landings. The gaps end at 10 and 20 and a jump carries
		# about two cells past that, so anything at 11 or 21 is where the player
		# comes down -- and these kill outright. 15 and 24 are open deck the
		# player walks onto, sees, and steps around.
		# **No spikes, and the reason is a design one rather than a technical
		# one.** Hazard is instant death. Three placements were tried here --
		# in the gaps, beside the gaps, and out on open deck -- and every one
		# was a kill on a flat run with nothing but the sprite to warn you.
		#
		# That is the weakest use of the element. In the original, spikes sit
		# where the geometry *already* asks for a jump or a slide: across a pit
		# you are jumping anyway, or on a ceiling you are sliding under. They
		# punish a badly-executed move the level has already asked for; they are
		# not an ambush on ground you would otherwise walk.
		#
		# So Hazard stays in the kit, tested, and stage 1 places none until
		# there is a piece of geometry that earns one. See docs/PLAN.md M5a.
	},
	{
		"name": "Under East", "col": 3, "band": BAND_UNDER,
		# The widest water in the stage, crossed on a moving platform. A gap
		# this wide is deliberately past MAX_GAP_TILES -- it is not a jump, and
		# the platform is the only way over.
		"gaps": [[9, 17]], "blocks": [],
		"enemies": [
			[FLYER, "gullbot", &"fly", 12.0, 4.0],
			[TURRET, "lampjack", &"idle", 21.0, 2.0],
		],
		"checkpoint": 2.0,
		# Travels 9 cells, not 7. At 7 it stopped at cell 15 against a gap that
		# ends at 17 and set the player down two cells short, over open water.
		# The authoring test caught it; the level looked fine.
		# Flush with the deck and starting *over* the gap, not a tile above it
		# beside it. A platform that rests above the walkway has to be jumped
		# onto, and a jump from the lip of an eight-cell gap is a commitment
		# made before you can see where it lands. Level with the deck, you step
		# on when it arrives and step off when it gets there.
		"movers": [[9, 0, 8.0, 0.0, 150]],
		# Stepping stones *inside* the ferry's gap, level with the deck: a second
		# way across the same water. Ride the platform slowly and safely, or hop
		# the planks quickly and hope. That is a choice; three crumbling blocks
		# sitting on solid deck a row up -- which is where these started -- were
		# waist-high obstacles that did nothing but get walked into.
		"crumbles": [[10, 0], [12, 0], [14, 0], [16, 0]],
		# Spikes at the bottom of the things you were already going to fall
		# into. Mechanically this changes nothing -- the pit plane was lethal
		# already -- but it makes the stakes visible at the moment the player
		# decides whether to board the platform or trust the planks, instead of
		# leaving them to find out by falling into water that looked survivable.
		"pit_spikes": [[9, 3, 8], [19, 3, 6]],
	},
	{
		"name": "Tide", "col": 4, "band": BAND_UNDER,
		# The gimmick. The water starts below the pilings and climbs; the only
		# way out is the ladder at the far end, and the tide stops one row below
		# the top of it so the exit is never covered.
		"gaps": [], "blocks": [[8, 2, 3, 2], [14, 4, 3, 2], [20, 6, 3, 2]],
		"enemies": [
			[CRAWLER, "limpet", &"crawl", 5.0, 0.0],
		],
		"checkpoint": 2.0,
		"tide": true,
		"shaft_up": [24, 2],
	},
	{
		"name": "Boss Door", "col": 4, "band": BAND_DECK,
		# Deliberately empty. The run-up to a boss is a breath, not a fight.
		"gaps": [], "blocks": [],
		"enemies": [],
		"checkpoint": 2.0,
	},
	{
		"name": "Arena", "col": 5, "band": BAND_DECK,
		# Flat, empty, and no checkpoint. The arena is the fight and nothing
		# else: a gap here would decide the fight instead of the boss, and a
		# checkpoint inside it would let a player who died mid-fight respawn
		# past the seal with the boss already gone.
		"gaps": [], "blocks": [],
		"enemies": [],
		"checkpoint": NO_CHECKPOINT,
	},
]


var _tide: RisingTide = null


func room_table() -> Array:
	return ROOMS


func stage_tile_set() -> TileSet:
	return TILESET


func backdrop_script() -> GDScript:
	return BACKGROUND


func boss_script() -> GDScript:
	return TIDE


func boss_frames_path() -> String:
	return BOSS_FRAMES_PATH


func boss_name() -> String:
	return "Tide"


## The stage's own element: the water that comes up.
func place_stage_elements(spec: Dictionary, _index: int, origin: int, deck: int,
		tile: float) -> void:
	if spec.get("tide", false):
		_add_tide(origin, deck, tile)


## The rising tide, filling the room from below.
##
## `ceiling_row` is the deck two rows above the highest block in the room, which
## is where a player waiting out the water ends up standing. Water above that
## line covers the only footing there is, and the section becomes unwinnable
## with nothing on screen to say why -- which is the failure RisingTide exists
## to make impossible rather than merely unlikely.
func _add_tide(origin: int, deck: int, tile: float) -> void:
	var water := RisingTide.new()
	water.name = "RisingTide"
	water.width_tiles = float(ROOM_WIDTH)
	water.start_row = float(deck) + 3.0
	water.ceiling_row = float(deck) - float(TIDE_CEILING_ABOVE_DECK)
	water.position = Vector2(float(origin), 0.0) * tile
	add_child(water)
	_tide = water
