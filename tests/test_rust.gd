## Rust, the third Robot Master, and the three answers its patterns ask for.
##
## Same argument as `test_arc.gd`: a roster only means something if boss three
## asks for something bosses one and two did not, and "three patterns" is easy to
## satisfy with three restatements of the same demand. Tide asked for three
## timings; Arc for movement, timing and position -- all of which are dodging.
## So most of what is checked here is the *shape* of the demand: that Scrap can
## be answered by shooting, that Press can be answered by walking away, and that
## Bloom can never take the whole floor.
extends TestCase

const RustScript := preload("res://scenes/actors/bosses/rust.gd")
const PLATE := preload("res://scenes/actors/projectiles/scrap_plate.gd")
const PATCH := preload("res://scenes/actors/projectiles/corrosion_patch.gd")

const FLOOR_TOP := 600.0
const ARENA_LEFT := 200.0
const ARENA_RIGHT := 1400.0
## 160/8 NES px of descent is 20 frames, plus the 20-frame landing pause.
const INTRO_FRAMES := 60

var root: Node2D
var boss: Rust


func is_async() -> bool:
	return true


func before_each_async() -> void:
	root = Node2D.new()
	tree.root.add_child(root)
	_add_floor(Vector2(-2000.0, FLOOR_TOP), Vector2(6000.0, 200.0))
	boss = RustScript.new() as Rust
	boss.position = Vector2(800.0, FLOOR_TOP)
	root.add_child(boss)
	boss.set_arena_span(ARENA_LEFT, ARENA_RIGHT)
	await _frames(2)


func after_each_async() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


# --- Identity ---------------------------------------------------------------------

func test_rust_is_boss_two_and_drops_rust_bloom() -> void:
	assert_eq(boss.boss_index, RustScript.INDEX)
	assert_eq(boss.boss_index, 2, "the roster puts Rust third (index 2)")
	assert_eq(boss.weapon_id, &"rust_bloom")
	assert_eq(boss.display_name, "Rust")


func test_rust_brings_its_own_art_and_table() -> void:
	assert_not_null(boss.sprite_frames, "Rust was given no sprite frames")
	assert_not_null(boss.damage_table, "Rust was given no damage table")
	assert_true(boss.sprite.sprite_frames.get_animation_names().size() > 0)


func test_rust_is_not_weak_to_its_own_weapon() -> void:
	# The roster's rule: no boss is weak to the weapon it drops.
	var table: DamageTable = boss.damage_table
	assert_true(table.damage_for(&"rust_bloom", 1) <= 2,
		"Rust takes weakness damage from its own Rust Bloom")
	assert_eq(table.damage_for(&"prism_ray", 1), 4,
		"Rust's weakness is Prism Ray, which is stage 4's and not built yet")


func test_it_closes_arcs_dangling_weakness() -> void:
	# The whole structural point of stage 3: Arc's table has named Rust Bloom
	# since M6a and there was no such weapon.
	var arc: DamageTable = load("res://resources/damage_tables/arc.tres")
	assert_eq(arc.damage_for(&"rust_bloom", 1), 4)
	assert_true(ResourceLoader.exists("res://resources/weapons/rust_bloom.tres"),
		"Arc is weak to a weapon that still does not exist")


func test_it_has_three_patterns_with_three_different_ids() -> void:
	var ids := {}
	for pattern in boss.patterns():
		ids[pattern.id] = true
	assert_eq(ids.size(), 3)
	assert_has(ids, &"scrap")
	assert_has(ids, &"press")
	assert_has(ids, &"bloom")


func test_every_pattern_tells_before_it_acts() -> void:
	for pattern in boss.patterns():
		assert_true(pattern.tell_frames > 0,
			"%s has no tell, so it cannot be answered" % pattern.id)
		assert_true(pattern.recover_frames > 0,
			"%s has no recovery, so there is no window to punish" % pattern.id)


# --- Scrap: the answer is offence -------------------------------------------------

