## Stage 1, "Dawn Boardwalk", authored end to end.
##
## Nineteen rooms of drowned boardwalk, laid out as a **W**: along the deck, down
## under it, back up, along the deck again, down a second time, and up into the
## arena.
##
##   col  0     1      2       3      4      5       6     7     8      9     10     11     12    13    14
##  band 0 Arrival-Pilings-Boardwalk-Bait-Gantry-Descent                    Rise-LongPier-Winch     BossDoor-Arena
##                                                    |                      ^              |          ^
##  band 1                                       UnderW-Barnacle-UnderE-Slack-TheCut      Deep-Low--Tide
##
## **The shape is the point, and the length is the shape repeated.** Four rooms
## in a straight line was ~19 s of traversal against MM3's 90-150; the first
## rewrite made it a U of eight and about 40 s, which was still half a stage.
## This is that U twice, and it comes to a little over two minutes -- inside
## MM3's range rather than past it.
##
## Going down and coming back up is what lets the stage use ladders, one-way
## platforms, moving platforms, crumbling planks and the rising tide, which is
## the vocabulary M5a exists to provide. Doing it twice is what lets each of
## those be **introduced, complicated, and then combined** instead of appearing
## once and never again:
##
##   slide       optional in Pilings, required in Bait Shop, closing Long Pier
##   one-ways    in daylight in Gantry, over water in Barnacle Run
##   ferry       with a plank alternative in Under East, alone in The Cut,
##               widest and unescorted in Deep Water
##   crumbles    beside a ferry in Under East, instead of a jump in Slack Water
##   tide        rehearsed dry in Low Water, then flooded in Tide
##
## Two rooms are deliberately empty -- Rise and Boss Door -- and both are the
## far side of a ladder, where SHAFT_LANDING_CELLS leaves three cells and no
## room for a room. They are written as breaths rather than pretended into
## content.
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

