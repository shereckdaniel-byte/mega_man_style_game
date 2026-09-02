## Stage 1, "Dawn Boardwalk", authored end to end.
##
## Five rooms of boardwalk over floodwater, left to right: four of stage, then
## the arena where Tide is fought. This is the stage the game boots into; `art_preview.tscn` stays as the
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
const TIDE := preload("res://scenes/actors/bosses/tide.gd")

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
## one screen tall, which locks the camera vertically -- the backdrop is placed
## against the viewport, so a camera that drifted would slide the horizon off.
const ROOM_TOP := DECK_ROW - 11
const ROOM_HEIGHT := 15
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

## The bottomless-pit plane: where it starts, and how deep it goes.
const PIT_ROW := DECK_ROW + 10
const PIT_DEPTH := 24

## One row per room, left to right.
##
## `gaps` are [from, to) in cells relative to the room's left edge; `blocks` are
## [x, rows_above_deck, w, h]; `enemies` are [archetype, art, animation, x,
## rows_above_deck]. Everything is room-relative so a room can be moved by
## changing one number.
##
## Two authoring limits, both enforced by tests/test_dawn_boardwalk.gd because
## breaking either produces a stage that looks fine and cannot be finished:
## a block rises at most MAX_STEP_TILES above the deck, and a gap is at most
## MAX_GAP_TILES wide.
const ROOMS := [
	{
		"name": "Arrival",
		"gaps": [],
		"blocks": [],
		"enemies": [
			[WALKER, "dockrat", &"walk", 14.0, 0.0],
			[WALKER, "dockrat", &"walk", 22.0, 0.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Pilings",
		# The first real jump, and a hopper on the far side of it. Two cells,
		# not three: a full jump covers about 3.4 tiles horizontally, so a
		# three-cell gap is clearable only with perfect timing -- which is a
		# late-stage ask, not a first one.
		"gaps": [[10, 12]],
		"blocks": [[18, 2, 4, 2]],
		"enemies": [
			[HOPPER, "bollard", &"hop", 16.0, 0.0],
			[TURRET, "lampjack", &"idle", 23.0, 2.0],
			# 3 tiles up, not 5. A flyer sweeps 1.5 tiles either side of its
			# marker, so 5 put the Gullbot's whole arc at 3.5-6.5 tiles -- above
			# a standing shot (which reaches 1.19) and above a jumping one
			# (4.08) for all but a sliver of its cycle. At 3 it descends to 1.5,
			# where a standing player can catch it at the bottom of the arc.
			[FLYER, "gullbot", &"fly", 8.0, 3.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Wreck",
		# Two gaps and a raised span: the room that asks for the jump arc.
		"gaps": [[7, 9], [18, 20]],
		# Both two tiles above the deck, not three. PlayerTuning's jump clears 2.89
		# tiles, and test_player_movement asserts 2 is clearable and 3 is not -- so
		# a three-tile step in a corridor with no way round it is a wall, and the
		# first draft of this room had one. The playthrough stopped dead at it.
		"blocks": [[12, 2, 4, 2], [24, 2, 3, 2]],
		"enemies": [
			[SPAWNER, "barnacle_hive", &"idle", 13.0, 4.0],
			[CRAWLER, "limpet", &"crawl", 5.0, 0.0],
			[WALKER, "dockrat", &"walk", 15.0, 0.0],
			[TURRET, "lampjack", &"idle", 26.0, 2.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Boss Door",
		# Deliberately empty. The run-up to a boss is a breath, not a fight.
		"gaps": [],
		"blocks": [],
		"enemies": [],
		"checkpoint": 2.0,
	},
	{
		"name": "Arena",
		# Flat, empty, and no checkpoint. The arena is the fight and nothing
		# else: a gap here would decide the fight instead of the boss, and a
		# checkpoint inside it would let a player who died mid-fight respawn
		# past the seal with the boss already gone.
		"gaps": [],
		"blocks": [],
		"enemies": [],
		"checkpoint": NO_CHECKPOINT,
	},
]

## Index of the arena in ROOMS, and of the last room the player walks through.
const ARENA_ROOM := 4
const BOSS_DOOR_ROOM := 3

var _player: Player
var _deck: TileMapLayer
var _rooms: Array[Room] = []


func _ready() -> void:
	var autoload := get_node_or_null(^"/root/Tuning")
	var tuning: PlayerTuning = autoload.player if autoload != null else PlayerTuning.new()
	var tile := tuning.tile_size()

	var background := Node2D.new()
	background.name = "Backdrop"
	background.set_script(BACKGROUND)
	add_child(background)

	_build_deck(tuning.world_scale)
	_build_rooms(tile)
	_add_pit_sensor(tile)

	_player = PLAYER_SCENE.instantiate()
	_player.position = Vector2(2.0, float(DECK_ROW) - 2.0) * tile
	add_child(_player)

	_add_arena(tile)
	_add_hud()
	_add_pause_menu()
	begin(_player, _rooms[0])


## Left edge of a room, in cells.
static func room_origin(index: int) -> int:
	return index * ROOM_WIDTH


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
		for x in range(origin, origin + ROOM_WIDTH):
			if _in_gap(spec, x - origin):
				continue
			for y in range(DECK_ROW, DECK_ROW + DECK_DEPTH):
				cells.append(Vector2i(x, y))
		for block in spec["blocks"]:
			var bx := origin + int(block[0])
			var by := DECK_ROW - int(block[1])
			for x in range(bx, bx + int(block[2])):
				for y in range(by, by + int(block[3])):
					var cell := Vector2i(x, y)
					if not cells.has(cell):
						cells.append(cell)

	_deck.set_cells_terrain_connect(cells, 0, 0)


func _in_gap(spec: Dictionary, local_x: int) -> bool:
	for gap in spec["gaps"]:
		if local_x >= int(gap[0]) and local_x < int(gap[1]):
			return true
	return false


func _build_rooms(tile: float) -> void:
	for index in ROOMS.size():
		var spec: Dictionary = ROOMS[index]
		var origin := room_origin(index)

		var room := Room.new()
		room.name = "Room%d_%s" % [index, String(spec["name"]).replace(" ", "")]
		room.bounds_tiles = Rect2i(origin, ROOM_TOP, ROOM_WIDTH, ROOM_HEIGHT)
		add_child(room)
		_rooms.append(room)

		var checkpoint_cell := float(spec["checkpoint"])
		if not is_equal_approx(checkpoint_cell, NO_CHECKPOINT):
			var checkpoint := Checkpoint.new()
			checkpoint.name = "%s_Checkpoint" % room.name
			checkpoint.position = Vector2(float(origin) + checkpoint_cell,
				float(DECK_ROW)) * tile
			add_child(checkpoint)

		for entry in spec["enemies"]:
			_add_marker(entry, origin, tile)

	# Doors last, so every room exists to be named.
	for index in _rooms.size() - 1:
		var door := Door.new()
		door.name = "Door%d" % index
		door.to_room = _rooms[index + 1].get_path()
		door.direction = Vector2.RIGHT
		# On the room's right edge, one cell in, so the player is inside the
		# outgoing room when it fires.
		door.position = Vector2(float(room_origin(index) + ROOM_WIDTH - 1),
			float(DECK_ROW)) * tile
		add_child(door)


func _add_marker(entry: Array, origin: int, tile: float) -> void:
	var frames_path := "res://resources/sprite_frames/%s.tres" % entry[1]
	if not ResourceLoader.exists(frames_path):
		return
	var marker := SpawnMarker.new()
	marker.name = "Spawn_%s_%d" % [String(entry[1]).capitalize(), origin + int(entry[3])]
	marker.enemy_scene = _enemy_scene(entry[0], load(frames_path), entry[2])
	marker.position = Vector2(float(origin) + float(entry[3]),
		float(DECK_ROW) - float(entry[4])) * tile
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
func _add_pit_sensor(tile: float) -> void:
	var width := ROOM_WIDTH * ROOMS.size() + 8
	var pit := KillPlane.new()
	pit.name = "Pit"
	pit.size_tiles = Vector2(float(width), float(PIT_DEPTH))
	pit.position = Vector2(-4.0 + float(width) * 0.5,
		float(PIT_ROW) + float(PIT_DEPTH) * 0.5) * tile
	add_child(pit)


## The boss room. The trigger sits a few cells inside the arena so the player is
## fully through the doorway before the room seals -- sealing on the threshold
## would trap them half in the door frame.
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


## Tide is down. Show what the player got, and only then give control back.
func _on_boss_cleared(_index: int, weapon_id: StringName) -> void:
	var weapons := get_node_or_null(^"/root/WeaponManager")
	var data: WeaponData = weapons.data_for(weapon_id) if weapons != null else null
	var weapon_name := data.display_name if data != null else String(weapon_id).capitalize()
	if _player != null:
		_player.set_frozen(true)
	var screen := WeaponGet.show_for(self, weapon_name, "Tide")
	screen.finished.connect(func() -> void:
		if _player != null and is_instance_valid(_player):
			_player.set_frozen(false))
