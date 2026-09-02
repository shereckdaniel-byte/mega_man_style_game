## Rooms, the scroll-locked camera, and the spawn/despawn rule.
##
## The respawn-on-rescroll rule is the M4 acceptance criterion and the easiest
## thing here to get subtly wrong, because every wrong version still *looks*
## like a working game: enemies that never come back, enemies that stack up,
## enemies that flicker on a boundary. Each of those has a test below.
extends TestCase

const PLAYER_SCENE := preload("res://scenes/actors/player/player.tscn")
const WALKER := preload("res://scenes/actors/enemies/walker.gd")

const FLOOR_TOP := 400.0

var root: Node2D
var tile := 72.0


func is_async() -> bool:
	return true


func before_each_async() -> void:
	root = Node2D.new()
	tree.root.add_child(root)
	var autoload := tree.root.get_node_or_null(^"/root/Tuning")
	tile = autoload.player.tile_size() if autoload != null else 72.0
	await tree.physics_frame


func after_each_async() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


# --- Rooms --------------------------------------------------------------------

func test_room_bounds_convert_from_tiles_to_world() -> void:
	var room := Room.new()
	room.bounds_tiles = Rect2i(2, 1, 26, 15)
	root.add_child(room)
	var bounds := room.world_bounds()
	assert_almost_eq(bounds.position.x, 2.0 * tile, 0.5)
	assert_almost_eq(bounds.size.x, 26.0 * tile, 0.5)
	assert_almost_eq(bounds.size.y, 15.0 * tile, 0.5)


## A room smaller than the viewport gives the camera limits it cannot satisfy,
## and Godot resolves that by pinning to the left/top edge -- which looks like a
## stuck camera rather than like a too-small room. Better to state the rule.
func test_a_room_is_at_least_one_screen_in_each_axis() -> void:
	var room := Room.new()
	root.add_child(room)
	var bounds := room.world_bounds()
	# The configured viewport, not the live one: a headless run's window is not
	# necessarily the project's resolution, and this is a statement about the
	# design rule rather than about whatever window the test happens to have.
	var view := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height")))
	assert_true(bounds.size.x >= view.x - tile,
		"default room is at least a screen wide (%.0f vs %.0f)" % [bounds.size.x, view.x])
	assert_true(bounds.size.y >= view.y - tile,
		"default room is at least a screen tall (%.0f vs %.0f)" % [bounds.size.y, view.y])


# --- The camera ---------------------------------------------------------------

func test_the_camera_stops_at_the_room_edge_rather_than_following_past_it() -> void:
	var stage := _build_stage(Rect2i(0, 0, 40, 15))
	var player: Player = stage.player
	await _frames(4)

	# Walk the player far past the right edge of the room.
	player.global_position.x = 60.0 * tile
	await _frames(4)
	var view := stage.camera.view_rect()
	assert_true(view.end.x <= stage.room.world_bounds().end.x + 1.0,
		"view stops at the room's right edge (%.0f) rather than following to %.0f"
			% [view.end.x, player.global_position.x])


func test_the_camera_keeps_the_player_below_centre() -> void:
	# A room exactly one screen tall gives the camera no vertical slack at all --
	# it is clamped top and bottom, and the anchor cannot do anything. Measuring
	# the anchor needs a room taller than the view, which is also the only case
	# where the anchor matters.
	var stage := _build_stage(Rect2i(0, 0, 40, 40))
	await _frames(6)
	stage.player.global_position = Vector2(20.0 * tile, 20.0 * tile)
	await _frames(4)
	var view := stage.camera.view_rect()
	var fraction := (stage.player.global_position.y - view.position.y) / view.size.y
	assert_between(fraction, 0.5, 0.8,
		"player sits below centre so there is sky above them")


# --- Spawn and despawn --------------------------------------------------------

func test_a_marker_spawns_when_the_camera_comes_near() -> void:
	var stage := _build_stage(Rect2i(0, 0, 60, 15))
	var marker := _add_marker(stage, Vector2(6.0 * tile, FLOOR_TOP))
	await _frames(4)
	assert_not_null(marker.live_enemy(), "marker in view has spawned")
	assert_false(marker.is_armed())


func test_a_marker_far_away_stays_armed_and_empty() -> void:
	var stage := _build_stage(Rect2i(0, 0, 60, 15))
	var marker := _add_marker(stage, Vector2(50.0 * tile, FLOOR_TOP))
	await _frames(4)
	assert_eq(marker.live_enemy(), null, "well outside the view; nothing spawned")
	assert_true(marker.is_armed())


## The acceptance criterion: scrolling back and forth yields a fresh enemy every
## time. That is the original's behaviour and level design depends on it.
func test_scrolling_away_and_back_respawns_the_enemy() -> void:
	var stage := _build_stage(Rect2i(0, 0, 120, 15))
	var marker := _add_marker(stage, Vector2(6.0 * tile, FLOOR_TOP))
	await _frames(4)
	var first := marker.live_enemy()
	assert_not_null(first, "spawned on approach")

	stage.player.global_position.x = 100.0 * tile      # scroll it off screen
	await _frames(6)
	assert_eq(marker.live_enemy(), null, "freed once well off screen")
	assert_true(marker.is_armed(), "and re-armed")

	stage.player.global_position.x = 6.0 * tile        # come back
	await _frames(6)
	var second := marker.live_enemy()
	assert_not_null(second, "a fresh one on return")
	assert_false(first == second, "a new instance, not the old one revived")


