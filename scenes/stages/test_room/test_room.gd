## M1 tuning room.
##
## Geometry is built in code from a tile-coordinate table rather than authored
## as a .tscn, because every block here exists to test one number and the table
## says which. Ledge heights in particular straddle the jump apex: 2 tiles must
## be clearable and 3 must not.
extends Node2D

const PLAYER_SCENE := preload("res://scenes/actors/player/player.tscn")
const LADDER_SCRIPT := preload("res://scenes/level/ladder.gd")

## Layer bits.
const L_WORLD := 1 << 0
const L_ONE_WAY := 1 << 1

const GROUND_ROW := 13

## [x, y, w, h] in tiles, plus a note saying what the block is for.
const SOLIDS := [
	[-1, 0, 1, 15, "wall"],
	[26, 0, 1, 15, "wall"],
	[0, GROUND_ROW, 10, 2, "ground"],
	[13, GROUND_ROW, 14, 2, "ground"],
	[4, GROUND_ROW - 1, 1, 1, "step 1 tile"],
	[6, GROUND_ROW - 2, 1, 2, "step 2 tiles - clearable"],
	[8, GROUND_ROW - 3, 1, 3, "step 3 tiles - must NOT be clearable"],
	[15, GROUND_ROW - 4, 4, 3, "low tunnel roof - slide only"],
	[20, GROUND_ROW - 5, 3, 1, "ladder landing"],
]

## [x, y, w] in tiles.
const ONE_WAY := [
	[23, GROUND_ROW - 3, 3],
]

## [x, foot_y, height] in tiles.
const LADDERS := [
	[21, GROUND_ROW, 5],
]

const SPAWN_TILE := Vector2(2, GROUND_ROW)

var _tile := 48.0
var _player: Player


func _ready() -> void:
	var autoload := get_node_or_null(^"/root/Tuning")
	_tile = autoload.player.tile_size() if autoload != null else 48.0

	for entry in SOLIDS:
		_add_box(entry[0], entry[1], entry[2], entry[3], L_WORLD)
	for entry in ONE_WAY:
		_add_one_way(entry[0], entry[1], entry[2])
	for entry in LADDERS:
		_add_ladder(entry[0], entry[1], entry[2])

	_player = PLAYER_SCENE.instantiate()
	_player.position = SPAWN_TILE * _tile
	add_child(_player)

	_add_camera()
	_add_overlay()
	queue_redraw()


func _add_box(tx: int, ty: int, tw: int, th: int, layer: int) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(float(tw), float(th)) * _tile
	shape.shape = rect
	body.add_child(shape)
	# Tile coordinates address a box's top-left corner; shapes are centred.
	body.position = Vector2(float(tx), float(ty)) * _tile + rect.size * 0.5
	add_child(body)
	return body


## Drop-through platforms. Godot models these with a one-way flag on the
## collision shape rather than a distinct node type.
func _add_one_way(tx: int, ty: int, tw: int) -> void:
	var body := _add_box(tx, ty, tw, 1, L_ONE_WAY)
	for child in body.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).one_way_collision = true


func _add_ladder(tx: int, foot_ty: int, height: int) -> void:
	var ladder := Area2D.new()
	ladder.set_script(LADDER_SCRIPT)
	ladder.height_tiles = height
	# Addressed by the centre of the column, at the foot.
	ladder.position = Vector2(float(tx) + 0.5, float(foot_ty)) * _tile
	add_child(ladder)


func _add_camera() -> void:
	var camera := Camera2D.new()
	camera.position_smoothing_enabled = false
	camera.ignore_rotation = true
	_player.add_child(camera)
	camera.make_current()


func _add_overlay() -> void:
	var overlay := CanvasLayer.new()
	overlay.set_script(load("res://scenes/ui/debug_overlay.gd"))
	# Absolute path, set before the overlay enters the tree: its _ready resolves
	# the player, so assigning afterwards leaves it looking at nothing.
	overlay.player_path = _player.get_path()
	add_child(overlay)


## Draws the geometry. Debug-only: real stages use a TileMapLayer from M4.
func _draw() -> void:
	var solid := Color(0.16, 0.19, 0.27)
	var edge := Color(0.35, 0.42, 0.58)
	for entry in SOLIDS:
		var r := Rect2(Vector2(float(entry[0]), float(entry[1])) * _tile,
			Vector2(float(entry[2]), float(entry[3])) * _tile)
		draw_rect(r, solid)
		draw_rect(r, edge, false, 2.0)
	for entry in ONE_WAY:
		draw_rect(Rect2(Vector2(float(entry[0]), float(entry[1])) * _tile,
			Vector2(float(entry[2]), 0.25) * _tile), Color(0.30, 0.45, 0.30))
	for entry in LADDERS:
		var x := (float(entry[0]) + 0.5) * _tile
		var foot := float(entry[1]) * _tile
		var head := foot - float(entry[2]) * _tile
		var rail := Color(0.75, 0.62, 0.35)
		draw_line(Vector2(x - 0.25 * _tile, foot), Vector2(x - 0.25 * _tile, head), rail, 3.0)
		draw_line(Vector2(x + 0.25 * _tile, foot), Vector2(x + 0.25 * _tile, head), rail, 3.0)
		var rung := head
		while rung < foot:
			draw_line(Vector2(x - 0.25 * _tile, rung), Vector2(x + 0.25 * _tile, rung), rail, 3.0)
			rung += _tile * 0.5
