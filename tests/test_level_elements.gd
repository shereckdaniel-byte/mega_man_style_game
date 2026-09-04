## The shared level kit: one-way platforms, moving platforms, crumbling blocks.
##
## These are the vocabulary every stage is authored from, so a fault here is a
## fault in eight stages rather than one. Each is exercised with a real player
## on a real body, because the interesting failures are physics ones -- a
## platform that arrives without its rider, a one-way surface solid from the
## wrong side, a block that vanishes visually and still holds the player up.
extends TestCase

const PLAYER_SCENE := preload("res://scenes/actors/player/player.tscn")
const OneWayScript := preload("res://scenes/level/one_way_platform.gd")
const MovingScript := preload("res://scenes/level/moving_platform.gd")
const CrumbleScript := preload("res://scenes/level/crumbling_block.gd")

const FLOOR_TOP := 700.0

var root: Node2D
var player: Player


func is_async() -> bool:
	return true


func before_each_async() -> void:
	_release_all()
	root = Node2D.new()
	tree.root.add_child(root)
	_add_floor()
	player = PLAYER_SCENE.instantiate()
	player.position = Vector2(300.0, FLOOR_TOP)
	root.add_child(player)
	await _frames(8)


func after_each_async() -> void:
	_release_all()
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


# --- One-way platforms -------------------------------------------------------------

func test_a_one_way_platform_is_on_the_reserved_layer() -> void:
	var plat := _one_way(Vector2(400.0, FLOOR_TOP - 200.0), Vector2(4.0, 0.5))
	await _frames(2)
	assert_eq(plat.collision_layer, Layers.bit(Layers.ONE_WAY))
	# The player's body must already watch that layer, or the platform is
	# furniture. The mask was reserved long before anything sat on it.
	assert_true(player.collision_mask & Layers.bit(Layers.ONE_WAY) != 0,
		"the player does not mask the one_way layer")


## Solid from above: the player falls onto it and stops.
func test_a_player_lands_on_a_one_way_platform() -> void:
	var plat := _one_way(Vector2(260.0, FLOOR_TOP - 220.0), Vector2(4.0, 0.5))
	await _frames(2)
	player.global_position = Vector2(340.0, FLOOR_TOP - 420.0)
	await _frames(60)
	assert_true(player.is_on_floor(), "the player fell straight through")
	assert_almost_eq(player.global_position.y, plat.global_position.y, 12.0,
		"landed at %.0f, platform top is %.0f"
			% [player.global_position.y, plat.global_position.y])


## Open from below: rising through it must not be blocked.
func test_a_player_passes_up_through_a_one_way_platform() -> void:
	var plat := _one_way(Vector2(260.0, FLOOR_TOP - 120.0), Vector2(4.0, 0.5))
	await _frames(2)
	player.global_position = Vector2(340.0, FLOOR_TOP)
	player.velocity = Vector2(0.0, -player.tuning.px_s(9.0))
	for i in 30:
		player.move_and_slide()
		await tree.physics_frame
	assert_true(player.global_position.y < plat.global_position.y,
		"the player was blocked from below at y=%.0f" % player.global_position.y)


# --- Moving platforms --------------------------------------------------------------

## The reason the class is an AnimatableBody2D with sync_to_physics rather than
## a StaticBody2D moved by hand: without it the platform slides out from under
## a standing player, who is left behind in mid-air.
func test_a_moving_platform_carries_the_player() -> void:
	var plat := _moving(Vector2(500.0, FLOOR_TOP - 240.0), Vector2(4.0, 0.5),
		Vector2(6.0, 0.0), 90)
	await _frames(2)
	player.global_position = Vector2(plat.global_position.x + 100.0,
		plat.global_position.y - 60.0)
	await _frames(40)
	assert_true(player.is_on_floor(), "the player never landed on the platform")
	var carried_from := player.global_position.x
	var platform_from := plat.global_position.x
	await _frames(45)
	var player_moved := player.global_position.x - carried_from
	var platform_moved := plat.global_position.x - platform_from
	assert_true(absf(platform_moved) > 40.0,
		"the platform barely moved (%.0f px), so the test proves nothing" % platform_moved)
	assert_almost_eq(player_moved, platform_moved, 24.0,
		"platform moved %.0f px, player moved %.0f" % [platform_moved, player_moved])


## Pure timing, checked across the whole cycle without stepping physics.
func test_ping_pong_returns_to_where_it_started() -> void:
	var leg := 60
	var pause := 12
	assert_almost_eq(MovingScript.progress_at(0, leg, pause, MovingPlatform.Mode.PING_PONG),
		0.0, 0.001)
	assert_almost_eq(MovingScript.progress_at(leg, leg, pause, MovingPlatform.Mode.PING_PONG),
		1.0, 0.001)
	# Held at the far end through the pause.
	assert_almost_eq(
		MovingScript.progress_at(leg + pause - 1, leg, pause, MovingPlatform.Mode.PING_PONG),
		1.0, 0.001)
	# And back to the start by the end of the cycle.
	var whole := (leg + pause) * 2
	assert_almost_eq(MovingScript.progress_at(whole, leg, pause,
		MovingPlatform.Mode.PING_PONG), 0.0, 0.001)


func test_progress_never_leaves_its_range() -> void:
	for frame in range(0, 400):
		for m in [MovingPlatform.Mode.PING_PONG, MovingPlatform.Mode.LOOP]:
			var p: float = MovingScript.progress_at(frame, 55, 17, m)
			assert_true(p >= -0.001 and p <= 1.001,
				"frame %d mode %d gave %.3f" % [frame, m, p])


