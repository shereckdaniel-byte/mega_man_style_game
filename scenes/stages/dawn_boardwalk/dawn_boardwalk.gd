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
## the rising tide, which is the vocabulary M5a exists to provide. This is the stage the game boots into; `art_preview.tscn` stays as the
## bare art harness.
##
## Authored as a table rather than as a .tscn for the same reason the tuning
## room is: every number here exists to make one decision, and the table says
## which. It also means a room is a row you can read, rather than a subtree you
## have to click through.
##
## The pit is one sensor spanning the whole stage rather than one per gap, so
## adding a gap needs no matching edit. Checkpoints must sit on solid deck --
## one over a gap respawns the player into the pit forever, which is how the
## first draft of the preview ate a whole life counter.
extends Stage

const BACKGROUND := preload("res://scenes/stages/dawn_boardwalk/parallax_background.gd")
const PLAYER_SCENE := preload("res://scenes/actors/player/player.tscn")
const TILESET := preload("res://resources/tilesets/dawn_boardwalk.tres")
const HUD_SCRIPT := preload("res://scenes/ui/hud.gd")
const PAUSE_MENU := preload("res://scenes/ui/pause_menu.gd")
const DEBUG_OVERLAY := preload("res://scenes/ui/debug_overlay.gd")
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

## Deck surface row, and how deep the planks go.
const DECK_ROW := 11
const DECK_DEPTH := 2
## Rows above the deck the room's top edge sits at. 11 makes every room exactly
## one screen tall, which locks the camera vertically within a band -- the
## backdrop is placed against the viewport, so a camera that drifted would slide
## the horizon off. Moving *between* bands is a vertical door transition.
const ROOM_TOP := DECK_ROW - 11
const ROOM_HEIGHT := 15

## Rooms sit in one of two horizontal bands: the boardwalk, and the pilings a
## screen beneath it.
const BAND_DECK := 0
const BAND_UNDER := 1
## One screen is 26.7 tiles; 28 gives a room a little more than a screen so the
## camera has somewhere to travel.
const ROOM_WIDTH := 28
## The tallest step the player can climb, and the widest gap they can cross.
##
## A full jump reaches 2.89 tiles up and covers about 3.4 tiles across at walk
## speed, so 2 is comfortable in both axes and 3 is frame-perfect. A first stage
## does not ask for frame-perfect.
const MAX_STEP_TILES := 2
const MAX_GAP_TILES := 2

## A room with no checkpoint. Not -1 by accident: a checkpoint at cell -1 would
## be placed silently outside the room, and the pit would eat the player.
const NO_CHECKPOINT := -1.0

## The bottomless-pit plane: how far below a band's deck it starts, and how deep.
##
## One per band rather than one for the stage. A single plane cannot work once
## rooms are stacked: set deep enough to sit under the pilings it is below the
## whole level, and set at the old height it cuts straight through the
## under-deck rooms and drowns anyone standing in them.
const PIT_DROP := 10
const PIT_DEPTH := 24

## How far above the under-deck the tide is allowed to climb, in rows. The
## highest block in the Tide room stands 6 above the deck, so 8 leaves the top
## of it dry with a tile to spare.
const TIDE_CEILING_ABOVE_DECK := 8

## Rows of solid deck a ceiling is made of.
const CEILING_THICKNESS := 2

## Clearance, in rows, that forces a slide.
##
## The player's standing box is 24 NES px and the sliding one is 14
## (PlayerTuning.NES_HITBOX / NES_SLIDE_HITBOX), and a tile is 16. So one row of
## clearance is 16 px: a slide fits with 2 px to spare and standing does not fit
## at all. Two rows would be 32 and let the player walk straight through.
const SLIDE_CLEARANCE := 1

