## Rust Bloom -- archetype 4, and the two things that make it worth its ammo.
##
## The archetype is "heavy slow arcing knuckle, high damage, hard to aim", and a
## weapon that is only those things is a worse buster with a penalty. What is
## checked here is the trade: that the lob really arcs (so the aim is a judgement
## about distance), and that the bloom really is larger than the knuckle and
## reaches more than one thing (so there is something being bought with the
## difficulty).
extends TestCase

const BLOOM := preload("res://scenes/actors/projectiles/bloom_shot.gd")
const DATA := preload("res://resources/weapons/rust_bloom.tres")

var root: Node2D
var tuning: PlayerTuning


func is_async() -> bool:
	return true


func before_each_async() -> void:
	root = Node2D.new()
	tree.root.add_child(root)
	var autoload := tree.root.get_node_or_null(^"Tuning")
	tuning = autoload.player if autoload != null else PlayerTuning.new()
	await tree.physics_frame


func after_each_async() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


func _fire(at: Vector2 = Vector2(400.0, 400.0), dir: int = 1) -> BloomShot:
	var shot := BLOOM.new() as BloomShot
	shot.launch(at, dir, tuning, DATA)
	root.add_child(shot)
	return shot


# --- The resource -----------------------------------------------------------------

func test_the_weapon_is_heavy_and_costs_more_than_a_pellet() -> void:
	assert_eq(DATA.id, &"rust_bloom")
	assert_eq(DATA.display_name, "Rust Bloom")
	assert_true(DATA.damage >= 3, "an archetype-4 weapon that does %d is not heavy"
		% DATA.damage)
	assert_true(DATA.ammo_cost >= 2, "a heavy weapon at cost %d is strictly better "
		% DATA.ammo_cost + "than the buster and there is no reason to tap")
	assert_eq(DATA.max_on_screen, 1,
		"two knuckles in the air removes the aiming decision")
	assert_true(DATA.fire_cooldown_frames > 0, "no cooldown on a heavy weapon")


func test_the_catalogue_finds_it() -> void:
	# The catalogue is a directory scan, so a weapon that is not picked up is a
	# weapon that silently does not exist.
	var manager := tree.root.get_node_or_null(^"WeaponManager")
	if manager == null:
		return
	manager.load_catalogue()
	assert_has(manager.catalogue, &"rust_bloom",
		"Rust Bloom is on disk and the catalogue did not find it")


func test_the_lob_numbers_live_in_the_resource() -> void:
	# Not in the script: a weapon's private numbers belong next to its damage
	# and its ammo cost, which is what WeaponData.tuning is for.
	for key in [&"speed_pf", &"lift_pf", &"fall_pf"]:
		assert_has(DATA.tuning, String(key), "rust_bloom.tres has no %s" % key)


# --- The lob ------------------------------------------------------------------------

func test_it_actually_arcs() -> void:
	var shot := _fire()
	var start := shot.global_position
	await tree.physics_frame
	await tree.physics_frame
	var rising := shot.global_position.y < start.y
	assert_true(rising, "the knuckle did not leave upward, so it is not a lob")
	# It has to come back down, or the archetype is a straight shot with lift.
	var peak := shot.global_position.y
	for i in 40:
		await tree.physics_frame
		if not is_instance_valid(shot):
			break
		peak = minf(peak, shot.global_position.y)
	assert_true(is_instance_valid(shot), "the knuckle expired before it landed")
	assert_true(shot.global_position.y > peak,
		"the knuckle never fell; a lob that does not come down is a straight shot")


func test_it_travels_the_way_it_was_fired() -> void:
	var left := _fire(Vector2(400.0, 400.0), -1)
	var right := _fire(Vector2(400.0, 400.0), 1)
	await tree.physics_frame
	await tree.physics_frame
	assert_true(left.global_position.x < 400.0, "the left-hand shot went right")
	assert_true(right.global_position.x > 400.0, "the right-hand shot went left")


func test_it_is_slower_than_the_buster() -> void:
	# Watching it is how the range is learned, so it has to be watchable.
	assert_true(DATA.get_number(&"speed_pf", 99.0) < 5.0,
		"a knuckle at buster speed is not something you aim, it is something you point")


func test_a_knuckle_that_hits_nothing_gives_up() -> void:
	assert_true(BLOOM.LIFETIME_FRAMES <= 300,
		"a lob that never lands is a projectile the level has to carry forever")


# --- The bloom ----------------------------------------------------------------------

func test_hitting_the_world_blooms_rather_than_vanishing() -> void:
	var shot := _fire()
	assert_false(shot.is_bloomed())
	await tree.physics_frame
	shot._on_body_entered(null)
	assert_true(shot.is_bloomed(), "the knuckle died on the wall instead of blooming")


func test_the_bloom_is_bigger_than_the_knuckle() -> void:
	var shot := _fire()
	await tree.physics_frame
	var before := (shot.get_child(0) as CollisionShape2D).shape as RectangleShape2D
	var knuckle := before.size
	shot._on_body_entered(null)
	var after := (shot.get_child(0) as CollisionShape2D).shape as RectangleShape2D
	assert_true(after.size.x > knuckle.x * 1.5,
		"the bloom is %.0f wide against a %.0f knuckle -- that is not a bloom"
			% [after.size.x, knuckle.x])
	assert_almost_eq(after.size.x, after.size.y, 0.001, "the bloom should be round")


func test_the_bloom_can_reach_more_than_one_thing() -> void:
	# The whole reason the knuckle does not stop on the first enemy it touches.
	var shot := _fire()
	await tree.physics_frame
	assert_false(shot.one_shot,
		"a one-shot knuckle can never bloom on a group, which is what it is for")
	assert_true(shot.repeat_delay_frames > 0,
		"a bloom with no repeat delay grinds one enemy instead of catching several")


func test_the_bloom_expires() -> void:
	var shot := _fire()
	await tree.physics_frame
	shot._on_body_entered(null)
	for i in BLOOM.BLOOM_FRAMES + 4:
		await tree.physics_frame
		if not is_instance_valid(shot):
			break
	assert_false(is_instance_valid(shot),
		"the bloom outlived BLOOM_FRAMES and is still damaging")


# --- What it is for -------------------------------------------------------------------

func test_it_is_arcs_weakness_and_not_its_own_bosss() -> void:
	var arc: DamageTable = load("res://resources/damage_tables/arc.tres")
	var rust: DamageTable = load("res://resources/damage_tables/rust.tres")
	assert_eq(arc.damage_for(&"rust_bloom", 1), 4, "Rust Bloom should break Arc")
	assert_true(rust.damage_for(&"rust_bloom", 1) < 4,
		"no boss is weak to the weapon it drops")
