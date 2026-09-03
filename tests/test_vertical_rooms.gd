## Vertical room transitions: climbing a ladder from one screen to the next.
##
## The M4 item deferred as "not needed by stage 1". It is needed now, and it
## turned out the camera never had to change: `begin_slide` already merges room
## bounds on both axes and `slide_target` already clamps both, so the slide was
## axis-agnostic from the day it was written. What was missing was a door that
## knew which way round it was.
extends TestCase

const PLAYER_SCENE := preload("res://scenes/actors/player/player.tscn")
const StageScript := preload("res://scenes/level/stage.gd")
const LadderScript := preload("res://scenes/level/ladder.gd")

const TILE := 72.0
## Two rooms stacked: the lower one's top edge is the upper one's bottom.
const ROOM_W := 27
const ROOM_H := 15
## Column the ladder and the vertical door share.
const LADDER_X := 8

var stage: Stage
var player: Player
var lower: Room
var upper: Room


func is_async() -> bool:
	return true


func before_each_async() -> void:
	_release_all()
	stage = StageScript.new() as Stage
	stage.name = "VerticalStage"
	tree.root.add_child(stage)

	lower = _room("Lower", Rect2i(0, ROOM_H, ROOM_W, ROOM_H))
	upper = _room("Upper", Rect2i(0, 0, ROOM_W, ROOM_H))

	# The lower room's floor, full width.
	_floor(0, ROOM_W, float(ROOM_H * 2) * TILE)
	# The upper room's floor sits on the boundary between the two -- with a hole
	# in it for the ladder. A ladder that runs into a solid ceiling is a ladder
	# the player climbs two tiles of and then stops, which is exactly what the
	# first version of this fixture built.
	_floor(0, LADDER_X - 1, float(ROOM_H) * TILE)
	_floor(LADDER_X + 2, ROOM_W - LADDER_X - 2, float(ROOM_H) * TILE)

	player = PLAYER_SCENE.instantiate()
	# Standing on the lower floor, at the foot of the ladder.
	player.position = Vector2(float(LADDER_X) * TILE, float(ROOM_H * 2) * TILE)
	stage.add_child(player)

	stage.begin(player, lower)
	await _frames(6)


func after_each_async() -> void:
	_release_all()
	if is_instance_valid(stage):
		stage.queue_free()
	await tree.physics_frame


# --- The door ------------------------------------------------------------------------

func test_a_door_knows_which_way_round_it_is() -> void:
	var across := _door(Vector2.RIGHT, upper, Vector2(10.0 * TILE, float(ROOM_H * 2) * TILE))
	var up := _door(Vector2.UP, upper, Vector2(14.0 * TILE, float(ROOM_H) * TILE))
	await _frames(2)
	assert_false(across.is_vertical())
	assert_true(up.is_vertical())


## A vertical door has to be wide and shallow. Left tall and thin -- the shape a
## horizontal door wants -- it becomes a doorpost the player walks past.
func test_a_vertical_door_is_wide_rather_than_tall() -> void:
	var up := _door(Vector2.UP, upper, Vector2(8.0 * TILE, float(ROOM_H) * TILE))
	await _frames(2)
	var shape: CollisionShape2D = null
	for child in up.get_children():
		if child is CollisionShape2D:
			shape = child
	assert_not_null(shape)
	var rect := shape.shape as RectangleShape2D
	assert_true(rect.size.x > rect.size.y,
		"the vertical door is %.0f x %.0f -- taller than it is wide" % [rect.size.x, rect.size.y])


# --- The transition ------------------------------------------------------------------

## The whole point: climbing up a ladder moves the camera to the room above.
func test_climbing_through_a_vertical_door_changes_room() -> void:
	var boundary := float(ROOM_H) * TILE
	# A ladder spanning the boundary, so the player still has something to hold
	# when they arrive -- see the note in door.gd.
	_ladder(Vector2(float(LADDER_X) * TILE, float(ROOM_H * 2) * TILE), 17)
	_door(Vector2.UP, upper, Vector2(float(LADDER_X) * TILE, boundary))
	await _frames(2)

	var entered: Array[String] = []
	stage.room_changed.connect(func(r: Room) -> void: entered.append(String(r.name)))

	player.global_position = Vector2(float(LADDER_X) * TILE, float(ROOM_H * 2) * TILE)
	Input.action_press(&"move_up")
	for i in 400:
		await tree.physics_frame
		if stage.room == upper:
			break
	Input.action_release(&"move_up")

	assert_eq(stage.room, upper, "still in %s after climbing" % stage.room.name)
	assert_has(entered, "Upper")


