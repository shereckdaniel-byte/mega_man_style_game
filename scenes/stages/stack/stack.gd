## Stage 6, "Stack" -- the waste incinerator, and Cinder's stage.
##
## Nineteen rooms that only ever go **down**. Stage 1 is a W, stage 2 a long J,
## stage 3 a staircase that only climbs, stage 4 fourteen flat rooms and one
## turn, stage 5 a V. This one is stage 3 read backwards: three bands, six or
## seven rooms each, and every band change is a drop. **It is the only stage in
## the game that ends lower than it starts**, and that is the shape an
## incinerator wants -- you are not exploring it, you are being fed into it.
##
##   col   0     1     2      3     4      5     6     7    8     9    10    11    12   13   14   15   16
##  band 0 TipFac-Charge-Sorter-Chute-Grate-TipHead
##                                            |
##  band 1                                   HallFlr-Opposed-Feed-Return-Clinker-Rake-HallHead
##                                                                                       |
##  band 2                                                                             FlueFlr-Burner-AshPit-Damper-Gate-Arena
##
## ### The gimmick: conveyors
##
## `ConveyorBelt` carries the grammar and the three fairness rules. What belongs
## here is the order the rooms teach it in, and the single sentence the whole
## stage is built on:
##
## **The wind was a cycle you time. The belt is a constant you fight.**
##
## Stage 5 asks "when do I move"; every answer is some form of waiting for the
## lull. A second cyclic horizontal force would have made stage 6 into stage 5
## in hotter tiles, so a belt never stops, never reverses and never warns. It
## asks "where do I stand", and every room here is a spatial answer:
##
##   * **Charge Floor** -- a belt running with the player over solid deck, with
##     nothing to fall into. It is free, and what it teaches is that the floor
##     moves you at all. The house pattern since stage 2's Riser.
##   * **Sorter** -- the same belt reversed. The drag, still free. The pair is
##     the lesson, exactly as Slipstream and Backdraft are on stage 5.
##   * **Chute** -- the first paid one, and the belt's signature: a belt running
##     *at* a hole. Standing still feeds you into it and walking off is enough,
##     which is fairness rule 1 arriving as an experience rather than a number.
##   * **Opposed** -- two belts meeting head-on. The seam between them is the
##     only still floor in the room, and it is one tile wide.
##   * **Feed** and **Return** -- the same slide tunnel with the belt under it
##     running each way. A slide covers a fixed distance; a slide on a belt does
##     not, and the room is the only place in the game where a move the player
##     has fully learned measures differently.
##   * **Rake** -- a belt with spikes at its downstream end. Idling is the
##     mistake and there is no timing to it, only a decision to keep walking.
##
## Seven rooms carry no belt at all -- Tip Face, Grate, Hall Floor, Clinker,
## Flue Floor, Gate and Arena -- for the reason stage 4 writes on Foot: a stage
## whose every room is the gimmick has no gimmick, only a floor.
##
## ### What a belt structurally cannot do, and why that matters here
##
## Stage 5's expensive lesson was that a ground force which reaches a jump can
## make authored gaps uncrossable -- a full-gust headwind cut a two-cell crossing
## below the reach it needs, and no retuning could have fixed it. A belt cannot
## do that to anything: it applies **only while the player is on the floor**
## (`Player._apply_carry`), so it changes a run-up and never an arc. That is why
## this stage is allowed to put belts next to holes at all, and why Turbine Row
## is not.
##
## ### Two things this stage deliberately does not contain
##
## **No wind.** Obviously, but worth writing down: the two would be
## indistinguishable to a player being moved sideways by something they cannot
## see, and the belt's whole claim is that it is a fact about a piece of floor.
##
## **No crushers.** Stage 3 owns the cycle that closes a column, and a stage
## whose gimmick is deliberately acyclic should not also contain the game's most
## cyclic object.
extends AuthoredStage

const BACKGROUND := preload("res://scenes/stages/stack/parallax_background.gd")
## TODO(art): swap to res://resources/tilesets/stack.tres once generated.
## Greyboxed against stage 3's tiles so the layout can be driven by the bot
## before any generation is paid for -- PLAN.md's rule, layout first and art
## second. Stages 4 and 5 were built the same way.
const TILESET := preload("res://resources/tilesets/breakers.tres")
const CINDER := preload("res://scenes/actors/bosses/cinder.gd")
const BELT := preload("res://scenes/level/conveyor_belt.gd")
## Cinder's art. By path rather than preloaded so the stage still opens if the
## sprite frames are mid-regeneration.
const BOSS_FRAMES_PATH := "res://resources/sprite_frames/cinder.tres"