## One row per room, in the order the player meets them.
##
## `col` and `band` place the room on the grid; everything else is relative to
## that room's own left edge and its band's deck row, so a room can be moved by
## changing two numbers.
##
## `gaps` are [from, to) in cells; `blocks` are [x, rows_above_deck, w, h];
## `enemies` are [archetype, art, animation, x, rows_above_deck]. The element
## lists are [x, rows_above_deck, ...] with their own trailing arguments.
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

## Index of the arena in ROOMS, and of the last room the player walks through.
const ARENA_ROOM := 7
const BOSS_DOOR_ROOM := 6

var _player: Player
var _deck: TileMapLayer
var _rooms: Array[Room] = []
var _backdrop: Node2D
var _tide: RisingTide = null
var _log: PlaytestLog = null


func _ready() -> void:
	var autoload := get_node_or_null(^"/root/Tuning")
	var tuning: PlayerTuning = autoload.player if autoload != null else PlayerTuning.new()
	var tile := tuning.tile_size()

	_backdrop = Node2D.new()
	_backdrop.name = "Backdrop"
	_backdrop.set_script(BACKGROUND)
	add_child(_backdrop)

	_build_deck(tuning.world_scale)
	_build_rooms(tile)
	_add_pit_sensor(tile)

	_player = PLAYER_SCENE.instantiate()
	_player.position = Vector2(2.0, float(DECK_ROW) - 2.0) * tile
	add_child(_player)

	_add_arena(tile)
	# The backdrop follows the band, so the rooms under the boardwalk stop
	# showing the sunrise. Driven from here because which band a room is in is
	# the stage's fact, not the backdrop's.
	room_changed.connect(_on_room_changed_backdrop)
	_add_hud()
	_add_pause_menu()
	_add_playtest_log()
	_add_overlay()
	_player.game_over.connect(_on_game_over)
	stage_cleared.connect(_print_ledger.bind("stage cleared"))
	begin(_player, _rooms[0])


## Left edge of a room, in cells.
static func room_origin(index: int) -> int:
	return int(ROOMS[index]["col"]) * ROOM_WIDTH


## The band a room sits in, and the deck row for that band.
static func room_band(index: int) -> int:
	return int(ROOMS[index]["band"])


static func band_deck_row(band: int) -> int:
	return DECK_ROW + band * ROOM_HEIGHT


static func band_top_row(band: int) -> int:
	return ROOM_TOP + band * ROOM_HEIGHT


static func room_deck_row(index: int) -> int:
	return band_deck_row(room_band(index))


func rooms() -> Array[Room]:
	return _rooms


## Where the run through the stage ends: the far side of the last walking room,
## which is the doorway into the arena. Not the arena itself -- reaching this
## point is what "got to the boss" means, and the fight is what comes after.
func boss_door_position() -> Vector2:
	var autoload := get_node_or_null(^"/root/Tuning")
	var tile: float = autoload.player.tile_size() if autoload != null else 72.0
	return Vector2(float(room_origin(BOSS_DOOR_ROOM) + ROOM_WIDTH - 3),
		float(DECK_ROW)) * tile


## The arena node, for the tests and for the playthrough tool.
func arena() -> BossArena:
	return get_node_or_null(^"BossArena") as BossArena


# --- Building -----------------------------------------------------------------

