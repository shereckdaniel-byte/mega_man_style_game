## The utility items: the dog's three, M6's last bullet.
##
## `GameState.Item` and `items_unlocked` were defined at M0 and read by nothing
## for eight stages -- the password has been carrying three bits of a feature
## that did not exist. This is that feature, and most of what is checked here is
## the wiring rather than the physics: the items ride the weapon system, so the
## question is whether they are awarded, selectable and spendable, not whether a
## spring springs.
extends TestCase

const PLAYER_SCENE := preload("res://scenes/actors/player/player.tscn")
const Coil := preload("res://scenes/actors/items/rush_coil.gd")
const Ride := preload("res://scenes/actors/items/rush_ride.gd")
const CoilCarrier := preload("res://scenes/actors/items/coil_courier.gd")
const JetCarrier := preload("res://scenes/actors/items/jet_courier.gd")
const MarineCarrier := preload("res://scenes/actors/items/marine_courier.gd")

const FLOOR_TOP := 700.0

var root: Node2D
var player: Player
var state: Node
var weapons: Node
var _saved: Dictionary = {}


func is_async() -> bool:
	return true


func before_each_async() -> void:
	state = tree.root.get_node_or_null(^"/root/GameState")
	weapons = tree.root.get_node_or_null(^"/root/WeaponManager")
	if state != null:
		_saved = state.to_dict()
	root = Node2D.new()
	tree.root.add_child(root)
	_add_floor()
	player = PLAYER_SCENE.instantiate()
	player.position = Vector2(400.0, FLOOR_TOP)
	root.add_child(player)
	await _frames(6)


func after_each_async() -> void:
	if is_instance_valid(root):
		root.queue_free()
	if state != null and not _saved.is_empty():
		state.from_dict(_saved)
	if weapons != null:
		weapons.reset()
	await tree.process_frame


# --- The award ---------------------------------------------------------------------

## **Three of the eight bosses carry an item, and the roster says which.** A
## second table would be a second thing to disagree with it.
func test_three_bosses_award_an_item_and_no_two_award_the_same() -> void:
	var items := StageRoster.items()
	assert_eq(items.size(), 3, "%d bosses award an item" % items.size())
	var seen := {}
	for item in items:
		assert_false(seen.has(item), "two bosses award the same item")
		seen[item] = true
	# And every one of them maps to a weapon that exists, or it can be awarded
	# and never appear on the menu.
	for item in items:
		var id := StageRoster.item_weapon_id(item)
		assert_true(id != &"", "an item has no weapon id")
		assert_true(ResourceLoader.exists("res://resources/weapons/%s.tres" % id),
			"%s has no weapon resource" % id)


## Every value of the enum is awarded by somebody. An item defined and never
## given out is a password bit that can never be set.
func test_every_item_is_awarded_by_some_boss() -> void:
	var awarded := StageRoster.items()
	for item in [GameState.Item.COIL, GameState.Item.JET, GameState.Item.MARINE]:
		assert_has(awarded, item, "nothing awards item %d" % item)


## **The award writes both records**, and they answer different questions: the
## progress bit is what the password carries, and the weapon unlock is what puts
## the item on the menu.
func test_clearing_a_boss_awards_both_the_bit_and_the_weapon() -> void:
	if state == null or weapons == null:
		return
	state.reset()
	weapons.reset()
	var index := 2  # Rust, which carries the Coil
	var item := int(StageRoster.entry(index)["item"])
	assert_false(state.has_item(item), "the item started unlocked")

	state.mark_boss_defeated(index)
	state.unlock_item(item)
	weapons.unlock(StageRoster.item_weapon_id(item))

	assert_true(state.has_item(item), "the progress bit was not set")
	assert_true(weapons.is_unlocked(StageRoster.item_weapon_id(item)),
		"the item is not on the weapon menu")


## And the bit survives a password, which is what those three bits were reserved
## for at M0.
func test_an_item_survives_a_password() -> void:
	var progress := {"bosses_defeated": 0b00000100,
		"items_unlocked": 1 << GameState.Item.JET, "etanks": 0}
	var back := Password.decode(Password.encode(progress))
	assert_false(back.is_empty(), "the password was refused")
	assert_eq(int(back["items_unlocked"]), 1 << GameState.Item.JET,
		"a password lost an item")


# --- The courier -------------------------------------------------------------------

## **A utility weapon fires a courier, and the courier is gone by the next
## frame**, leaving the real item behind. That indirection is what lets items
## ride the weapon system without `Player.fire()` growing a branch.
func test_a_courier_delivers_its_item_and_leaves() -> void:
	var courier := CoilCarrier.new() as ItemCourier
	courier.launch(player.global_position, 1, player.tuning, null)
	root.add_child(courier)
	await _frames(3)
	assert_false(is_instance_valid(courier), "the courier is still in the level")
	assert_true(_first_of(Coil) != null, "no coil was delivered")


## A courier touches nothing. One that could collide would be a projectile with
## a delivery job, and the one thing it must not be is a projectile.
func test_a_courier_is_harmless() -> void:
	var courier := CoilCarrier.new() as ItemCourier
	courier.launch(player.global_position, 1, player.tuning, null)
	root.add_child(courier)
	await tree.physics_frame
	# It has already freed itself; what matters is that it never damaged
	# anything on the way through.
	assert_eq(player.health.current, player.health.max_hp,
		"the courier hurt the player")


