## Integration tests: a real Player node, in a real scene tree, moved by
## move_and_slide() against real collision.
##
## The tuning tests in test_tuning.gd check the arithmetic. These check that the
## controller actually produces that arithmetic once Godot's physics, collision
## and floor detection are in the loop -- which is where the arithmetic usually
## turns out to be right and the result still wrong.
extends TestCase

const PLAYER_SCENE := preload("res://scenes/actors/player/player.tscn")

const FLOOR_TOP := 400.0
const SPAWN := Vector2(200.0, FLOOR_TOP)
## Physics frames to wait for the player to settle on the floor at spawn.
const SETTLE_FRAMES := 12

var root: Node2D
var player: Player
var t: PlayerTuning


func is_async() -> bool:
	return true


func before_each_async() -> void:
	_release_all()
	root = Node2D.new()
	tree.root.add_child(root)

	_add_floor(Vector2(0.0, FLOOR_TOP), Vector2(2000.0, 200.0))

	player = PLAYER_SCENE.instantiate()
	player.position = SPAWN
	root.add_child(player)
	t = player.tuning

	await _settle()


func after_each_async() -> void:
	_release_all()
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


# --- Falling and landing ------------------------------------------------------

func test_spawns_and_lands_on_the_floor() -> void:
	assert_true(player.is_on_floor(), "should be resting on the floor after settling")
	assert_eq(player.state_machine.current_name(), &"Idle")
	assert_almost_eq(player.position.y, FLOOR_TOP, 1.0, "feet sit on the floor surface")


func test_falling_clamps_at_terminal_velocity() -> void:
	player.position = Vector2(SPAWN.x, FLOOR_TOP - 4000.0)
	await _frames(200)
	assert_true(player.velocity.y <= t.px_s(t.terminal_velocity_pf) + 1.0,
		"fall speed is clamped, not unbounded")


# --- Walking ------------------------------------------------------------------

## No acceleration and no friction. Asserted by polling for the first frame on
## which the velocity is non-zero and requiring it to already be at full speed --
## a ramp would show up as an intermediate value here.
func test_walk_is_instant_on_and_instant_off() -> void:
	Input.action_press(&"move_right")
	var first := 0.0
	for i in 8:
		await tree.physics_frame
		if absf(player.velocity.x) > 0.0:
			first = player.velocity.x
			break
	assert_almost_eq(first, t.px_s(t.walk_speed_pf), 0.01,
		"the first non-zero frame is already at full speed")

	Input.action_release(&"move_right")
	var last := first
	for i in 8:
		await tree.physics_frame
		if absf(player.velocity.x) < absf(first):
			last = player.velocity.x
			break
	assert_almost_eq(last, 0.0, 0.01,
		"the first frame after release is already at zero, with no decay")


func test_walking_covers_the_tuned_distance() -> void:
	var start := player.position.x
	Input.action_press(&"move_right")
	await _frames(60)
	Input.action_release(&"move_right")
	var travelled := player.position.x - start
	# 60 frames at 1.375 NES px/frame, scaled: about 4 tiles.
	assert_almost_eq(travelled, t.px_s(t.walk_speed_pf), t.tile_size() * 0.15,
		"one second of walking covers walk_speed px")


func test_facing_follows_input_and_persists() -> void:
	Input.action_press(&"move_left")
	await _frames(2)
	assert_eq(player.facing, -1)
	assert_true(player.sprite.flip_h, "sprite mirrors when facing left")
	Input.action_release(&"move_left")
	await _frames(2)
	assert_eq(player.facing, -1, "facing persists after input stops")


# --- Jumping ------------------------------------------------------------------

func test_full_jump_reaches_the_tuned_apex() -> void:
	var apex := await _measure_jump(-1)
	assert_almost_eq(apex, t.jump_apex_px(), t.tile_size() * 0.12,
		"measured apex vs PlayerTuning.jump_apex_px()")


## Two tiles must be clearable and three must not: that is the constraint every
## room in the game is laid out against.
func test_jump_clears_two_tiles_but_not_three() -> void:
	var apex := await _measure_jump(-1)
	assert_true(apex > t.tile_size() * 2.0,
		"apex %.1f must clear a 2-tile ledge (%.1f)" % [apex, t.tile_size() * 2.0])
	assert_true(apex < t.tile_size() * 3.0,
		"apex %.1f must not clear a 3-tile ledge (%.1f)" % [apex, t.tile_size() * 3.0])


