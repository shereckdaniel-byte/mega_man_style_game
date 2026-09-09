## Stage 2, "Substation" -- the flooded switchyard, and Arc's stage.
##
## Nineteen rooms laid out as a long **J**: a short run across the yard, down
## into the cable trench almost immediately, a long dark stretch, a lit yard in
## the middle, a second and harder dark stretch, and one climb into the arena.
##
##   col  0    1      2      3     4     5     6      7        8      9     10    11    12    13     14
##  band 0 Yard-Busbars                            Daylight-TfmrRow-YardTwo-Catwalk              Gate-Arena
##               |                                    ^                        |                   ^
##  band 1    Trench-Flooded-CableRun-Hall-Sump-TieLine                    LowerTrench-Blackout-Feeder-Dead-Riser
##
## **The shape is chosen against stage 1's.** Dawn Boardwalk is a W that spends
## as long above the deck as below it. Copying that would make stage 2 the same
## walk with different tiles, which is the failure M5a's whole argument was
## about. So this one commits early and stays down: the descent is the second
## room, **eleven of the nineteen are dark**, and the yard is something the stage
## visits rather than something it runs along.
##
## **The lit middle is not a rest, it is the rehearsal.** Six dark rooms, then
## four with the lights on, then five more dark. Everything the second stretch
## asks for is asked first in the light -- Yard Two's slide is Blackout's spiked
## tunnel without the teeth, Transformer Row's gaps are Feeder's planks without
## the dark. A stage that just kept going down would have to teach in the dark or
## not teach at all, and `DarkRoom`'s three rules exist precisely because
## teaching in the dark is how a gimmick becomes unfair.
##
## That also gives the gimmick the room it needs. A dark section one screen long
## is a novelty; four rooms is a place; eleven, split by a return to daylight, is
## the stage. `DarkRoom` is what makes them dark, and its docstring carries the
## three rules that keep it fair.
##
## **What is not different from stage 1 is deliberate.** The vocabulary is the
## M5a kit -- ladders, one-ways, movers, crumbling blocks, spikes -- because a
## kit used once per stage is a kit nobody learns. What changes is which of them
## a room asks for and in what order, and here it is mostly asked for in the dark.
extends AuthoredStage

const BACKGROUND := preload("res://scenes/stages/substation/parallax_background.gd")
const TILESET := preload("res://resources/tilesets/substation.tres")
const ARC := preload("res://scenes/actors/bosses/arc.gd")
const DARK_ROOM := preload("res://scenes/level/dark_room.gd")
## Arc's art. By path rather than preloaded so the stage still opens if the
## sprite frames are mid-regeneration.
const BOSS_FRAMES_PATH := "res://resources/sprite_frames/arc.tres"

const WALKER := preload("res://scenes/actors/enemies/walker.gd")
const HOPPER := preload("res://scenes/actors/enemies/hopper.gd")
const TURRET := preload("res://scenes/actors/enemies/turret.gd")
const FLYER := preload("res://scenes/actors/enemies/flyer.gd")
const SPAWNER := preload("res://scenes/actors/enemies/spawner.gd")
const CRAWLER := preload("res://scenes/actors/enemies/wall_crawler.gd")

## The yard, and the cable trench a screen beneath it.
const BAND_YARD := 0
const BAND_TRENCH := 1

## The substation's six, one per archetype.
##
## The roster's rule (docs/PLAN.md section 4) is that **the behaviour is the
## archetype and the art is the theme** -- the same six behaviours are reskinned
## per stage rather than redesigned. So this is a column of names, and the
## behaviour each wears is whatever `scenes/actors/enemies/` already does.
##
## Named off the switchyard rather than invented: a breaker is a switchgear
## cabinet, an isolator is a knife switch on a ceramic stack, an arrester
## discharges a surge, corona is the glow that creeps around a live conductor, a
## splice box is where cables are joined, and creepage is the tracking current
## that crawls across wet insulation. Each is a thing that is actually in a
## substation and does roughly what its archetype does.
const SKIN_WALKER := "breaker"
const SKIN_HOPPER := "isolator"
const SKIN_TURRET := "arrester"
const SKIN_FLYER := "corona"
const SKIN_SPAWNER := "splicebox"
const SKIN_CRAWLER := "creeper"

