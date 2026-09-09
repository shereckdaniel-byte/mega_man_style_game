## Fortress 4, "Keep" -- the core, and the end of the run.
##
##   col   0      1       2      3      4      5     6     7
##  band 0 Gate---Spine---Vault
##                          |
##  band 1                Race---Sluice--Breach--Door--Arena
##
## **Nine rooms, and it is the shortest stage in the game on purpose.** Every
## fortress stage is shorter than a master stage; this one is shorter than the
## other three, because what is at the end of it is the only thing anyone is here
## for and every room before it is a room spent on the way. MM3's last Wily stage
## is a corridor and a fight, and it is right.
##
## ### It has no new idea, and it does not reuse one either
##
## Outfall paired the two waters. Caisson paired the belt and the press.
## Switchgear had no gimmick at all -- the eight fights were the stage.
##
## Keep has **spikes, crumbling blocks and moving platforms**: the kit from M5a,
## which every stage in the game has had access to since stage 1 and which the
## player has been reading since the first room they ever played. Nothing here
## needs explaining, and that is the point. A gimmick in the last stage is a
## thing to learn on the way to the thing you came to do, and the fortress has
## already asked twice whether the player learned anything.
##
## What it *is* is dense. The rooms are ordinary and they are packed, and the
## only resource that matters is the one the player walks in with -- there is
## nothing after this to save it for.
##
## ### The ending
##
## This is the one stage in the game whose clear does not lead anywhere. The
## other eleven hand the player back to the grid or on to the next fortress
## stage; this one ends the run, which is a thing nothing in the project has ever
## had to do. See `_on_stage_exited`.
extends FortressStage

const BACKGROUND := preload("res://scenes/stages/fortress/parallax_background.gd")
## TODO(art): the fortress wants its own tileset. Greyboxed against stage 3's,
## as stages 4-8 and the rest of the fortress are.
const TILESET := preload("res://resources/tilesets/breakers.tres")
const BULWARK := preload("res://scenes/actors/bosses/bulwark.gd")
const BOSS_FRAMES_PATH := "res://resources/sprite_frames/rust.tres"

const WALKER := preload("res://scenes/actors/enemies/walker.gd")
const HOPPER := preload("res://scenes/actors/enemies/hopper.gd")
const TURRET := preload("res://scenes/actors/enemies/turret.gd")
const FLYER := preload("res://scenes/actors/enemies/flyer.gd")
const SPAWNER := preload("res://scenes/actors/enemies/spawner.gd")
const CRAWLER := preload("res://scenes/actors/enemies/wall_crawler.gd")

const BAND_APPROACH := 0
const BAND_CORE := 1

## TODO(art): stage 3's skins, as everything greyboxed against stage 3's tiles
## uses. This stage wants **Sentry** (walks the spine), **Bollard** (hops the
## race), **Embrasure** (a slit that fires), **Mote** (drifting), **Oubliette**
## (releases crawlers) and **Creep** (the crawler).
const SKIN_WALKER := "cutter"
const SKIN_HOPPER := "jack"
const SKIN_TURRET := "rivetgun"
const SKIN_FLYER := "slag"
const SKIN_SPAWNER := "skip"
const SKIN_CRAWLER := "seam"


