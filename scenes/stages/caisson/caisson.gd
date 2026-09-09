## Fortress 2, "Caisson" -- the pressure chamber, and whoever is waiting in it.
##
##   col   0      1      2      3     4      5       6      7      8     9     10
##  band 0 Airlock-Trunk--Gate
##                          |
##  band 1                Press--Feed--Anvil--Chamber-Relief
##                                                       |
##  band 2                                             Floor--Sluice-Ram--Door--Arena
##
## Thirteen rooms, straight down. Outfall's route reversed and came back to the
## band it started in; this one only ever descends, because what the fortress
## does to a visitor is take them further in.
##
## ### The pair: the belt and the press
##
## Outfall mixed the two waters. Caisson mixes **stage 6's conveyor and stage
## 3's crusher**, and the reason they go together is that neither is dangerous
## and both are about *when*:
##
##   * A belt is a constant you fight. It never hurts you; it decides where you
##     end up if you stop thinking.
##   * A press is a clock. It is inert at the top, it shudders for 36 frames,
##     and then the column is death for as long as it takes to come back up.
##
## **The belt decides when you arrive. The press decides whether that was a good
## time.** That is the whole stage in a sentence, and it is a thing neither
## master stage could say, because each of them has only one half of it.
##
## ### The rule that keeps it fair: they never touch
##
## A belt must not overlap a press's column, and it must stop `BELT_MARGIN_CELLS`
## short of one. This is arithmetic rather than taste.
##
## `CrusherPress.TELL_FRAMES` is 36 and it is sized from the walk: 36 frames at
## 1.375 NES px/frame is 49 px, or 3.06 tiles, which is why `MAX_PRESS_TILES` is
## 3. That budget is what makes the tell a fair warning -- from anywhere inside
## the widest legal press, a standing player can walk clear before the drop.
##
## Put a belt under the press and the budget is gone. Walking out against a
## 0.6 px/frame belt nets 0.775, and 36 frames of that is 27.9 px -- **1.74
## tiles**, against a column up to 3 wide. The player would be shown a warning
## they cannot act on, which is worse than no warning at all.
##
## So the two never share cells, and there are `BELT_MARGIN_CELLS` of ordinary
## floor between them, so that the moment the player has a decision to make they
## are standing on something that lets them make it. `tests/test_caisson.gd`
## computes both numbers from `CrusherPress` and `ConveyorBelt` rather than
## restating them, so a change to either constant fails the stage rather than
## quietly making a room unfair.
##
## ### The boss door opens onto someone who is not a boss
##
## Ward is at the end of this stage, and he cannot be beaten and cannot kill.
## docs/PLAN.md section 1 asks for "a scripted mid-stage duel"; this is at the
## end of a stage instead, and the reason is the seal.
##
## What makes a duel a set piece rather than an encounter is that the room shuts
## and the player cannot walk away, and `BossArena` is the thing in this project
## that shuts a room. Putting Ward behind a boss door also uses eight stages of
## training against the player: they have learned exactly what that door means,
## and this one opens onto a fight with no bar to empty, no weapon at the end,
## and a whistle first.
##
## He is also the reason Caisson has no reprise. Switchgear is eight of them; a
## fortress whose first three stages were all refights would be ten old fights
## and one new one.
extends FortressStage

const BACKGROUND := preload("res://scenes/stages/fortress/parallax_background.gd")
## TODO(art): the fortress wants its own tileset. Greyboxed against stage 3's,
## as stages 4-8 and Outfall are.
const TILESET := preload("res://resources/tilesets/breakers.tres")
const RIVAL := preload("res://scenes/actors/bosses/rival.gd")
const CRUSHER := preload("res://scenes/level/crusher_press.gd")
const BELT := preload("res://scenes/level/conveyor_belt.gd")
## Ward wears the player's frames, tinted -- see `Rival`. The award screen never
## opens for him (he drops nothing), so this is only ever read by the tests.
const BOSS_FRAMES_PATH := "res://resources/sprite_frames/player.tres"

const WALKER := preload("res://scenes/actors/enemies/walker.gd")
const HOPPER := preload("res://scenes/actors/enemies/hopper.gd")
const TURRET := preload("res://scenes/actors/enemies/turret.gd")
const FLYER := preload("res://scenes/actors/enemies/flyer.gd")
const SPAWNER := preload("res://scenes/actors/enemies/spawner.gd")
const CRAWLER := preload("res://scenes/actors/enemies/wall_crawler.gd")

