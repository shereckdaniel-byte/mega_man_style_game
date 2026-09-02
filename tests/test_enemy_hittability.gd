## Can the player actually shoot this enemy?
##
## The question `tests/test_enemies.gd` does not ask. That file places a Hitbox
## directly onto an enemy's Hurtbox and checks the damage arrives, which proves
## the damage pipeline works and proves nothing at all about whether a shot the
## player fires can reach the enemy. It cannot: it never fires one.
##
## For two milestones the Dockrat -- the most common enemy in stage 1 -- had a
## hurtbox 10.6 NES px tall under a buster line at 13, so every shot passed over
## it and it could not be killed. 193 tests passed throughout. This file fires
## the real buster from a real Player at a real enemy and waits for it to die,
## which is the only version of the question that has an honest answer.
extends TestCase

const PLAYER_SCENE := preload("res://scenes/actors/player/player.tscn")
const WALKER := preload("res://scenes/actors/enemies/walker.gd")
const HOPPER := preload("res://scenes/actors/enemies/hopper.gd")
const TURRET := preload("res://scenes/actors/enemies/turret.gd")
const SPAWNER := preload("res://scenes/actors/enemies/spawner.gd")
const CRAWLER := preload("res://scenes/actors/enemies/wall_crawler.gd")
const FLYER := preload("res://scenes/actors/enemies/flyer.gd")

const FLOOR_TOP := 600.0
const PLAYER_X := 300.0
const ENEMY_X := 700.0
## Frames to keep firing before giving up. An enemy has 3 HP, the buster does 1,
## and only 3 pellets may be live, so this is many times what it needs.
const PATIENCE := 400

var root: Node2D
var player: Player


func is_async() -> bool:
	return true


func before_each_async() -> void:
	root = Node2D.new()
	tree.root.add_child(root)
	_add_floor()
	player = PLAYER_SCENE.instantiate()
	player.position = Vector2(PLAYER_X, FLOOR_TOP)
	root.add_child(player)
	await _frames(8)


func after_each_async() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


# --- One test per ground archetype ------------------------------------------------

func test_a_walker_can_be_shot() -> void:
	await _assert_killable(WALKER, "walker (Dockrat)")


func test_a_hopper_can_be_shot() -> void:
	await _assert_killable(HOPPER, "hopper (Bollard)")


func test_a_turret_can_be_shot() -> void:
	await _assert_killable(TURRET, "turret (Lampjack)")


func test_a_spawner_can_be_shot() -> void:
	await _assert_killable(SPAWNER, "spawner (Barnacle Hive)")


func test_a_wall_crawler_can_be_shot() -> void:
	await _assert_killable(CRAWLER, "wall crawler (Limpet)")


# --- The rule behind it ------------------------------------------------------------

## Ties Enemy's minimum to the buster's actual geometry. Both numbers are
## authored in different files, and the whole bug was that nothing connected
## them -- move the muzzle and this fails rather than quietly un-shooting half
## the roster.
func test_the_minimum_hurtbox_reaches_the_busters_line() -> void:
	var muzzle: float = -Player.DEFAULT_MUZZLE.y
	var shot_bottom := muzzle - BusterShot.SIZE_NES.y * 0.5
	assert_true(Enemy.MIN_HURTBOX_NES > shot_bottom,
		"the minimum hurtbox (%.1f) does not reach the bottom of the shot (%.1f)"
			% [Enemy.MIN_HURTBOX_NES, shot_bottom])
	# And with room to spare, not by a pixel.
	assert_true(Enemy.MIN_HURTBOX_NES - shot_bottom >= 2.0,
		"only %.1f NES of overlap; a graze is not a hit"
			% (Enemy.MIN_HURTBOX_NES - shot_bottom))


## Every ground enemy is shootable by default. An enemy that means otherwise has
## to say so out loud, so "too short to hit" cannot happen by accident again.
func test_ground_enemies_are_shootable_unless_they_say_otherwise() -> void:
	for script in [WALKER, HOPPER, TURRET, SPAWNER, CRAWLER]:
		var enemy := script.new() as Enemy
		root.add_child(enemy)
		assert_true(enemy.shootable_from_the_ground(),
			"%s opted out of being shootable" % enemy.get_script().resource_path)
		assert_true(enemy.hurtbox_size().y >= Enemy.MIN_HURTBOX_NES * enemy.tuning.world_scale,
			"%s hurtbox is %.1f px, under the %.1f px floor"
				% [enemy.get_script().resource_path, enemy.hurtbox_size().y,
					Enemy.MIN_HURTBOX_NES * enemy.tuning.world_scale])
		enemy.queue_free()


## The flyer is the deliberate exception, and its fairness comes from its path
## instead: the bottom of the sweep has to enter the band a standing shot
## occupies, or it is unkillable in a different way.
func test_the_flyer_opts_out_but_its_arc_comes_within_reach() -> void:
	var flyer := FLYER.new() as Enemy
	root.add_child(flyer)
	assert_false(flyer.shootable_from_the_ground())
	assert_almost_eq(flyer.hurtbox_size().y, flyer.body_size().y, 0.01,
		"a flyer's hurtbox should be its body")

	var tile: float = flyer.tuning.tile_size()
	var marker_tiles := 3.0  # DawnBoardwalk's Gullbot row, above the deck
	var amplitude: float = flyer.get("amplitude_tiles")
	var body_tiles: float = flyer.body_size().y / tile
	# Lowest point of the hurtbox over the whole sweep.
	var lowest := marker_tiles - amplitude - body_tiles
	var shot_top: float = (-Player.DEFAULT_MUZZLE.y + BusterShot.SIZE_NES.y * 0.5) / 16.0
	assert_true(lowest <= shot_top,
		"the Gullbot's arc bottoms out at %.2f tiles, above the standing shot's %.2f"
			% [lowest, shot_top])
	flyer.queue_free()


# --- Helpers ------------------------------------------------------------------------

## Stands an enemy in front of the player and empties the buster into it.
func _assert_killable(script: Script, label: String) -> void:
	var enemy := script.new() as Enemy
	enemy.position = Vector2(ENEMY_X, FLOOR_TOP)
	root.add_child(enemy)
	await _frames(6)

	# The enemy has to be to the right for the player's default facing to point
	# at it; assert that rather than assume it, or a failure here would read as
	# a hitbox bug when it was the fixture.
	assert_true(enemy.global_position.x > player.global_position.x,
		"%s: fixture is wrong, the enemy is behind the player" % label)

	var hp_before: int = enemy.health.current
	for i in PATIENCE:
		if not is_instance_valid(enemy) or enemy.is_dead():
			break
		player.fire()
		await tree.physics_frame

	var died: bool = not is_instance_valid(enemy) or enemy.is_dead()
	assert_true(died, "%s survived %d frames of point-blank buster fire (hp %d -> %d)"
		% [label, PATIENCE, hp_before,
			enemy.health.current if is_instance_valid(enemy) else -1])


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
