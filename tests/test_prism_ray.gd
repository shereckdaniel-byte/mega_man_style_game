## Prism Ray -- archetype 3, and the one property that makes it archetype 3.
##
## "Splitting or mirrored beam (multi-lane)" is the brief, and a beam that flies
## straight and stops is a buster pellet with a nicer sprite. So what is checked
## here is the fork: that a ray really does become two on what it hits, that the
## two go somewhere the parent was not going, and -- the check this file exists
## for -- that **an arm cannot fork again**.
##
## That last one is not fussiness. One shot that splits without limit fills a
## room in about a second and a half, and the failure is the kind that is funny
## in a playtest and then has to be deleted along with the weapon.
extends TestCase

const RAY := preload("res://scenes/actors/projectiles/ray_shot.gd")
const DATA := preload("res://resources/weapons/prism_ray.tres")

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


func _fire(at: Vector2 = Vector2(400.0, 400.0), dir: int = 1) -> RayShot:
	var shot := RAY.new() as RayShot
	shot.launch(at, dir, tuning, DATA)
	root.add_child(shot)
	return shot


func _rays() -> Array[RayShot]:
	var out: Array[RayShot] = []
	for child in root.get_children():
		if child is RayShot and not child.is_queued_for_deletion():
			out.append(child as RayShot)
	return out


# --- The resource -----------------------------------------------------------------

func test_the_weapon_is_named_and_costed() -> void:
	assert_eq(DATA.id, &"prism_ray")
	assert_eq(DATA.display_name, "Prism Ray")
	assert_true(DATA.ammo_cost >= 1,
		"a free weapon that does more than the buster removes the reason to tap")
	assert_true(DATA.fire_cooldown_frames > 0,
		"no cooldown on a shot that becomes three")


func test_the_catalogue_finds_it() -> void:
	# The catalogue is a directory scan, so a weapon that is not picked up is a
	# weapon that silently does not exist.
	var manager := tree.root.get_node_or_null(^"WeaponManager")
	assert_true(manager != null, "WeaponManager is not loaded")
	manager.load_catalogue()
	assert_true(manager.data_for(&"prism_ray") != null,
		"the catalogue did not pick up prism_ray.tres")


func test_the_fork_numbers_live_in_the_resource() -> void:
	# Weapon constants belong next to the damage and the ammo cost, not scattered
	# through the projectile script -- WeaponData.tuning's whole purpose.
	for key in [&"speed_pf", &"spread_deg", &"arm_damage"]:
		assert_has(DATA.tuning, String(key),
			"%s is hard-coded in the script instead of authored" % key)


## An arm hits for less than the shot that made it. Parent plus two arms at full
## damage would be four buster pellets for one tick of ammo.
func test_an_arm_is_weaker_than_the_shot_that_made_it() -> void:
	var arm := int(DATA.get_number(&"arm_damage", 1.0))
	assert_true(arm < DATA.damage,
		"an arm does %d against the parent's %d" % [arm, DATA.damage])
	assert_true(arm >= 1, "an arm that does nothing is not a second lane")


# --- The fork ---------------------------------------------------------------------

func test_hitting_the_world_forks_rather_than_vanishing() -> void:
	var shot := _fire()
	await tree.physics_frame
	shot._on_body_entered(root)
	await tree.physics_frame
	await tree.physics_frame
	var arms := _rays()
	assert_eq(arms.size(), 2, "a ray that met a wall left %d beams" % arms.size())
	for arm in arms:
		assert_eq(arm.generation(), 1, "the fork produced something that is not an arm")


## **And the arms go somewhere the parent was not.** Two arms travelling along
## the parent's own line is one beam drawn three times, which is not a lane.
func test_the_arms_leave_on_different_lines() -> void:
	var shot := _fire()
	await tree.physics_frame
	shot._on_body_entered(root)
	await tree.physics_frame
	await tree.physics_frame
	var arms := _rays()
	assert_eq(arms.size(), 2)
	assert_true(absf(arms[0].rotation - arms[1].rotation) > 0.1,
		"both arms left on the same heading")
	for arm in arms:
		assert_true(absf(arm.rotation) > 0.01,
			"an arm left along the parent's own line")


## The arms start where the fork happened, not where the shot was fired. An arm
## that appeared at the muzzle would arrive behind the player and read as a bug.
func test_the_arms_start_at_the_thing_that_was_hit() -> void:
	var shot := _fire(Vector2(400.0, 400.0))
	for _i in 6:
		await tree.physics_frame
	var struck := shot.global_position
	assert_true(struck.x > 400.0, "the shot did not travel before being struck")
	shot._on_body_entered(root)
	# Two frames: one for the arm to enter the tree and one for it to be drawn.
	# It is travelling in both, so the tolerance has to be the distance a ray
	# covers in that time plus its own length -- measuring against zero fails on
	# a correct arm, which is what it did first.
	const FRAMES := 2
	var slack: float = DATA.get_number(&"speed_pf", 5.0) * float(FRAMES) \
		* tuning.world_scale + RAY.SIZE_NES.x * tuning.world_scale
	for _i in FRAMES:
		await tree.physics_frame
	for arm in _rays():
		assert_true(arm.global_position.distance_to(struck) < slack,
			"an arm appeared %.0f px from where the ray was struck, past the %.0f it could have travelled"
				% [arm.global_position.distance_to(struck), slack])


## **An arm cannot fork again.** The reason this file exists.
func test_an_arm_does_not_fork() -> void:
	var shot := _fire()
	await tree.physics_frame
	shot._on_body_entered(root)
	await tree.physics_frame
	await tree.physics_frame
	var arms := _rays()
	assert_eq(arms.size(), 2)
	for arm in arms:
		assert_false(arm.can_split(), "an arm is allowed to fork")
		arm._on_body_entered(root)
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(_rays().size(), 0,
		"forking the arms left %d beams behind; the weapon is exponential"
			% _rays().size())


func test_it_travels_the_way_it_was_fired() -> void:
	var right := _fire(Vector2(400.0, 400.0), 1)
	var left := _fire(Vector2(400.0, 400.0), -1)
	for _i in 4:
		await tree.physics_frame
	assert_true(right.global_position.x > 400.0, "a ray fired right went left")
	assert_true(left.global_position.x < 400.0, "a ray fired left went right")


## It is Rust's weakness and not its own boss's, which is the roster property
## PLAN section 4 requires: no boss is weak to the weapon it drops.
func test_it_is_rusts_weakness_and_not_prisms() -> void:
	var rust: DamageTable = preload("res://resources/damage_tables/rust.tres")
	var prism: DamageTable = preload("res://resources/damage_tables/prism.tres")
	assert_eq(rust.damage_for(&"prism_ray", 1), 4,
		"Prism Ray is not Rust's weakness, so beating Prism gives nothing")
	assert_true(prism.damage_for(&"prism_ray", 1) < 4,
		"Prism is weak to the weapon it drops")