## The camera has to follow. A room change that leaves the camera behind is the
## failure that looks like the level broke rather than the camera.
func test_the_camera_moves_to_the_room_above() -> void:
	var boundary := float(ROOM_H) * TILE
	_ladder(Vector2(float(LADDER_X) * TILE, float(ROOM_H * 2) * TILE), 17)
	_door(Vector2.UP, upper, Vector2(float(LADDER_X) * TILE, boundary))
	await _frames(2)

	var camera_before := stage.camera.global_position.y
	player.global_position = Vector2(float(LADDER_X) * TILE, float(ROOM_H * 2) * TILE)
	Input.action_press(&"move_up")
	for i in 400:
		await tree.physics_frame
		if stage.room == upper and not stage.is_transitioning():
			break
	Input.action_release(&"move_up")

	assert_true(stage.camera.global_position.y < camera_before - 200.0,
		"the camera only rose %.0f px" % (camera_before - stage.camera.global_position.y))
	assert_eq(stage.camera.limit_top, int(upper.world_bounds().position.y),
		"the camera limits were not handed to the new room")


## The transition is on rails in both axes: the player must not be left below
## the boundary they just crossed, or they immediately fall back through it.
func test_the_player_ends_up_above_the_boundary() -> void:
	var boundary := float(ROOM_H) * TILE
	_ladder(Vector2(float(LADDER_X) * TILE, float(ROOM_H * 2) * TILE), 17)
	_door(Vector2.UP, upper, Vector2(float(LADDER_X) * TILE, boundary))
	await _frames(2)

	player.global_position = Vector2(float(LADDER_X) * TILE, float(ROOM_H * 2) * TILE)
	Input.action_press(&"move_up")
	for i in 400:
		await tree.physics_frame
		if stage.room == upper and not stage.is_transitioning():
			break
	Input.action_release(&"move_up")
	assert_true(player.global_position.y < boundary,
		"the player finished at y=%.0f, still below the boundary at %.0f"
			% [player.global_position.y, boundary])


# --- Helpers -------------------------------------------------------------------------

func _room(room_name: String, bounds: Rect2i) -> Room:
	var r := Room.new()
	r.name = room_name
	r.bounds_tiles = bounds
	stage.add_child(r)
	return r


func _door(direction: Vector2, to: Room, at: Vector2) -> Door:
	var d := Door.new()
	d.name = "Door_%s_%d" % [to.name, stage.get_child_count()]
	d.direction = direction
	d.position = at
	stage.add_child(d)
	# Absolute, not relative to the door: Door.target_room resolves the path
	# from the *stage*, so a path relative to the door silently finds nothing
	# and the transition never fires -- which looks exactly like a trigger that
	# is not being entered.
	d.to_room = to.get_path()
	return d


func _ladder(foot: Vector2, height: int) -> Ladder:
	var l := LadderScript.new() as Ladder
	l.height_tiles = height
	l.position = foot
	stage.add_child(l)
	return l


## A floor slab from tile column `from_tile`, `width_tiles` wide, whose top
## surface is at world `top_y`.
func _floor(from_tile: int, width_tiles: int, top_y: float) -> void:
	if width_tiles <= 0:
		return
	var body := StaticBody2D.new()
	body.collision_layer = Layers.bit(Layers.WORLD)
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(float(width_tiles) * TILE, 2.0 * TILE)
	shape.shape = rect
	body.add_child(shape)
	body.position = Vector2(float(from_tile) * TILE + rect.size.x * 0.5,
		top_y + rect.size.y * 0.5)
	stage.add_child(body)


func _frames(count: int) -> void:
	for i in count:
		await tree.physics_frame


func _release_all() -> void:
	for action in [&"move_left", &"move_right", &"move_up", &"move_down",
			&"jump", &"shoot", &"melee"]:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			Input.action_release(action)
