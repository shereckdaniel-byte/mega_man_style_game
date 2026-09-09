## Fortress 3, "Switchgear" -- eight pads, and everything you already beat.
##
## The boss rush. A hub with eight lit plates in the floor; each one drops you
## into a sealed arena with one of the Robot Masters, and beating them puts you
## back on the hub. When all eight are down the ninth plate lights and takes you
## out of the stage.
##
##   band 0   Entry -- Approach -- Hub
##                                  |
##   bands 1-8, all at column 0:    the eight arenas, one per band, no
##                                  connection to each other or to anything
##
## ### Why the arenas are stacked in their own bands
##
## They have to be **unreachable on foot**, and the room table has only two
## kinds of link in it: a door along a band and a ladder between two. Laid out
## side by side, the eight arenas would share a continuous deck, and a player
## who walked off the end of one would be standing in the next one's floor with
## `Stage.room` still naming the first -- no enemies, a camera locked to a room
## they have left, and no way to say so. That is the M6i shaft bug's exact
## shape, and it was worth a whole stage being unfinishable then.
##
## A band is 15 rows and nothing crosses one without a ladder, so eight bands is
## eight islands, for free, with no walls to author and no new element.
##
## The table therefore describes rooms that are **not** in the order they are
## played and are not joined to each other. `"exit": "teleport"` is how a row
## says so -- `AuthoredStage` hangs no door across such a link, and the rule in
## `tests/test_stage_authoring.gd` that a change of band needs a ladder is a
## rule about walking and skips it.
##
## ### The difficulty is one health bar, not eight harder fights
##
## The refights are the fights as shipped: same patterns, same speeds, no
## `aggression`. Making each of them harder would be the obvious thing and it
## would be the wrong one -- the boss rush is a **resource** problem, and it is
## the only place in the game where the question is what you have left rather
## than what you can do. Eight fights on one bar, in an order you choose,
## against weapons you have a finite amount of, is a different question from any
## of the eight stages, and it stops being that question the moment the fights
## themselves start being the difficulty.
##
## Which is also why the order is the player's. A pad is a choice: start with
## the one you have the weapon for, or save it.
##
## ### What this stage does to the playthrough bot
##
## It breaks it, and knowingly. `tools/playthrough.gd` walks right until it
## reaches `boss_door_position()` and then fights whatever is in the last room;
## Switchgear has no boss door, no last-room boss, and a route that is not a
## walk. Driving it would mean teaching the bot to read pads and pick an order,
## which is a bot feature rather than a stage feature. The stage is checked by
## `tests/test_switchgear.gd` instead -- built for real, every pad and every
## arena, and every rule about them -- and it is written down here rather than
## discovered later that the bot's silence about this stage means nothing.
extends FortressStage

const BACKGROUND := preload("res://scenes/stages/fortress/parallax_background.gd")
## The fortress's own terrain: poured sea-defence concrete, board-form grain,
## tide staining and rust bleeding from the rebar.
##
## **One tileset for all four fortress stages**, as they share one backdrop
## and one music track and for the same reason: they are one place, and four
## terrains for it would be four answers to a question that has one.
const TILESET := preload("res://resources/tilesets/fortress.tres")
const PAD := preload("res://scenes/level/teleport_pad.gd")

const WALKER := preload("res://scenes/actors/enemies/walker.gd")
const TURRET := preload("res://scenes/actors/enemies/turret.gd")
const FLYER := preload("res://scenes/actors/enemies/flyer.gd")

## TODO(art): stage 3's skins, as everything greyboxed against stage 3's tiles
## uses. The approach wants **Bus** (walks the switchyard), **Isolator** (a
## breaker head that fires) and **Corona** (arcing across the gap).
const SKIN_WALKER := "cutter"
const SKIN_TURRET := "rivetgun"
const SKIN_FLYER := "slag"

## The room the pads live in, and the first of the eight arena rooms. Derived
## from the table below rather than written twice -- see `hub_room_index`.
const HUB_NAME := "Hub"

## Where the eight pads sit in the hub, in cells, and where the exit sits.
##
## Eight in a row with a gap between each, and the exit past all of them,
## because the room should read left-to-right as "these, then out". The
## checkpoint at cell 2 is clear of every plate, so a death does not put the
## player standing on one.
##
## **The first draft had them three cells apart** and no room left for the
## ninth: a pad that fires on contact has to be far enough from its neighbour
## that a stride cannot touch both, and eight of those plus an exit does not fit
## in a 28-cell room. `TeleportPad` now fires on a press of up instead, which is
## the better rule anyway -- a hub is a room about choosing, and a pad that
## fired on contact would answer the question for you.
const PAD_CELLS := [4, 6, 8, 10, 12, 14, 16, 18]
const EXIT_CELL := 22

## Where the player lands in an arena, and where its return pad sits.
##
## The landing is at the left end and the pad is under it: the player arrives
## standing on the pad that takes them home, which is why `TeleportPad` arms
## only once it has been stepped off. Walking right is walking into the fight.
const ARENA_LANDING_CELL := 3
const ARENA_RETURN_CELL := 3