## Which way a platform is about to go, which `progress` on its own cannot say.
##
## The bug this pins: on a ping-pong leg, progress 0.16 is both "just set off"
## and "nearly home". The playthrough bot read the second as the first, boarded a
## ferry travelling away from the crossing, kept walking forwards and stepped off
## the far end into the spikes -- the same frame every run, on stage 3.
func test_a_platform_says_which_way_it_is_about_to_go() -> void:
	var plat := _moving(Vector2(500.0, FLOOR_TOP - 240.0), Vector2(3.0, 0.5),
		Vector2(4.0, 0.0), 60)
	plat.pause_frames = 10
	var cycle := plat.cycle_frames()

	# Walk a whole cycle and check the answer against where it actually goes.
	for frame in cycle:
		plat._frames = frame
		var here := plat.current_position().x
		plat._frames = frame + 1
		var moved := plat.current_position().x - here
		plat._frames = frame
		var said := plat.next_heading()
		if absf(moved) > 0.001:
			assert_eq(said, signi(int(signf(moved))),
				"frame %d: said %d, actually moved %.2f" % [frame, said, moved])
	plat.queue_free()


func test_a_paused_platform_still_says_which_way_it_will_go() -> void:
	# "Stationary" is not an answer a rider can use: the whole point of the pause
	# is that it is when you decide whether to step on.
	var plat := _moving(Vector2(500.0, FLOOR_TOP - 240.0), Vector2(3.0, 0.5),
		Vector2(4.0, 0.0), 60)
	plat.pause_frames = 10
	plat._frames = 0                       # parked at the near end, about to set off
	assert_eq(plat.next_heading(), 1, "parked at the start and not heading out")
	plat._frames = 60 + 5                  # parked at the far end, mid-pause
	assert_eq(plat.next_heading(), -1, "parked at the far end and not heading back")
	plat.queue_free()


func test_a_vertical_lift_has_no_horizontal_heading() -> void:
	var lift := _moving(Vector2(500.0, FLOOR_TOP - 240.0), Vector2(3.0, 0.5),
		Vector2(0.0, -4.0), 60)
	assert_eq(lift.next_heading(), 0,
		"a lift carries a rider either way and must not refuse them")
	lift.queue_free()


## A platform with no pause is one the player has to board on the exact frame it
## arrives. The pause is what makes it catchable.
func test_the_default_platform_pauses_at_each_end() -> void:
	var plat := _moving(Vector2(500.0, FLOOR_TOP - 240.0), Vector2(3.0, 0.5),
		Vector2(4.0, 0.0), 90)
	assert_true(plat.pause_frames > 0)


# --- Crumbling blocks --------------------------------------------------------------

## The warning is the design. Without it the block is a trap learnt by dying.
func test_a_crumbling_block_warns_before_it_falls() -> void:
	var block := _crumble(Vector2(500.0, FLOOR_TOP - 200.0))
	await _frames(2)
	assert_eq(block.phase, CrumblingBlock.Phase.SOLID)
	block.trigger()
	assert_eq(block.phase, CrumblingBlock.Phase.WARNING)
	assert_true(block.is_solid(), "it stopped holding the player up during the warning")
	await _frames(block.warn_frames + 2)
	assert_eq(block.phase, CrumblingBlock.Phase.GONE)


## The failure that would be worst: invisible but still solid. A player standing
## on nothing, unable to fall, is a soft lock with no explanation on screen.
func test_a_fallen_block_is_neither_visible_nor_solid() -> void:
	var block := _crumble(Vector2(500.0, FLOOR_TOP - 200.0))
	await _frames(2)
	block.trigger()
	await _frames(block.warn_frames + 4)
	assert_false(block.visible)
	assert_false(block.is_solid())
	assert_eq(block.collision_layer, 0, "it is gone but still on a collision layer")


func test_a_block_comes_back_where_it_was() -> void:
	var block := _crumble(Vector2(500.0, FLOOR_TOP - 200.0))
	await _frames(2)
	var home := block.global_position
	block.trigger()
	await _frames(block.warn_frames + block.respawn_frames + 6)
	assert_eq(block.phase, CrumblingBlock.Phase.SOLID)
	assert_true(block.visible)
	assert_true(block.is_solid())
	assert_almost_eq(block.global_position.x, home.x, 0.5,
		"the shake left it %.1f px off" % (block.global_position.x - home.x))


## Standing on one has to set it off, or the sensor is not wired and the whole
## element does nothing in a real stage.
func test_standing_on_a_block_sets_it_off() -> void:
	var block := _crumble(Vector2(400.0, FLOOR_TOP - 260.0), Vector2(3.0, 1.0))
	await _frames(2)
	player.global_position = Vector2(block.global_position.x + 100.0,
		block.global_position.y - 90.0)
	await _frames(50)
	assert_ne(block.phase, CrumblingBlock.Phase.SOLID,
		"the player stood on it and nothing happened")


# --- Helpers -------------------------------------------------------------------------

func _one_way(at: Vector2, size: Vector2) -> OneWayPlatform:
	var plat := OneWayScript.new() as OneWayPlatform
	plat.size_tiles = size
	plat.position = at
	root.add_child(plat)
	return plat


func _moving(at: Vector2, size: Vector2, travel: Vector2, leg: int) -> MovingPlatform:
	var plat := MovingScript.new() as MovingPlatform
	plat.size_tiles = size
	plat.travel_tiles = travel
	plat.frames_per_leg = leg
	plat.position = at
	root.add_child(plat)
	return plat


func _crumble(at: Vector2, size := Vector2(1.0, 1.0)) -> CrumblingBlock:
	var block := CrumbleScript.new() as CrumblingBlock
	block.size_tiles = size
	block.position = at
	root.add_child(block)
	return block


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


func _release_all() -> void:
	for action in [&"move_left", &"move_right", &"move_up", &"move_down",
			&"jump", &"shoot", &"melee"]:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			Input.action_release(action)
