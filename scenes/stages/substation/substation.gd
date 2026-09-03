## Stage 2, "Substation" -- the flooded switchyard, and Arc's stage.
##
## Eight rooms laid out as a **J**: a short run across the yard, down into the
## cable trench almost immediately, a long dark middle along the bottom, and one
## climb at the end into the arena.
##
##      col 0     1                                 4        5
##  band 0  Yard  - Busbars                      Gate  - Arena
##                     |                            ^
##  band 1           Trench - Flooded Bay - Hall - Riser
##
## **The shape is chosen against stage 1's.** Dawn Boardwalk is a U: down in the
## middle and up again, with the two ends of the stage at the same height and the
## descent as a mid-stage event. Copying that would make stage 2 the same walk
## with different tiles, which is the failure M5a's whole argument was about. So
## this one commits early and stays down: the descent is the second room, four of
## the eight rooms are the dark trench, and the climb is the last thing before
## the boss door rather than the middle of the level.
##
## That also gives the gimmick the room it needs. A dark section that is one
## screen long is a novelty; four rooms is a place. `DarkRoom` is what makes them
## dark, and its docstring carries the three rules that keep it fair.
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

## **Stage 2 wears stage 1's enemy skins, and that is a known gap, not a choice.**
## The roster (docs/PLAN.md section 4) says the six archetypes are reskinned per
## stage -- the behaviour is the archetype, the art is the theme -- and the
## substation's six have not been drawn. Naming them here as the boardwalk's is
## honest about it and keeps the stage playable and testable meanwhile; the swap
## is one column of this table when the art lands.
const SKIN_WALKER := "dockrat"
const SKIN_HOPPER := "bollard"
const SKIN_TURRET := "lampjack"
const SKIN_FLYER := "gullbot"
const SKIN_SPAWNER := "barnacle_hive"
const SKIN_CRAWLER := "limpet"

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
		"name": "Switch Hall", "col": 3, "band": BAND_TRENCH,
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
		"name": "Riser", "col": 4, "band": BAND_TRENCH,
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
		"shaft_up": [24, 2],
	},
	{
		"name": "Gate", "col": 4, "band": BAND_YARD,
		# Lit, and deliberately empty. The run-up to a boss is a breath, and
		# coming back into the light is the stage's own punctuation before it.
		"gaps": [], "blocks": [],
		"enemies": [],
		"checkpoint": 2.0,
	},
	{
		"name": "Arena", "col": 5, "band": BAND_YARD,
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