func _build_deck(world_scale: float) -> void:
	_deck = TileMapLayer.new()
	_deck.name = "Boardwalk"
	_deck.tile_set = TILESET
	_deck.scale = Vector2(world_scale, world_scale)
	# 16 px art magnified 4.5x. The project default is Linear and must stay
	# Linear for the character -- SPRITES.md section 8.
	_deck.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_deck)

	var cells: Array[Vector2i] = []
	for index in ROOMS.size():
		var spec: Dictionary = ROOMS[index]
		var origin := room_origin(index)
		var deck := room_deck_row(index)
		for x in range(origin, origin + ROOM_WIDTH):
			if _in_gap(spec, x - origin):
				continue
			if _in_shaft(spec, x - origin):
				continue  # the hole the ladder goes through
			for y in range(deck, deck + DECK_DEPTH):
				cells.append(Vector2i(x, y))
		# Overhead geometry. Authored as its own key rather than as a block,
		# because a ceiling is something the player goes *under* and a block is
		# something they climb *onto* -- and the step test cannot tell them
		# apart from coordinates alone. [x, clearance_rows, w] leaves
		# `clearance_rows` of open air above the deck and fills two rows above
		# that, which is enough to stand on top of and impossible to walk
		# through underneath.
		for ceiling in spec.get("ceilings", []):
			var cx := origin + int(ceiling[0])
			# Thickness is optional and decides whether the tunnel can be
			# *avoided*. One row puts the top surface two tiles above the deck,
			# which a jump reaches, so the player may go over instead of under.
			# Two rows puts it at three, which the jump cannot clear, and the
			# slide becomes the only way through.
			var thickness := int(ceiling[3]) if ceiling.size() > 3 else CEILING_THICKNESS
			var cy := deck - int(ceiling[1]) - thickness
			for x in range(cx, cx + int(ceiling[2])):
				for y in range(cy, cy + thickness):
					var cell := Vector2i(x, y)
					if not cells.has(cell):
						cells.append(cell)

		for block in spec.get("blocks", []):
			var bx := origin + int(block[0])
			var by := deck - int(block[1])
			for x in range(bx, bx + int(block[2])):
				for y in range(by, by + int(block[3])):
					var cell := Vector2i(x, y)
					if not cells.has(cell):
						cells.append(cell)

	_deck.set_cells_terrain_connect(cells, 0, 0)


## Cells a ladder shaft opens in the deck, so a ladder is not blocked by the
## floor it passes through. A ladder into a solid ceiling climbs two tiles and
## stops, which reads as a broken ladder rather than a missing hole.
func _in_shaft(spec: Dictionary, local_x: int) -> bool:
	for key in ["shaft", "shaft_up"]:
		if not spec.has(key):
			continue
		var shaft: Array = spec[key]
		var from := int(shaft[0])
		if local_x >= from and local_x < from + int(shaft[1]):
			return true
	return false


func _in_gap(spec: Dictionary, local_x: int) -> bool:
	for gap in spec["gaps"]:
		if local_x >= int(gap[0]) and local_x < int(gap[1]):
			return true
	return false


func _build_rooms(tile: float) -> void:
	for index in ROOMS.size():
		var spec: Dictionary = ROOMS[index]
		var origin := room_origin(index)
		var band := room_band(index)
		var deck := band_deck_row(index if false else band)

		var room := Room.new()
		room.name = "Room%d_%s" % [index, String(spec["name"]).replace(" ", "")]
		room.bounds_tiles = Rect2i(origin, band_top_row(band), ROOM_WIDTH, ROOM_HEIGHT)
		add_child(room)
		_rooms.append(room)

		var checkpoint_cell := float(spec["checkpoint"])
		if not is_equal_approx(checkpoint_cell, NO_CHECKPOINT):
			var checkpoint := Checkpoint.new()
			checkpoint.name = "%s_Checkpoint" % room.name
			checkpoint.position = Vector2(float(origin) + checkpoint_cell,
				float(deck)) * tile
			add_child(checkpoint)

		for entry in spec.get("enemies", []):
			_add_marker(entry, origin, deck, tile)
		_add_elements(spec, index, origin, deck, tile)

	# Doors last, so every room exists to be named.
	for index in _rooms.size() - 1:
		_add_door(index, tile)


