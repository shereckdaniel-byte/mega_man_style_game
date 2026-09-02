## The end of a stage: award, victory pose, beam out.
##
## The sequence is four handoffs — boss defeated, award screen dismissed, pose
## finished, beam cleared the screen — and every one of them is a place it can
## stall with the player frozen and nothing on screen changing. A stall here is
## not a crash and nothing logs it; the game just stops. So each handoff gets a
## test rather than the sequence getting one.
extends TestCase

const PLAYER_SCENE := preload("res://scenes/actors/player/player.tscn")
const VictoryState := preload("res://scenes/actors/player/states/victory.gd")
const TeleportOutState := preload("res://scenes/actors/player/states/teleport_out.gd")

const FLOOR_TOP := 600.0

var root: Node2D
var player: Player


func is_async() -> bool:
	return true


func before_each_async() -> void:
	root = Node2D.new()
	tree.root.add_child(root)
	_add_floor()
	player = PLAYER_SCENE.instantiate()
	player.position = Vector2(300.0, FLOOR_TOP)
	root.add_child(player)
	await _frames(8)


func after_each_async() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


func test_the_player_has_both_end_of_stage_states() -> void:
	assert_true(player.state_machine.has_state(&"Victory"))
	assert_true(player.state_machine.has_state(&"TeleportOut"))


## The award screen freezes the player, and a frozen player runs no states —
## so a victory that did not unfreeze first would sit on frame one of the pose
## for ever, with the stage apparently hung.
func test_beginning_the_victory_unfreezes_the_player() -> void:
	player.set_frozen(true)
	player.begin_victory()
	assert_false(player.is_frozen(), "the pose would never advance")
	assert_eq(player.state_machine.current_name(), &"Victory")


func test_the_pose_hands_over_to_the_beam() -> void:
	player.begin_victory()
	await _frames(VictoryState.HOLD_FRAMES + 10)
	assert_eq(player.state_machine.current_name(), &"TeleportOut",
		"the victory pose never finished")


## The beam must actually rise. Gravity is the trap: `apply_gravity` would fight
## the climb and the character would rise, slow and sag back like a bad jump.
func test_the_beam_rises_rather_than_falling_back() -> void:
	player.begin_victory()
	await _frames(VictoryState.HOLD_FRAMES + 10)
	var start := player.global_position.y
	await _frames(TeleportOutState.WIND_UP_FRAMES + 30)
	assert_true(player.global_position.y < start - 100.0,
		"the beam only climbed %.0f px" % (start - player.global_position.y))


func test_the_beam_reports_when_the_stage_is_over() -> void:
	var exited := [0]
	player.stage_exited.connect(func() -> void: exited[0] += 1)
	player.begin_victory()
	await _frames(VictoryState.HOLD_FRAMES + TeleportOutState.MAX_FRAMES + 20)
	assert_eq(exited[0], 1, "stage_exited fired %d times" % exited[0])


## A backstop, not a nicety. There is no camera in a bare test tree, so the
## "have I cleared the view" check cannot answer — without the frame cap the
## beam would rise for ever and the stage would never end.
func test_the_beam_gives_up_on_a_frame_count_when_it_cannot_see_the_view() -> void:
	assert_true(TeleportOutState.MAX_FRAMES > 0)
	var exited := [false]
	player.stage_exited.connect(func() -> void: exited[0] = true)
	player.begin_victory()
	await _frames(VictoryState.HOLD_FRAMES + TeleportOutState.MAX_FRAMES + 20)
	assert_true(exited[0], "the beam never gave up")


## Neither end-of-stage state may be interrupted by input. The player has just
## won; taking a shot or a slide out of the celebration reads as a bug.
func test_the_end_of_stage_states_ignore_the_buster() -> void:
	player.begin_victory()
	await _frames(4)
	assert_false(player.can_shoot(), "the player can shoot during the victory pose")
	await _frames(VictoryState.HOLD_FRAMES + 10)
	assert_eq(player.state_machine.current_name(), &"TeleportOut")
	assert_false(player.can_shoot(), "the player can shoot during the beam")


func _add_floor() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = Layers.bit(Layers.WORLD)
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000.0, 200.0)
	shape.shape = rect
	body.add_child(shape)
	body.position = Vector2(1000.0, FLOOR_TOP + 100.0)
	root.add_child(body)


func _frames(count: int) -> void:
	for i in count:
		await tree.physics_frame
