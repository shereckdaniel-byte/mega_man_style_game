## Item drops: the capsule, what it refuses, and the roll that produces it.
##
## Built in a real tree with a real floor, because a capsule that does not land
## is a capsule the player cannot reach and nothing else would notice: it would
## sit in the air exactly where the flyer that dropped it was shot.
extends TestCase

const PLAYER_SCENE := preload("res://scenes/actors/player/player.tscn")
const WalkerScript := preload("res://scenes/actors/enemies/walker.gd")

const FLOOR_TOP := 500.0
const SPAWN := Vector2(300.0, FLOOR_TOP)

var root: Node2D
var player: Player
var weapons: Node
var state: Node
var _saved_lives: int
var _saved_etanks: int


func is_async() -> bool:
	return true


func before_each_async() -> void:
	root = Node2D.new()
	tree.root.add_child(root)
	_add_floor(Vector2(-1000.0, FLOOR_TOP), Vector2(4000.0, 200.0))
	player = PLAYER_SCENE.instantiate()
	player.position = SPAWN
	root.add_child(player)

	weapons = tree.root.get_node_or_null(^"WeaponManager")
	state = tree.root.get_node_or_null(^"GameState")
	if weapons != null:
		weapons.reset()
	if state != null:
		_saved_lives = state.lives
		_saved_etanks = state.etanks
		state.etanks = 0
	await _frames(4)


func after_each_async() -> void:
	if state != null:
		state.lives = _saved_lives
		state.etanks = _saved_etanks
	if weapons != null:
		weapons.reset()
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


# --- The capsule ----------------------------------------------------------------

## It spawns in the air, because half the archetypes fly or hop, and it has to
## end up somewhere a player standing on the floor can walk into.
func test_a_dropped_capsule_falls_to_the_floor() -> void:
	var item := Pickup.drop(root, Vector2(900.0, FLOOR_TOP - 400.0),
		Pickup.Kind.HEALTH_SMALL)
	assert_not_null(item)
	await _frames(90)
	assert_true(is_instance_valid(item), "the capsule vanished on the way down")
	assert_true(item.is_on_floor(), "the capsule never landed")
	assert_almost_eq(item.global_position.y, FLOOR_TOP, 40.0,
		"the capsule settled at y=%.0f, floor is %.0f"
			% [item.global_position.y, FLOOR_TOP])


## Nothing may collide *with* a capsule. One sitting in a doorway that blocked a
## jump would be a reward that punishes.
func test_a_capsule_blocks_nothing() -> void:
	var item := Pickup.drop(root, Vector2(900.0, FLOOR_TOP), Pickup.Kind.HEALTH_SMALL)
	await _frames(2)
	assert_eq(item.collision_layer, 0, "a capsule is on a collision layer")


func test_a_capsule_expires_after_its_lifetime() -> void:
	var item := Pickup.drop(root, Vector2(900.0, FLOOR_TOP), Pickup.Kind.HEALTH_SMALL)
	await _frames(10)
	assert_false(item.is_blinking(), "it started the run blinking")
	assert_true(item.frames_left() > 0)
	# Only the last stretch blinks, and the blink is the fair warning that it is
	# going -- a capsule that vanished without notice would read as a bug.
	item._frames = Pickup.LIFETIME_FRAMES - Pickup.BLINK_FRAMES + 1
	await _frames(2)
	assert_true(item.is_blinking(), "it went without warning")


# --- What it gives, and what it refuses -----------------------------------------

func test_health_is_taken_when_the_player_is_hurt() -> void:
	player.health.current = player.health.max_hp - 6
	var item := Pickup.drop(root, player.global_position, Pickup.Kind.HEALTH_SMALL)
	await _frames(6)
	assert_eq(player.health.current, player.health.max_hp - 4,
		"a small capsule restores %d" % Pickup.SMALL_AMOUNT)
	assert_false(is_instance_valid(item), "the capsule was not consumed")


## Refused rather than wasted, which is the decision `PauseMenu.use_etank`
## already makes about spending a tank at full health: consuming it here is a
## mistake the game should not let the player make. The capsule waits.
func test_health_is_left_alone_at_full_health() -> void:
	player.health.current = player.health.max_hp
	var item := Pickup.drop(root, player.global_position, Pickup.Kind.HEALTH_SMALL)
	await _frames(6)
	assert_true(is_instance_valid(item), "a full-health player ate the capsule")
	assert_eq(player.health.current, player.health.max_hp)