## Releasing jump cuts upward velocity to zero outright. The hard cut is what
## gives the original its short hop.
func test_releasing_jump_early_produces_a_shorter_hop() -> void:
	var full := await _measure_jump(-1)
	await _settle()
	var short := await _measure_jump(4)
	assert_true(short < full * 0.7,
		"short hop %.1f should be well under the full jump %.1f" % [short, full])
	assert_true(short > 0.0, "a short hop still leaves the ground")


func test_cannot_double_jump() -> void:
	Input.action_press(&"jump")
	await _frames(2)
	Input.action_release(&"jump")
	await _frames(6)
	var height_before := FLOOR_TOP - player.position.y
	Input.action_press(&"jump")
	await _frames(2)
	Input.action_release(&"jump")
	await _frames(4)
	assert_true(player.velocity.y > 0.0 or FLOOR_TOP - player.position.y <= height_before + 4.0,
		"a second jump press in mid-air must do nothing")


## The original had no coyote time and PLAN.md section 6 keeps it that way, so
## walking off a ledge and pressing jump must not launch.
func test_no_coyote_time_off_a_ledge() -> void:
	assert_eq(t.coyote_frames, 0)
	player.position = Vector2(SPAWN.x, FLOOR_TOP - 200.0)
	await _frames(4)
	assert_false(player.is_on_floor())
	Input.action_press(&"jump")
	await _frames(1)
	Input.action_release(&"jump")
	assert_true(player.velocity.y > 0.0, "still falling; the jump was not granted")


# --- Sliding ------------------------------------------------------------------

## Measured from the state change itself rather than from a fixed frame count,
## so the figure is the slide and nothing else -- no leading walk frames, and no
## dependence on how long the harness takes to make an input visible.
func test_slide_covers_the_tuned_distance() -> void:
	Input.action_press(&"move_right")
	await _frames(2)
	Input.action_press(&"move_down")
	Input.action_press(&"jump")

	var start := 0.0
	var finish := 0.0
	var sliding_frames := 0
	var was_sliding := false
	var previous_x := player.position.x
	var completed := false

	for i in 90:
		await tree.physics_frame
		var sliding := player.state_machine.current_name() == &"Slide"
		if sliding and not was_sliding:
			# The frame the slide begins has already moved, so the position
			# from before it is the true start.
			start = previous_x
			Input.action_release(&"jump")
		if sliding:
			sliding_frames += 1
		elif was_sliding:
			# The frame the slide ends has already applied the next state's
			# movement, so the position from before it is the true finish.
			finish = previous_x
			completed = true
			break
		was_sliding = sliding
		previous_x = player.position.x

	Input.action_release(&"move_down")
	Input.action_release(&"move_right")

	assert_true(completed, "the slide started and finished")
	assert_eq(sliding_frames, t.slide_frames,
		"slide lasts exactly slide_frames physics frames")
	assert_almost_eq(finish - start, t.slide_distance_px(), 1.0,
		"slide distance vs PlayerTuning.slide_distance_px()")


## The hitbox has to shrink, or the slide cannot fit under anything.
func test_slide_shrinks_the_hitbox_and_restores_it() -> void:
	var standing: Vector2 = (player.collision.shape as RectangleShape2D).size
	assert_eq(standing, t.hitbox_size())

	Input.action_press(&"move_down")
	Input.action_press(&"jump")
	await _frames(2)
	Input.action_release(&"jump")
	var sliding: Vector2 = (player.collision.shape as RectangleShape2D).size
	assert_eq(sliding, t.slide_hitbox_size(), "hitbox shrinks while sliding")
	assert_true(sliding.y < standing.y)

	await _frames(t.slide_frames + 6)
	Input.action_release(&"move_down")
	await _frames(2)
	assert_eq((player.collision.shape as RectangleShape2D).size, t.hitbox_size(),
		"hitbox is restored on exit")