## How far above the under-deck the tide is allowed to climb, in rows.
##
## **The blocks are a staircase toward the ladder, not a refuge**, and this
## number is what makes that true: the highest of them stands 6 rows above the
## deck and the water tops out at 8, so the top of it goes under. A player who
## climbs the staircase and stops has done half of the thing the room is asking
## for. The escape is the `shaft_up` at cell 23, whose top is a full band -- 15
## rows -- above the deck, seven clear of the water.
##
## The previous comment here read "8 leaves the top of it dry with a tile to
## spare", which is the arithmetic backwards: rows count downward, so row
## deck-8 is *above* row deck-6, and the water covers it. Nothing noticed
## because until M7b nothing ever started the tide.
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
		"name": "Boardwalk", "col": 2, "band": BAND_DECK,
		# Gaps, complicated. Pilings taught one; this is two, with a step
		# between them so the room is not the same jump twice.
		#
		# **The step comes after both gaps, and it took two goes to learn why.**
		#
		# The first draft put a two-high block between the gaps with four cells
		# of flat deck after it, which sounds like room. It is not: a jump taken
		# from the top of a block starts two tiles up and carries *further* than
		# one from the ground, so the bot leapt off the step, sailed over all
		# four cells of run-up and into the hole. Four times, then the whole life
		# counter, without leaving this room.
		#
		# Pilings records the same fault from the other direction one room
		# earlier -- a slide overhang that "sets the player down at 10, which is
		# the lip of the gap". Twice is a rule, so it is now
		# `tests/test_stage_authoring.gd`, which measures the clearance a gap
		# needs against the height of whatever stands before it.
		#
		# With the step last, nothing in this room drops the player anywhere near
		# a hole: two gaps off flat deck, then something to climb.
		# Seven cells between the two gaps, not four. At four the bot took a
		# gullbot hit on the walk between them and went straight into the second
		# one -- a full bar in the only room of nineteen that was costing more
		# than two. A flyer's sweep is wide enough to reach both holes, so the
		# room has to leave ground between them on which being hit is survivable.
		"gaps": [[8, 10], [17, 19]], "blocks": [[23, 2, 3, 2]],
		"enemies": [
			[WALKER, "dockrat", &"walk", 5.0, 0.0],
			# Over the first gap, so the jump the room asks for is the jump the
			# flyer is patrolling. Neither is hard; together they are a choice
			# about when.
			[FLYER, "gullbot", &"fly", 9.0, 3.0],
			[TURRET, "lampjack", &"idle", 21.0, 2.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Bait Shop", "col": 3, "band": BAND_DECK,
		# **The slide stops being optional.** Pilings put a one-row overhang
		# where going over was as good as going under; this one is four rows
		# thick, so its top is out of the jump's reach and the tunnel is the
		# only way through. Introducing a move and requiring it in the same
		# breath is what Pilings was careful not to do -- two rooms later is
		# where the asking belongs.
		#
		# Three cells wide, because a slide covers about four and a tunnel
		# longer than the slide traps the player inside it, standing up into
		# the ceiling. tests/test_dawn_boardwalk.gd holds every tunnel to it.
		"gaps": [[5, 7]], "blocks": [[20, 2, 4, 2]],
		"ceilings": [[12, SLIDE_CLEARANCE, 3, 4]],
		"enemies": [
			[HOPPER, "bollard", &"hop", 8.0, 0.0],
			[FLYER, "gullbot", &"fly", 17.0, 4.0],
			[WALKER, "dockrat", &"walk", 22.0, 2.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Gantry", "col": 4, "band": BAND_DECK,
		# One-way platforms, introduced in daylight on the deck rather than in
		# the dark under it. They are the one element whose rule -- solid from
		# above, passable from below -- cannot be read off the art, so the
		# player meets them here, where getting it wrong costs a step and not a
		# life.
		#
		# Two rises of two, which is exactly MAX_STEP_TILES: a climb the jump
		# makes without a run-up, so the room reads as a staircase rather than
		# as a puzzle.
		"gaps": [[8, 10]], "blocks": [],
		"one_ways": [[13, 2, 4], [19, 4, 4]],
		"enemies": [
			[TURRET, "lampjack", &"idle", 11.0, 2.0],
			# High and to the right, over the top platform: the reason to climb
			# is also the reason to be careful up there.
			[FLYER, "gullbot", &"fly", 16.0, 6.0],
			[WALKER, "dockrat", &"walk", 24.0, 0.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Descent", "col": 5, "band": BAND_DECK,
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
		"name": "Under West", "col": 5, "band": BAND_UNDER,
		# Tight and low. The ceiling is the deck the player was just walking on.
		"gaps": [[8, 10], [18, 20]], "blocks": [],
		"enemies": [
			[CRAWLER, "limpet", &"crawl", 6.0, 0.0],
			[CRAWLER, "limpet", &"crawl", 25.0, 0.0],
			[SPAWNER, "barnacle_hive", &"idle", 14.0, 4.0],
		],
		"checkpoint": 2.0,
		"one_ways": [[11, 3, 4]],
		# **At cell 21, not 13.** It was authored at 13, which is the shaft's own
		# column -- the ladder from Descent comes down at 14 -- so the tunnel and
		# its teeth were hanging in the space the player arrives in, and the
		# room's only route through them was the two cells of luck between the
		# ladder's edge and the spikes'. Correcting where a Hazard sits and how
		# deep it hangs turned that luck into eighteen deaths on the ladder,
		# which is the honest reading of a tunnel built on top of its own
		# entrance.
		#
		# At 21 it is past both gaps and on the walk the player actually makes,
		# left to right, from the foot of the ladder to the door. Which is what
		# makes it a tunnel rather than scenery -- the first version could be
		# neither used nor avoided.
		# SPIKED_CLEARANCE, not SLIDE_CLEARANCE. This tunnel was authored at one
		# row with teeth hung in it, which reads right and is impassable: the
		# spikes filled the gap the slide had to go through. It went unnoticed
		# for two milestones because the room is entered from the ladder beyond
		# the tunnel, so nothing ever had to slide under it. See
		# AuthoredStage.SPIKED_CLEARANCE.
		# SPIKED_CLEARANCE, not SLIDE_CLEARANCE. This was authored at one row with
		# teeth hung in it, which reads right and is impassable: the spikes fill
		# the gap the slide has to pass through. See AuthoredStage.SPIKED_CLEARANCE.
		"ceilings": [[21, SPIKED_CLEARANCE, 2]],
		"ceiling_spikes": [[21, SPIKED_CLEARANCE, 2]],
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
		"name": "Barnacle Run", "col": 6, "band": BAND_UNDER,
		# The spawner's room. Under West introduced one on a wall the player
		# walks past; here it sits over the middle of the room and the crawlers
		# it releases arrive while the two gaps are being crossed. That is what
		# a spawner is for -- a room that does not get easier the longer you
		# stand in it.
		# The platform sits past both gaps for Boardwalk's reason: a one-way is
		# something to jump off, and a gap two cells beyond one is a hole the
		# jump lands in.
		"gaps": [[6, 8], [15, 17]], "blocks": [],
		"one_ways": [[20, 3, 4]],
		"enemies": [
			[CRAWLER, "limpet", &"crawl", 4.0, 0.0],
			[SPAWNER, "barnacle_hive", &"idle", 12.0, 4.0],
			[CRAWLER, "limpet", &"crawl", 22.0, 0.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Under East", "col": 7, "band": BAND_UNDER,
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
		# A crumbling walkway *inside* the ferry's gap, level with the deck: a
		# second way across the same water. Ride the platform slowly and safely,
		# or run the planks quickly and hope. That is a choice; three crumbling
		# blocks sitting on solid deck a row up -- which is where these started
		# -- were waist-high obstacles that did nothing but get walked into.
		#
		# **Continuous, not every other cell.** They were spaced two apart, which
		# made each one a separate one-tile jump onto a block that then falls --
		# and read, in a playtester's words, as blocks that "look odd, there
		# should be more of them to look like a proper platform". They were
		# right about the look and the spacing was worse than it looked: a gap
		# between two crumbling blocks is a jump you take *while the one you are
		# leaving is already collapsing*. Filling the span makes it a walkway
		# that fails behind you, which is the thing that was being aimed at.
		# 10 to 16, not 9 to 16: **cell 9 is where the ferry parks.** Filling it
		# put a solid crumbling block inside the moving platform's home position,
		# and the bot stood at the lip waiting for a ferry that could not arrive.
		# The walkway starts one cell in, which also leaves the player a lip to
		# stand on while they choose between the two routes.
		"crumbles": [[10, 0], [11, 0], [12, 0], [13, 0], [14, 0], [15, 0], [16, 0]],
		# Spikes at the bottom of the things you were already going to fall
		# into. Mechanically this changes nothing -- the pit plane was lethal
		# already -- but it makes the stakes visible at the moment the player
		# decides whether to board the platform or trust the planks, instead of
		# leaving them to find out by falling into water that looked survivable.
		"pit_spikes": [[9, 3, 8], [19, 3, 6]],
	},
	{
		"name": "Slack Water", "col": 8, "band": BAND_UNDER,
		# Under East's choice, without the safety net. There the crumbling
		# walkway was the fast alternative to a ferry; here it is the fast
		# alternative to *jumping*, and each of the three gaps is a jump the
		# player can already make. Run the planks and keep the pace, or stop at
		# every lip and take each one properly.
		#
		# Two cells each, so every gap is inside MAX_GAP_TILES and the planks
		# stay genuinely optional. A crumbling block is never allowed to be the
		# only way across -- it falls, and tests/test_dawn_boardwalk.gd accepts
		# only a mover as a crossing for a gap past the jump.
		"gaps": [[7, 9], [12, 14], [17, 19]], "blocks": [],
		"crumbles": [[7, 0], [8, 0], [12, 0], [13, 0], [17, 0], [18, 0]],
		"enemies": [
			[CRAWLER, "limpet", &"crawl", 4.0, 0.0],
			[FLYER, "gullbot", &"fly", 15.0, 4.0],
			[CRAWLER, "limpet", &"crawl", 24.0, 0.0],
		],
		# The stakes, visible at the lip rather than discovered underneath it.
		"pit_spikes": [[7, 3, 2], [12, 3, 2], [17, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "The Cut", "col": 9, "band": BAND_UNDER,
		# The widest water under the deck, and the way back up. One ferry and no
		# planks beside it: Under East offered a choice between patience and
		# speed, and this is the room that says patience was a real option.
		"gaps": [[6, 14]], "blocks": [],
		"movers": [[6, 0, 8.0, 0.0, 150]],
		"pit_spikes": [[6, 3, 8]],
		"enemies": [
			[TURRET, "lampjack", &"idle", 18.0, 2.0],
			[CRAWLER, "limpet", &"crawl", 20.0, 0.0],
		],
		"checkpoint": 2.0,
		"shaft_up": [23, 2],
	},
	{
		"name": "Rise", "col": 9, "band": BAND_DECK,
		# A breath, and deliberately so. The ladder delivers the player three
		# cells from this room's exit -- SHAFT_LANDING_CELLS guarantees the
		# landing is solid and forbids anything being built on it -- so there is
		# no room here for a room. Fighting that would mean moving the ladder to
		# the left-hand end of The Cut, which would put it before the water
		# instead of after it.
		#
		# So it is written as what it is: the stage's long crossing ends with
		# the player stepping back out onto the boardwalk. Boss Door makes the
		# same argument at the other end of the stage.
		"gaps": [], "blocks": [],
		"enemies": [],
		"checkpoint": 2.0,
	},
	{
		"name": "Long Pier", "col": 10, "band": BAND_DECK,
		# Everything the deck has taught, in one room: two gaps, a step, a
		# turret to shoot past, a flyer to time, and a slide to finish. The
		# stage's densest room, and the last one before it goes back down.
		#
		# Ordered the way Boardwalk had to be: **both gaps first, off flat
		# ground, and everything you can fall off afterwards.** The draft had a
		# step three cells before the second gap, which is a jump that lands in
		# it.
		#
		# So the room reads left to right as jump, jump, slide, climb -- four
		# things the stage has taught, each given its own ground.
		"gaps": [[6, 8], [12, 14]], "blocks": [[23, 2, 3, 2]],
		"ceilings": [[18, SLIDE_CLEARANCE, 3, 3]],
		"enemies": [
			[WALKER, "dockrat", &"walk", 4.0, 0.0],
			[TURRET, "lampjack", &"idle", 10.0, 2.0],
			[FLYER, "gullbot", &"fly", 16.0, 4.0],
			[HOPPER, "bollard", &"hop", 22.0, 0.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Winch Deck", "col": 11, "band": BAND_DECK,
		# **No gaps, and not by choice.** Deep Water sits directly underneath,
		# and a hole cut in this deck would open into that room rather than into
		# a pit -- tests/test_stage_authoring.gd refuses gaps in any band that
		# is not the deepest in its column. So this room climbs instead of
		# opening: two steps and a platform, with the shaft at the far end.
		"gaps": [], "blocks": [[5, 2, 3, 2], [10, 2, 3, 2]],
		"one_ways": [[16, 2, 4]],
		"enemies": [
			[HOPPER, "bollard", &"hop", 13.0, 0.0],
			[WALKER, "dockrat", &"walk", 6.0, 2.0],
			[TURRET, "lampjack", &"idle", 19.0, 3.0],
		],
		"checkpoint": 2.0,
		"shaft": [22, 2],
	},
	{
		"name": "Deep Water", "col": 11, "band": BAND_UNDER,
		# The widest water in the stage, and the second ferry. Nine cells
		# against The Cut's eight -- barely more, deliberately. The difference
		# is not the distance; it is that this one is crossed with a flyer over
		# it and no lip to wait on halfway.
		"gaps": [[8, 17]], "blocks": [],
		"movers": [[8, 0, 9.0, 0.0, 160]],
		"pit_spikes": [[8, 3, 9]],
		"enemies": [
			[FLYER, "gullbot", &"fly", 12.0, 5.0],
			[CRAWLER, "limpet", &"crawl", 22.0, 0.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Low Water", "col": 12, "band": BAND_UNDER,
		# The tide's room, dry. Exactly the block ladder the next room has --
		# three steps of two, rising six above the deck -- so the shape the
		# player climbs under pressure is one they have already climbed at their
		# own pace. Introduce, then complicate: the water is the complication,
		# and the geometry is not.
		"gaps": [], "blocks": [[6, 2, 3, 2], [12, 4, 3, 2], [18, 6, 3, 2]],
		"enemies": [
			[CRAWLER, "limpet", &"crawl", 4.0, 0.0],
			[FLYER, "gullbot", &"fly", 15.0, 7.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Tide", "col": 13, "band": BAND_UNDER,
		# The gimmick. The water starts below the pilings and climbs; the only
		# way out is the ladder at the far end, and the tide stops one row below
		# the top of it so the exit is never covered.
		"gaps": [], "blocks": [[8, 2, 3, 2], [14, 4, 3, 2], [20, 6, 3, 2]],
		"enemies": [
			[CRAWLER, "limpet", &"crawl", 5.0, 0.0],
		],
		"checkpoint": 2.0,
		"tide": true,
		"shaft_up": [23, 2],
	},
	{
		"name": "Boss Door", "col": 13, "band": BAND_DECK,
		# Deliberately empty. The run-up to a boss is a breath, not a fight.
		"gaps": [], "blocks": [],
		"enemies": [],
		"checkpoint": 2.0,
	},
	{
		"name": "Arena", "col": 14, "band": BAND_DECK,
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
func place_stage_elements(spec: Dictionary, index: int, origin: int, deck: int,
		tile: float) -> void:
	if spec.get("tide", false):
		_add_tide(index, origin, deck, tile)


## The rising tide, filling the room from below.
##
## `ceiling_row` is the deck two rows above the highest block in the room, which
## is where a player waiting out the water ends up standing. Water above that
## line covers the only footing there is, and the section becomes unwinnable
## with nothing on screen to say why -- which is the failure RisingTide exists
## to make impossible rather than merely unlikely.
func _add_tide(index: int, origin: int, deck: int, tile: float) -> void:
	var water := RisingTide.new()
	water.name = "RisingTide"
	water.width_tiles = float(ROOM_WIDTH)
	water.start_row = float(deck) + 3.0
	water.ceiling_row = float(deck) - float(TIDE_CEILING_ABOVE_DECK)
	water.position = Vector2(float(origin), 0.0) * tile
	add_child(water)
	_tide = water
	# Registered with the base class, which starts it when the player enters this
	# room and sends it back down when they leave -- including when "entering"
	# means respawning after drowning in it.
	register_tide(index, water)
