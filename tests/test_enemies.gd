## The six enemy archetypes.
##
## Behaviour, not art. Each archetype exists to ask the player a different
## question, and these check the property that makes it that archetype rather
## than a reskin of the walker: a turret you can time, a hopper you can wait
## out, a flyer you duck, a spawner that does not bury the room, a crawler that
## follows a corner.
extends TestCase

const WALKER := preload("res://scenes/actors/enemies/walker.gd")
const HOPPER := preload("res://scenes/actors/enemies/hopper.gd")
const TURRET := preload("res://scenes/actors/enemies/turret.gd")
const FLYER := preload("res://scenes/actors/enemies/flyer.gd")
const SPAWNER := preload("res://scenes/actors/enemies/spawner.gd")
const CRAWLER := preload("res://scenes/actors/enemies/wall_crawler.gd")
const PLAYER_SCENE := preload("res://scenes/actors/player/player.tscn")

const FLOOR_TOP := 600.0

var root: Node2D
var tile := 72.0


func is_async() -> bool:
	return true


func before_each_async() -> void:
	root = Node2D.new()
	tree.root.add_child(root)
	var autoload := tree.root.get_node_or_null(^"/root/Tuning")
	tile = autoload.player.tile_size() if autoload != null else 72.0
	await tree.physics_frame


func after_each_async() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


# --- Shared behaviour ---------------------------------------------------------

func test_every_archetype_is_damageable_and_hurts_on_contact() -> void:
	for script in [WALKER, HOPPER, TURRET, FLYER, SPAWNER, CRAWLER]:
		var enemy := script.new() as Enemy
		enemy.global_position = Vector2(400.0, FLOOR_TOP)
		root.add_child(enemy)
		await tree.physics_frame
		assert_not_null(enemy.health, "%s has health" % enemy.get_script().resource_path)
		assert_not_null(enemy.hurtbox, "and a hurtbox the player's shots can find")
		assert_eq(enemy.hurtbox.collision_layer, Layers.bit(Layers.ENEMY_HURTBOX))
		assert_not_null(enemy.contact, "and a contact box")
		assert_eq(enemy.contact.collision_layer, Layers.bit(Layers.ENEMY_ATTACK))
		assert_false(enemy.contact.one_shot,
			"contact damage must keep applying, or it goes harmless after one hit")
		enemy.queue_free()
		await tree.physics_frame


func test_a_dead_enemy_stops_behaving_immediately() -> void:
	_add_floor(Vector2(0.0, FLOOR_TOP), Vector2(2000.0, 200.0))
	var walker := WALKER.new() as Enemy
	walker.global_position = Vector2(400.0, FLOOR_TOP)
	root.add_child(walker)
	await _frames(10)
	var moved_before := walker.global_position.x
	walker.health.kill()
	# Freed on the same frame it dies, so "stopped behaving" is really "gone".
	await _frames(4)
	assert_false(is_instance_valid(walker), "gone rather than a frozen corpse")
	assert_true(moved_before != 400.0, "and it really was moving beforehand")


# --- Turret -------------------------------------------------------------------

## A turret is a timing puzzle: the player learns the period and walks through
## the gap. A randomised period would make it damage rather than a puzzle.
func test_a_turret_fires_on_a_fixed_period() -> void:
	var turret := TURRET.new() as Turret
	turret.period_frames = 30
	turret.global_position = Vector2(400.0, FLOOR_TOP)
	root.add_child(turret)
	await _frames(31)
	assert_eq(_shots(), 1, "one shot after one period")
	await _frames(30)
	assert_eq(_shots(), 2, "and another after the next")


func test_a_turret_telegraphs_before_it_fires() -> void:
	var turret := TURRET.new() as Turret
	turret.period_frames = 60
	turret.telegraph_frames = 20
	turret.global_position = Vector2(400.0, FLOOR_TOP)
	root.add_child(turret)
	await _frames(5)
	assert_false(turret.is_telegraphing(), "quiet early in the cycle")
	await _frames(40)
	assert_true(turret.is_telegraphing(), "and tells before the shot")


## Enemy shots pass through terrain (ARCHITECTURE section 4). A turret behind
## the scenery it stands on would otherwise be harmless.
func test_an_enemy_shot_ignores_walls_but_can_hit_the_player() -> void:
	var shot := EnemyShot.new()
	shot.launch(Vector2(400.0, FLOOR_TOP), Vector2.LEFT, 2.0, 2, _tuning())
	root.add_child(shot)
	await tree.physics_frame
	assert_eq(shot.collision_mask & Layers.bit(Layers.WORLD), 0,
		"terrain is not in the mask")
	assert_true(shot.collision_mask & Layers.bit(Layers.PLAYER_HURTBOX) != 0,
		"but the player is")


func test_a_shot_can_be_told_to_stop_at_walls() -> void:
	var shot := EnemyShot.new()
	shot.stops_at_walls = true
	shot.launch(Vector2(400.0, FLOOR_TOP), Vector2.LEFT, 2.0, 2, _tuning())
	root.add_child(shot)
	await tree.physics_frame
	assert_true(shot.collision_mask & Layers.bit(Layers.WORLD) != 0)


# --- Hopper -------------------------------------------------------------------

