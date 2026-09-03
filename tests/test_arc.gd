## Arc, the second Robot Master, and the three answers its patterns ask for.
##
## Tide's tests check that a fight is *winnable*. Arc's check that it is a
## *different* fight: the roster only means anything if boss two asks for
## something boss one did not, and "three patterns" is easy to satisfy with three
## restatements of the same demand. So the assertions here are mostly about the
## shape of the demand -- movement, timing, position -- rather than about damage.
extends TestCase

const ArcScript := preload("res://scenes/actors/bosses/arc.gd")
const SPARK_ORB := preload("res://scenes/actors/projectiles/spark_orb.gd")

const FLOOR_TOP := 600.0
const ARENA_LEFT := 200.0
const ARENA_RIGHT := 1400.0
## 160/8 NES px of descent is 20 frames, plus the 20-frame landing pause.
const INTRO_FRAMES := 60

var root: Node2D
var boss: Arc


func is_async() -> bool:
	return true


func before_each_async() -> void:
	root = Node2D.new()
	tree.root.add_child(root)
	_add_floor(Vector2(-2000.0, FLOOR_TOP), Vector2(6000.0, 200.0))
	boss = ArcScript.new() as Arc
	boss.position = Vector2(800.0, FLOOR_TOP)
	root.add_child(boss)
	boss.set_arena_span(ARENA_LEFT, ARENA_RIGHT)
	await _frames(2)


func after_each_async() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


# --- Identity ---------------------------------------------------------------------

func test_arc_is_boss_one_and_drops_the_arc_lance() -> void:
	assert_eq(boss.boss_index, ArcScript.INDEX)
	assert_eq(boss.boss_index, 1, "the roster puts Arc second (index 1)")
	assert_eq(boss.weapon_id, &"arc_lance")
	assert_eq(boss.display_name, "Arc")


func test_arc_brings_its_own_art_and_table() -> void:
	# Tide fought through the whole of M5 as an invisible box because nothing
	# assigned its frames and nothing checked.
	assert_not_null(boss.sprite_frames, "Arc was given no sprite frames")
	assert_not_null(boss.damage_table, "Arc was given no damage table")
	assert_true(boss.sprite.sprite_frames.get_animation_names().size() > 0)


## No boss is weak to the weapon it drops, or the play order stops mattering.
func test_arc_is_not_weak_to_its_own_lance() -> void:
	var lance := boss.damage_table.damage_for(&"arc_lance", 1)
	var rust := boss.damage_table.damage_for(&"rust_bloom", 1)
	assert_eq(lance, 1, "the Arc Lance should do buster damage to Arc")
	assert_true(rust > lance, "Arc is meant to be weak to Rust Bloom")
	assert_true(rust >= 2 and rust <= 4, "weakness damage stays inside the 2-4x rule")


func test_a_boss_has_a_body_collider() -> void:
	var shapes := 0
	for child in boss.get_children():
		if child is CollisionShape2D:
			shapes += 1
	assert_true(shapes >= 1, "the boss body has no collision shape")


# --- The three answers ------------------------------------------------------------

## Every pattern is tell -> act -> recover, and a tell nobody can read is not one.
func test_every_pattern_is_telegraphed_long_enough_to_react_to() -> void:
	for pattern in boss.patterns():
		assert_true(pattern.tell_frames >= 20,
			"%s telegraphs for only %d frames" % [pattern.id, pattern.tell_frames])
		assert_true(pattern.recover_frames >= 24,
			"%s leaves only %d frames to shoot back" % [pattern.id, pattern.recover_frames])


func test_arc_has_the_three_patterns_the_stage_was_built_around() -> void:
	var ids: Array[StringName] = []
	for pattern in boss.patterns():
		ids.append(pattern.id)
	assert_eq(ids.size(), 3)
	for wanted in [&"lash", &"rail", &"curtain"]:
		assert_true(ids.has(wanted), "no %s pattern" % wanted)


## **Movement.** The seeker has to be escapable, and what makes it escapable is
## that it expires -- a homing shot with no lifetime turns a dodge into a delay.
func test_the_seeker_gives_up() -> void:
	var orb := SPARK_ORB.new() as SparkOrb
	root.add_child(orb)
	orb.launch(Vector2(400.0, 400.0), Vector2.RIGHT, 1.5, 3, PlayerTuning.new())
	await _frames(4)
	assert_true(is_instance_valid(orb), "the orb died immediately")
	await _frames(SPARK_ORB.LIFETIME_FRAMES + 4)
	assert_false(is_instance_valid(orb),
		"the seeker never expires -- it can only be waited out, not dodged")