const WALKER := preload("res://scenes/actors/enemies/walker.gd")
const HOPPER := preload("res://scenes/actors/enemies/hopper.gd")
const TURRET := preload("res://scenes/actors/enemies/turret.gd")
const FLYER := preload("res://scenes/actors/enemies/flyer.gd")
const SPAWNER := preload("res://scenes/actors/enemies/spawner.gd")
const CRAWLER := preload("res://scenes/actors/enemies/wall_crawler.gd")

## The three bands, top to bottom. The stage only ever moves down through them.
const BAND_TIP := 0
const BAND_GALLERY := 1
const BAND_HALL := 2

## The plant's six, one per archetype.
##
## **TODO(art): these are stage 4's skins, not stage 6's.** The behaviour is the
## archetype and the art is the theme (docs/PLAN.md section 4), and
## `tests/test_stage_authoring.gd` requires every named enemy to have art on
## disk -- so a stage cannot be greyboxed with names that do not exist yet.
## Borrowing a shipped set is the only honest way to author rooms first.
##
## The six this stage wants: **Stoker** (the ram that feeds the grate),
## **Clinker** (a fused lump of ash that hops the tip), **Pilot** (the ignition
## nozzle, which pivots and fires), **Fly Ash** (airborne grit riding the
## draught), **Hopper** (the charge bin that drops small burners), and **Scale**
## (the crawler that walks a firebox wall).
const SKIN_WALKER := "tracker"
const SKIN_HOPPER := "ballast"
const SKIN_TURRET := "fresnel"
const SKIN_FLYER := "glint"
const SKIN_SPAWNER := "rack"
const SKIN_CRAWLER := "wiper"

## Which way a belt runs. Named because `-1` in a table is a direction nobody
## can read, and half the stage turns on which one it is.
const WITH_YOU := 1
const AGAINST_YOU := -1