func test_a_thrown_plate_can_be_shot_down() -> void:
	# The first destructible attack in the game. One buster pellet, because a
	# player may arrive with nothing else.
	var plate := PLATE.new() as ScrapPlate
	plate.launch(Vector2(800.0, FLOOR_TOP - 90.0), Vector2.RIGHT, 2.0, 4,
		boss.tuning)
	root.add_child(plate)
	await _frames(2)
	assert_not_null(plate.health(), "the plate has no Health to shoot")
	assert_eq(plate.health().max_hp, PLATE.PLATE_HP)
	assert_eq(PLATE.PLATE_HP, 1, "a plate that takes two pellets is not "
		+ "answerable on the frame the player sees it")

	var hurtbox := plate.get_node(^"Hurtbox") as Hurtbox
	assert_not_null(hurtbox, "the plate has no Hurtbox, so nothing can hit it")
	assert_eq(hurtbox.collision_layer, Layers.bit(Layers.ENEMY_HURTBOX),
		"a plate off the enemy hurtbox layer is invisible to the buster")
	assert_eq(hurtbox.receive(DamageInfo.new(1, Vector2.ZERO, &"buster")), 1)
	await _frames(2)
	assert_false(is_instance_valid(plate), "a broken plate stayed in the level")


func test_a_plate_is_big_and_slow_enough_to_be_shootable() -> void:
	# The archetype only works if the player has time to react and a target big
	# enough to hit. Both are pinned so a later "tightening" has to argue here.
	assert_true(RustScript.SCRAP_SPEED_PF < 2.5,
		"a plate at %.1f NES px/frame outruns the decision to shoot it"
			% RustScript.SCRAP_SPEED_PF)
	assert_true(PLATE.PLATE_NES.x >= 16.0 and PLATE.PLATE_NES.y >= 14.0,
		"a plate smaller than a tile is a pellet, not a target")


func test_a_plate_can_also_be_slid_under() -> void:
	# The new idea keeps an old answer available while it is being learned.
	var tuning := PlayerTuning.new()
	var bottom := RustScript.SCRAP_HEIGHT_NES - PLATE.PLATE_NES.y * 0.5
	assert_true(bottom > tuning.NES_SLIDE_HITBOX.y,
		"a plate whose underside is %.1f px up cannot be slid under (slide is %.1f)"
			% [bottom, tuning.NES_SLIDE_HITBOX.y])
	assert_true(bottom < tuning.NES_HITBOX.y,
		"a plate whose underside is %.1f px up can be walked under (standing is %.1f)"
			% [bottom, tuning.NES_HITBOX.y])


# --- Press: the answer is distance ------------------------------------------------

func test_the_approach_is_slower_than_a_walk() -> void:
	# The bound that makes "back off" an answer that always works, rather than
	# one that works if you started far enough away.
	var tuning := PlayerTuning.new()
	assert_true(RustScript.PRESS_STEP_PF < tuning.walk_speed_pf,
		"Rust closes at %.2f and the player walks at %.2f"
			% [RustScript.PRESS_STEP_PF, tuning.walk_speed_pf])


func test_the_slam_is_short_ranged() -> void:
	# A "distance" answer needs a distance that exists. Two tiles of reach is
	# close enough that standing off is a real option.
	assert_true(RustScript.PRESS_REACH_NES <= 32.0,
		"a slam reaching %.0f NES px is not answered by backing off"
			% RustScript.PRESS_REACH_NES)


func test_the_slam_box_is_off_except_while_slamming() -> void:
	boss.begin_intro(Vector2(800.0, FLOOR_TOP), null)
	await _frames(INTRO_FRAMES)
	boss.begin_fight()
	await _frames(2)
	var box := boss.press_box()
	assert_not_null(box)
	assert_false(box.monitoring,
		"the slam was live before any pattern had started")


# --- Bloom: the answer is a shrinking floor, and it has a bound --------------------