## And it has to be out-turnable. The player's own Arc Lance turns at 7 degrees a
## frame; the boss's version must turn slower, or the same archetype in the
## player's hands is not the upgrade it is meant to be.
func test_the_players_lance_out_turns_the_bosss_orb() -> void:
	assert_true(SPARK_ORB.TURN_RATE_DEG < LanceShot.TURN_RATE_DEG,
		"the boss's seeker (%.1f deg/frame) turns at least as hard as the player's (%.1f)"
			% [SPARK_ORB.TURN_RATE_DEG, LanceShot.TURN_RATE_DEG])


## **Timing.** Rail crosses the floor and stops at the wall rather than turning
## round: a dash that bounced would ask for a second jump on a timing the player
## cannot see coming, which is two answers to one pattern.
##
## Run long enough to see every pattern several times, because what this really
## checks is that *nothing* Arc does takes it out of the room -- Curtain's hop
## was walking it 900 px past the wall while Rail behaved perfectly.
func test_the_dash_stops_at_the_arena_wall() -> void:
	boss.begin_intro(Vector2(800.0, FLOOR_TOP), null)
	await _frames(INTRO_FRAMES)
	boss.begin_fight()
	var left := boss.global_position.x
	var right := boss.global_position.x
	for i in 900:
		await tree.physics_frame
		left = minf(left, boss.global_position.x)
		right = maxf(right, boss.global_position.x)
	var margin := Arc.BODY_NES.x * boss.tuning.world_scale
	assert_true(left >= ARENA_LEFT - margin,
		"Arc reached x=%.0f, past the arena's left wall at %.0f" % [left, ARENA_LEFT])
	assert_true(right <= ARENA_RIGHT + margin,
		"Arc reached x=%.0f, past the arena's right wall at %.0f" % [right, ARENA_RIGHT])


## **Position.** Curtain always leaves a column open, and it leaves the one the
## player is standing in -- which reads backwards until you notice the
## alternative: a random column asks the player to cross the arena during a
## falling attack, in a stage where they may not be able to see it.
func test_the_curtain_always_leaves_the_players_column_open() -> void:
	var dummy := Node2D.new()
	root.add_child(dummy)
	boss.target = dummy
	var curtain := _pattern(&"curtain")
	for column in Arc.CURTAIN_COLUMNS:
		var span := ARENA_RIGHT - ARENA_LEFT
		var width := span / float(Arc.CURTAIN_COLUMNS)
		dummy.global_position = Vector2(ARENA_LEFT + width * (float(column) + 0.5), FLOOR_TOP)
		boss.tell(curtain, 0)
		assert_eq(boss._open_column, column,
			"the player stood in column %d and Arc left %d open"
				% [column, boss._open_column])


## And the gap is a real one: every other column drops, so the pattern is a
## question with exactly one answer rather than a wall or a shower.
func test_the_curtain_drops_every_column_but_one() -> void:
	var dummy := Node2D.new()
	dummy.global_position = Vector2(ARENA_LEFT + 100.0, FLOOR_TOP)
	root.add_child(dummy)
	boss.target = dummy
	boss.global_position = Vector2(900.0, FLOOR_TOP)
	var curtain := _pattern(&"curtain")
	boss.tell(curtain, 0)
	boss.act(curtain, Arc.CURTAIN_INTERVAL)
	await tree.physics_frame

	var columns: Array[int] = []
	for child in root.get_children():
		if child is EnemyShot and not (child is SparkOrb):
			columns.append(boss._column_at((child as Node2D).global_position.x))
	assert_eq(columns.size(), Arc.CURTAIN_COLUMNS - 1,
		"expected %d falling columns, got %d" % [Arc.CURTAIN_COLUMNS - 1, columns.size()])
	assert_false(columns.has(boss._open_column),
		"something fell down the column that was meant to be open")


## Nothing is fired during a tell. The rule is structural in BossPattern; this
## checks Arc keeps it, since a boss can always spawn something in `tell()`.
func test_no_pattern_attacks_during_its_own_telegraph() -> void:
	var dummy := Node2D.new()
	dummy.global_position = Vector2(700.0, FLOOR_TOP)
	root.add_child(dummy)
	boss.target = dummy
	for pattern in boss.patterns():
		for frame in pattern.tell_frames:
			boss.tell(pattern, frame)
		await tree.physics_frame
		var shots := 0
		for child in root.get_children():
			if child is Hitbox and not (child is Hazard):
				shots += 1
		assert_eq(shots, 0, "%s fired %d things during its tell" % [pattern.id, shots])


func _pattern(id: StringName) -> BossPattern:
	for pattern in boss.patterns():
		if pattern.id == id:
			return pattern
	return null


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
