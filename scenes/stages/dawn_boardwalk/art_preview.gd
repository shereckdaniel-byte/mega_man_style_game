## Stage 1 art, assembled: the parallax backdrop, a boardwalk laid from the
## generated tileset, and the player standing on it.
##
## This is the cheap answer to the question SPRITES.md section 8 left open --
## pixel terrain behind a smooth anti-aliased character is a deliberate mixed
## style, and the only way to settle it is to look at the two together at the
## size they are actually seen, before generating seven more stages of it.
##
## The deck is painted with `set_cells_terrain_connect` rather than by naming
## tiles, so it is also the check on the importer: if the Wang corner data were
## wrong, the autotiler would pick the wrong edges and it would show here.
##
## This is where boot.gd lands a windowed run, so it is what the game looks like
## today. It is a Stage now rather than a bare Node2D, so the room bounds and the
## camera are the real ones -- the invisible walls at the deck ends and the fixed
## camera offset it used to fake those with are gone.
##
## Still scaffolding, not a level: the deck is built in _ready() from the table
## below rather than authored, and there is nothing on it to fight. Authored
## stages are the rest of M4.
extends Stage

const BACKGROUND := preload("res://scenes/stages/dawn_boardwalk/parallax_background.gd")
const PLAYER_SCENE := preload("res://scenes/actors/player/player.tscn")
const TILESET := preload("res://resources/tilesets/dawn_boardwalk.tres")
const HUD_SCRIPT := preload("res://scenes/ui/hud.gd")

## A gap in the deck, [from, to) in cells. Falling through it is the M3
## acceptance case: the pit sensor below kills, and a knockback you cannot steer
## out of is what puts you in it.
const GAP := [18, 22]

## Cells below the deck where the bottomless-pit sensor sits.
const PIT_ROW := DECK_ROW + 12

## Row of the deck's top cell. Corner terrain puts the walking surface half a
## tile below that, through the middle of the row -- see the importer header.
const DECK_ROW := 11
const DECK_DEPTH := 2
const DECK_FROM := -14
const DECK_TO := 34

## [x, y, w, h] in cells: a raised section and a stub, so the autotiler has to
## produce outside corners, inside corners and ends rather than just a flat run.
const RAISED := [
	[12, DECK_ROW - 2, 6, 2],
	[24, DECK_ROW - 4, 3, 4],
]

const SPAWN_CELL := Vector2(2, DECK_ROW)

## The room, in tiles. Wide enough to walk, and exactly one screen tall so the
## camera is vertically locked -- the backdrop is placed against the viewport, so
## a camera that drifted vertically would slide the horizon off the top.
const ROOM_TILES := Rect2i(DECK_FROM - 1, DECK_ROW - 11, DECK_TO - DECK_FROM + 2, 15)

var _player: Player


func _ready() -> void:
	var autoload := get_node_or_null(^"/root/Tuning")
	var tuning: PlayerTuning = autoload.player if autoload != null else PlayerTuning.new()

	var background := Node2D.new()
	background.name = "Backdrop"
	background.set_script(BACKGROUND)
	add_child(background)

	_add_deck(tuning.world_scale)

	_add_pit_sensor(tuning.tile_size())
	_add_checkpoints(tuning.tile_size())

	var room := Room.new()
	room.name = "Room"
	room.bounds_tiles = ROOM_TILES
	add_child(room)

	_player = PLAYER_SCENE.instantiate()
	# Half a tile up, because the walking surface runs through the middle of the
	# top row; a couple of tiles higher again so the drop proves the collision.
	_player.position = Vector2(SPAWN_CELL.x, SPAWN_CELL.y - 2.0) * tuning.tile_size()
	add_child(_player)

	_add_hud()
	# The room's limits are what stop the player leaving now, and the camera's
	# vertical anchor is what frames the deck low. Both used to be faked here --
	# invisible walls at the deck ends, and a fixed camera offset.
	begin(_player, room)


## Below the gap, and below the ends of the deck: anything that leaves the
## boardwalk has left the stage. One wide sensor rather than one per hole means
## a new gap in the deck needs no matching edit here.
func _add_pit_sensor(tile: float) -> void:
	var pit := Hazard.new()
	pit.name = "Pit"
	pit.size_tiles = Vector2(float(DECK_TO - DECK_FROM + 4), 2.0)
	pit.position = Vector2(float(DECK_FROM - 2) + pit.size_tiles.x * 0.5,
		float(PIT_ROW)) * tile
	add_child(pit)


## Cells 8 and 28 are plain deck. A checkpoint over the GAP would respawn the
## player straight back into the pit, which is an infinite death loop rather
## than a difficulty spike -- the first draft of this had one at cell 20 and it
## cost every life in the counter.
func _add_checkpoints(tile: float) -> void:
	for cell_x in [SPAWN_CELL.x, 8.0, 28.0]:
		var checkpoint := Checkpoint.new()
		checkpoint.position = Vector2(float(cell_x), float(DECK_ROW)) * tile
		add_child(checkpoint)


func _add_hud() -> void:
	var hud := HUD_SCRIPT.new()
	hud.name = "Hud"
	add_child(hud)
	hud.track(_player)


func _add_deck(world_scale: float) -> void:
	var deck := TileMapLayer.new()
	deck.name = "Boardwalk"
	deck.tile_set = TILESET
	# 16 px art on a 72 px grid: the tileset keeps its native cell size and the
	# layer is scaled, which is the same 4.5x every other world metric uses.
	deck.scale = Vector2(world_scale, world_scale)
	# Pixel art magnified 4.5x. The project default is Linear and has to stay
	# Linear for the character -- see SPRITES.md section 8.
	deck.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(deck)

	var cells: Array[Vector2i] = []
	for x in range(DECK_FROM, DECK_TO):
		if x >= int(GAP[0]) and x < int(GAP[1]):
			continue
		for y in range(DECK_ROW, DECK_ROW + DECK_DEPTH):
			cells.append(Vector2i(x, y))
	for entry in RAISED:
		for x in range(int(entry[0]), int(entry[0]) + int(entry[2])):
			for y in range(int(entry[1]), int(entry[1]) + int(entry[3])):
				var cell := Vector2i(x, y)
				if not cells.has(cell):
					cells.append(cell)

	deck.set_cells_terrain_connect(cells, 0, 0)
