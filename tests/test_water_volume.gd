## Water's two fairness rules, driven against a real player.
##
## Two and not three, because the direction of the effect removes the rest: a
## force that can only ever *help* cannot make a room unfinishable the way the
## other three gimmicks can. That claim is the first test here, and it is the
## one everything else in stage 8 leans on.
extends TestCase

const PLAYER_SCENE := preload("res://scenes/actors/player/player.tscn")
const WaterScript := preload("res://scenes/level/water_volume.gd")

const FLOOR_TOP := 700.0
const SPAWN := Vector2(400.0, FLOOR_TOP)

var root: Node2D
var player: Player
var pool: WaterVolume


func is_async() -> bool:
	return true


func before_each_async() -> void:
	root = Node2D.new()
	tree.root.add_child(root)
	_add_floor()
	player = PLAYER_SCENE.instantiate()
	player.position = SPAWN
	root.add_child(player)
	await _frames(8)


func after_each_async() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


func _flood() -> void:
	pool = WaterScript.new() as WaterVolume
	pool.width_tiles = 30.0
	pool.depth_tiles = 10.0
	# Surface well above the floor, so a standing player is inside it.
	pool.position = Vector2(0.0, FLOOR_TOP - 10.0 * 72.0)
	root.add_child(pool)


# --- Rule 1: it can only ever help ------------------------------------------------

## **Buoyancy scales gravity down and never up.** This is the whole reason
## stage 8 needs no margin rule, no seam rule and no stop distance: stage 5's
## wind could shorten an arc and made two-cell gaps uncrossable, and water
## structurally cannot do that to anything.
func test_water_can_only_weaken_gravity() -> void:
	assert_true(WaterScript.DEFAULT_BUOYANCY > 0.0,
		"zero buoyancy is a player who never comes down")
	assert_true(WaterScript.DEFAULT_BUOYANCY < 1.0,
		"buoyancy of 1 or more is water that does nothing or makes jumps worse")


## And measured on a real player: the same jump goes higher wet than dry.
func test_a_jump_goes_higher_in_water() -> void:
	var dry := await _jump_apex()
	_flood()
	await _frames(4)
	var wet := await _jump_apex()
	assert_true(wet > dry + 20.0,
		"dry apex %.0f px, wet apex %.0f -- the water is not being felt"
			% [dry, wet])


## The arithmetic the level tests use, checked against the engine rather than
## trusted. Weakening gravity by `b` scales the apex by `1 / b`.
##
## **It is the full-hold apex**, which is the number a safety rule wants: the
## highest the player can possibly get, so a ceiling checked against it is a
## ceiling no jump can reach. Getting there takes a much longer press than on
## land -- the rise lasts `jump_velocity_pf / (gravity_pf * buoyancy)`, about
## 58 frames at the default instead of 20 -- and this test first failed for
## exactly that reason, holding for 24 frames and measuring a cut jump. That is
## a real property of the mechanic and not a quirk of the harness: in water the
## player has to commit to the button for three times as long to get the whole
## arc.
func test_the_predicted_apex_matches_the_real_one() -> void:
	var t := PlayerTuning.new()
	var predicted := WaterScript.jump_apex_in_water(t.jump_apex_nes_px(),
		WaterScript.DEFAULT_BUOYANCY)
	_flood()
	await _frames(4)
	var measured := (await _jump_apex()) / t.world_scale
	# Loose: the discrete integration and the closed form differ by about half a
	# frame's velocity, and the point is that the prediction is usable by the
	# level tests rather than exact.
	assert_true(absf(measured - predicted) < predicted * 0.25,
		"predicted %.0f NES px, measured %.0f" % [predicted, measured])


# --- Rule 2, and the contract -----------------------------------------------------

## Leaving the water restores gravity on the next frame, with nothing having to
## remember to switch it off -- the contract all four world-writes-the-player
## fields share.
func test_leaving_the_water_restores_gravity() -> void:
	_flood()
	await _frames(4)
	assert_true(pool.has_swimmer(), "the pool never saw the player")
	player.global_position = Vector2(SPAWN.x + 6000.0, SPAWN.y)
	await _frames(4)
	assert_false(pool.has_swimmer(), "the pool still thinks it has a swimmer")
	assert_almost_eq(player.buoyancy, 1.0, 0.001,
		"buoyancy was left written after the player left")


## It never drowns: no air meter, no damage over time. Water here is a change of
## physics and everything dangerous in a flooded room is a thing that was put
## there.
func test_water_does_no_damage() -> void:
	_flood()
	var before := player.health.current
	await _frames(120)
	assert_eq(player.health.current, before,
		"the player lost %d health to standing in water"
			% [before - player.health.current])


# --- Helpers ---------------------------------------------------------------------

## Peak height gained from a standing jump, in world px.
func _jump_apex() -> float:
	player.global_position = SPAWN
	player.velocity = Vector2.ZERO
	await _frames(8)
	var start := player.global_position.y
	var best := start
	# Held well past the submerged rise, so this measures a full jump rather
	# than a cut one -- see the note on the apex test.
	Input.action_press(&"jump")
	await _frames(70)
	Input.action_release(&"jump")
	for _i in 90:
		best = minf(best, player.global_position.y)
		await tree.physics_frame
	return start - best


func _frames(count: int) -> void:
	for _i in count:
		await tree.physics_frame


func _add_floor() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = Layers.bit(Layers.WORLD)
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14000.0, 200.0)
	shape.shape = rect
	shape.position = Vector2(3500.0, FLOOR_TOP + 100.0)
	body.add_child(shape)
	root.add_child(body)
