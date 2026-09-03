## The three attacks: tap fire, the charged blast, and the sword.
##
## Driven through real input on a real player in a real tree, for the reason
## test_enemy_hittability.gd exists: a charge that accumulates correctly and
## fires a shot the damage table scores as 1 is a charge that does nothing, and
## only firing it at something says so.
extends TestCase

const PLAYER_SCENE := preload("res://scenes/actors/player/player.tscn")
const WALKER := preload("res://scenes/actors/enemies/walker.gd")
const TIDE_TABLE := preload("res://resources/damage_tables/tide.tres")
## The state scripts carry no class_name -- states are scene children, not a
## global type -- so its constants come from the script resource.
const AttackState := preload("res://scenes/actors/player/states/attack.gd")

const FLOOR_TOP := 600.0
const SPAWN := Vector2(300.0, FLOOR_TOP)

var root: Node2D
var player: Player
var weapons: Node


func is_async() -> bool:
	return true


func before_each_async() -> void:
	_release_all()
	root = Node2D.new()
	tree.root.add_child(root)
	_add_floor()
	player = PLAYER_SCENE.instantiate()
	player.position = SPAWN
	root.add_child(player)
	weapons = tree.root.get_node_or_null(^"WeaponManager")
	if weapons != null:
		weapons.reset()
	await _frames(10)


func after_each_async() -> void:
	_release_all()
	if weapons != null:
		weapons.reset()
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


# --- Charge ---------------------------------------------------------------------

func test_the_buster_is_chargeable_and_the_others_are_not_yet() -> void:
	if weapons == null:
		return
	assert_true(weapons.data_for(&"buster").chargeable)
	for id in [&"tide_crawler", &"arc_lance"]:
		var data: WeaponData = weapons.data_for(id)
		if data != null:
			assert_false(data.chargeable, "%s opted into charging early" % id)


## Pressing fires a pellet straight away *and* starts the charge, so a full
## charge costs an ordinary shot up front. Without that, holding would be
## strictly better than tapping and there would be no reason ever to tap.
func test_pressing_fire_shoots_immediately_and_starts_charging() -> void:
	Input.action_press(&"shoot")
	await _frames(2)
	assert_true(player.live_shots() >= 1, "the press did not fire a pellet")
	assert_true(player.charge_frames() > 0, "the press did not start a charge")


func test_the_charge_reaches_its_two_stages_on_time() -> void:
	var data: WeaponData = weapons.data_for(&"buster")
	Input.action_press(&"shoot")
	await _frames(data.charge_mid_frames - 2)
	assert_eq(player.charge_level(), 0, "reached mid early")
	await _frames(4)
	assert_eq(player.charge_level(), 1, "did not reach mid on time")
	await _frames(data.charge_full_frames - data.charge_mid_frames + 2)
	assert_eq(player.charge_level(), 2, "did not reach full on time")


func test_releasing_a_full_charge_fires_a_charged_shot() -> void:
	var data: WeaponData = weapons.data_for(&"buster")
	Input.action_press(&"shoot")
	await _frames(data.charge_full_frames + 4)
	assert_eq(player.charge_level(), 2)
	Input.action_release(&"shoot")
	await _frames(2)

	var blast := _first_charged()
	assert_not_null(blast, "no charged shot after releasing a full charge")
	assert_eq(blast.charge_level, 2)
	assert_eq(player.charge_level(), 0, "the charge was not cleared on release")


## The thing that would break silently. A blast tagged with the weapon's own id
## looks up the 1 that tap fire is meant to do, and the charge does nothing at
## all -- no error, no visible difference except a boss that will not die.
func test_a_charged_shot_carries_its_own_weapon_id_and_damage() -> void:
	var data: WeaponData = weapons.data_for(&"buster")
	Input.action_press(&"shoot")
	await _frames(data.charge_full_frames + 4)
	Input.action_release(&"shoot")
	await _frames(2)

	var blast := _first_charged()
	assert_not_null(blast)
	assert_ne(blast.weapon_id, &"buster", "the blast is tagged as tap fire")
	assert_eq(blast.weapon_id, data.charged_id())
	assert_eq(blast.amount, data.charged_full_damage)


func test_releasing_below_the_first_stage_fires_nothing_extra() -> void:
	var data: WeaponData = weapons.data_for(&"buster")
	Input.action_press(&"shoot")
	await _frames(maxi(data.charge_mid_frames - 6, 2))
	Input.action_release(&"shoot")
	await _frames(3)
	assert_true(_first_charged() == null, "a blast came out of a tap")


func test_only_one_charged_shot_is_allowed_on_screen() -> void:
	var data: WeaponData = weapons.data_for(&"buster")
	for i in 2:
		Input.action_press(&"shoot")
		await _frames(data.charge_full_frames + 4)
		Input.action_release(&"shoot")
		await _frames(2)
	assert_eq(_count_charged(), data.charged_max_on_screen)


