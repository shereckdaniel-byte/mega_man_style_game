## A stage authored as a table of rooms: the machinery every stage shares.
##
## **Why this exists.** M5a built the level-element kit before extending stage 1,
## on the argument that eight stages built from two elements are eight versions
## of one stage. The same argument applies one level up, and this is where it
## bites: stage 1's builder is 850 lines of which about 800 are "lay a deck, cut
## the gaps, place the rooms, hang the doors, wire the HUD" — generic to the last
## comma. Authoring stage 2 by copying that file would put eight copies of it in
## the repository by M6's end, and the eighth would be the one where a fix to the
## first never landed.
##
## So a stage is a **table plus its differences**. Everything below is the same
## for every stage in the game; a subclass supplies the room table, the art, the
## boss, and whatever its own gimmick needs. `DawnBoardwalk` is the first, and
## after the extraction it is its table, its tide, and nothing else.
##
## ### The table
##
## One row per room, in the order the player meets them, each a Dictionary:
##
## | Key | Meaning |
## | --- | --- |
## | `name` | Room name, used for the node and for the playtest ledger |
## | `col`, `band` | Where the room sits on the grid. Everything else is relative to it |
## | `gaps` | `[from, to)` in cells: holes cut in the deck |
## | `blocks` | `[x, rows_above_deck, w, h]`: solid geometry to climb |
## | `ceilings` | `[x, clearance_rows, w, thickness?]`: overhead geometry to pass under |
## | `enemies` | `[archetype, art, animation, x, rows_above_deck]` |
## | `checkpoint` | Cell to respawn at, or `NO_CHECKPOINT` |
## | `shaft` / `shaft_up` | `[x, width]`: a ladder down to, or up from, the next band |
## | `spikes`, `ceiling_spikes`, `pit_spikes`, `one_ways`, `movers`, `crumbles` | The M5a kit |
##
## A subclass adds its own keys and reads them in `place_stage_elements()`.
##
## ### Why a table and not a .tscn
##
## Every number in a room exists to make one decision, and a table says which one
## next to the number. A subtree says it in a property inspector three clicks
## deep, if at all. It also means a room is a row that can be read in a diff.
class_name AuthoredStage
extends Stage

const PLAYER_SCENE := preload("res://scenes/actors/player/player.tscn")
const HUD_SCRIPT := preload("res://scenes/ui/hud.gd")
const PAUSE_MENU := preload("res://scenes/ui/pause_menu.gd")
const DEBUG_OVERLAY := preload("res://scenes/ui/debug_overlay.gd")

## Deck surface row within a band, and how deep the floor goes.
const DECK_ROW := 11
const DECK_DEPTH := 2
## Rows above the deck the room's top edge sits at. 11 makes every room exactly
## one screen tall, which locks the camera vertically within a band -- the
## backdrop is placed against the viewport, so a camera that drifted would slide
## the horizon off. Moving *between* bands is a vertical door transition.
const ROOM_TOP := DECK_ROW - 11
const ROOM_HEIGHT := 15
## One screen is 26.7 tiles; 28 gives a room a little more than a screen so the
## camera has somewhere to travel.
const ROOM_WIDTH := 28

## The tallest step the player can climb, and the widest gap they can cross.
##
## A full jump reaches 2.89 tiles up and covers about 3.4 tiles across at walk
## speed, so 2 is comfortable in both axes and 3 is frame-perfect. Enforced per
## stage by that stage's authoring test, because breaking either produces a
## level that looks fine and cannot be finished.
const MAX_STEP_TILES := 2
const MAX_GAP_TILES := 2

## A room with no checkpoint. Not -1 by accident: a checkpoint at cell -1 would
## be placed silently outside the room, and the pit would eat the player.
const NO_CHECKPOINT := -1.0

## The bottomless-pit plane: how far below a band's deck it starts, and how deep.
const PIT_DROP := 10
const PIT_DEPTH := 24

## Rows of solid deck a ceiling is made of, unless the row says otherwise.
const CEILING_THICKNESS := 2

## Clearance, in rows, that forces a slide.
##
## The player's standing box is 24 NES px and the sliding one is 14
## (PlayerTuning.NES_HITBOX / NES_SLIDE_HITBOX), and a tile is 16. So one row of
## clearance is 16 px: a slide fits with 2 px to spare and standing does not fit
## at all. Two rows would be 32 and let the player walk straight through.
const SLIDE_CLEARANCE := 1

