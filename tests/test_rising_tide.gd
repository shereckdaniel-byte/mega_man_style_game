## Dawn Boardwalk's gimmick, and mostly the ways it could trap someone.
##
## A wall of instant death moving up a level is the easiest thing in games to
## make unwinnable, and the player cannot see the geometry above them to plan
## around it. Most of this file is therefore about the ceiling and the recede,
## which are the two properties that keep it a challenge instead of a soft lock.
extends TestCase

const PLAYER_SCENE := preload("res://scenes/actors/player/player.tscn")
const TideScript := preload("res://scenes/level/rising_tide.gd")

const TILE := 72.0
const FLOOR_TOP := 1200.0

var root: Node2D
var water: RisingTide


func is_async() -> bool:
	return true


func before_each_async() -> void:
	root = Node2D.new()
	tree.root.add_child(root)
	water = TideScript.new() as RisingTide
	water.width_tiles = 20.0
	water.start_row = 20.0
	water.ceiling_row = 10.0
	water.step_pause_frames = 6
	water.step_frames = 3
	root.add_child(water)
	await _frames(2)


func after_each_async() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


func test_it_starts_where_it_is_told_and_holds_still() -> void:
	assert_almost_eq(water.surface_row, 20.0, 0.001)
	await _frames(60)
	assert_almost_eq(water.surface_row, 20.0, 0.001,
		"the water moved without being started")


func test_it_rises_once_started() -> void:
	water.begin()
	await _frames(60)
	assert_true(water.surface_row < 20.0,
		"the water is still at row %.2f" % water.surface_row)


## The single most important property. Water that keeps going covers the only
## ground there is to stand on, and the section becomes unwinnable with no way
## for the player to know why.
func test_it_never_rises_above_its_ceiling() -> void:
	water.begin()
	# Far longer than the section would ever last.
	await _frames(900)
	assert_true(water.surface_row >= water.ceiling_row - 0.001,
		"the water reached row %.2f, above its %.2f ceiling"
			% [water.surface_row, water.ceiling_row])
	assert_true(water.is_at_ceiling(), "it stopped short of the ceiling instead")


func test_it_says_when_it_has_topped_out() -> void:
	var topped := [0]
	water.reached_ceiling.connect(func() -> void: topped[0] += 1)
	water.begin()
	await _frames(900)
	assert_true(topped[0] >= 1, "reached_ceiling never fired")


## It rises in steps with a pause, not smoothly. A continuous climb is a race
## with no moment to think in; the pause is where the player gets to climb.
func test_it_rises_in_steps_rather_than_smoothly() -> void:
	water.begin()
	var samples: Array[float] = []
	for i in 90:
		await tree.physics_frame
		samples.append(water.surface_row)
	var still := 0
	for i in range(1, samples.size()):
		if is_equal_approx(samples[i], samples[i - 1]):
			still += 1
	assert_true(still > samples.size() / 3,
		"the water was moving on %d of %d frames -- that is a slide, not steps"
			% [samples.size() - still, samples.size()])


## The other soft-lock guard. Dying with the water at the top and respawning at
## a checkpoint *under* it would kill the player again on arrival, forever.
func test_it_goes_back_down_when_told() -> void:
	water.begin()
	await _frames(300)
	var high := water.surface_row
	assert_true(high < 20.0)
	water.recede()
	await _frames(400)
	assert_almost_eq(water.surface_row, water.start_row, 0.01,
		"the water receded to %.2f rather than back to %.2f"
			% [water.surface_row, water.start_row])


func test_receding_is_faster_than_rising() -> void:
	# Going down is a reset, not a challenge; making the player watch it at
	# climbing speed is dead time.
	var rise_per_frame: float = water.step_rows / float(water.step_frames + water.step_pause_frames)
	assert_true(water.recede_rows_per_frame > rise_per_frame,
		"receding at %.4f rows/frame is slower than rising at %.4f"
			% [water.recede_rows_per_frame, rise_per_frame])


func test_reset_puts_it_back_at_the_start() -> void:
	water.begin()
	await _frames(200)
	water.reset()
	assert_almost_eq(water.surface_row, water.start_row, 0.001)
	assert_false(water.running)


# --- Drowning ------------------------------------------------------------------------

## Touching it is a kill, not damage. Water that honours i-frames lets a player
## who was just hit swim through the surface and fall out of the level.
func test_the_water_kills_outright_even_during_iframes() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	player.position = Vector2(4.0 * TILE, FLOOR_TOP)
	root.add_child(player)
	await _frames(6)
	# Mid-flicker, exactly the state a Hazard would refuse to act on.
	player.health.grant_invulnerability(90)
	assert_true(player.health.is_invulnerable())

	# Put the surface above the player, so they are under water.
	water.start_row = 4.0
	water.reset()
	await _frames(6)
	assert_true(player.health.is_dead(),
		"the player survived the water on %d HP" % player.health.current)


func _frames(count: int) -> void:
	for i in count:
		await tree.physics_frame