func test_slide_ends_on_the_ground_in_a_ground_state() -> void:
	Input.action_press(&"move_down")
	Input.action_press(&"jump")
	await _frames(2)
	Input.action_release(&"jump")
	Input.action_release(&"move_down")
	await _frames(t.slide_frames + 10)
	assert_true(player.state_machine.current_name() in [&"Idle", &"Walk"],
		"ended in %s" % player.state_machine.current_name())
	assert_true(player.is_on_floor())


## Cancelling a slide with jump is a skill expression PLAN.md section 6 keeps
## deliberately.
func test_slide_can_be_cancelled_into_a_jump() -> void:
	Input.action_press(&"move_down")
	Input.action_press(&"jump")
	await _frames(2)
	Input.action_release(&"jump")
	Input.action_release(&"move_down")
	await _frames(4)
	assert_eq(player.state_machine.current_name(), &"Slide")
	Input.action_press(&"jump")
	await _frames(2)
	Input.action_release(&"jump")
	assert_eq(player.state_machine.current_name(), &"Jump", "jump cancels the slide")
	assert_true(player.velocity.y < 0.0, "and actually leaves the ground")


# --- Sprite alignment ---------------------------------------------------------

## The art does not fill its cell -- it is 177 px tall with its feet on row 223
## of 256 -- so aligning the sprite to the cell instead of to the art sinks the
## character into the floor. Cheap to get wrong, and it looks like a physics bug.
func test_sprite_feet_sit_on_the_origin() -> void:
	assert_almost_eq(player.sprite_feet_offset(), 0.0, 0.5,
		"drawn feet vs the base of the collision box")


func test_sprite_is_drawn_at_the_character_height() -> void:
	var drawn := Player.SOURCE_ART_HEIGHT * player.sprite.scale.y
	assert_almost_eq(drawn, t.character_height(), 0.5,
		"177 px of art drawn at %.0f px" % t.character_height())
	assert_almost_eq(player.sprite.scale.x, player.sprite.scale.y, 0.0001,
		"uniform scale; a non-uniform one would stretch the art")


# --- Damage -------------------------------------------------------------------

## Knockback pushes away from the source with control locked, which is what
## makes a hit over a pit lethal.
func test_knockback_pushes_away_from_the_source() -> void:
	player.state_machine.transition_to(&"Hurt", {
		"source_position": player.global_position + Vector2(50.0, 0.0)})
	await _frames(2)
	assert_true(player.velocity.x < 0.0, "hit from the right pushes left")
	Input.action_press(&"move_right")
	await _frames(2)
	assert_true(player.velocity.x < 0.0, "input cannot override the knockback")
	Input.action_release(&"move_right")


func test_knockback_releases_after_the_tuned_frames() -> void:
	player.state_machine.transition_to(&"Hurt", {
		"source_position": player.global_position + Vector2(50.0, 0.0)})
	await _frames(t.knockback_frames + 6)
	assert_true(player.state_machine.current_name() in [&"Idle", &"Walk", &"Fall"],
		"recovered into %s" % player.state_machine.current_name())


# --- Helpers ------------------------------------------------------------------

## Jumps and returns the peak height above the starting ground, in world px.
## `hold_frames` of -1 holds jump for the whole ascent.
func _measure_jump(hold_frames: int) -> float:
	var ground := player.position.y
	var apex := 0.0
	Input.action_press(&"jump")
	var held := 0
	# 120 frames is well past the ~40-frame round trip at any sane tuning.
	for i in 120:
		await tree.physics_frame
		apex = maxf(apex, ground - player.position.y)
		held += 1
		if hold_frames >= 0 and held >= hold_frames:
			Input.action_release(&"jump")
		if i > 4 and player.is_on_floor():
			break
	Input.action_release(&"jump")
	return apex


func _add_floor(top_left: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1        # world
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	body.position = top_left + size * 0.5
	root.add_child(body)


## Presses an action and waits until the engine has sampled it.
##
## Input pressed from a coroutine lands after the current frame's input flush,
## so it first becomes visible to _physics_process on the frame after next. Two
## frames is the reliable minimum; this is a property of driving Input from
## test code, not a lag in the controller.
func _press(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)


func _frames(count: int) -> void:
	for i in count:
		await tree.physics_frame


func _settle() -> void:
	await _frames(SETTLE_FRAMES)


func _release_all() -> void:
	for action in [&"move_left", &"move_right", &"move_up", &"move_down", &"jump", &"shoot"]:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			Input.action_release(action)
