## The boss room sequence: seal, entrance, bar fill, release, award.
##
## The arena owns the order these happen in, and the order is the thing worth
## testing -- a player released before the bar is full can walk into a boss that
## is still immune, and a weapon awarded before the explosion ends is a weapon
## the player never sees themselves get.
extends TestCase

const PLAYER_SCENE := preload("res://scenes/actors/player/player.tscn")
const TideScript := preload("res://scenes/actors/bosses/tide.gd")
const WeaponManagerScript := preload("res://scripts/autoload/weapon_manager.gd")

const FLOOR_TOP := 600.0
const TILE := 72.0

var root: Node2D
var arena: BossArena
var player: Player


func is_async() -> bool:
	return true


func before_each_async() -> void:
	root = Node2D.new()
	tree.root.add_child(root)
	_add_floor(Vector2(-2000.0, FLOOR_TOP), Vector2(8000.0, 200.0))

	player = PLAYER_SCENE.instantiate()
	player.position = Vector2(200.0, FLOOR_TOP)
	root.add_child(player)

	arena = BossArena.new()
	arena.boss_script = TideScript
	arena.position = Vector2(400.0, FLOOR_TOP)
	arena.boss_offset_tiles = Vector2(8.0, 0.0)
	root.add_child(arena)
	await _frames(4)


func after_each_async() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


# --- The seal ---------------------------------------------------------------------

func test_the_arena_waits_until_the_player_arrives() -> void:
	assert_eq(arena.phase, BossArena.Phase.WAITING)
	assert_true(arena.boss == null)
	assert_false(player.is_frozen())


func test_crossing_the_threshold_seals_the_room_and_freezes_the_player() -> void:
	await _walk_in()
	assert_eq(arena.phase, BossArena.Phase.SEALING)
	assert_true(player.is_frozen(), "the player was not frozen by the seal")


## The order that matters most. Between the seal and the bar filling the player
## cannot move, so the boss must not be able to touch them.
func test_the_player_stays_frozen_until_the_bar_is_full() -> void:
	await _walk_in()
	await _frames(BossArena.SEAL_PAUSE_FRAMES + Boss.LAND_PAUSE_FRAMES + 40)
	assert_true(arena.phase == BossArena.Phase.FILLING
		or arena.phase == BossArena.Phase.ENTERING,
		"expected the bar to be filling, got %d" % arena.phase)
	assert_true(player.is_frozen(), "control came back before the bar was full")
	assert_not_null(arena.boss)
	assert_true(arena.boss.health.immune, "the boss was damageable during its own intro")


func test_the_fight_starts_once_the_bar_has_filled() -> void:
	await _walk_in()
	await _reach_fight()
	assert_eq(arena.phase, BossArena.Phase.FIGHTING)
	assert_false(player.is_frozen(), "the player never got control back")
	assert_true(arena.boss.is_fighting())
	assert_false(arena.boss.health.immune)


## One tick per four frames for 28 ticks. The number is the boss intro's whole
## length, so it is worth pinning rather than leaving to the bar's internals.
func test_the_bar_fill_takes_one_tick_every_four_frames() -> void:
	assert_eq(arena.fill_frames(), Health.BAR_TICKS * EnergyBar.FILL_FRAMES_PER_TICK)
	assert_eq(arena.fill_frames(), 112)


# --- The award ---------------------------------------------------------------------

func test_beating_the_boss_awards_its_weapon_and_records_the_kill() -> void:
	# The *autoload*, not a fresh instance. The arena reaches WeaponManager by
	# path, and under the test runner the real autoload is already sitting at
	# /root/WeaponManager -- a second one added alongside it gets a different
	# node name, the arena unlocks the weapon on the real one, and the test
	# watches its own empty copy forever. Which is exactly what happened.
	var weapons := _weapon_manager()
	weapons.reset()

	await _walk_in()
	await _reach_fight()
	assert_false(weapons.is_unlocked(&"tide_crawler"))

	var awarded: Array = []
	arena.cleared.connect(func(index: int, id: StringName) -> void:
		awarded.append([index, id]))
	arena.boss.health.kill()
	await _frames(Boss.DEATH_FRAMES + 20)

	assert_eq(awarded.size(), 1, "cleared fired %d times" % awarded.size())
	assert_eq(awarded[0][1], &"tide_crawler")
	assert_eq(awarded[0][0], 0)
	assert_true(arena.is_cleared())
	assert_true(weapons.is_unlocked(&"tide_crawler"))
	assert_eq(weapons.get_ammo(&"tide_crawler"), Health.BAR_TICKS)

	# Put the autoload back: it outlives this test and the next one must not
	# start with Tide Crawler already unlocked.
	weapons.reset()


## The award waits for the explosion. Firing it on the killing blow would put
## the weapon-get screen over a boss that is still visibly exploding.
func test_the_award_waits_for_the_death_sequence() -> void:
	await _walk_in()
	await _reach_fight()
	var cleared := [false]
	arena.cleared.connect(func(_i: int, _w: StringName) -> void: cleared[0] = true)
	arena.boss.health.kill()
	await _frames(10)
	assert_false(cleared[0], "the weapon was awarded before the boss finished dying")


# --- Helpers -----------------------------------------------------------------------

## Walks the player into the trigger the way the game does, rather than calling
## the handler: the trigger's layers and shape are part of what is being tested.
func _walk_in() -> void:
	for i in 120:
		if arena.phase != BossArena.Phase.WAITING:
			return
		player.global_position.x += 8.0
		await tree.physics_frame


func _reach_fight() -> void:
	for i in 400:
		if arena.phase == BossArena.Phase.FIGHTING:
			return
		await tree.physics_frame


## The WeaponManager autoload, or a bare instance parented to this test's root
## when there is none -- so the file still runs outside the project runner.
func _weapon_manager() -> Node:
	var autoload := tree.root.get_node_or_null(^"WeaponManager")
	if autoload != null:
		return autoload
	var made := WeaponManagerScript.new()
	made.load_catalogue()
	root.add_child(made)
	return made


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