## The door out of room `index`, pointing at the next one.
##
## Which way it faces is derived from where the two rooms actually are rather
## than authored, because a door whose direction disagrees with the geometry
## still works -- it just carries the player sideways out of a ladder shaft, and
## the symptom is a transition that dumps them in a wall.
func _add_door(index: int, tile: float) -> void:
	var from_band := room_band(index)
	var to_band := room_band(index + 1)
	var door := Door.new()
	door.name = "Door%d" % index
	door.to_room = _rooms[index + 1].get_path()

	if to_band == from_band:
		door.direction = Vector2.RIGHT
		# On the room's right edge, one cell in, so the player is inside the
		# outgoing room when it fires.
		door.position = Vector2(float(room_origin(index) + ROOM_WIDTH - 1),
			float(band_deck_row(from_band))) * tile
		add_child(door)
		return

	# A band change: the door sits on the boundary between the two rooms, in the
	# shaft's column, and faces the way the player is travelling.
	var going_down := to_band > from_band
	var spec: Dictionary = ROOMS[index]
	var shaft: Array = spec.get("shaft", spec.get("shaft_up", [ROOM_WIDTH / 2, 2]))
	var column := float(room_origin(index) + int(shaft[0])) + float(shaft[1]) * 0.5
	var boundary := float(band_top_row(maxi(from_band, to_band)))
	door.direction = Vector2.DOWN if going_down else Vector2.UP
	door.vertical_size_tiles = Vector2(float(shaft[1]) + 1.0, 1.0)
	door.position = Vector2(column, boundary) * tile
	add_child(door)


## Places everything in a room that is not deck, enemies or a checkpoint.
##
## One function rather than one per element because the placement rule is the
## same for all of them -- room-relative cell, rows above that band's deck -- and
## the interesting per-element decisions are all in the element's own class.
func _add_elements(spec: Dictionary, index: int, origin: int, deck: int,
		tile: float) -> void:
	for entry in spec.get("spikes", []):
		var spikes := Hazard.new()
		spikes.name = "Spikes_%d_%d" % [origin + int(entry[0]), deck]
		spikes.size_tiles = Vector2(float(entry[2]), 0.5)
		# Sitting in the floor line, so a jump clears them and a walk does not.
		spikes.position = Vector2(float(origin + int(entry[0])),
			float(deck) - float(entry[1])) * tile
		add_child(spikes)

	# Spikes hung on the underside of a ceiling: the thing that makes a low
	# tunnel a slide rather than a duck.
	for entry in spec.get("ceiling_spikes", []):
		var teeth := Hazard.new()
		teeth.name = "CeilingSpikes_%d_%d" % [origin + int(entry[0]), deck]
		teeth.size_tiles = Vector2(float(entry[2]), 0.5)
		# Hanging just below the ceiling's face, so a standing head meets them
		# and a sliding one passes beneath.
		teeth.position = Vector2(float(origin + int(entry[0])),
			float(deck) - float(entry[1]) + 0.25) * tile
		add_child(teeth)

	# Spikes on the floor of a pit the player is already crossing.
	for entry in spec.get("pit_spikes", []):
		var floor_teeth := Hazard.new()
		floor_teeth.name = "PitSpikes_%d_%d" % [origin + int(entry[0]), deck]
		floor_teeth.size_tiles = Vector2(float(entry[2]), 0.5)
		floor_teeth.position = Vector2(float(origin + int(entry[0])),
			float(deck) + float(entry[1])) * tile
		add_child(floor_teeth)

	for entry in spec.get("one_ways", []):
		var plat := OneWayPlatform.new()
		plat.name = "OneWay_%d_%d" % [origin + int(entry[0]), deck]
		plat.size_tiles = Vector2(float(entry[2]), 0.5)
		plat.position = Vector2(float(origin + int(entry[0])),
			float(deck) - float(entry[1])) * tile
		add_child(plat)

	for entry in spec.get("movers", []):
		var mover := MovingPlatform.new()
		mover.name = "Mover_%d_%d" % [origin + int(entry[0]), deck]
		mover.size_tiles = Vector2(3.0, 0.5)
		mover.travel_tiles = Vector2(float(entry[2]), float(entry[3]))
		mover.frames_per_leg = int(entry[4])
		mover.position = Vector2(float(origin + int(entry[0])),
			float(deck) - float(entry[1])) * tile
		add_child(mover)

	for entry in spec.get("crumbles", []):
		var block := CrumblingBlock.new()
		block.name = "Crumble_%d_%d" % [origin + int(entry[0]), deck]
		block.size_tiles = Vector2(1.0, 1.0)
		block.position = Vector2(float(origin + int(entry[0])),
			float(deck) - float(entry[1])) * tile
		add_child(block)

	# Ladders. A shaft leaves this room downward; a shaft_up arrives from below.
	# Both span the boundary between the bands, because a ladder that stops at
	# the room edge hands the player nothing to hold when the transition
	# delivers them (see door.gd).
	if spec.has("shaft"):
		_add_ladder(origin + int(spec["shaft"][0]), deck, room_band(index) + 1, tile)
	if spec.has("shaft_up"):
		_add_ladder(origin + int(spec["shaft_up"][0]), deck, room_band(index) - 1, tile)

	if spec.get("tide", false):
		_add_tide(origin, deck, tile)