## Clearance for a tunnel that is **hung with spikes**, which is a different
## number and has to be.
##
## A one-row tunnel is closed by its own geometry -- a standing player does not
## fit, so the tiles already say "slide". Hanging spikes in the two-pixel gap
## that is left does not add a warning to that; it fills the only space the slide
## was going to pass through, and the tunnel stops being passable at all. Stage 1
## shipped one of these from M5a and nothing noticed, because the bot enters that
## room from a ladder beyond the tunnel and never had to use it. Stage 2's bot
## slid correctly into one and died on its teeth.
##
## Two rows is 32 NES px: a standing player (24) fits, so the *tiles* no longer
## forbid anything and the spikes are what does -- which is the arrangement the
## room was always described as having. The arithmetic that has to hold is in
## `CEILING_SPIKE_DEPTH`.
const SPIKED_CLEARANCE := 2

## How far ceiling spikes hang below the ceiling's face, in tiles.
##
## Sized so that in a `SPIKED_CLEARANCE` tunnel the teeth catch a standing head
## and miss a sliding one, with margin at both ends rather than to the pixel:
##
##   opening      2 rows           = 32 NES px
##   teeth        0.75 rows        = 12 NES px, hanging from the top
##   standing     24 NES px tall   -> head is 8 px into the teeth. Caught.
##   sliding      14 NES px tall   -> head is 6 px clear of them. Through.
##
## `tests/test_stage_authoring.gd` asserts both halves against the real boxes, so
## a later change to either hitbox or to this number cannot quietly close the
## tunnel again.
const CEILING_SPIKE_DEPTH := 0.75

var _player: Player
var _deck: TileMapLayer
var _rooms: Array[Room] = []
var _backdrop: Node2D
var _log: PlaytestLog = null


# --- What a subclass supplies -------------------------------------------------
#
# Constants cannot be overridden in GDScript, and a stage's table wants to stay
# a `const` so a test can read it without building the stage. So each subclass
# declares `const ROOMS := [...]` and hands it over through this method: the
# table is still `Substation.ROOMS` from outside, and still readable from in here.

func room_table() -> Array:
	return []


func stage_tile_set() -> TileSet:
	return null


func backdrop_script() -> GDScript:
	return null


func boss_script() -> GDScript:
	return null


## Where the boss's art lives. Loaded by path rather than preloaded, so a stage
## still opens while its sprites are mid-regeneration.
func boss_frames_path() -> String:
	return ""


## The name on the weapon-get screen.
func boss_name() -> String:
	return "Boss"


## How far into the arena the boss lands. Far enough from the doorway that the
## fight starts at a readable distance rather than in the player's face.
func boss_offset_tiles() -> Vector2:
	return Vector2(16.0, 0.0)


## Anything this stage has that the shared kit does not: stage 1's tide, stage
## 2's darkness. Called once per room, after that room's kit elements are placed.
func place_stage_elements(_spec: Dictionary, _index: int, _origin: int,
		_deck: int, _tile: float) -> void:
	pass


# --- Reading the table --------------------------------------------------------
#
# Derived rather than authored. The arena is the last room and the boss door is
# the one before it -- stating those as constants alongside a table that decides
# them is two sources for one fact, and the stale one is a stage that thinks the
# fight is in the wrong room.

func arena_room_index() -> int:
	return room_table().size() - 1


func boss_door_room_index() -> int:
	return room_table().size() - 2


## Left edge of a room, in cells.
func room_origin(index: int) -> int:
	return int(room_table()[index]["col"]) * ROOM_WIDTH


## The band a room sits in, and the deck row for that band.
func room_band(index: int) -> int:
	return int(room_table()[index]["band"])


func band_deck_row(band: int) -> int:
	return DECK_ROW + band * ROOM_HEIGHT


func band_top_row(band: int) -> int:
	return ROOM_TOP + band * ROOM_HEIGHT


func room_deck_row(index: int) -> int:
	return band_deck_row(room_band(index))


func rooms() -> Array[Room]:
	return _rooms