func test_bloom_only_ever_uses_alternate_columns() -> void:
	# The bound the docstring promises: whichever parity is chosen, the other
	# parity is untouched, so the floor can never be covered.
	for offset in 2:
		boss._bloom_offset = offset
		var used := {}
		for i in RustScript.BLOOM_DROPS:
			used[boss._bloom_column(i)] = true
		for column in used:
			assert_eq(int(column) % 2, offset,
				"offset %d placed a patch in column %s" % [offset, column])
		assert_true(used.size() <= (RustScript.BLOOM_COLUMNS + 1) / 2)


func test_at_least_three_columns_are_always_clear() -> void:
	for offset in 2:
		boss._bloom_offset = offset
		var used := {}
		for i in RustScript.BLOOM_DROPS:
			used[boss._bloom_column(i)] = true
		var clear := RustScript.BLOOM_COLUMNS - used.size()
		assert_true(clear >= 3,
			"offset %d leaves only %d of %d columns clear"
				% [offset, clear, RustScript.BLOOM_COLUMNS])


func test_the_columns_it_uses_are_inside_the_arena() -> void:
	for offset in 2:
		boss._bloom_offset = offset
		for i in RustScript.BLOOM_DROPS:
			var x := boss.column_centre(boss._bloom_column(i))
			assert_between(x, ARENA_LEFT, ARENA_RIGHT,
				"a patch would land at %.0f, outside the arena" % x)


func test_a_patch_damages_rather_than_kills_and_expires() -> void:
	var patch := PATCH.new() as CorrosionPatch
	patch.land(Vector2(800.0, FLOOR_TOP), RustScript.BLOOM_DAMAGE, boss.tuning)
	root.add_child(patch)
	await _frames(2)
	assert_eq(patch.amount, RustScript.BLOOM_DAMAGE)
	assert_true(patch.amount < 28, "a patch that kills outright turns the fight "
		+ "into precision platforming against a boss that is also attacking")
	assert_false(patch.is_armed(), "a patch bit before its warning had run")
	await _frames(PATCH.ARM_FRAMES)
	assert_true(patch.is_armed(), "a patch never armed")
	assert_true(PATCH.LIFE_FRAMES < 60 * 5, "a patch that outlives a full cycle "
		+ "of patterns takes the floor away permanently")


func test_a_patch_warns_before_it_bites() -> void:
	# It lands under a player who may already be standing there, and a hazard
	# that appears *on* you is not a decision you were offered.
	assert_true(PATCH.ARM_FRAMES >= 15,
		"%d frames of warning is not a warning" % PATCH.ARM_FRAMES)


# --- The shared bound -------------------------------------------------------------

func test_rust_cannot_leave_the_arena() -> void:
	boss.begin_intro(Vector2(800.0, FLOOR_TOP), null)
	await _frames(INTRO_FRAMES)
	boss.begin_fight()
	for i in 240:
		await tree.physics_frame
		assert_between(boss.global_position.x, ARENA_LEFT - 1.0, ARENA_RIGHT + 1.0,
			"Rust left the arena at x=%.0f on frame %d" % [boss.global_position.x, i])


func test_nothing_is_fired_during_a_tell() -> void:
	boss.begin_intro(Vector2(800.0, FLOOR_TOP), null)
	await _frames(INTRO_FRAMES)
	for pattern in boss.patterns():
		for child in root.get_children():
			if child is Hitbox and not (child is Hazard) and child != boss:
				child.free()
		boss.tell(pattern, 0)
		await tree.physics_frame
		var fired := 0
		for child in root.get_children():
			if child is Hitbox and not (child is Hazard):
				fired += 1
		assert_eq(fired, 0, "%s fired %d things during its tell" % [pattern.id, fired])


func _add_floor(top_left: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = Layers.bit(Layers.WORLD)
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = top_left + size * 0.5
	body.add_child(shape)
	root.add_child(body)


func _frames(count: int) -> void:
	for i in count:
		await tree.physics_frame
