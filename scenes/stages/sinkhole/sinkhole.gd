## Stage 8, "Sinkhole" -- the flooded mine, and Quarry's stage. The last one.
##
## Nineteen rooms with a **false bottom**. Stage 1 is a W, stage 2 a long J,
## stage 3 a staircase that only climbs, stage 4 fourteen flat rooms and one
## turn, stage 5 a V, stage 6 a descent, stage 7 a zigzag between two decks.
## This one descends, **climbs back out once**, and then goes deeper than
## before -- the only stage that returns to a band it has already left and then
## leaves it again. You reach what looks like the bottom, find it is a shelf,
## and have to go up to get down.
##
##   col   0     1     2     3      4     5     6     7    8     9    10    11    12    13   14
##  band 0 Colla-Seep--Ciste-HeadRise
##                            |
##  band 1                   Galler-DryDr-Flood-SumpHead      BackG-Fault-SecHead
##                                              |               ^          |
##  band 2                                     SumpFl-Deep-FalseBot      LowerS-Drown-BoreH-Gate-Arena
##
## ### The gimmick: water, and it is the only one that helps
##
## Stage 5's wind is a cycle you time, stage 6's belt a constant you fight,
## stage 7's ice a floor that will not stop you. All three take something away.
## Water gives: gravity is weaker in it, so the same jump goes higher and the
## fall is slower, and **every crossing in a flooded room is easier than the
## same crossing dry.**
##
## That is not the last stage going soft. It is what makes its rooms authorable:
## a gimmick that only ever helps lets the level put geometry in front of the
## player that would be unreasonable on land, so the difficulty comes from the
## shape of the room rather than from a force fighting the controls.
##
## **The dry rooms are the hard ones**, and that inversion is the whole stage:
##
##   * **Seep** -- a shallow pool over solid deck. Free, as every gimmick's
##     first appearance has been since stage 2's Riser, and what it teaches is
##     that the jump changes.
##   * **Cistern** -- water over a hole that is wider than a dry jump covers.
##     The pool *is* the crossing, which is the first time in eight stages that
##     the gimmick is the route rather than the toll.
##   * **Dry Drift** and **Flooded Drift** -- the same room twice, drained and
##     filled. The pair is the lesson, exactly as Slipstream and Backdraft are
##     on stage 5 and Feed and Return on stage 6, and it is the only pair in the
##     game where the wet one is the easy one.
##   * **Deep** -- a pool with something worth reaching at the top of it, so the
##     extra apex is a reward rather than a convenience.
##   * **Drown Line** -- the exam: wet and dry alternating, so every jump has to
##     be aimed twice.
##
## ### Two rules, and why there are only two
##
## The other three gimmicks each needed three fairness rules. Water needs two,
## because the direction of the effect removes the rest:
##
##   1. **It can only make a jump longer.** `buoyancy` scales gravity down and
##      never up and leaves jump velocity alone, so no authored gap is harder
##      wet than dry. Stage 5's wind could shorten an arc and made two-cell gaps
##      uncrossable; water structurally cannot, which is why there is no stop
##      margin or seam rule here.
##   2. **Nothing lethal hangs over water.** This is the one that bites. A
##      higher jump reaches ceilings the player has spent seven stages learning
##      they cannot reach, so teeth that were safely out of range on land are
##      not out of range here. `tests/test_sinkhole.gd` computes the submerged
##      apex from `PlayerTuning` and `WaterVolume.DEFAULT_BUOYANCY` and checks
##      every pool against every ceiling spike in its room.
##
## ### What this stage deliberately does not contain
##
## **None of the other three gimmicks.** Wind, belts and ice all act
## horizontally and water acts vertically, so mixing them would not even be
## confusing -- it would just be two stages at once. The last stage should be
## its own idea played out, not a medley.
extends AuthoredStage

const BACKGROUND := preload("res://scenes/stages/sinkhole/parallax_background.gd")
## Its own terrain: wet drill-scarred rock, ore seams, water beading on the faces.
##
## Generated at M8e from the description in this stage's own docstring,
## once `backblaze.pixellab.ai` was opened. Greyboxed against stage 3's
## tiles until then -- layout first, art second, which is PLAN.md's rule
## and the reason a two-milestone wait for a host cost this stage nothing.
const TILESET := preload("res://resources/tilesets/sinkhole.tres")
const QUARRY := preload("res://scenes/actors/bosses/quarry.gd")
const WATER := preload("res://scenes/level/water_volume.gd")
const BOSS_FRAMES_PATH := "res://resources/sprite_frames/quarry.tres"