func test_a_life_capsule_adds_a_life() -> void:
	if state == null:
		return
	state.lives = 2
	var item := Pickup.drop(root, player.global_position, Pickup.Kind.ONE_UP)
	await _frames(6)
	assert_eq(state.lives, 3, "the life was not awarded")
	assert_false(is_instance_valid(item))


## The row that could not be anything but x0 until now. An E-tank is *banked*
## rather than spent, so unlike health it is taken at full health.
func test_an_etank_capsule_banks_a_tank_even_at_full_health() -> void:
	if state == null:
		return
	state.etanks = 0
	player.health.current = player.health.max_hp
	var item := Pickup.drop(root, player.global_position, Pickup.Kind.ETANK)
	await _frames(6)
	assert_eq(state.etanks, 1, "the tank was not banked")
	assert_false(is_instance_valid(item))


## Weapon energy on the buster is refused, not swallowed. The buster never runs
## dry, so a capsule spent on it is a capsule thrown away -- it waits for the
## player to switch to the weapon that needs it.
## **A capsule dropped before the player owns any weapon is not a weapon
## capsule.** Weapon energy is 16% of the drop table and nothing can hold it
## until the first boss falls, so for a whole first stage one drop in six was a
## thing the player could walk over forever with no way to tell why. It arrives
## as health instead.
##
## This test replaces one that asserted the opposite -- that the capsule sat
## there untaken -- which was the shipped behaviour and was the bug.
func test_a_weapon_capsule_is_health_before_any_weapon_is_won() -> void:
	if weapons == null:
		return
	weapons.reset()
	weapons.select(weapons.BUSTER)
	player.health.take(DamageInfo.new(6, Vector2.ZERO, &"test", DamageInfo.NONE))
	var before: int = player.health.current
	var item := Pickup.drop(root, player.global_position, Pickup.Kind.AMMO_SMALL)
	await _frames(6)
	assert_false(is_instance_valid(item),
		"a capsule nobody can use was left on the floor")
	assert_eq(player.health.current, before + Pickup.SMALL_AMOUNT,
		"the substituted capsule did not heal")


## **The buster is not a reason to refuse a capsule.** It has no bar to fill, so
## the capsule feeds the unlocked weapon that needs it most rather than waiting
## for the player to guess that they have to switch first. The player is holding
## the buster for most of the game and all of it before the first weapon-get.
func test_a_weapon_capsule_feeds_the_neediest_weapon_from_the_buster() -> void:
	if weapons == null:
		return
	weapons.unlock(&"tide_crawler")
	weapons.unlock(&"arc_lance")
	# The Arc Lance is emptier, so it is the one that should be fed -- even
	# though neither is equipped.
	weapons.consume(&"tide_crawler", 4)
	weapons.consume(&"arc_lance", 16)
	assert_true(weapons.select(weapons.BUSTER))
	var crawler: int = weapons.get_ammo(&"tide_crawler")
	var lance: int = weapons.get_ammo(&"arc_lance")
	var item := Pickup.drop(root, player.global_position, Pickup.Kind.AMMO_LARGE)
	await _frames(6)
	assert_false(is_instance_valid(item), "the buster ate a weapon capsule")
	assert_eq(weapons.get_ammo(&"arc_lance"), lance + Pickup.LARGE_AMOUNT,
		"the emptier weapon was not the one filled")
	assert_eq(weapons.get_ammo(&"tide_crawler"), crawler,
		"the fuller weapon was filled as well")


func test_weapon_energy_refills_the_equipped_weapon() -> void:
	if weapons == null:
		return
	weapons.unlock(&"tide_crawler")
	assert_true(weapons.select(&"tide_crawler"))
	# Spent well below the cap, so this measures the capsule rather than
	# `WeaponManager.refill`'s clamp.
	weapons.consume(&"tide_crawler", 14)
	var before: int = weapons.get_ammo(&"tide_crawler")
	var item := Pickup.drop(root, player.global_position, Pickup.Kind.AMMO_LARGE)
	await _frames(6)
	assert_eq(weapons.get_ammo(&"tide_crawler"), before + Pickup.LARGE_AMOUNT,
		"a large capsule restores %d" % Pickup.LARGE_AMOUNT)
	assert_false(is_instance_valid(item))


## A capsule on a full weapon is refused for the same reason a health capsule is
## refused at full health: it waits rather than being thrown away.
func test_weapon_energy_is_left_alone_when_the_weapon_is_full() -> void:
	if weapons == null:
		return
	weapons.unlock(&"tide_crawler")
	assert_true(weapons.select(&"tide_crawler"))
	var item := Pickup.drop(root, player.global_position, Pickup.Kind.AMMO_SMALL)
	await _frames(6)
	assert_true(is_instance_valid(item), "a full weapon ate the capsule")