## Where the run through the stage ends: the far side of the last walking room,
## which is the doorway into the arena. Not the arena itself -- reaching this
## point is what "got to the boss" means, and the fight is what comes after.
func boss_door_position() -> Vector2:
	return Vector2(float(room_origin(boss_door_room_index()) + ROOM_WIDTH - 3),
		float(DECK_ROW)) * tile_size()


## The arena node, for the tests and for the playthrough tool.
func arena() -> BossArena:
	return get_node_or_null(^"BossArena") as BossArena


func playtest_log() -> PlaytestLog:
	return _log


func tile_size() -> float:
	var autoload := get_node_or_null(^"/root/Tuning")
	return autoload.player.tile_size() if autoload != null else 72.0


# --- Building -----------------------------------------------------------------

func _ready() -> void:
	var autoload := get_node_or_null(^"/root/Tuning")
	var tuning: PlayerTuning = autoload.player if autoload != null else PlayerTuning.new()
	var tile := tuning.tile_size()

	_build_backdrop()
	_build_deck(tuning.world_scale)
	_build_rooms(tile)
	_add_pit_sensor(tile)

	_player = PLAYER_SCENE.instantiate()
	_player.position = Vector2(2.0, float(DECK_ROW) - 2.0) * tile
	add_child(_player)

	_add_arena(tile)
	# The backdrop follows the band, so rooms in a lower band stop showing the
	# upper one's sky. Driven from here because which band a room is in is the
	# stage's fact, not the backdrop's.
	room_changed.connect(_on_room_changed_backdrop)
	_add_hud()
	_add_pause_menu()
	_add_playtest_log()
	_add_overlay()
	_player.game_over.connect(_on_game_over)
	stage_cleared.connect(_print_ledger.bind("stage cleared"))
	begin(_player, _rooms[0])


func _build_backdrop() -> void:
	var script := backdrop_script()
	if script == null:
		return
	_backdrop = Node2D.new()
	_backdrop.name = "Backdrop"
	_backdrop.set_script(script)
	add_child(_backdrop)


func _build_deck(world_scale: float) -> void:
	_deck = TileMapLayer.new()
	# Named for what it is in every stage, not for what stage 1 calls it. The
	# playthrough bot reads the deck by node name, and a per-stage name would
	# make the bot stage-specific for no gain.
	_deck.name = "Terrain"
	_deck.tile_set = stage_tile_set()
	_deck.scale = Vector2(world_scale, world_scale)
	# 16 px art magnified 4.5x. The project default is Linear and must stay
	# Linear for the character -- SPRITES.md section 8.
	_deck.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_deck)

	var table := room_table()
	var cells: Array[Vector2i] = []
	for index in table.size():
		var spec: Dictionary = table[index]
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
		# `clearance_rows` of open air above the deck and fills the rows above
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
	for gap in spec.get("gaps", []):
		if local_x >= int(gap[0]) and local_x < int(gap[1]):
			return true
	return false