## One row per room, in the order the player meets them. The key reference is in
## AuthoredStage's docstring; `belts` is this stage's own:
##
##   {"dir": WITH_YOU|AGAINST_YOU, "from": cell, "to": cell}
##
## `from`/`to` bound the run in cells. There is no phase and no period, and that
## absence is the design -- see the docstring. A room may choose where a belt is
## and which way it runs, and nothing else.
const ROOMS := [
	{
		"name": "Tip Face", "col": 0, "band": BAND_TIP,
		# The room with nothing in it that can kill you, which every stage owes
		# the player first -- and no belt, so the first thing taught is the
		# stage's own controls on still ground.
		"gaps": [[18, 20]], "blocks": [],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 12.0, 0.0],
			[WALKER, SKIN_WALKER, &"walk", 23.0, 0.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Charge Floor", "col": 1, "band": BAND_TIP,
		# **The belt, taught alone and taught free.** A long run with the player,
		# over solid deck, with nothing to fall into. Walk onto it and arrive
		# somewhere sooner than you meant to; that is the entire lesson and it
		# costs nothing to get wrong.
		"gaps": [], "blocks": [[20, 2, 4, 2]],
		"enemies": [
			[HOPPER, SKIN_HOPPER, &"hop", 6.0, 0.0],
		],
		"checkpoint": 2.0,
		"belts": [{"dir": WITH_YOU, "from": 8, "to": 17}],
	},
	{
		"name": "Sorter", "col": 2, "band": BAND_TIP,
		# The same belt reversed, and still free. The pair is the lesson -- the
		# same argument Slipstream and Backdraft make on stage 5 -- and it is
		# where the player finds out that walking upstream works and is slow.
		"gaps": [], "blocks": [],
		"enemies": [
			[TURRET, SKIN_TURRET, &"idle", 24.0, 2.0],
		],
		"checkpoint": 2.0,
		"belts": [{"dir": AGAINST_YOU, "from": 7, "to": 18}],
	},
	{
		"name": "Chute", "col": 3, "band": BAND_TIP,
		# **The belt's signature, and the first one that charges.** A run that
		# ends at a hole: the floor is taking you somewhere and walking is enough
		# to refuse. Fairness rule 1 arriving as an experience rather than a
		# constant.
		#
		# The belt stops one cell short of the lip. It could run to the edge and
		# the arithmetic would still be fair, but a belt that ends exactly at a
		# hole gives a player who has just stepped on nowhere to stand while
		# they work out what is happening.
		"gaps": [[16, 18]], "blocks": [],
		"enemies": [
			[FLYER, SKIN_FLYER, &"fly", 23.0, 4.0],
		],
		"pit_spikes": [[16, 3, 2]],
		"checkpoint": 2.0,
		"belts": [{"dir": WITH_YOU, "from": 8, "to": 15}],
	},
	{
		"name": "Grate", "col": 4, "band": BAND_TIP,
		# No belt. Two gimmick rooms have just run back to back and the stage's
		# own rule -- stage 4 writes it on Foot -- is that a room of plain
		# platforming has to come between, or the belts stop being an event and
		# become the floor.
		"gaps": [[7, 9], [17, 19]], "blocks": [[22, 2, 4, 2]],
		"enemies": [
			[CRAWLER, SKIN_CRAWLER, &"crawl", 13.0, 0.0],
			[TURRET, SKIN_TURRET, &"idle", 25.0, 2.0],
		],
		"pit_spikes": [[7, 3, 2], [17, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Tip Head", "col": 5, "band": BAND_TIP,
		# The end of the tip floor and the way down. **No gaps**: the gallery is
		# under this column, and a hole here would open into the room below.
		#
		# The belt stops well short of the shaft. A player being carried while
		# they reach for a ladder is a player who misses it -- the same rule
		# Turbine Row's Pier Head and Tower Foot are built on, and there is no
		# version of that which reads as anything but a bug.
		"gaps": [], "blocks": [[7, 2, 3, 2]],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 14.0, 0.0],
		],
		"checkpoint": 2.0,
		"belts": [{"dir": WITH_YOU, "from": 11, "to": 18}],
		"shaft": [22, 2],
	},
	{
		"name": "Hall Floor", "col": 5, "band": BAND_GALLERY,
		# Arrival, and still floor. The player has just changed bands and the
		# backdrop has changed with them; a room that also moved the ground
		# would be a room they read none of. The same call Turbine Row's Pontoon
		# makes, and it was made there because the stage's own breath rule caught
		# a fourth gimmick room in a row.
		"gaps": [[16, 18]], "blocks": [],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 8.0, 0.0],
			[FLYER, SKIN_FLYER, &"fly", 22.0, 5.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Opposed", "col": 6, "band": BAND_GALLERY,
		# **Two belts meeting head-on.** The seam between them is the only still
		# floor in the room and it is two cells wide; step either side of it and
		# you are returned to it.
		#
		# It is the first room where a belt is a *place* rather than a push, and
		# it is worth having because it is the one arrangement a cyclic force
		# could never produce -- two winds cancelling would only cancel for part
		# of the cycle.
		"gaps": [], "blocks": [[2, 2, 3, 2], [23, 2, 3, 2]],
		"enemies": [
			[HOPPER, SKIN_HOPPER, &"hop", 18.0, 0.0],
			[TURRET, SKIN_TURRET, &"idle", 8.0, 2.0],
		],
		"checkpoint": 2.0,
		"belts": [
			{"dir": WITH_YOU, "from": 7, "to": 13},
			{"dir": AGAINST_YOU, "from": 15, "to": 21},
		],
	},
	{
		"name": "Feed", "col": 7, "band": BAND_GALLERY,
		# **A slide tunnel with a belt under it, running with the player.** A
		# slide covers 4.06 tiles from where it starts, and every player who has
		# reached stage 6 knows that in their hands rather than as a number.
		# On a belt it does not, and this is the only place in the game where a
		# fully learned move measures differently.
		#
		# With the belt, so the slide overshoots. That is the safe half of the
		# pair and it comes first.
		"gaps": [[6, 8]], "blocks": [[21, 2, 4, 2]],
		"ceilings": [[13, SLIDE_CLEARANCE, 3, 4]],
		"enemies": [
			[CRAWLER, SKIN_CRAWLER, &"crawl", 19.0, 0.0],
		],
		"pit_spikes": [[6, 3, 2]],
		"checkpoint": 2.0,
		"belts": [{"dir": WITH_YOU, "from": 11, "to": 18}],
	},
	{
		"name": "Return", "col": 8, "band": BAND_GALLERY,
		# The same tunnel with the belt reversed, so the slide falls short. Same
		# geometry, one number different -- a second difference would make the
		# comparison say nothing, which is the rule Slipstream and Backdraft are
		# held to by `tests/test_turbine_row.gd`.
		"gaps": [[6, 8]], "blocks": [[21, 2, 4, 2]],
		"ceilings": [[13, SLIDE_CLEARANCE, 3, 4]],
		"enemies": [
			[FLYER, SKIN_FLYER, &"fly", 20.0, 4.0],
		],
		"pit_spikes": [[6, 3, 2]],
		"checkpoint": 2.0,
		"belts": [{"dir": AGAINST_YOU, "from": 11, "to": 18}],
	},
	{
		"name": "Clinker", "col": 9, "band": BAND_GALLERY,
		# No belt: the stage's second breath, placed where stage 5 puts Bilge --
		# after the pair, before the exam.
		#
		# The wide gap is on a moving platform, and the gap starts **six cells
		# in**, which is where all four shipped mover rooms put theirs. That is
		# not a habit: a mover's cycle is measured from when the room is built,
		# so where the gap sits decides what phase the player meets it at, and
		# stage 5's Kite was a room with no solution until it was moved.
		"gaps": [[6, 14]], "blocks": [],
		"movers": [[6, 0, 8.0, 0.0, 150]],
		"enemies": [
			[TURRET, SKIN_TURRET, &"idle", 24.0, 2.0],
		],
		"pit_spikes": [[6, 3, 8]],
		"checkpoint": 2.0,
	},
	{
		"name": "Rake", "col": 10, "band": BAND_GALLERY,
		# **A climb against the belt.** The rake floor rises in two steps and the
		# belt runs back down it, so gaining height is work rather than a jump:
		# every landing gives some of itself away before the next take-off.
		#
		# It is the only room in the stage where the belt costs *progress*
		# instead of position, and it is the one place the constant is felt as
		# attrition -- which is the closest a thing with no cycle can get to
		# being a rhythm.
		#
		# **It was a bed of floor spikes at the end of the belt, and that was
		# two mistakes.** Four cells wide is past what a jump covers, so the room
		# was a wall -- the bot walked into the teeth five times a run and never
		# got past, and it was the game's first floor-spike bed so no authoring
		# rule objected (there is one now). Narrowed to two, it was still a wall,
		# for a reason worth writing down: the bot's spike lookahead starts a
		# jump 2.2 tiles out, which lands it *inside* a two-cell bed. Retuning
		# that constant would have touched five shipped stages to rescue the
		# weakest idea in this one, so the idea went instead.
		#
		# No hazard at all here, deliberately. The stage already asks for a belt
		# at a hole twice (Chute, Ash Pit); a third would be repetition, and this
		# room is better as the one where the belt is simply hard work.
		# **The two steps touch, and they both sit on the deck.** Drafted with a
		# two-cell trench between a slab and a wall, which is a staircase in the
		# table and a four-tile wall in the room: the low road is closed by the
		# second block and the high road needs a slab-to-slab jump the bot never
		# found. Twenty seconds in the room, no deaths, no progress.
		#
		# `test_no_step_is_taller_than_the_jump` passed it, because it reads the
		# *set* of heights a room uses rather than whether you can get from one
		# to the next. A general rule for that was written and thrown away: it
		# failed four shipped rooms -- Dawn Boardwalk's Low Water and Tide,
		# Substation's Tie Line, Mirror Field's Crust -- which are 2/4/6
		# staircases of floating slabs three cells apart that the bot climbs
		# every run. A rule that condemns working rooms is a wrong rule, and the
		# real distinction (a slab you can walk under versus a wall you cannot)
		# is not one this table can see. So this is a comment and not a test.
		"gaps": [], "blocks": [[10, 2, 4, 2], [14, 4, 4, 4]],
		"enemies": [
			[HOPPER, SKIN_HOPPER, &"hop", 6.0, 0.0],
			[CRAWLER, SKIN_CRAWLER, &"crawl", 25.0, 0.0],
		],
		"checkpoint": 2.0,
		"belts": [{"dir": AGAINST_YOU, "from": 4, "to": 10}],
	},
	{
		"name": "Hall Head", "col": 11, "band": BAND_GALLERY,
		# The second drop. **No gaps** -- the hall is under this column -- and
		# still floor around the shaft, for the reason Tip Head gives.
		"gaps": [], "blocks": [[6, 2, 4, 2]],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 15.0, 0.0],
			[SPAWNER, SKIN_SPAWNER, &"idle", 3.0, 3.0],
		],
		"checkpoint": 2.0,
		"belts": [{"dir": AGAINST_YOU, "from": 12, "to": 18}],
		"shaft": [22, 2],
	},
	{
		"name": "Flue Floor", "col": 11, "band": BAND_HALL,
		# Arrival in the furnace hall. Still floor again, same argument as Hall
		# Floor: a band change is already a thing to read.
		"gaps": [[17, 19]], "blocks": [],
		"enemies": [
			[FLYER, SKIN_FLYER, &"fly", 9.0, 5.0],
			[CRAWLER, SKIN_CRAWLER, &"crawl", 24.0, 0.0],
		],
		"pit_spikes": [[17, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Burner", "col": 12, "band": BAND_HALL,
		# A belt against the player with the room's fighting in it. The drag is
		# the whole difficulty: every shot is taken while losing ground, which is
		# a thing no other stage's gimmick does to a fight.
		"gaps": [], "blocks": [[8, 2, 4, 2]],
		"enemies": [
			[TURRET, SKIN_TURRET, &"idle", 20.0, 2.0],
			[HOPPER, SKIN_HOPPER, &"hop", 14.0, 0.0],
		],
		"checkpoint": 2.0,
		"belts": [{"dir": AGAINST_YOU, "from": 13, "to": 24}],
	},
	{
		"name": "Ash Pit", "col": 13, "band": BAND_HALL,
		# **The exam.** A belt running at a hole, as Chute was, with the run
		# doubled and a second hole past the first -- so the answer that worked
		# in Chute (step off and walk) has to be made twice with a landing in
		# between.
		"gaps": [[10, 12], [20, 22]], "blocks": [],
		"enemies": [
			[FLYER, SKIN_FLYER, &"fly", 5.0, 4.0],
		],
		"pit_spikes": [[10, 3, 2], [20, 3, 2]],
		"checkpoint": 2.0,
		"belts": [{"dir": WITH_YOU, "from": 3, "to": 9}],
	},
	{
		"name": "Damper", "col": 14, "band": BAND_HALL,
		# The last room with anything in it, and no new ideas: the room before
		# the run-up should be the stage's vocabulary spoken once more.
		"gaps": [], "blocks": [[6, 2, 4, 2], [16, 2, 3, 2]],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 12.0, 0.0],
			[CRAWLER, SKIN_CRAWLER, &"crawl", 25.0, 0.0],
		],
		"checkpoint": 2.0,
		"belts": [{"dir": AGAINST_YOU, "from": 20, "to": 25}],
	},
	{
		"name": "Gate", "col": 15, "band": BAND_HALL,
		# Deliberately empty. The run-up to a boss is a breath, and
		# `tests/test_stage_authoring.gd` holds every stage to it.
		"gaps": [], "blocks": [],
		"enemies": [],
		"checkpoint": 2.0,
	},
	{
		"name": "Arena", "col": 16, "band": BAND_HALL,
		# Flat, empty and no checkpoint. **No belt either**, for the reason
		# Breakers keeps the press out of Rust's arena and Turbine Row keeps the
		# wind out of Gale's: Cinder's Flue already writes the player's carry
		# every frame, and a room belt writing it as well would be two
		# authorities on one number and a pull the player cannot attribute.
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
	return CINDER


func boss_frames_path() -> String:
	return BOSS_FRAMES_PATH


func boss_name() -> String:
	return "Cinder"


## The belts. This stage's own key, placed here for the same reason stage 1's
## tide, stage 3's presses, stage 4's panels and stage 5's wind are: the shared
## kit should not grow a slot for every stage's one idea.
##
## **A belt is told where it is and which way it runs, and nothing about time.**
## There is no period to author because there is no cycle -- which is the whole
## difference between this stage and the last one.
func place_stage_elements(spec: Dictionary, _index: int, origin: int, deck: int,
		tile: float) -> void:
	# On the deck's **surface**, not its tile row. A belt is the top of the floor
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


## Every belt in the stage, in placement order. For the playtest tools and for
## `tests/test_stack.gd`, which checks the built nodes rather than only the
## table -- the shaft bug at M6i was a table that was right and a translation
## that was not.
func belts() -> Array[ConveyorBelt]:
	var out: Array[ConveyorBelt] = []
	for child in get_children():
		if child is ConveyorBelt:
			out.append(child as ConveyorBelt)
	return out