## The whole path in one test: a real attack kills a real enemy, the enemy rolls
## its table, and the capsule falls and lands.
##
## Every other test here reaches into the middle of that -- `Pickup.drop` called
## directly, or `roll_drop` called directly -- and the middle is not where the
## surprises were. `Enemy._on_died` runs inside a `Hitbox` area callback, which
## is a different world from test code calling a function: it is why the capsule
## is added to the tree deferred (see `Pickup.drop`). This test does not catch
## that particular fault -- nothing in the suite does, it shows up as console
## noise rather than as behaviour -- but it is the only test that exercises the
## path the game actually uses.
func test_a_capsule_from_a_real_kill_still_lands() -> void:
	var enemy := WalkerScript.new() as Enemy
	enemy.max_hp = 1
	enemy.affected_by_gravity = false
	enemy.drops = {Pickup.Kind.HEALTH_SMALL: 1}
	enemy.position = Vector2(900.0, FLOOR_TOP - 300.0)
	root.add_child(enemy)
	await _frames(2)

	# A real attack box, on the layers a weapon uses, so the kill is delivered
	# by the physics server rather than by calling `take` directly.
	var blade := Hitbox.new()
	blade.amount = 8
	blade.weapon_id = &"buster"
	blade.collision_layer = Layers.bit(Layers.PLAYER_ATTACK)
	blade.collision_mask = Layers.bit(Layers.ENEMY_HURTBOX)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(80.0, 80.0)
	shape.shape = rect
	blade.add_child(shape)
	blade.global_position = enemy.global_position
	root.add_child(blade)

	await _frames(120)
	var capsule: Pickup = null
	for child in root.get_children():
		if child is Pickup:
			capsule = child
			break
	assert_not_null(capsule, "a certain drop left nothing behind")
	if capsule == null:
		return
	assert_true(capsule.is_on_floor(),
		"the capsule never landed -- its body collider was not built")


# --- The roll --------------------------------------------------------------------

## The default table is written as percentages so a reader can see the drop rate
## without adding anything up. If it stops summing to 100 that stops being true,
## and the comment above it becomes a lie.
func test_the_default_drop_table_sums_to_a_hundred() -> void:
	var total := 0
	for weight: int in Enemy.DEFAULT_DROPS.values():
		total += weight
	assert_eq(total, 100, "the default table sums to %d" % total)


## Every key is either NO_DROP or a real `Pickup.Kind`. A typo'd key would roll
## as often as it was weighted and then drop nothing, silently.
func test_every_drop_table_key_is_a_real_kind() -> void:
	for key: int in Enemy.DEFAULT_DROPS:
		if key == Enemy.NO_DROP:
			continue
		assert_true(Pickup.Kind.values().has(key),
			"%d is not a Pickup.Kind" % key)


## The property `tools/playthrough.gd -- seed=<n>` rests on, for the half of the
## randomness that is not the boss. A run is reproducible only if *every* source
## is pinned, and a new one added later would not fail anything -- runs would
## just quietly stop reproducing.
func test_the_same_seed_gives_the_same_drops() -> void:
	var enemy := WalkerScript.new() as Enemy
	root.add_child(enemy)
	await tree.physics_frame

	Enemy.seed_drops(99)
	var first: Array[int] = []
	for i in 40:
		first.append(enemy.roll_drop())

	Enemy.seed_drops(99)
	var second: Array[int] = []
	for i in 40:
		second.append(enemy.roll_drop())

	assert_eq(first, second, "same seed, different drops")
	# And it is actually rolling rather than returning one answer.
	var distinct := {}
	for value in first:
		distinct[value] = true
	assert_true(distinct.size() >= 2,
		"40 rolls produced only %d distinct outcomes" % distinct.size())


## An override that does not sum to 100 is still a set of relative weights, and
## a table with one entry always rolls it.
func test_an_override_replaces_the_default() -> void:
	var enemy := WalkerScript.new() as Enemy
	enemy.drops = {Pickup.Kind.ETANK: 3}
	root.add_child(enemy)
	await tree.physics_frame
	for i in 12:
		assert_eq(enemy.roll_drop(), int(Pickup.Kind.ETANK),
			"a single-entry table rolled something else")


## A table of nothing but zeroes cannot divide by its total.
func test_an_empty_weighting_drops_nothing() -> void:
	var enemy := WalkerScript.new() as Enemy
	enemy.drops = {Enemy.NO_DROP: 0}
	root.add_child(enemy)
	await tree.physics_frame
	assert_eq(enemy.roll_drop(), Enemy.NO_DROP)


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