func _build_rooms(tile: float) -> void:
	var table := room_table()
	for index in table.size():
		var spec: Dictionary = table[index]
		var origin := room_origin(index)
		var band := room_band(index)
		var deck := band_deck_row(band)

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
		place_stage_elements(spec, index, origin, deck, tile)

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
	var spec: Dictionary = room_table()[index]
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
	# **Every element's x in the table is its left edge**, in cells, the same as
	# a gap's or a block's. `OneWayPlatform`, `MovingPlatform` and
	# `CrumblingBlock` each offset their own shape by half its size to make that
	# true; `Hazard` is a plain `Hitbox` and centres its box on its origin, like
	# every other Area2D in the project. So spikes -- and only spikes -- have to
	# be handed a centre.
	#
	# They were not, from M5a until stage 2 was authored, and the effect was that
	# every spike in the game sat **half its own width to the left of the cell it
	# was declared at**. Stage 1's ceiling teeth hung a tile and a half back from
	# the tunnel they belong to, over open deck a player walks upright along --
	# which is precisely the ambush that room's comment refuses to build -- and
	# its pit spikes lay mostly under solid boardwalk instead of under the gap
	# they were meant to make visible.
	#
	# Nothing caught it because a spike is lethal wherever it is: the stage still
	# played, and it killed you somewhere slightly wrong. The playthrough bot
	# found it on stage 2 by dying two cells before a tunnel it had correctly
	# decided to slide through.
	for entry in spec.get("spikes", []):
		var spikes := Hazard.new()
		spikes.name = "Spikes_%d_%d" % [origin + int(entry[0]), deck]
		spikes.size_tiles = Vector2(float(entry[2]), 0.5)
		# Sitting in the floor line, so a jump clears them and a walk does not.
		spikes.position = Vector2(_element_centre(origin, entry),
			float(deck) - float(entry[1])) * tile
		add_child(spikes)

	# Spikes hung on the underside of a ceiling: the thing that makes a low
	# tunnel a slide rather than a duck.
	for entry in spec.get("ceiling_spikes", []):
		var teeth := Hazard.new()
		teeth.name = "CeilingSpikes_%d_%d" % [origin + int(entry[0]), deck]
		teeth.size_tiles = Vector2(float(entry[2]), CEILING_SPIKE_DEPTH)
		# Hanging flush under the ceiling's face, so a standing head meets them
		# and a sliding one passes beneath. Derived from the depth rather than
		# written as a fixed offset: the two have to move together, and the
		# version that did not is what made the tunnel impassable.
		teeth.position = Vector2(_element_centre(origin, entry),
			float(deck) - float(entry[1]) + CEILING_SPIKE_DEPTH * 0.5) * tile
		add_child(teeth)

	# Spikes on the floor of a pit the player is already crossing.
	for entry in spec.get("pit_spikes", []):
		var floor_teeth := Hazard.new()
		floor_teeth.name = "PitSpikes_%d_%d" % [origin + int(entry[0]), deck]
		floor_teeth.size_tiles = Vector2(float(entry[2]), 0.5)
		floor_teeth.position = Vector2(_element_centre(origin, entry),
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


## The world-cell centre of a `[x, rows, width]` element, for the classes that
## want a centre rather than a corner. See the note in `_add_elements`.
func _element_centre(origin: int, entry: Array) -> float:
	return float(origin) + float(entry[0]) + float(entry[2]) * 0.5


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


## A KillPlane, not a Hazard: falling off the level is not damage, it is the end
## of the run. A Hazard here honours i-frames, and a player who fell in while
## still flickering from a contact hit fell through it forever.
##
## **One per band, spanning only that band's own columns.** A single plane for
## the stage cannot work once rooms are stacked: hung low enough to sit under the
## bottom band it is beneath the whole level and catches nobody, and left at the
## top band's height it cuts straight through the rooms below and drowns anyone
## standing in them.
func _add_pit_sensor(tile: float) -> void:
	# The lowest band present in each column. A pit belongs under the *bottom*
	# of a column, never under a band that has another one beneath it.
	var table := room_table()
	var deepest: Dictionary = {}
	for index in table.size():
		var col := int(table[index]["col"])
		var band := room_band(index)
		deepest[col] = maxi(int(deepest.get(col, band)), band)

	var columns: Array = deepest.keys()
	columns.sort()

	# Merge neighbouring columns that share a depth into one plane, so a run of
	# level at one height gets one sensor rather than one per screen.
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
	var script := boss_script()
	if script == null:
		return
	var index := arena_room_index()
	var arena_node := BossArena.new()
	arena_node.name = "BossArena"
	arena_node.boss_script = script
	arena_node.arena_room = _rooms[index].get_path()
	arena_node.position = Vector2(float(room_origin(index)) + 4.0,
		float(band_deck_row(room_band(index)))) * tile
	arena_node.boss_offset_tiles = boss_offset_tiles()
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


## The playtest ledger, on for every run of every stage.
##
## **This is here so that a person playing produces the same artefact the bot
## does.** Stage 1's difficulty is the open question in docs/PLAN.md M5b, and the
## one thing that will settle it is somebody playing it -- but a session that
## ends in "that felt hard" settles nothing either. Ending it with a table of
## which rooms cost what, in the same layout tools/playthrough.gd prints, means
## the two can be laid side by side: a cost only the bot pays is the bot's, and a
## cost they both pay is the stage's.
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
	if _backdrop == null:
		return
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


## The boss is down: award, pose, leave.
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
	var path := boss_frames_path()
	if not path.is_empty() and ResourceLoader.exists(path):
		boss_art = load(path)
	var screen := WeaponGet.show_for(self, weapon_name, boss_name(), boss_art)
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