const WALKER := preload("res://scenes/actors/enemies/walker.gd")
const HOPPER := preload("res://scenes/actors/enemies/hopper.gd")
const TURRET := preload("res://scenes/actors/enemies/turret.gd")
const FLYER := preload("res://scenes/actors/enemies/flyer.gd")
const SPAWNER := preload("res://scenes/actors/enemies/spawner.gd")
const CRAWLER := preload("res://scenes/actors/enemies/wall_crawler.gd")

## The collapsed surface, the gallery under it, and the flooded sump.
const BAND_SURFACE := 0
const BAND_GALLERY := 1
const BAND_SUMP := 2

## The mine's six, one per archetype.
##
## **TODO(art): these are stage 4's skins, not stage 8's.** The behaviour is the
## archetype and the art is the theme (docs/PLAN.md section 4), and
## `tests/test_stage_authoring.gd` requires every named enemy to have art on
## disk, so a stage cannot be greyboxed with names that do not exist yet.
##
## The six this stage wants: **Hauler** (the ore car that runs the drift),
## **Prop** (a pit prop that hops the spoil), **Blower** (a ventilation head
## that pivots and fires), **Damp** (gas riding the water), **Adit** (a mouth in
## the wall that releases crawlers), and **Seep** (the crawler that walks a
## wet face).
const SKIN_WALKER := "tracker"
const SKIN_HOPPER := "ballast"
const SKIN_TURRET := "fresnel"
const SKIN_FLYER := "glint"
const SKIN_SPAWNER := "rack"
const SKIN_CRAWLER := "wiper"


