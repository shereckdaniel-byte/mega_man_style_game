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
## today. It is still scaffolding, not a level: the deck is built in _ready()
## from the table below rather than authored, there is nothing to do on it, and
## the camera fakes its framing with an offset. Real stages come in M4 and this
## goes back to being a preview.
extends Node2D

const BACKGROUND := preload("res://scenes/stages/dawn_boardwalk/parallax_background.gd")
const PLAYER_SCENE := preload("res://scenes/actors/player/player.tscn")
const TILESET := preload("res://resources/tilesets/dawn_boardwalk.tres")

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

## Screen pixels of sky kept above the player. The backdrop is placed against
## the viewport, not the world, so the horizon sits at a fixed height on screen
## and the deck has to be framed below it. 280 puts the deck's surface a little
## under the waterline, which is what a boardwalk standing in floodwater looks
## like. M4 does this with camera limits; until then this stands in for them.
const HORIZON_HEADROOM := 280.0

var _player: Player


func _ready() -> void:
	var autoload := get_node_or_null(^"/root/Tuning")
	var tuning: PlayerTuning = autoload.player if autoload != null else PlayerTuning.new()

	var background := Node2D.new()
	background.name = "Backdrop"
	background.set_script(BACKGROUND)
	add_child(background)

	_add_deck(tuning.world_scale)

	_add_end_stops(tuning.tile_size())

	_player = PLAYER_SCENE.instantiate()
	# Half a tile up, because the walking surface runs through the middle of the
	# top row; a couple of tiles higher again so the drop proves the collision.
	_player.position = Vector2(SPAWN_CELL.x, SPAWN_CELL.y - 2.0) * tuning.tile_size()
	add_child(_player)

	_add_camera()


## The deck has ends, and this is the scene the game boots into, so walking off
## one would drop the player into an endless fall with nothing to respawn them.
## Invisible stops at both ends, the same trick the tuning room uses for its
## room edges, keep a look around from turning into a stuck game.
func _add_end_stops(tile: float) -> void:
	for cell_x in [DECK_FROM - 1, DECK_TO]:
		var body := StaticBody2D.new()
		body.collision_layer = 1 << 0
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(tile, tile * (DECK_DEPTH + 8))
		shape.shape = rect
		body.add_child(shape)
		body.position = Vector2(float(cell_x) * tile, float(DECK_ROW - 8) * tile) \
			+ rect.size * 0.5
		add_child(body)


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
		for y in range(DECK_ROW, DECK_ROW + DECK_DEPTH):
			cells.append(Vector2i(x, y))
	for entry in RAISED:
		for x in range(int(entry[0]), int(entry[0]) + int(entry[2])):
			for y in range(int(entry[1]), int(entry[1]) + int(entry[3])):
				var cell := Vector2i(x, y)
				if not cells.has(cell):
					cells.append(cell)

	deck.set_cells_terrain_connect(cells, 0, 0)


func _add_camera() -> void:
	var camera := Camera2D.new()
	camera.position_smoothing_enabled = false
	camera.ignore_rotation = true
	# Frames the deck low, the way a real stage will. The tuning room's camera
	# is centred on the player, which puts the walking surface across the middle
	# of the screen and buries the horizon -- fine for reading a debug overlay,
	# wrong for judging a backdrop. M4 does this properly with camera limits;
	# until then this offset stands in for them.
	camera.offset = Vector2(0.0, -HORIZON_HEADROOM)
	_player.add_child(camera)
	camera.make_current()