## A ladder joining this room's deck to the neighbouring band's.
##
## Height is measured from the lower deck to a little above the upper one, so
## the ladder crosses the boundary with room to spare at both ends.
func _add_ladder(cell: int, deck: int, other_band: int, tile: float) -> void:
	var other_deck := band_deck_row(other_band)
	var foot := maxi(deck, other_deck)
	var head := mini(deck, other_deck)
	var ladder := Ladder.new()
	ladder.name = "Ladder_%d_%d" % [cell, foot]
	# One tile past the upper deck, not three. Three left the top of the ladder
	# hanging in mid-air above the shaft, and a player who climbed to it was
	# stranded: Climb holds you until you jump or reach ground, and there was no
	# ground at that height. One tile is enough to grab from the deck.
	ladder.height_tiles = (foot - head) + 1
	ladder.position = Vector2(float(cell) + 0.5, float(foot)) * tile
	add_child(ladder)


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


func _add_marker(entry: Array, origin: int, deck: int, tile: float) -> void:
	var frames_path := "res://resources/sprite_frames/%s.tres" % entry[1]
	if not ResourceLoader.exists(frames_path):
		return
	var marker := SpawnMarker.new()
	marker.name = "Spawn_%s_%d_%d" % [String(entry[1]).capitalize(),
		origin + int(entry[3]), deck]
	marker.enemy_scene = _enemy_scene(entry[0], load(frames_path), entry[2])
	marker.position = Vector2(float(origin) + float(entry[3]),
		float(deck) - float(entry[4])) * tile
	add_child(marker)


## Wraps an archetype script and its art into a PackedScene, because markers
## spawn scenes rather than scripts.
func _enemy_scene(script: GDScript, frames: SpriteFrames, anim: StringName) -> PackedScene:
	var enemy := script.new() as Enemy
	enemy.sprite_frames = frames
	enemy.anim_name = anim
	var packed := PackedScene.new()
	packed.pack(enemy)
	enemy.free()
	return packed