func test_a_hopper_rests_then_leaves_the_ground() -> void:
	_add_floor(Vector2(0.0, FLOOR_TOP), Vector2(2000.0, 200.0))
	var hopper := HOPPER.new() as Hopper
	hopper.rest_frames = 20
	hopper.global_position = Vector2(400.0, FLOOR_TOP)
	root.add_child(hopper)
	await _frames(14)
	assert_true(hopper.is_on_floor(), "still resting")
	var resting_y := hopper.global_position.y
	await _frames(20)
	assert_true(hopper.global_position.y < resting_y - 1.0, "left the ground")


## The arc is authored in tiles because that is the question level design asks:
## can it clear the gap next to it.
func test_a_hoppers_arc_reaches_about_its_authored_height() -> void:
	_add_floor(Vector2(0.0, FLOOR_TOP), Vector2(4000.0, 200.0))
	var hopper := HOPPER.new() as Hopper
	hopper.rest_frames = 2
	hopper.hop_height_tiles = 2.0
	hopper.hop_distance_tiles = 0.0
	hopper.global_position = Vector2(400.0, FLOOR_TOP)
	root.add_child(hopper)
	var apex := FLOOR_TOP
	for i in 120:
		await tree.physics_frame
		apex = minf(apex, hopper.global_position.y)
	var reached := (FLOOR_TOP - apex) / tile
	assert_between(reached, 1.6, 2.4, "apex near the authored 2 tiles")


# --- Flyer --------------------------------------------------------------------

func test_a_flyer_ignores_gravity_and_terrain() -> void:
	_add_floor(Vector2(0.0, FLOOR_TOP), Vector2(4000.0, 200.0))
	var flyer := FLYER.new() as Flyer
	flyer.global_position = Vector2(2000.0, FLOOR_TOP - 4.0 * tile)
	root.add_child(flyer)
	var start_y := flyer.global_position.y
	await _frames(60)
	assert_false(flyer.affected_by_gravity)
	assert_true(absf(flyer.global_position.y - start_y) < 3.0 * tile,
		"stays around its lane rather than falling to the floor")


func test_a_flyer_oscillates_rather_than_flying_straight() -> void:
	var flyer := FLYER.new() as Flyer
	flyer.wavelength_tiles = 4.0
	flyer.amplitude_tiles = 1.5
	flyer.global_position = Vector2(2000.0, 400.0)
	root.add_child(flyer)
	var lowest := 1.0e9
	var highest := -1.0e9
	for i in 200:
		await tree.physics_frame
		lowest = minf(lowest, flyer.global_position.y)
		highest = maxf(highest, flyer.global_position.y)
	assert_true(highest - lowest > tile, "swept a real amplitude, not a line")


# --- Spawner ------------------------------------------------------------------

func test_a_spawner_releases_drones_on_its_cycle() -> void:
	var spawner := SPAWNER.new() as Spawner
	spawner.period_frames = 20
	spawner.global_position = Vector2(400.0, FLOOR_TOP)
	root.add_child(spawner)
	await _frames(25)
	assert_eq(spawner.brood_size(), 1)


## Uncapped, a spawner left alone fills the room -- and a player returning to a
## corridor they skipped meets a wall of drones rather than a fight.
func test_a_spawner_caps_its_brood() -> void:
	var spawner := SPAWNER.new() as Spawner
	spawner.period_frames = 5
	spawner.max_brood = 2
	spawner.global_position = Vector2(400.0, FLOOR_TOP)
	root.add_child(spawner)
	await _frames(120)
	assert_true(spawner.brood_size() <= 2,
		"never more than the cap, however long it is left running")


# --- Wall-crawler -------------------------------------------------------------

func test_a_crawler_stays_stuck_to_its_surface() -> void:
	_add_floor(Vector2(0.0, FLOOR_TOP), Vector2(2000.0, 200.0))
	var crawler := CRAWLER.new() as WallCrawler
	crawler.global_position = Vector2(400.0, FLOOR_TOP - tile * 0.35)
	root.add_child(crawler)
	await _frames(90)
	assert_false(crawler.affected_by_gravity, "clings rather than falls")
	assert_true(absf(crawler.global_position.y - (FLOOR_TOP - tile * 0.35)) < tile,
		"still on the surface it started on")


func test_a_crawler_moves_along_its_surface() -> void:
	_add_floor(Vector2(0.0, FLOOR_TOP), Vector2(2000.0, 200.0))
	var crawler := CRAWLER.new() as WallCrawler
	crawler.global_position = Vector2(400.0, FLOOR_TOP - tile * 0.35)
	root.add_child(crawler)
	var start := crawler.global_position.x
	await _frames(90)
	assert_true(absf(crawler.global_position.x - start) > 4.0,
		"travelled along the surface")


# --- Helpers ------------------------------------------------------------------

func _tuning() -> PlayerTuning:
	var autoload := tree.root.get_node_or_null(^"/root/Tuning")
	return autoload.player if autoload != null else PlayerTuning.new()


func _shots() -> int:
	var n := 0
	for child in root.get_children():
		if child is EnemyShot:
			n += 1
	return n


func _add_floor(top_left: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = Layers.bit(Layers.WORLD)
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	body.position = top_left + size * 0.5
	root.add_child(body)


func _frames(count: int) -> void:
	for i in count:
		await tree.physics_frame