## One row per room, in the order the player meets them. The key reference is in
## AuthoredStage's docstring; `dark` is this stage's own.
##
## The same two authoring limits apply as on stage 1, and are enforced by
## tests/test_substation.gd: a block rises at most MAX_STEP_TILES above the deck
## and a gap is at most MAX_GAP_TILES wide, except where a ladder or a platform
## crosses it.
const ROOMS := [
	{
		"name": "Yard", "col": 0, "band": BAND_YARD,
		# The lit room. A dark stage has to show the player a room with the
		# lights on first, or the gimmick reads as the game being broken rather
		# than as the power being out.
		#
		# **The stage's one teaching gap is here, and it is here for a structural
		# reason rather than a pacing one.** A gap is a hole in the deck, and a
		# hole is only a pit if there is nothing underneath -- in a column that
		# has another band below it, the player falls into the room beneath
		# without going through its door, and arrives in a room the stage does
		# not think they are in. Column 0 is the only lit column with nothing
		# below it, so it is the only place a gap can teach anything.
		# `tests/test_stage_authoring.gd` enforces this across every stage.
		"gaps": [[18, 20]], "blocks": [],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 15.0, 0.0],
			[WALKER, SKIN_WALKER, &"walk", 23.0, 0.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Busbars", "col": 1, "band": BAND_YARD,
		# The last of the light, and **no gaps** -- the Trench is directly below
		# this column, so a hole here drops the player past its door. Steps
		# instead: two blocks at the limit, which is a different verb from the
		# Yard's gap and the last thing asked in daylight.
		"gaps": [], "blocks": [[9, 2, 3, 2], [16, 2, 4, 2]],
		"enemies": [
			[HOPPER, SKIN_HOPPER, &"hop", 6.0, 0.0],
			[TURRET, SKIN_TURRET, &"idle", 21.0, 2.0],
		],
		"checkpoint": 2.0,
		# Down at cell 24, near the far end: the descent is the room's exit, and
		# a shaft in the middle would have the player walk past it to a dead end.
		"shaft": [24, 2],
	},
	{
		"name": "Trench", "col": 1, "band": BAND_TRENCH,
		# **Dark from here.** The first dark room is deliberately the tamest one
		# in the stage: no gaps, no spikes, one crawler. What is being taught is
		# the flash rhythm, and teaching it over a pit teaches it once.
		"dark": true,
		"gaps": [], "blocks": [[6, 2, 3, 2]],
		"enemies": [
			[CRAWLER, SKIN_CRAWLER, &"crawl", 12.0, 0.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Flooded Bay", "col": 2, "band": BAND_TRENCH,
		# Dark and now it costs something. Two gaps, both inside MAX_GAP_TILES,
		# so they are jumps the player already knows -- the new thing is doing
		# them on a remembered layout rather than a visible one.
		#
		# Spikes at the bottom of the gaps rather than beside them: the same rule
		# stage 1 arrived at, and it matters more here. A spike you can only see
		# in a flash, placed on ground you would otherwise walk, is the exact
		# unfair dark room DarkRoom's docstring refuses to build.
		"dark": true,
		"gaps": [[8, 10], [17, 19]], "blocks": [],
		"enemies": [
			[FLYER, SKIN_FLYER, &"fly", 13.0, 4.0],
			[CRAWLER, SKIN_CRAWLER, &"crawl", 23.0, 0.0],
		],
		"checkpoint": 2.0,
		"pit_spikes": [[8, 3, 2], [17, 3, 2]],
	},
	{
		"name": "Cable Run", "col": 3, "band": BAND_TRENCH,
		# One-way platforms, in the dark. Stage 1 introduces them in daylight
		# because their rule -- solid from above, passable from below -- cannot
		# be read off the art; here the player already knows the rule and the
		# new thing is finding the platform on a remembered layout.
		"dark": true,
		"gaps": [[7, 9]], "blocks": [],
		"one_ways": [[14, 3, 5]],
		"enemies": [
			[CRAWLER, SKIN_CRAWLER, &"crawl", 5.0, 0.0],
			[FLYER, SKIN_FLYER, &"fly", 18.0, 4.0],
		],
		"pit_spikes": [[7, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Switch Hall", "col": 4, "band": BAND_TRENCH,
		# The hardest dark room, and the only one that asks for two things at
		# once: a slide under live gear, then a crossing on the mover.
		#
		# The tunnel is one row of clearance and hung with spikes, which is the
		# stage 1 lesson about where a spike belongs -- on geometry the level has
		# already asked you to slide under, punishing a badly executed move
		# rather than ambushing a walk.
		"dark": true,
		"gaps": [[14, 20]], "blocks": [],
		"enemies": [
			[SPAWNER, SKIN_SPAWNER, &"idle", 10.0, 4.0],
			[TURRET, SKIN_TURRET, &"idle", 24.0, 2.0],
		],
		"checkpoint": 2.0,
		# **Two cells, not three, and that is an authoring limit rather than a
		# taste.** A slide covers 4.06 tiles from where it starts, and both a bot
		# and a player commit to it a cell or two before the lip -- so a spiked
		# tunnel three wide leaves about a tile of slack and is cleared or not
		# depending on which pixel the slide began at. The bot proved it by
		# standing up inside a three-wide one and dying on its teeth, then
		# clearing the identical tunnel on the next two attempts.
		# `tests/test_stage_authoring.gd` caps it at MAX_SPIKED_TUNNEL_TILES.
		"ceilings": [[5, SPIKED_CLEARANCE, 2]],
		"ceiling_spikes": [[5, SPIKED_CLEARANCE, 2]],
		# Six cells: past MAX_GAP_TILES on purpose, so the mover is the crossing
		# and not a shortcut over a jump. Level with the deck and starting over
		# the gap, for the reason Under East's ferry is -- a platform you have to
		# jump *onto* asks for a commitment made before you can see the landing,
		# which in the dark is not a decision at all.
		# 150 frames a leg, which is Under East's number rather than a fresh one.
		# At 130 the platform is quick enough that a rider who steps on late is
		# still travelling when it turns, and the bot walked off the lip into the
		# spikes below. A crossing is not the place to be inventive.
		"movers": [[14, 0, 6.0, 0.0, 150]],
		"pit_spikes": [[14, 3, 6]],
	},
	{
		"name": "Sump", "col": 5, "band": BAND_TRENCH,
		# Crumbling planks in the dark, and the reason they are only ever laid
		# across a jumpable gap: a plank falls, so it can never be the sole way
		# over -- and in the dark a player who guesses wrong about where the far
		# lip is has already committed. Two cells each, both inside
		# MAX_GAP_TILES, so the planks are the fast route and not the only one.
		"dark": true,
		"gaps": [[9, 11], [16, 18]], "blocks": [],
		"crumbles": [[9, 0], [10, 0], [16, 0], [17, 0]],
		"enemies": [
			[CRAWLER, SKIN_CRAWLER, &"crawl", 5.0, 0.0],
			[SPAWNER, SKIN_SPAWNER, &"idle", 13.0, 4.0],
		],
		"pit_spikes": [[9, 3, 2], [16, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Tie Line", "col": 6, "band": BAND_TRENCH,
		# The way back up, and the end of the first dark stretch. A block ladder
		# rather than an obstacle: after six rooms in the dark the exit should be
		# something the player can find by walking into it.
		"dark": true,
		"gaps": [], "blocks": [[6, 2, 3, 2], [12, 4, 3, 2]],
		"enemies": [
			[TURRET, SKIN_TURRET, &"idle", 18.0, 2.0],
			[CRAWLER, SKIN_CRAWLER, &"crawl", 20.0, 0.0],
		],
		"checkpoint": 2.0,
		"shaft_up": [23, 2],
	},
	{
		"name": "Daylight", "col": 6, "band": BAND_YARD,
		# **The light is the event.** Six rooms of flash-lit trench, and then the
		# lid comes off. Nothing is asked here beyond one walker, because the
		# room is doing its work by being visible -- and because the ladder puts
		# the player three cells from the door (SHAFT_LANDING_CELLS), so there is
		# no space for a room even if one were wanted.
		#
		# No gaps: Tie Line is directly below, and a hole would drop the player
		# into it past its own door.
		"gaps": [], "blocks": [],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 10.0, 0.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Transformer Row", "col": 7, "band": BAND_YARD,
		# The lit stretch is not a rest, it is a rehearsal. Everything the second
		# dark run will ask for gets asked here first with the lights on: two
		# gaps to time against a flyer, and a step to climb past a turret.
		"gaps": [[8, 10], [18, 20]], "blocks": [[23, 2, 3, 2]],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 5.0, 0.0],
			[TURRET, SKIN_TURRET, &"idle", 14.0, 2.0],
			[FLYER, SKIN_FLYER, &"fly", 16.0, 4.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Yard Two", "col": 8, "band": BAND_YARD,
		# The slide, in the light. Switch Hall already asked for one under live
		# gear in the dark, which was the stage's hardest single moment; asking
		# again here, visible and un-toothed, is what makes the *next* dark
		# tunnel a thing the player has practised rather than a thing they
		# remember being hurt by.
		#
		# Four rows thick, so its top is out of the jump's reach and the tunnel
		# is the only way through. Three cells wide, because a slide covers about
		# four and a longer tunnel traps the player standing up inside it.
		"gaps": [[6, 8]], "blocks": [[20, 2, 4, 2]],
		"ceilings": [[13, SLIDE_CLEARANCE, 3, 4]],
		"enemies": [
			[HOPPER, SKIN_HOPPER, &"hop", 10.0, 0.0],
			[TURRET, SKIN_TURRET, &"idle", 18.0, 2.0],
			[WALKER, SKIN_WALKER, &"walk", 22.0, 2.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Catwalk", "col": 9, "band": BAND_YARD,
		# Climbing, and then the way back down. No gaps -- Lower Trench is
		# underneath -- so the room goes up instead of opening, which also puts
		# the player at the top of the yard for the drop into the second dark
		# stretch. The stage descends twice and this is the second commitment.
		"gaps": [], "blocks": [[5, 2, 3, 2]],
		"one_ways": [[11, 2, 4], [17, 4, 4]],
		"enemies": [
			[TURRET, SKIN_TURRET, &"idle", 8.0, 2.0],
			[FLYER, SKIN_FLYER, &"fly", 14.0, 6.0],
		],
		"checkpoint": 2.0,
		"shaft": [22, 2],
	},
	{
		"name": "Lower Trench", "col": 9, "band": BAND_TRENCH,
		# Dark again, and it opens with the thing the first stretch closed with:
		# a crossing on a mover over spikes. No teaching room this time -- the
		# lit stretch was the teaching, and the second descent is allowed to
		# start where the first one finished.
		"dark": true,
		"gaps": [[8, 14]], "blocks": [],
		"movers": [[8, 0, 6.0, 0.0, 150]],
		"pit_spikes": [[8, 3, 6]],
		"enemies": [
			[CRAWLER, SKIN_CRAWLER, &"crawl", 4.0, 0.0],
			[TURRET, SKIN_TURRET, &"idle", 20.0, 2.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Blackout", "col": 10, "band": BAND_TRENCH,
		# The stage's hardest room, and the one Yard Two exists to prepare. A
		# spiked tunnel in the dark, then a gap over spikes.
		#
		# Two cells of tunnel, not three: a slide covers 4.06 tiles and a player
		# commits a cell or two before the lip, so a three-wide spiked tunnel is
		# cleared or not depending on which pixel the slide began at. Switch Hall
		# proved that with the bot; MAX_SPIKED_TUNNEL_TILES holds every stage to
		# it.
		"dark": true,
		"gaps": [[16, 18]], "blocks": [],
		"ceilings": [[6, SPIKED_CLEARANCE, 2]],
		"ceiling_spikes": [[6, SPIKED_CLEARANCE, 2]],
		"enemies": [
			[SPAWNER, SKIN_SPAWNER, &"idle", 12.0, 4.0],
			[CRAWLER, SKIN_CRAWLER, &"crawl", 22.0, 0.0],
		],
		"pit_spikes": [[16, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Feeder", "col": 11, "band": BAND_TRENCH,
		# Three plank crossings in a row, in the dark, over spikes. Sump asked
		# for two; this is the same move at a rhythm, which is the only way the
		# element gets to be about pace rather than about one decision.
		"dark": true,
		"gaps": [[7, 9], [13, 15], [19, 21]], "blocks": [],
		"crumbles": [[7, 0], [8, 0], [13, 0], [14, 0], [19, 0], [20, 0]],
		"enemies": [
			[CRAWLER, SKIN_CRAWLER, &"crawl", 4.0, 0.0],
			[FLYER, SKIN_FLYER, &"fly", 11.0, 4.0],
		],
		"pit_spikes": [[7, 3, 2], [13, 3, 2], [19, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Dead Section", "col": 12, "band": BAND_TRENCH,
		# The last full dark room, and **the only one with no hole in it.**
		#
		# It had a two-cell gap off nine cells of flat deck, which is the most
		# ordinary jump in the game, and the bot walked into it twice from two
		# different positions -- 26 HP and a life, in the one room out of
		# nineteen that cost anything. Moving the gap and moving the turret both
		# failed to fix it, which is the signal that the room was wrong rather
		# than its numbers.
		#
		# It is wrong because of where it sits. Five dark rooms deep, every one
		# of them ending in a hole, the stage has made "there is a gap here" the
		# default expectation -- and a stage that only ever says the same thing
		# in the dark has stopped saying anything. So the last one climbs: a
		# step, a platform, and the ladder out. Riser owns the final gap, one
		# room later, where it is the last obstacle rather than the fifth in a
		# row.
		"dark": true,
		# **The turret is past the step, not across the gap.** It was authored at
		# cell 11 with the gap at 6-8, which put a thing that fires horizontally
		# on the far side of a hole the player has to jump -- in the dark, where
		# the shot arrives before the shooter is visible. The bot lost 22 HP and
		# a life in this one room and nowhere else in nineteen. A turret is a
		# thing to shoot past; it is not a thing to be shot by mid-air, and the
		# stage has no other room that asks for both at once.
		#
		# The gap also moved back to 10, so the room opens with ground rather
		# than with a hole three cells inside the door.
		"gaps": [], "blocks": [[10, 2, 3, 2]],
		"one_ways": [[17, 3, 5]],
		"enemies": [
			[CRAWLER, SKIN_CRAWLER, &"crawl", 4.0, 0.0],
			[FLYER, SKIN_FLYER, &"fly", 17.0, 5.0],
			[TURRET, SKIN_TURRET, &"idle", 24.0, 2.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Riser", "col": 13, "band": BAND_TRENCH,
		# Still dark, and the way out is up. The crumbling planks are the last
		# obstacle in the dark and they are optional: the one-way platforms above
		# them are a slower way to the same ladder, so a player who cannot read
		# the flash rhythm is not stuck, only slower.
		"dark": true,
		"gaps": [[10, 12]], "blocks": [],
		"enemies": [
			[CRAWLER, SKIN_CRAWLER, &"crawl", 7.0, 0.0],
			[FLYER, SKIN_FLYER, &"fly", 18.0, 4.0],
		],
		"checkpoint": 2.0,
		"crumbles": [[10, 0], [11, 0]],
		"one_ways": [[9, 3, 5]],
		"shaft_up": [23, 2],
	},
	{
		"name": "Gate", "col": 13, "band": BAND_YARD,
		# Lit, and deliberately empty. The run-up to a boss is a breath, and
		# coming back into the light is the stage's own punctuation before it.
		"gaps": [], "blocks": [],
		"enemies": [],
		"checkpoint": 2.0,
	},
	{
		"name": "Arena", "col": 14, "band": BAND_YARD,
		# Flat, empty, lit, and no checkpoint. A dark arena would make Arc's
		# Curtain unreadable, and the pattern's answer is reading it.
		"gaps": [], "blocks": [],
		"enemies": [],
		"checkpoint": NO_CHECKPOINT,
	},
]

var _dark: DarkRoom = null


func room_table() -> Array:
	return ROOMS


func stage_tile_set() -> TileSet:
	return TILESET


func backdrop_script() -> GDScript:
	return BACKGROUND


func boss_script() -> GDScript:
	return ARC


func boss_frames_path() -> String:
	return BOSS_FRAMES_PATH


func boss_name() -> String:
	return "Arc"


func _ready() -> void:
	super()
	# After the base has built everything, because it needs the room list to
	# know which rooms are dark, and it hangs on room changes rather than on
	# geometry.
	_add_dark_room()


## Which rooms the lights are out in, by index.
func dark_rooms() -> Array[int]:
	var out: Array[int] = []
	for index in ROOMS.size():
		if bool(ROOMS[index].get("dark", false)):
			out.append(index)
	return out


func dark_room() -> DarkRoom:
	return _dark


func _add_dark_room() -> void:
	_dark = DARK_ROOM.new()
	_dark.name = "DarkRoom"
	add_child(_dark)
	room_changed.connect(_on_room_changed_dark)
	# The stage starts in room 0, which the base already announced before this
	# node existed, so set the initial state by hand rather than waiting for a
	# signal that has already been emitted.
	_on_room_changed_dark(room)


func _on_room_changed_dark(entered: Room) -> void:
	if _dark == null or entered == null:
		return
	for index in rooms().size():
		if rooms()[index] == entered:
			_dark.set_active(bool(ROOMS[index].get("dark", false)))
			return