## A KillPlane, not a Hazard: falling off the boardwalk is not damage, it is the
## end of the run. A Hazard here honours i-frames, and a player who fell in while
## still flickering from a contact hit fell through it forever.
##
## Deep as well as unconditional. At terminal velocity a body covers 31.5 px per
## frame, so a plane two tiles deep is a few frames of overlap and a thin one is
## a coin flip.
##
## **One per band, spanning only that band's own columns.** A single plane for
## the stage cannot work once rooms are stacked: hung low enough to sit under
## the pilings it is beneath the whole level and catches nobody, and left at the
## boardwalk's height it cuts straight through the under-deck rooms and drowns
## anyone standing in them.
func _add_pit_sensor(tile: float) -> void:
	# The lowest band present in each column. A pit belongs under the *bottom*
	# of a column, never under a band that has another one beneath it.
	#
	# Doing this per band instead -- one plane spanning that band's leftmost to
	# rightmost column -- is what the first version did, and it put the
	# boardwalk's pit across columns 0 to 5 at row 21, straight through the
	# under-deck rooms that live at rows 15 to 30. The symptom was a player
	# climbing down the shaft and dying in mid-air at the exact moment they
	# passed row 21, which reads as the ladder being lethal.
	var deepest: Dictionary = {}
	for index in ROOMS.size():
		var col := int(ROOMS[index]["col"])
		var band := room_band(index)
		deepest[col] = maxi(int(deepest.get(col, band)), band)

	var columns: Array = deepest.keys()
	columns.sort()

	# Merge neighbouring columns that share a depth into one plane, so a run of
	# boardwalk gets one sensor rather than one per screen.
	var run_start := -1
	var run_band := -1
	for i in columns.size():
		var col: int = columns[i]
		var band: int = deepest[col]
		var continues: bool = run_start >= 0 and band == run_band \
			and col == int(columns[i - 1]) + 1
		if not continues:
			if run_start >= 0:
				_add_pit_run(run_start, int(columns[i - 1]), run_band, tile)
			run_start = col
			run_band = band
	if run_start >= 0:
		_add_pit_run(run_start, int(columns[columns.size() - 1]), run_band, tile)


## One kill plane under a run of columns that bottom out in the same band.
##
## A KillPlane, not a Hazard: falling off the boardwalk is not damage, it is the
## end of the run. A Hazard here honours i-frames, and a player who fell in while
## still flickering from a contact hit fell through it forever.
##
## Deep as well as unconditional. At terminal velocity a body covers 31.5 px per
## frame, so a plane two tiles deep is a few frames of overlap and a thin one is
## a coin flip.
func _add_pit_run(from_col: int, to_col: int, band: int, tile: float) -> void:
	var from_cell := from_col * ROOM_WIDTH
	var width := (to_col - from_col + 1) * ROOM_WIDTH
	var top := float(band_deck_row(band) + PIT_DROP)
	var pit := KillPlane.new()
	pit.name = "Pit_col%d_%d_band%d" % [from_col, to_col, band]
	pit.size_tiles = Vector2(float(width), float(PIT_DEPTH))
	pit.position = Vector2(float(from_cell) + float(width) * 0.5,
		top + float(PIT_DEPTH) * 0.5) * tile
	add_child(pit)


func _add_arena(tile: float) -> void:
	var origin := room_origin(ARENA_ROOM)
	var arena_node := BossArena.new()
	arena_node.name = "BossArena"
	arena_node.boss_script = TIDE
	arena_node.arena_room = _rooms[ARENA_ROOM].get_path()
	arena_node.position = Vector2(float(origin) + 4.0, float(DECK_ROW)) * tile
	# Tide lands well clear of the doorway, at the far end of the arena.
	arena_node.boss_offset_tiles = Vector2(16.0, 0.0)
	add_child(arena_node)
	arena_node.cleared.connect(_on_boss_cleared)


func _add_hud() -> void:
	var hud := HUD_SCRIPT.new()
	hud.name = "Hud"
	add_child(hud)
	hud.track(_player)
	var arena_node := arena()
	if arena_node != null:
		arena_node.use_hud(hud)


func _add_pause_menu() -> void:
	var menu := PAUSE_MENU.new()
	menu.name = "PauseMenu"
	add_child(menu)
	menu.bind(_player)
	menu.restart_requested.connect(_restart_run)


## The playtest ledger, on for every run of this stage.
##
## **This is here so that a person playing produces the same artefact the bot
## does.** Stage 1's difficulty is the open question in docs/PLAN.md, and the one
## thing that will settle it is somebody playing it -- but a session that ends in
## "that felt hard" settles nothing either. Ending it with a table of which rooms
## cost what, in the same layout tools/playthrough.gd prints, means the two can
## be laid side by side: a cost only the bot pays is the bot's, and a cost they
## both pay is the stage's.
##
## Always recording rather than behind a flag. It is a handful of signal
## connections and an array, the game has no title screen to enable it from yet,
## and a playtest instrument that has to be remembered before the session is one
## that produces nothing after it. Revisit at M8.
func _add_playtest_log() -> void:
	_log = PlaytestLog.new()
	_log.name = "PlaytestLog"
	add_child(_log)
	_log.watch(_player, self)