## Where the player comes back to on the hub.
##
## The pad they left from, so a player who has beaten Rust is standing on Rust's
## plate when they return and can see which of the other seven are still lit.
## Returning to a fixed spot would make the hub a place you are put rather than
## a place you are in.
const RETURN_TO_OWN_PAD := true


## One row per room. The first three are walked; the eight after them are not
## joined to anything, and say so with `"exit": "teleport"`.
##
## `refight` is this stage's own key: the boss index whose arena this room is.
## The script comes from `StageRoster` -- eight preloads here would be a second
## table saying which boss is which.
const ROOMS := [
	{
		"name": "Entry", "col": 0, "band": 0,
		# No gaps: column 0 carries all eight arena bands under this room, and
		# holes may only be cut in the deepest band of a column.
		"gaps": [], "blocks": [],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 12.0, 0.0],
			[WALKER, SKIN_WALKER, &"walk", 21.0, 0.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Approach", "col": 1, "band": 0,
		# The last ordinary platforming in the fortress, and deliberately mild.
		# What comes after it is eight boss fights on one health bar, and a room
		# that spent any of that bar would be taking from the thing it is the
		# run-up to.
		# The hole is five cells past the block, not four: a jump taken off a
		# two-tile step carries further than one from the ground, so the rule is
		# RUN_UP_CELLS plus one per tile of height. Authored at four first, and
		# `test_a_gap_does_not_start_within_a_jump_of_a_drop` said so.
		"gaps": [[18, 20]], "blocks": [[8, 2, 4, 2]],
		"enemies": [
			[TURRET, SKIN_TURRET, &"idle", 23.0, 2.0],
			[FLYER, SKIN_FLYER, &"fly", 12.0, 5.0],
		],
		"pit_spikes": [[18, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": HUB_NAME, "col": 2, "band": 0,
		# Flat, empty, and no enemies. Every decision in this room is which pad
		# to take, and anything else in it is noise on top of the one question
		# the stage asks.
		#
		# **A checkpoint, unlike an arena.** The player returns here eight times
		# and a death anywhere in the stage should put them back on the hub with
		# their progress through the eight intact, not at the start of the
		# fortress.
		"gaps": [], "blocks": [],
		"enemies": [],
		"checkpoint": 2.0,
		"exit": "teleport",
	},
	{
		"name": "Cell 1", "col": 0, "band": 1,
		"gaps": [], "blocks": [], "enemies": [],
		"checkpoint": NO_CHECKPOINT,
		"refight": 0, "exit": "teleport",
	},
	{
		"name": "Cell 2", "col": 0, "band": 2,
		"gaps": [], "blocks": [], "enemies": [],
		"checkpoint": NO_CHECKPOINT,
		"refight": 1, "exit": "teleport",
	},
	{
		"name": "Cell 3", "col": 0, "band": 3,
		"gaps": [], "blocks": [], "enemies": [],
		"checkpoint": NO_CHECKPOINT,
		"refight": 2, "exit": "teleport",
	},
	{
		"name": "Cell 4", "col": 0, "band": 4,
		"gaps": [], "blocks": [], "enemies": [],
		"checkpoint": NO_CHECKPOINT,
		"refight": 3, "exit": "teleport",
	},
	{
		"name": "Cell 5", "col": 0, "band": 5,
		"gaps": [], "blocks": [], "enemies": [],
		"checkpoint": NO_CHECKPOINT,
		"refight": 4, "exit": "teleport",
	},
	{
		"name": "Cell 6", "col": 0, "band": 6,
		"gaps": [], "blocks": [], "enemies": [],
		"checkpoint": NO_CHECKPOINT,
		"refight": 5, "exit": "teleport",
	},
	{
		"name": "Cell 7", "col": 0, "band": 7,
		"gaps": [], "blocks": [], "enemies": [],
		"checkpoint": NO_CHECKPOINT,
		"refight": 6, "exit": "teleport",
	},
	{
		"name": "Cell 8", "col": 0, "band": 8,
		"gaps": [], "blocks": [], "enemies": [],
		"checkpoint": NO_CHECKPOINT,
		"refight": 7, "exit": "teleport",
	},
]


## Pads on the hub, by boss index. The exit is held separately: it is the one
## pad that is not a fight.
var _pads: Dictionary = {}
var _exit_pad: TeleportPad = null
var _return_pads: Dictionary = {}
## Which of the eight have been beaten **in this stage**.
##
## Not `GameState.bosses_defeated`: every one of those bits is already set, or
## the fortress would not have opened. The boss rush is its own eight.
var _down: Dictionary = {}
## The pad the player left the hub from, so they come back to it.
var _left_from := -1


func fortress_index() -> int:
	return 2


func room_table() -> Array:
	return ROOMS


func stage_tile_set() -> TileSet:
	return TILESET


func backdrop_script() -> GDScript:
	return BACKGROUND


## **No stage boss.** `AuthoredStage._add_arena` builds nothing, and the stage
## ends when the player takes the exit pad rather than when a fight is won.
func boss_script() -> GDScript:
	return null


func hub_room_index() -> int:
	for i in ROOMS.size():
		if String(ROOMS[i]["name"]) == HUB_NAME:
			return i
	return -1


## The arena room for a boss index, or -1.
func cell_room_index(boss_index: int) -> int:
	for i in ROOMS.size():
		if int(ROOMS[i].get("refight", -1)) == boss_index:
			return i
	return -1


func is_beaten(boss_index: int) -> bool:
	return bool(_down.get(boss_index, false))


func beaten_count() -> int:
	return _down.size()


func exit_pad() -> TeleportPad:
	return _exit_pad


func pad_for(boss_index: int) -> TeleportPad:
	return _pads.get(boss_index, null)


## The pads and the eight arenas.
func place_stage_elements(spec: Dictionary, index: int, origin: int, deck: int,
		tile: float) -> void:
	var surface := float(deck) + deck_surface_offset()

	if String(spec["name"]) == HUB_NAME:
		for i in PAD_CELLS.size():
			var pad := _make_pad(i, origin + int(PAD_CELLS[i]), surface, tile)
			pad.name = "Pad_%d" % i
			_pads[i] = pad
			pad.used.connect(_on_pad_used)
		_exit_pad = _make_pad(-1, origin + EXIT_CELL, surface, tile)
		_exit_pad.name = "Pad_Exit"
		# Dark until all eight are down. A pad that looked live and refused
		# would be a puzzle about the pad rather than about the eight.
		_exit_pad.live = false
		_exit_pad.used.connect(_on_exit_used)
		return

	if not spec.has("refight"):
		return

	var boss_index := int(spec["refight"])
	var back := _make_pad(boss_index, origin + ARENA_RETURN_CELL, surface, tile)
	back.name = "Return_%d" % boss_index
	back.used.connect(_on_return_used)
	_return_pads[boss_index] = back

	var script := StageRoster.boss_script(boss_index)
	if script == null:
		# A missing boss leaves the cell empty rather than crashing the stage:
		# the player teleports in, finds nothing, and can teleport out.
		return
	var fight := BossArena.new()
	fight.name = "Arena_%d" % boss_index
	fight.boss_script = script
	fight.arena_room = _rooms[index].get_path()
	# Past the landing, so crossing the room is what starts the fight -- the
	# player arrives standing on the return pad and chooses to walk in.
	fight.position = Vector2(float(origin + ARENA_LANDING_CELL + 4),
		band_surface_row(room_band(index))) * tile
	fight.boss_offset_tiles = boss_offset_tiles()
	fight.cleared.connect(_on_refight_cleared)
	add_child(fight)


func _make_pad(pad_index: int, cell: int, surface: float,
		tile: float) -> TeleportPad:
	var pad := PAD.new() as TeleportPad
	pad.pad_index = pad_index
	pad.position = Vector2(float(cell), surface) * tile
	add_child(pad)
	return pad


# --- The pads --------------------------------------------------------------------

func _on_pad_used(pad: TeleportPad) -> void:
	var boss_index := pad.pad_index
	if is_beaten(boss_index):
		# A beaten cell is an empty room with a way out, which is honest -- but
		# there is nothing in it, so the pad simply goes dark instead of sending
		# the player to look at it.
		return
	var room_index := cell_room_index(boss_index)
	if room_index < 0:
		return
	_left_from = boss_index if RETURN_TO_OWN_PAD else 0
	_go_to(room_index, ARENA_LANDING_CELL, _return_pads.get(boss_index, null))


func _on_return_used(pad: TeleportPad) -> void:
	var hub := hub_room_index()
	if hub < 0:
		return
	var cell: int = PAD_CELLS[clampi(
		_left_from if _left_from >= 0 else pad.pad_index, 0, PAD_CELLS.size() - 1)]
	_go_to(hub, cell, _pads.get(pad.pad_index, null))


## The stage ends here rather than on a boss dying, which is the one structural
## difference between this stage and every other one in the game.
func _on_exit_used(_pad: TeleportPad) -> void:
	if beaten_count() < GameState.BOSS_COUNT:
		return
	_begin_stage_exit()


func _go_to(room_index: int, cell: int, landing_pad: TeleportPad) -> void:
	if room_index < 0 or room_index >= _rooms.size():
		return
	var tile := tile_size()
	var at := Vector2(float(room_origin(room_index) + cell),
		band_surface_row(room_band(room_index))) * tile
	# The pad the player is about to stand on must not fire on arrival: see
	# `TeleportPad.disarm_until_empty`.
	if landing_pad != null:
		landing_pad.disarm_until_empty()
	teleport_player(_rooms[room_index], at)


func _on_refight_cleared(boss_index: int, _weapon_id: StringName) -> void:
	_down[boss_index] = true
	var pad: TeleportPad = _pads.get(boss_index, null)
	if pad != null:
		# The plate goes dark, which is the hub's whole readout: eight lights,
		# and how many are left is how many are still on.
		pad.live = false
	if beaten_count() >= GameState.BOSS_COUNT and _exit_pad != null:
		_exit_pad.live = true