## The chamber head, the works, and the floor of the caisson.
const BAND_HEAD := 0
const BAND_WORKS := 1
const BAND_FLOOR := 2

## Press geometry, borrowed from stage 3 rather than re-chosen: these are the
## two shapes the player has already learned to read.
const PRESS_TILES := 3
const PRESS_ROWS := 2
## A press that comes all the way down: the column is closed and the only answer
## is to be somewhere else.
const CLEARANCE_SEALED := 0.0
## A press that stops a slide's height above the deck, so there is a second
## answer for a player who commits.
const CLEARANCE_SLIDE := 1.5

## Cells of ordinary floor between a belt and a press.
##
## Two. The press's tell buys 3.06 tiles of walking and the widest press is 3,
## so a player standing anywhere in the column gets out -- but only at walking
## speed on still ground. Two cells is the room saying "you are off the belt
## now" before it asks the question. See the class docstring for the arithmetic
## that makes a smaller number unfair rather than merely tight.
const BELT_MARGIN_CELLS := 2

## Belts are the ones from stage 6, with stage 6's names for their directions.
const WITH_YOU := 1
const AGAINST_YOU := -1

## TODO(art): the fortress's own six. Stage 3's skins, which is what greyboxing
## against stage 3's tileset implies.
##
## The six this stage wants: **Cofferdam** (walks the chamber floor),
## **Shackle** (hops the works), **Manifold** (a valve head that fires),
## **Blowout** (compressed air, drifting), **Airlock** (a hatch that releases
## crawlers), and **Gasket** (the crawler).
const SKIN_WALKER := "cutter"
const SKIN_HOPPER := "jack"
const SKIN_TURRET := "rivetgun"
const SKIN_FLYER := "slag"
const SKIN_SPAWNER := "skip"
const SKIN_CRAWLER := "seam"