## One row per room. No stage keys of its own -- see the class docstring for why
## the last stage deliberately has nothing new in it.
const ROOMS := [
	{
		"name": "Gate", "col": 0, "band": BAND_APPROACH,
		# The last quiet room in the game. Two walkers and a floor.
		"gaps": [], "blocks": [],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 13.0, 0.0],
			[WALKER, SKIN_WALKER, &"walk", 22.0, 0.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Spine", "col": 1, "band": BAND_APPROACH,
		# **The crumbling blocks are the floor over the hole**, which is the
		# idiom stage 1's Boardwalk and stage 3 both use: `crumbles` is
		# `[x, rows_above_deck]` and 0 means "in the deck". They do not come
		# back -- that was the first playtest's second note and it has been true
		# since -- so this is one crossing with one answer, taken at the speed
		# the player picks.
		#
		# Authored first at rise 2, which put three one-tile blocks floating two
		# rows up and left a single tile of headroom under them. A standing
		# player is a tile and a half. The bot walked into the first one and
		# stood there for 900 frames.
		"gaps": [[14, 16]], "blocks": [[6, 2, 3, 2]],
		"crumbles": [[14, 0], [15, 0]],
		"enemies": [
			[FLYER, SKIN_FLYER, &"fly", 20.0, 5.0],
		],
		"pit_spikes": [[14, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Vault", "col": 2, "band": BAND_APPROACH,
		# No gaps -- the core band runs under this column -- and the shaft down
		# is the way in. A spiked tunnel to slide, because the last thing the
		# approach asks for should be a thing the player is good at by now.
		"gaps": [], "blocks": [[6, 2, 3, 2]],
		"ceilings": [[12, SPIKED_CLEARANCE, 2, 3]],
		"ceiling_spikes": [[12, SPIKED_CLEARANCE, 2]],
		"enemies": [
			[CRAWLER, SKIN_CRAWLER, &"crawl", 17.0, 0.0],
		],
		"checkpoint": 2.0,
		"shaft": [23, 2],
	},
	{
		"name": "Race", "col": 2, "band": BAND_CORE,
		# Arrival in the core, and the backdrop changes with it. Nothing east of
		# 20: the ladder delivers at 23-24 and building on a landing spawns the
		# player inside terrain.
		"gaps": [[8, 10]], "blocks": [],
		"enemies": [
			[TURRET, SKIN_TURRET, &"idle", 4.0, 2.0],
			[HOPPER, SKIN_HOPPER, &"hop", 15.0, 0.0],
		],
		"pit_spikes": [[8, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Sluice", "col": 3, "band": BAND_CORE,
		# **Turbine Row's Kite, exactly**: a hole far wider than a jump, one
		# platform, and no other way over. A turret watching it is the whole
		# difference.
		#
		# Authored first as a two-cell gap with a mover beside it, which is a
		# crossing the player can simply jump -- so the platform is decoration
		# and the bot fell in the hole once every single run, at the same frame,
		# on every seed. A mover is worth having when it is the route; next to a
		# gap that does not need it, it is one more thing moving near a ledge.
		#
		# No pit spikes: the hole is eight cells and the pit plane is already
		# underneath it. Teeth inside a gap nobody survives falling into are
		# teeth nobody ever sees.
		"gaps": [[8, 16]], "blocks": [],
		"movers": [[8, 0, 8.0, 0.0, 150]],
		"enemies": [
			[TURRET, SKIN_TURRET, &"idle", 24.0, 2.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Breach", "col": 4, "band": BAND_CORE,
		# The densest room in the game, and the last one with anything in it: a
		# spawner, a flyer and a spike bed, all inside one screen. Nothing in it
		# is new. That is the exam -- not "can you learn this" but "are you still
		# good at all of it".
		# **No floor spikes, after four attempts to place some.**
		#
		# `RUN_UP_CELLS + rise` models a player walking up to a bed along the
		# deck and jumping from the ground. The bot climbs the block, walks to
		# its far edge and leaps from up there, which starts the arc with height
		# already spent; and this room also has a flyer in it, which pushes the
		# player somewhere they did not choose to be. The bed was moved to five
		# cells clear of the block, then six, then ten, and the bot died in it
		# every time from a slightly different place.
		#
		# The honest reading is that **a floor-spike bed in a room with a flyer
		# is two hazards that multiply**, and the rule cannot see the second one.
		# Stack shipped the game's first bed four cells wide with a conveyor
		# running into it and it was a wall; this is the same lesson from the
		# other side.
		#
		# The room's density was always meant to be *enemies* -- three inside one
		# screen, which no other room in the game has -- and it still is. The
		# stage keeps its teeth in Vault's tunnel and in three pits.
		"gaps": [], "blocks": [[7, 2, 3, 2]],
		"enemies": [
			[SPAWNER, SKIN_SPAWNER, &"idle", 4.0, 0.0],
			[FLYER, SKIN_FLYER, &"fly", 14.0, 5.0],
			[WALKER, SKIN_WALKER, &"walk", 22.0, 0.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Boss Door", "col": 5, "band": BAND_CORE,
		# Deliberately empty, and it has never mattered more: what is on the
		# other side of it is two fights, and the player walks in with whatever
		# they have left.
		"gaps": [], "blocks": [],
		"enemies": [],
		"checkpoint": 2.0,
	},
	{
		"name": "Arena", "col": 6, "band": BAND_CORE,
		# Flat, empty, no checkpoint. Bulwark's rubble builds the only footing
		# this room ever has, which is the fight furnishing itself.
		"gaps": [], "blocks": [],
		"enemies": [],
		"checkpoint": NO_CHECKPOINT,
	},
]


func fortress_index() -> int:
	return 3


func room_table() -> Array:
	return ROOMS


func stage_tile_set() -> TileSet:
	return TILESET


func backdrop_script() -> GDScript:
	return BACKGROUND


func boss_script() -> GDScript:
	return BULWARK


func boss_frames_path() -> String:
	return BOSS_FRAMES_PATH


func boss_name() -> String:
	return "Bulwark"


## Bulwark configures itself: it is not a reprise of anything and there is no
## ninth master for it to claim. Stated rather than inherited so the difference
## from Outfall is visible in the file.
func configure_boss(_boss: Boss) -> void:
	pass


## **The end of the run**, and the one stage clear in the game that does not lead
## somewhere else.
##
## `FortressStage` marks the stage cleared and then walks to the next fortress
## stage; there is no next one, so its fallback hands the player back to the
## stage select. That is correct for a fortress stage that has not been built
## yet and wrong for this one -- finishing the game and being returned to the
## grid with every cell green is not an ending, it is the absence of one.
##
## So this overrides the walk and routes to the ending instead. The bit is
## written first, exactly as `FortressStage` writes it first, because the save
## that records a finished run is the one moment it matters most that the save is
## right.
##
## **M8 owns the ending screen itself** -- title, intro, ending and credits are
## its bullet -- and `SceneRouter.ENDING` points at a scene that does not exist
## yet. `goto_ending()` falls back to the stage select when it is missing, so the
## game is completable today and gets its ending the moment one is written,
## without this file changing.
func _on_stage_exited() -> void:
	var state := get_node_or_null(^"/root/GameState")
	if state != null:
		state.mark_fortress_cleared(fortress_index())
	stage_cleared.emit()
	var router := get_node_or_null(^"/root/SceneRouter")
	if router != null:
		router.goto_ending()