## One row per room, in the order the player meets them. The key reference is in
## AuthoredStage's docstring; `water` is this stage's own:
##
##   {"from": cell, "to": cell, "surface": rows_above_deck, "depth": tiles}
##
## `surface` is where the waterline sits above the room's deck and `depth` how
## far down it reaches; both default to a pool that fills the deck. There is no
## direction, no period and no strength, because water has none of those --
## which is what makes it a fourth idea rather than a fourth force.
const ROOMS := [
	{
		"name": "Collapse", "col": 0, "band": BAND_SURFACE,
		# The room with nothing in it that can kill you, and no water: the last
		# stage still owes the player one room of plain walking.
		"gaps": [[18, 20]], "blocks": [],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 12.0, 0.0],
			[WALKER, SKIN_WALKER, &"walk", 23.0, 0.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Seep", "col": 1, "band": BAND_SURFACE,
		# **Water, taught alone and taught free.** A shallow pool over solid
		# deck: jump inside it, notice you went twice as high, and land safely
		# because there is nothing to land in.
		"gaps": [], "blocks": [[21, 2, 4, 2]],
		"enemies": [
			[HOPPER, SKIN_HOPPER, &"hop", 6.0, 0.0],
		],
		"checkpoint": 2.0,
		"water": [{"from": 8, "to": 17, "surface": 3, "depth": 3.0}],
	},
	{
		"name": "Cistern", "col": 2, "band": BAND_SURFACE,
		# **Water as a route rather than a toll**, which is the first time in
		# eight stages that a gimmick is the thing carrying the player forward.
		#
		# The four-cell hole still has a platform over it, and it has to: the
		# grammar requires one for any gap past `MAX_GAP_TILES` and that rule is
		# right regardless of what is standing in the hole -- a player who
		# arrives without knowing water is here would find a room with no
		# crossing. What the pool does is make the platform optional rather than
		# obligatory: submerged, the gap is inside a single jump.
		#
		# That is the honest version of the idea, and it is better than the one
		# it replaces. "The water is the only way across" would have been a room
		# that reads as broken until the player works out the trick.
		"gaps": [[12, 16]], "blocks": [],
		"movers": [[12, 0, 4.0, 0.0, 130]],
		"enemies": [
			[FLYER, SKIN_FLYER, &"fly", 23.0, 4.0],
		],
		"checkpoint": 2.0,
		"water": [{"from": 11, "to": 17, "surface": 4, "depth": 6.0}],
	},
	{
		"name": "Head Rise", "col": 3, "band": BAND_SURFACE,
		# **No gaps** -- the gallery is under this column -- and dry ground round
		# the ladder. A player whose jump is three times its usual height while
		# reaching for a rung is a player who overshoots it, which is the same
		# rule Turbine Row's Pier Head and Stack's Tip Head are built on, wearing
		# the opposite sign.
		"gaps": [], "blocks": [[7, 2, 3, 2]],
		"enemies": [
			[TURRET, SKIN_TURRET, &"idle", 14.0, 2.0],
		],
		"checkpoint": 2.0,
		"shaft": [22, 2],
	},
	{
		"name": "Gallery Floor", "col": 3, "band": BAND_GALLERY,
		# Arrival, and dry. The player has just changed bands and the backdrop
		# has gone dark with them; a room that also changed their jump would be
		# a room they read none of.
		"gaps": [[16, 18]], "blocks": [],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 8.0, 0.0],
			[CRAWLER, SKIN_CRAWLER, &"crawl", 24.0, 0.0],
		],
		"pit_spikes": [[16, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Dry Drift", "col": 4, "band": BAND_GALLERY,
		# **The hard half of the pair, and it is the dry one.** Two holes and a
		# slide tunnel at ordinary gravity -- the stage's vocabulary with none of
		# its help.
		"gaps": [[7, 9], [18, 20]], "blocks": [],
		"ceilings": [[12, SLIDE_CLEARANCE, 3, 4]],
		"enemies": [
			[HOPPER, SKIN_HOPPER, &"hop", 23.0, 0.0],
		],
		"pit_spikes": [[7, 3, 2], [18, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Flooded Drift", "col": 5, "band": BAND_GALLERY,
		# The same room filled. Same holes, same tunnel, one difference -- a
		# second would make the comparison say nothing, which is the rule stage
		# 5's Slipstream pair and stage 6's slide pair are held to.
		#
		# **No teeth on the tunnel here.** Rule 2: a submerged jump reaches
		# ceilings the player has spent seven stages learning they cannot, so
		# anything lethal overhead is a trap they were taught to ignore.
		"gaps": [[7, 9], [18, 20]], "blocks": [],
		"ceilings": [[12, SLIDE_CLEARANCE, 3, 4]],
		"enemies": [
			[FLYER, SKIN_FLYER, &"fly", 23.0, 5.0],
		],
		"pit_spikes": [[7, 3, 2], [18, 3, 2]],
		"checkpoint": 2.0,
		"water": [{"from": 4, "to": 11, "surface": 4, "depth": 5.0}],
	},
	{
		"name": "Sump Head", "col": 6, "band": BAND_GALLERY,
		# **No gaps** -- the sump is under this column -- and dry round the
		# ladder.
		"gaps": [], "blocks": [[6, 2, 4, 2]],
		"enemies": [
			[TURRET, SKIN_TURRET, &"idle", 13.0, 2.0],
			[WALKER, SKIN_WALKER, &"walk", 17.0, 0.0],
		],
		"checkpoint": 2.0,
		"shaft": [22, 2],
	},
	{
		"name": "Sump Floor", "col": 6, "band": BAND_SUMP,
		# Arrival at what looks like the bottom. Dry, and quiet.
		"gaps": [[15, 17]], "blocks": [],
		"enemies": [
			[FLYER, SKIN_FLYER, &"fly", 9.0, 4.0],
			[CRAWLER, SKIN_CRAWLER, &"crawl", 25.0, 0.0],
		],
		"pit_spikes": [[15, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Deep", "col": 7, "band": BAND_SUMP,
		# **A pool with something worth reaching over it.** The block sits four
		# rows up, which is past a dry jump and comfortable in water, so the
		# extra apex is a reward rather than a convenience.
		"gaps": [], "blocks": [[13, 4, 5, 4], [8, 2, 5, 2]],
		"enemies": [
			[HOPPER, SKIN_HOPPER, &"hop", 4.0, 0.0],
			[SPAWNER, SKIN_SPAWNER, &"idle", 24.0, 3.0],
		],
		"checkpoint": 2.0,
		"water": [{"from": 6, "to": 20, "surface": 5, "depth": 6.0}],
	},
	{
		"name": "False Bottom", "col": 8, "band": BAND_SUMP,
		# **The stage's turn, and its name.** This is the deepest the player has
		# been and there is no way on from it -- the route goes back up, and only
		# then deeper. The only room in the game that asks the player to undo a
		# descent.
		"gaps": [], "blocks": [[6, 2, 4, 2]],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 14.0, 0.0],
		],
		"checkpoint": 2.0,
		"shaft_up": [23, 2],
	},
	{
		"name": "Back Gallery", "col": 8, "band": BAND_GALLERY,
		# **No gaps** -- the sump is under this column -- and nothing at all in
		# cells 23-27, which is where False Bottom's ladder delivers. Building on
		# a landing spawns the player inside terrain and Godot shoves them out
		# sideways; on stage 4 that shove walked them into the next room's door
		# and spent it.
		"gaps": [], "blocks": [[4, 2, 4, 2]],
		"enemies": [
			[CRAWLER, SKIN_CRAWLER, &"crawl", 12.0, 0.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Fault", "col": 9, "band": BAND_GALLERY,
		# Dry, and the stage's breath before the last descent. The wide gap is on
		# a moving platform and starts **six cells in**, which is where all six
		# shipped mover rooms put theirs: a mover's cycle runs from when the room
		# is built, so where the gap sits decides what phase the player meets it
		# at, and stage 5's Kite was a room with no solution until it moved.
		"gaps": [[6, 14]], "blocks": [],
		"movers": [[6, 0, 8.0, 0.0, 150]],
		"enemies": [
			[TURRET, SKIN_TURRET, &"idle", 24.0, 2.0],
		],
		"pit_spikes": [[6, 3, 8]],
		"checkpoint": 2.0,
	},
	{
		"name": "Second Head", "col": 10, "band": BAND_GALLERY,
		# **No gaps** -- the lower sump is under this column -- and the last
		# ladder down.
		"gaps": [], "blocks": [],
		"enemies": [
			[HOPPER, SKIN_HOPPER, &"hop", 10.0, 0.0],
		],
		"checkpoint": 2.0,
		"shaft": [22, 2],
	},
	{
		"name": "Lower Sump", "col": 10, "band": BAND_SUMP,
		# Arrival at the real bottom. Dry ground, then the water starts.
		"gaps": [[17, 19]], "blocks": [],
		"enemies": [
			[FLYER, SKIN_FLYER, &"fly", 8.0, 4.0],
		],
		"pit_spikes": [[17, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Drown Line", "col": 11, "band": BAND_SUMP,
		# **The exam: wet and dry alternating**, so every jump in the room has to
		# be aimed twice and telling which is which at a glance is the whole of
		# it.
		"gaps": [[9, 11], [19, 21]], "blocks": [],
		"enemies": [
			[CRAWLER, SKIN_CRAWLER, &"crawl", 25.0, 0.0],
		],
		"pit_spikes": [[9, 3, 2], [19, 3, 2]],
		"checkpoint": 2.0,
		"water": [{"from": 5, "to": 13, "surface": 4, "depth": 5.0}],
	},
	{
		"name": "Bore Hole", "col": 12, "band": BAND_SUMP,
		# The last room with anything in it, and no new ideas: the room before
		# the run-up should be the stage's vocabulary spoken once more.
		"gaps": [], "blocks": [[6, 2, 4, 2], [16, 2, 3, 2]],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 12.0, 0.0],
			[TURRET, SKIN_TURRET, &"idle", 22.0, 2.0],
		],
		"checkpoint": 2.0,
		"water": [{"from": 9, "to": 15, "surface": 3, "depth": 4.0}],
	},
	{
		"name": "Gate", "col": 13, "band": BAND_SUMP,
		# Deliberately empty. The run-up to a boss is a breath, and
		# `tests/test_stage_authoring.gd` holds every stage to it.
		"gaps": [], "blocks": [],
		"enemies": [],
		"checkpoint": 2.0,
	},
	{
		"name": "Arena", "col": 14, "band": BAND_SUMP,
		# Flat, empty, no checkpoint and **dry**. Quarry's Flood raises its own
		# water and the whole pattern is the player's jump changing under them;
		# a room pool would mean the arena was already flooded and the pattern
		# would do nothing. Same call Breakers makes about the press, Turbine Row
		# about the wind, Stack about the belt and Cold Store about the ice --
		# **all eight stages keep their gimmick out of their boss's room**, and
		# every one of them does it for this reason: the boss owns the idea in
		# there.
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
	return QUARRY


func boss_frames_path() -> String:
	return BOSS_FRAMES_PATH


func boss_name() -> String:
	return "Quarry"


## The water. This stage's own key -- the eighth and last of them.
##
## A pool is placed by its **surface**, because that is the line the player
## reads: it is where their jump changes. Everything else about it follows.
func place_stage_elements(spec: Dictionary, _index: int, origin: int, deck: int,
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


## Every pool in the stage, in placement order. For the playtest tools and for
## `tests/test_sinkhole.gd`, which checks the built nodes rather than only the
## table -- the shaft bug at M6i was a table that was right and a translation
## that was not.
func pools() -> Array[WaterVolume]:
	var out: Array[WaterVolume] = []
	for child in get_children():
		if child is WaterVolume:
			out.append(child as WaterVolume)
	return out