## Killing an enemy must NOT re-arm its marker. If it did, a player could farm
## one enemy by standing still; the original makes you scroll it off and back.
func test_killing_an_enemy_does_not_re_arm_its_marker() -> void:
	var stage := _build_stage(Rect2i(0, 0, 60, 15))
	var marker := _add_marker(stage, Vector2(6.0 * tile, FLOOR_TOP))
	await _frames(4)
	var enemy := marker.live_enemy() as Enemy
	assert_not_null(enemy)
	enemy.health.kill()
	await _frames(6)
	assert_eq(marker.live_enemy(), null, "the enemy is gone")
	await _frames(20)
	assert_eq(marker.live_enemy(), null,
		"and does not come back while the camera has not left")


## The two margins differ so an enemy on the boundary does not spawn, despawn
## and spawn again as the camera jitters by a pixel. One margin would do exactly
## that, and it would look like flickering rather than like a boundary bug.
func test_the_despawn_margin_is_wider_than_the_spawn_margin() -> void:
	assert_true(SpawnMarker.DESPAWN_MARGIN_NES > SpawnMarker.SPAWN_MARGIN_NES,
		"hysteresis: %f must exceed %f"
			% [SpawnMarker.DESPAWN_MARGIN_NES, SpawnMarker.SPAWN_MARGIN_NES])


func test_a_marker_holds_one_enemy_at_a_time() -> void:
	var stage := _build_stage(Rect2i(0, 0, 60, 15))
	var marker := _add_marker(stage, Vector2(6.0 * tile, FLOOR_TOP))
	await _frames(20)
	assert_eq(stage.live_enemies(), 1, "twenty frames in view, still one enemy")


## Persistent markers are how bosses and gimmick platforms opt out
## (ARCHITECTURE section 5.5) -- a boss that despawned mid-fight because the
## camera drifted would be a spectacular bug.
func test_a_persistent_enemy_survives_the_camera_leaving() -> void:
	var stage := _build_stage(Rect2i(0, 0, 120, 15))
	var marker := _add_marker(stage, Vector2(6.0 * tile, FLOOR_TOP))
	marker.persistent = true
	await _frames(4)
	var enemy := marker.live_enemy()
	assert_not_null(enemy)
	stage.player.global_position.x = 100.0 * tile
	await _frames(8)
	assert_true(is_instance_valid(enemy), "still alive well off screen")


# --- The walker ---------------------------------------------------------------

func test_a_walker_turns_around_at_a_ledge_rather_than_walking_off() -> void:
	var stage := _build_stage(Rect2i(0, 0, 60, 15), false)
	# A short plank with nothing beyond either end.
	_add_floor(Vector2(4.0 * tile, FLOOR_TOP), Vector2(6.0 * tile, 2.0 * tile))
	var walker := WALKER.new() as Enemy
	walker.global_position = Vector2(7.0 * tile, FLOOR_TOP)
	root.add_child(walker)
	await _frames(180)
	assert_true(is_instance_valid(walker), "still alive")
	assert_between(walker.global_position.x, 4.0 * tile - tile, 10.0 * tile + tile,
		"stayed on the plank instead of walking off it")
	assert_almost_eq(walker.global_position.y, FLOOR_TOP, tile,
		"and did not fall")


# --- Helpers ------------------------------------------------------------------

func _build_stage(bounds: Rect2i, with_floor: bool = true) -> Stage:
	if with_floor:
		_add_floor(Vector2(-10.0 * tile, FLOOR_TOP),
			Vector2(200.0 * tile, 4.0 * tile))
	var stage := Stage.new()
	root.add_child(stage)

	var room := Room.new()
	room.bounds_tiles = bounds
	stage.add_child(room)

	var player: Player = PLAYER_SCENE.instantiate()
	player.position = Vector2(4.0 * tile, FLOOR_TOP)
	stage.add_child(player)

	stage.begin(player, room)
	return stage


func _add_marker(stage: Stage, at: Vector2) -> SpawnMarker:
	var marker := SpawnMarker.new()
	marker.enemy_scene = _walker_scene()
	marker.position = at
	stage.add_child(marker)
	stage.refresh_markers()
	return marker


## A PackedScene wrapping the walker script, since markers take scenes.
func _walker_scene() -> PackedScene:
	var walker := WALKER.new() as Node2D
	walker.name = "Walker"
	var packed := PackedScene.new()
	packed.pack(walker)
	walker.free()
	return packed


func _add_floor(top_left: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = Layers.bit(Layers.WORLD)
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	body.position = top_left + size * 0.5
	root.add_child(body)


func _frames(count: int) -> void:
	for i in count:
		await tree.physics_frame
