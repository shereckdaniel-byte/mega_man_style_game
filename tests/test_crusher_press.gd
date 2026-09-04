## The press: its cycle, and the two rules its shape has to keep.
##
## The cycle is checked as arithmetic rather than by standing under one for six
## seconds -- `extension_at` and `phase_at` are pure, which is what makes that
## possible and is why they are written that way. What cannot be checked as
## arithmetic is the pair of rules in `CrusherPress`'s docstring, so those are
## checked against the real nodes: the teeth reach below the body, and they are
## only live on the way down.
extends TestCase

const Press := preload("res://scenes/level/crusher_press.gd")

var root: Node2D
var press: CrusherPress


func is_async() -> bool:
	return true


func before_each_async() -> void:
	root = Node2D.new()
	tree.root.add_child(root)
	press = Press.new() as CrusherPress
	press.size_tiles = Vector2(3.0, 2.0)
	press.drop_tiles = 7.0
	press.running = false
	root.add_child(press)
	await tree.physics_frame


func after_each_async() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


# --- The cycle ------------------------------------------------------------------

func test_the_cycle_is_the_five_phases_and_nothing_else() -> void:
	var total := Press.HOLD_FRAMES + Press.TELL_FRAMES + press.drop_frames() \
		+ Press.REST_FRAMES + press.rise_frames()
	assert_eq(press.cycle_frames(), total)
	# Every frame of the cycle belongs to exactly one phase: walking the whole
	# cycle must visit all five and end back at the first.
	var seen := {}
	for frame in press.cycle_frames():
		seen[press.phase_at(frame)[0]] = true
	assert_eq(seen.size(), 5, "a phase is unreachable")
	assert_eq(press.phase_at(press.cycle_frames())[0], press.phase_at(0)[0])


func test_the_drop_is_faster_than_the_rise() -> void:
	# Not a taste: a press you can outrun downward is not a press, and a snap
	# reset reads as a teleport rather than as machinery.
	assert_true(press.drop_frames() < press.rise_frames(),
		"drop %d frames vs rise %d" % [press.drop_frames(), press.rise_frames()])


func test_it_is_up_for_the_whole_hold_and_the_whole_tell() -> void:
	# The tell has to happen with the press still up, or it is not a warning,
	# it is the first part of the attack.
	var down := press.drop_frames()
	var up := press.rise_frames()
	for frame in Press.HOLD_FRAMES + Press.TELL_FRAMES:
		assert_almost_eq(Press.extension_at(frame, down, up), 0.0, 0.0001,
			"press had already started down on frame %d" % frame)


func test_it_is_fully_down_for_the_whole_rest() -> void:
	var down := press.drop_frames()
	var up := press.rise_frames()
	var first := Press.HOLD_FRAMES + Press.TELL_FRAMES + down
	for frame in range(first, first + Press.REST_FRAMES):
		assert_almost_eq(Press.extension_at(frame, down, up), 1.0, 0.0001,
			"press was not at the bottom on frame %d" % frame)


func test_the_extension_never_leaves_zero_to_one() -> void:
	var down := press.drop_frames()
	var up := press.rise_frames()
	for frame in press.cycle_frames() * 2:
		var at := Press.extension_at(frame, down, up)
		assert_between(at, 0.0, 1.0, "extension %f on frame %d" % [at, frame])


func test_the_phase_offset_staggers_two_presses_without_changing_the_cycle() -> void:
	var other := Press.new() as CrusherPress
	other.size_tiles = press.size_tiles
	other.drop_tiles = press.drop_tiles
	other.phase_frames = press.cycle_frames() / 2
	other.running = false
	root.add_child(other)
	await tree.physics_frame
	assert_eq(other.cycle_frames(), press.cycle_frames(),
		"a phase offset must not change how long the cycle is")
	assert_ne(other.phase(), press.phase(),
		"half a cycle apart and both presses are in the same phase")


# --- Rule 1: the teeth bite only on the way down --------------------------------

func test_the_teeth_are_live_only_while_it_is_dropping() -> void:
	var teeth := press.get_node(^"Teeth") as Hazard
	assert_not_null(teeth)
	press.running = true
	var live_phases := {}
	for i in press.cycle_frames():
		await tree.physics_frame
		if teeth.monitoring:
			live_phases[press.phase()] = true
	assert_eq(live_phases.size(), 1, "the teeth were live in more than one phase")
	assert_true(live_phases.has(Press.Phase.DROP),
		"the teeth were live outside the drop")


func test_a_press_at_rest_is_inert() -> void:
	# The safe state is what makes the cycle a timing puzzle rather than a wall,
	# so it is worth pinning that resting really is safe.
	press.phase_frames = Press.HOLD_FRAMES + Press.TELL_FRAMES + press.drop_frames() + 2
	press._frames = press.phase_frames
	press.running = true
	await tree.physics_frame
	assert_eq(press.phase(), Press.Phase.REST)
	assert_false(press.is_biting(), "a resting press was still biting")


# --- Rule 2: the teeth reach below the body -------------------------------------

func test_the_teeth_hang_below_the_solid_box() -> void:
	# Without this the solid arrives first, Godot shoves the player into the
	# deck, and the result is stuck rather than dead.
	var teeth := press.get_node(^"Teeth") as Hazard
	var tile := press.tile_size()
	var body_bottom := press.world_size().y
	var teeth_bottom: float = teeth.position.y + teeth.size_tiles.y * 0.5 * tile
	assert_true(teeth_bottom > body_bottom,
		"teeth end at %f, body at %f" % [teeth_bottom, body_bottom])


func test_the_teeth_span_the_full_width_of_the_press() -> void:
	var teeth := press.get_node(^"Teeth") as Hazard
	assert_almost_eq(teeth.size_tiles.x, press.size_tiles.x, 0.001,
		"a press narrower at the teeth than at the body has a safe corner")


func test_a_press_is_never_wider_than_its_tell_lets_you_walk_clear_of() -> void:
	# TELL_FRAMES is sized from the walk speed; MAX_PRESS_TILES is what that
	# arithmetic assumes. Checked here so the two cannot drift apart.
	var walk_pf := 1.375
	var covered := float(Press.TELL_FRAMES) * walk_pf / 16.0
	assert_true(covered >= Press.MAX_PRESS_TILES,
		"a tell of %d frames covers %.2f tiles, less than MAX_PRESS_TILES %.2f"
			% [Press.TELL_FRAMES, covered, Press.MAX_PRESS_TILES])


# --- Being a solid ---------------------------------------------------------------

func test_it_is_on_the_platform_layer_and_looks_for_nothing() -> void:
	assert_eq(press.collision_layer, Layers.bit(Layers.PLATFORM))
	assert_eq(press.collision_mask, 0, "a press has no reason to detect anything")
	assert_true(press.sync_to_physics,
		"without sync_to_physics a rider is left behind by the rise")


func test_the_shudder_does_not_move_it_down() -> void:
	# A tell that lowered the press would start the attack early, which is the
	# one thing a tell must not do.
	press.phase_frames = Press.HOLD_FRAMES + 4
	press._frames = press.phase_frames
	press.running = true
	await tree.physics_frame
	assert_eq(press.phase(), Press.Phase.TELL)
	assert_almost_eq(press.current_position().y, press.position.y, 0.001)
	assert_almost_eq(press.extension(), 0.0, 0.0001)