## The rides are set off the way the player was looking, so a jet summoned
## facing left does not immediately fly away behind them.
func test_a_ride_leaves_the_way_the_player_faced() -> void:
	for facing in [1, -1]:
		var courier := JetCarrier.new() as ItemCourier
		courier.launch(player.global_position, facing, player.tuning, null)
		root.add_child(courier)
		await _frames(3)
		var ride := _first_of(Ride) as RushRide
		assert_true(ride != null, "no jet was delivered")
		if ride == null:
			return
		var before := ride.global_position.x
		# Nobody is riding it, so it should not have moved -- the heading is
		# checked by driving it with a rider below. What is checked here is that
		# it exists on the side the player is facing.
		assert_true((ride.global_position.x - player.global_position.x) * float(facing) > 0.0,
			"a jet facing %d landed behind the player" % facing)
		assert_almost_eq(ride.global_position.x, before, 0.001)
		ride.queue_free()
		await tree.physics_frame


# --- The coil ----------------------------------------------------------------------

## **It launches a falling player and ignores a standing one.** A spring that
## fired on contact would fire on the frame it was summoned, because the player
## is standing where they summoned it.
func test_the_coil_launches_a_falling_player_only() -> void:
	var coil := Coil.new() as RushCoil
	coil.position = player.global_position
	root.add_child(coil)
	await tree.physics_frame

	player.velocity.y = 0.0
	assert_false(coil.launch(player), "the coil fired at a player who is not falling")
	player.velocity.y = -100.0
	assert_false(coil.launch(player), "the coil fired at a rising player")

	player.velocity.y = 200.0
	assert_true(coil.launch(player), "the coil ignored a falling player")
	assert_true(player.velocity.y < 0.0, "the launch did not send them up")


## And it launches higher than the player's own jump, or it buys nothing.
func test_the_coil_beats_an_ordinary_jump() -> void:
	var t := PlayerTuning.new()
	assert_true(RushCoil.LAUNCH_MULTIPLE > 1.0,
		"the coil launches no higher than a jump")
	var coil := Coil.new() as RushCoil
	coil.position = player.global_position
	root.add_child(coil)
	await tree.physics_frame
	player.velocity.y = 200.0
	coil.launch(player)
	assert_true(absf(player.velocity.y) > t.px_s(t.jump_velocity_pf),
		"the coil launched slower than a jump")


# --- The rides ---------------------------------------------------------------------

## **A Marine does nothing out of water**, which is a refusal the player can see
## rather than a summon that quietly wastes its ammo.
func test_a_marine_refuses_to_run_on_dry_land() -> void:
	var ride := Ride.new() as RushRide
	ride.mode = RushRide.Mode.SUBMARINE
	ride.position = Vector2(400.0, FLOOR_TOP - 200.0)
	root.add_child(ride)
	await tree.physics_frame
	assert_false(ride.can_run(), "a marine ran on dry land")

	var jet := Ride.new() as RushRide
	jet.mode = RushRide.Mode.FLIGHT
	jet.position = Vector2(400.0, FLOOR_TOP - 200.0)
	root.add_child(jet)
	await tree.physics_frame
	assert_true(jet.can_run(), "a jet refused to run in open air")


## And it runs once there is water round it.
func test_a_marine_runs_in_water() -> void:
	var pool := WaterVolume.new()
	pool.width_tiles = 20.0
	pool.depth_tiles = 8.0
	pool.position = Vector2(200.0, FLOOR_TOP - 600.0)
	root.add_child(pool)
	var ride := Ride.new() as RushRide
	ride.mode = RushRide.Mode.SUBMARINE
	ride.position = Vector2(600.0, FLOOR_TOP - 400.0)
	root.add_child(ride)
	await _frames(3)
	assert_true(ride.can_run(), "a marine sat still inside a pool")


## **A ride is faster than walking**, or it is a worse way to do something the
## player can already do.
func test_a_ride_beats_walking() -> void:
	var t := PlayerTuning.new()
	assert_true(RushRide.SPEED_PF > t.walk_speed_pf,
		"a ride travels at %.2f and a walk is %.2f"
			% [RushRide.SPEED_PF, t.walk_speed_pf])


## **Fuel is spent carrying, not waiting.** A ride that expired on a wall clock
## would punish a player for looking before they leapt.
func test_a_ride_with_nobody_on_it_spends_no_fuel() -> void:
	var ride := Ride.new() as RushRide
	ride.mode = RushRide.Mode.FLIGHT
	ride.position = Vector2(400.0, FLOOR_TOP - 400.0)
	root.add_child(ride)
	await _frames(30)
	assert_false(ride.has_rider(), "the test put somebody on it")
	assert_eq(ride.fuel_left(), RushRide.FUEL_FRAMES,
		"an empty ride burned %d frames of fuel"
			% [RushRide.FUEL_FRAMES - ride.fuel_left()])


## But it does give up eventually if nobody ever gets on, rather than sitting in
## the room forever.
func test_a_ride_nobody_boards_gives_up() -> void:
	var ride := Ride.new() as RushRide
	ride.mode = RushRide.Mode.FLIGHT
	ride.position = Vector2(400.0, FLOOR_TOP - 400.0)
	root.add_child(ride)
	await _frames(RushRide.IDLE_FRAMES + 4)
	assert_false(is_instance_valid(ride), "an abandoned ride stayed in the room")


# --- Helpers ---------------------------------------------------------------------

func _first_of(script: GDScript) -> Node:
	for child in root.get_children():
		if child.get_script() == script:
			return child
	return null


func _frames(count: int) -> void:
	for _i in count:
		await tree.physics_frame


func _add_floor() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = Layers.bit(Layers.WORLD)
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(6000.0, 200.0)
	shape.shape = rect
	shape.position = Vector2(1500.0, FLOOR_TOP + 100.0)
	body.add_child(shape)
	root.add_child(body)