## One row per room. The key reference is in AuthoredStage's docstring; two
## stage keys, both borrowed rather than new:
##
##   `crushers`  [x, w, h, clearance, phase]        -- stage 3's press
##   `belts`     {"dir", "from", "to"}              -- stage 6's conveyor
const ROOMS := [
	{
		"name": "Airlock", "col": 0, "band": BAND_HEAD,
		# A breath. The player has just come out of Outfall's arena and into a
		# load; the first room of a fortress stage establishes that the controls
		# are still the controls.
		"gaps": [], "blocks": [],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 12.0, 0.0],
			[WALKER, SKIN_WALKER, &"walk", 21.0, 0.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Trunk", "col": 1, "band": BAND_HEAD,
		# **The belt, alone and free.** Nothing to fall into and nothing to be
		# carried into. Every gimmick in the game gets a free first appearance,
		# and a gimmick the player already knows still gets one, because what is
		# being established is that *this stage has it*.
		"gaps": [], "blocks": [[21, 2, 4, 2]],
		"enemies": [
			[HOPPER, SKIN_HOPPER, &"hop", 6.0, 0.0],
		],
		"checkpoint": 2.0,
		"belts": [{"dir": WITH_YOU, "from": 8, "to": 17}],
	},
	{
		"name": "Gate", "col": 2, "band": BAND_HEAD,
		# **The press, alone and free.** No belt, no hole, and the sealed
		# clearance so the answer is the simple one: wait, then walk. The ladder
		# out is at 23, well clear of the column.
		"gaps": [], "blocks": [],
		"enemies": [
			[CRAWLER, SKIN_CRAWLER, &"crawl", 6.0, 0.0],
		],
		"checkpoint": 2.0,
		"crushers": [[12, PRESS_TILES, PRESS_ROWS, CLEARANCE_SEALED, 0]],
		"shaft": [23, 2],
	},
	{
		"name": "Press Row", "col": 2, "band": BAND_WORKS,
		# Arrival in the works, and the backdrop changes with it. Nothing east of
		# 20: the ladder from Gate delivers at 23-24 and building on a landing
		# spawns the player inside terrain.
		#
		# Two presses out of phase and no belt. The pair is the room: one column
		# is always open, so it is a rhythm rather than a wait.
		"gaps": [], "blocks": [],
		"enemies": [
			[TURRET, SKIN_TURRET, &"idle", 4.0, 2.0],
		],
		"checkpoint": 2.0,
		"crushers": [
			[8, PRESS_TILES, PRESS_ROWS, CLEARANCE_SEALED, 0],
			[14, PRESS_TILES, PRESS_ROWS, CLEARANCE_SEALED, 74],
		],
	},
	{
		"name": "Feed", "col": 3, "band": BAND_WORKS,
		# **The lesson.** A belt running with the player, then two cells of plain
		# floor, then a press. The belt sets the time of arrival and the floor is
		# where the decision gets made -- see BELT_MARGIN_CELLS.
		"gaps": [], "blocks": [],
		"enemies": [
			[FLYER, SKIN_FLYER, &"fly", 22.0, 4.0],
		],
		"checkpoint": 2.0,
		"belts": [{"dir": WITH_YOU, "from": 5, "to": 12}],
		"crushers": [[14, PRESS_TILES, PRESS_ROWS, CLEARANCE_SEALED, 0]],
	},
	{
		"name": "Anvil", "col": 4, "band": BAND_WORKS,
		# The same idea with the belt against the player: now the timing is
		# something to be *held*, not something to be arrived at. Standing still
		# on this belt carries you away from the press, which is the safe
		# direction -- the room asks the player to choose to be in danger.
		"gaps": [], "blocks": [[20, 2, 4, 2]],
		"enemies": [
			[HOPPER, SKIN_HOPPER, &"hop", 24.0, 2.0],
		],
		"checkpoint": 2.0,
		"belts": [{"dir": AGAINST_YOU, "from": 4, "to": 11}],
		"crushers": [[13, PRESS_TILES, PRESS_ROWS, CLEARANCE_SLIDE, 30]],
	},
	{
		"name": "Chamber", "col": 5, "band": BAND_WORKS,
		# A breath, and the stage's only room with neither gimmick in it. Stage
		# 4's Foot writes the rule and every stage since has kept it: a room of
		# plain platforming has to come between, or the gimmick stops being an
		# event and becomes the floor.
		"gaps": [[9, 11]], "blocks": [[16, 2, 4, 2]],
		"enemies": [
			[SPAWNER, SKIN_SPAWNER, &"idle", 5.0, 0.0],
			[WALKER, SKIN_WALKER, &"walk", 22.0, 2.0],
		],
		"pit_spikes": [[9, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Relief", "col": 6, "band": BAND_WORKS,
		# No gaps -- the floor band runs under this column -- and the shaft down
		# is the room's exit. One press, sealed, well clear of the ladder.
		"gaps": [], "blocks": [[6, 2, 3, 2]],
		"enemies": [
			[TURRET, SKIN_TURRET, &"idle", 18.0, 2.0],
		],
		"checkpoint": 2.0,
		"crushers": [[11, PRESS_TILES, PRESS_ROWS, CLEARANCE_SLIDE, 0]],
		"shaft": [22, 2],
	},
	{
		"name": "Floor", "col": 6, "band": BAND_FLOOR,
		# The bottom of the caisson. Arrival room: a hole to cross, and neither
		# gimmick, because the player has just changed band and the backdrop
		# with it. Nothing east of 19 -- the ladder lands at 22-23.
		"gaps": [[8, 10]], "blocks": [],
		"enemies": [
			[CRAWLER, SKIN_CRAWLER, &"crawl", 15.0, 0.0],
		],
		"pit_spikes": [[8, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Sluice", "col": 7, "band": BAND_FLOOR,
		# **A belt that ends at a hole.** The belt is running with the player and
		# it stops two cells short of the lip, which is the same margin the
		# presses get and for the same reason: the jump has to be taken from
		# ground that is not moving. Cold Store's Brine Line is the room this is
		# quoting.
		"gaps": [[16, 18]], "blocks": [],
		"enemies": [
			[FLYER, SKIN_FLYER, &"fly", 21.0, 5.0],
		],
		"pit_spikes": [[16, 3, 2]],
		"checkpoint": 2.0,
		"belts": [{"dir": WITH_YOU, "from": 6, "to": 14}],
	},
	{
		"name": "Ram", "col": 8, "band": BAND_FLOOR,
		# **The exam.** Belt, floor, press, floor, press -- the second one out of
		# phase with the first, so the rhythm the belt sets you down in is the
		# wrong one for the second column and has to be broken.
		"gaps": [], "blocks": [],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 25.0, 0.0],
		],
		"checkpoint": 2.0,
		"belts": [{"dir": WITH_YOU, "from": 3, "to": 9}],
		"crushers": [
			[11, PRESS_TILES, PRESS_ROWS, CLEARANCE_SEALED, 0],
			[17, PRESS_TILES, PRESS_ROWS, CLEARANCE_SEALED, 96],
		],
	},
	{
		"name": "Boss Door", "col": 9, "band": BAND_FLOOR,
		# Deliberately empty, as every boss door in the game is. It is worth more
		# here than anywhere else: what it promises is a Robot Master.
		"gaps": [], "blocks": [],
		"enemies": [],
		"checkpoint": 2.0,
	},
	{
		"name": "Arena", "col": 10, "band": BAND_FLOOR,
		# Flat, empty, no checkpoint. The duel.
		"gaps": [], "blocks": [],
		"enemies": [],
		"checkpoint": NO_CHECKPOINT,
	},
]


func fortress_index() -> int:
	return 1


func room_table() -> Array:
	return ROOMS


func stage_tile_set() -> TileSet:
	return TILESET


func backdrop_script() -> GDScript:
	return BACKGROUND


func boss_script() -> GDScript:
	return RIVAL


func boss_frames_path() -> String:
	return BOSS_FRAMES_PATH


func boss_name() -> String:
	return "Ward"


## Ward configures himself -- he is not a reprise of anything, so there is
## nothing for the stage to override. Stated rather than left to the base class
## so that the difference from Outfall is visible in the file.
func configure_boss(_boss: Boss) -> void:
	pass


## The two machines. Both borrowed literally from the stages that taught them:
## a fortress that re-authored the gimmicks it is examining would be examining
## something else.
func place_stage_elements(spec: Dictionary, _index: int, origin: int, deck: int,
		tile: float) -> void:
	# On the deck's **surface**, not its tile row: a belt is the top of the floor
	# and the player stands on it, and the two are half a tile apart on a corner
	# tileset -- the alignment bug that made every kit element float at M6j.
	var surface := float(deck) + deck_surface_offset()
	for entry in spec.get("belts", []) as Array:
		var from := int(entry["from"])
		var to := int(entry["to"])
		var belt := BELT.new() as ConveyorBelt
		belt.name = "Belt_%d_%d" % [origin + from, deck]
		belt.direction = int(entry.get("dir", WITH_YOU))
		belt.speed_pf = float(entry.get("speed", ConveyorBelt.DEFAULT_SPEED_PF))
		belt.width_tiles = float(to - from)
		belt.position = Vector2(float(origin + from), surface) * tile
		add_child(belt)

	for entry in spec.get("crushers", []) as Array:
		var press := CRUSHER.new() as CrusherPress
		press.name = "Crusher_%d_%d" % [origin + int(entry[0]), deck]
		press.size_tiles = Vector2(float(entry[1]), float(entry[2]))
		press.drop_tiles = press_drop_rows(float(entry[2]), float(entry[3]))
		press.phase_frames = int(entry[4])
		press.track_extra_tiles = float(entry[3])
		# Hung from the room's ceiling, which is where a press in a chamber is.
		press.position = Vector2(float(origin + int(entry[0])),
			float(deck - ceiling_to_deck_rows())) * tile
		add_child(press)


## Every belt and every press in the stage, in placement order. For
## `tests/test_caisson.gd`, which checks the built nodes rather than only the
## table -- the M6i shaft bug was a table that was right and a translation that
## was not.
func belts() -> Array[ConveyorBelt]:
	var out: Array[ConveyorBelt] = []
	for child in get_children():
		if child is ConveyorBelt:
			out.append(child as ConveyorBelt)
	return out


func presses() -> Array[CrusherPress]:
	var out: Array[CrusherPress] = []
	for child in get_children():
		if child is CrusherPress:
			out.append(child as CrusherPress)
	return out