## Every interruption drops the charge. A charge that survived a hit would go
## off on whatever frame the knockback ended, which is not a moment the player
## chose -- and the worst version fires it during a respawn.
func test_taking_a_hit_drops_the_charge() -> void:
	var data: WeaponData = weapons.data_for(&"buster")
	Input.action_press(&"shoot")
	await _frames(data.charge_full_frames + 4)
	assert_eq(player.charge_level(), 2)
	player.health.take(DamageInfo.new(2, Vector2.ZERO, &"contact"))
	player.on_damaged(DamageInfo.new(2, Vector2.ZERO, &"contact"), 2)
	await _frames(2)
	assert_eq(player.charge_level(), 0, "the charge survived a hit")


func test_freezing_drops_the_charge() -> void:
	Input.action_press(&"shoot")
	await _frames(50)
	player.set_frozen(true)
	assert_eq(player.charge_level(), 0)
	player.set_frozen(false)


func test_dying_drops_the_charge() -> void:
	Input.action_press(&"shoot")
	await _frames(50)
	player.health.kill()
	await _frames(2)
	assert_eq(player.charge_level(), 0)


# --- The charge against the weakness chain ----------------------------------------

## The reason the charged buster does 3 and not 4. The weakness chain is the
## spine of the game -- if a charge matched a weakness, there would be no reason
## to hunt for the right weapon and boss order would stop meaning anything.
func test_a_weakness_still_beats_a_full_charge() -> void:
	var charged := TIDE_TABLE.damage_for(&"buster_charged", 3)
	var weakness := TIDE_TABLE.damage_for(&"arc_lance", 2)
	var tap := TIDE_TABLE.damage_for(&"buster", 1)
	assert_eq(tap, 1)
	assert_eq(charged, 3)
	assert_true(weakness > charged,
		"the weakness does %d and a full charge does %d" % [weakness, charged])


# --- Sword ------------------------------------------------------------------------

func test_the_melee_action_exists_with_both_bindings() -> void:
	assert_true(InputMap.has_action(&"melee"))
	var keyboard := false
	var gamepad := false
	for event in InputMap.action_get_events(&"melee"):
		if event is InputEventKey:
			keyboard = true
		elif event is InputEventJoypadButton:
			gamepad = true
	assert_true(keyboard, "melee has no keyboard binding")
	assert_true(gamepad, "melee has no gamepad binding")


func test_pressing_melee_enters_the_attack_state() -> void:
	Input.action_press(&"melee")
	await _frames(3)
	assert_eq(player.state_machine.current_name(), &"Attack")


func test_the_blade_is_only_dangerous_inside_its_window() -> void:
	Input.action_press(&"melee")
	await _frames(2)
	Input.action_release(&"melee")
	assert_false(player.melee_is_active(), "the blade was live before the swing")
	await _frames(AttackState.ACTIVE_FROM + 1)
	assert_true(player.melee_is_active(), "the blade never went live")
	await _frames(AttackState.SWING_FRAMES)
	assert_false(player.melee_is_active(), "the blade stayed live after the swing")


func test_the_player_cannot_shoot_mid_swing() -> void:
	Input.action_press(&"melee")
	await _frames(3)
	assert_eq(player.state_machine.current_name(), &"Attack")
	assert_false(player.can_shoot(), "the sword and the buster both fire at once")


## The check the buster failed for two milestones: a blade placed at the arm's
## height sails over the short enemies exactly as the pellets did, and with no
## projectile to watch flying past it just looks broken.
func test_the_sword_kills_a_short_enemy() -> void:
	var enemy := WALKER.new() as Enemy
	enemy.turns_at_ledges = false
	enemy.speed_pf = 0.0
	enemy.position = Vector2(SPAWN.x + player.tuning.world_scale * 14.0, FLOOR_TOP)
	root.add_child(enemy)
	await _frames(4)

	for swing in 6:
		if not is_instance_valid(enemy) or enemy.is_dead():
			break
		Input.action_press(&"melee")
		await _frames(2)
		Input.action_release(&"melee")
		await _frames(AttackState.SWING_FRAMES + 6)

	assert_true(not is_instance_valid(enemy) or enemy.is_dead(),
		"the sword could not kill a walker standing next to the player")


func test_the_sword_reaches_the_ground() -> void:
	# The hitbox has to start at the ground line, not at the arm.
	var shape: CollisionShape2D = null
	for child in player.melee.get_children():
		if child is CollisionShape2D:
			shape = child
	assert_not_null(shape)
	var rect := shape.shape as RectangleShape2D
	var bottom: float = player.melee.position.y + rect.size.y * 0.5
	assert_almost_eq(bottom, 0.0, 1.0,
		"the blade's lower edge sits %.1f px off the ground line" % bottom)


# --- Helpers ------------------------------------------------------------------------

func _first_charged() -> ChargedShot:
	for child in root.get_children():
		if child is ChargedShot:
			return child as ChargedShot
	return null


func _count_charged() -> int:
	var n := 0
	for child in root.get_children():
		if child is ChargedShot:
			n += 1
	return n


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


func _release_all() -> void:
	for action in [&"move_left", &"move_right", &"move_up", &"move_down",
			&"jump", &"shoot", &"melee"]:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			Input.action_release(action)