## F3, the same overlay the M1 tuning room uses, plus the running ledger.
##
## Stage 1 had none: every readout in the project pointed at the test room, so
## the one place anybody would actually play was the one place showing nothing.
func _add_overlay() -> void:
	var overlay := CanvasLayer.new()
	overlay.set_script(DEBUG_OVERLAY)
	# Both set before it enters the tree: _ready resolves them, so assigning
	# afterwards leaves the overlay looking at nothing.
	overlay.player_path = _player.get_path()
	overlay.playtest_log_path = _log.get_path()
	overlay.visible = false
	add_child(overlay)


## Prints the run's ledger to the console. Called when a run ends, either way.
func _print_ledger(reason: String) -> void:
	if _log == null:
		return
	print("playtest ledger -- %s" % reason)
	for line in _log.report():
		print(line)


## Held as a reference rather than looked up by name, and called without a
## `has_method` guard: both of those turn a backdrop that stopped answering into
## a silent no-op, and a silent no-op here looks exactly like art nobody made.
func _on_room_changed_backdrop(room_entered: Room) -> void:
	for index in _rooms.size():
		if _rooms[index] == room_entered:
			_backdrop.call(&"show_band", room_band(index))
			return


## Out of lives. Show the screen, then start the run over.
##
## The whole run, not the room: lives go back to the starting count and the
## checkpoint is cleared, because a game over that dropped the player back at
## the last checkpoint with no lives left would be a game over in name only.
func _on_game_over() -> void:
	_print_ledger("game over")
	if _player != null and is_instance_valid(_player):
		_player.set_frozen(true)
	var screen := GameOver.show_over(self)
	screen.finished.connect(_restart_run)


## Back to the top of the stage with a fresh life count.
func _restart_run() -> void:
	var state := get_node_or_null(^"/root/GameState")
	if state != null:
		state.lives = state.STARTING_LIVES
		state.clear_checkpoint()
	var weapons := get_node_or_null(^"/root/WeaponManager")
	if weapons != null:
		weapons.refill_all()
	# Rebuilt rather than repaired. A stage carries spent spawn markers, a
	# defeated boss, a receded tide and crumbled planks; putting all of that
	# back by hand is a list that grows every time an element is added, and the
	# one forgotten entry is a stage that looks reset and is not.
	get_tree().reload_current_scene()


## Tide is down: award, pose, leave.
##
## The order is the award screen, then the victory pose, then the beam-up. The
## screen comes first because it is the *reward* and it should land while the
## explosion is still fresh; the pose and the exit are the punctuation after it.
func _on_boss_cleared(_index: int, weapon_id: StringName) -> void:
	var weapons := get_node_or_null(^"/root/WeaponManager")
	var data: WeaponData = weapons.data_for(weapon_id) if weapons != null else null
	var weapon_name := data.display_name if data != null else String(weapon_id).capitalize()
	if _player != null:
		_player.set_frozen(true)

	var boss_art: SpriteFrames = null
	if ResourceLoader.exists(BOSS_FRAMES_PATH):
		boss_art = load(BOSS_FRAMES_PATH)
	var screen := WeaponGet.show_for(self, weapon_name, "Tide", boss_art)
	screen.finished.connect(_begin_stage_exit)


## The award screen is gone. Pose, then beam out.
func _begin_stage_exit() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if not _player.stage_exited.is_connected(_on_stage_exited):
		_player.stage_exited.connect(_on_stage_exited)
	_player.begin_victory()


func _on_stage_exited() -> void:
	# Nothing consumes this yet; the stage select is M6. It is emitted now so
	# the sequence has an end rather than trailing off with the player somewhere
	# above the room.
	stage_cleared.emit()
