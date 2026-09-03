## The damage pipeline, end to end: a real Hitbox overlapping a real Hurtbox,
## forwarded to a real Health, on a real Player in a real scene tree.
##
## Unit-testing Health alone would pass while the pipeline is disconnected --
## the interesting failures here are wiring failures. A hurtbox on the wrong
## layer, a hitbox that masks nothing, or a hurtbox that resolves no Health all
## produce a player who simply cannot be hurt, and nothing errors.
extends TestCase

const PLAYER_SCENE := preload("res://scenes/actors/player/player.tscn")

const FLOOR_TOP := 400.0
const SPAWN := Vector2(200.0, FLOOR_TOP)
const SETTLE_FRAMES := 12

var root: Node2D
var player: Player
var t: PlayerTuning


func is_async() -> bool:
	return true


func before_each_async() -> void:
	_release_all()
	root = Node2D.new()
	tree.root.add_child(root)
	_add_floor(Vector2(-1000.0, FLOOR_TOP), Vector2(4000.0, 200.0))
	player = PLAYER_SCENE.instantiate()
	player.position = SPAWN
	root.add_child(player)
	t = player.tuning
	await _frames(SETTLE_FRAMES)


func after_each_async() -> void:
	_release_all()
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


# --- Health and the damage table ----------------------------------------------

## 28 HP for the player and every boss, so one energy-bar tick is one HP and the
## HUD needs no scaling maths. ARCHITECTURE section 5.3.
func test_player_starts_at_the_full_bar() -> void:
	assert_eq(player.health.max_hp, Health.BAR_TICKS)
	assert_eq(player.health.max_hp, 28)
	assert_eq(player.health.current, 28)


func test_damage_tables_are_absolute_not_multipliers() -> void:
	var table := DamageTable.new()
	table.by_weapon = {&"needle": 4}
	# The listed weapon does its listed damage, whatever the hit carried...
	assert_eq(table.damage_for(&"needle", 1), 4)
	assert_eq(table.damage_for(&"needle", 3), 4, "absolute, not 3x")
	# ...and an unlisted one falls through to what the hit carried, which is how
	# the buster's 1 works without every table spelling it out.
	assert_eq(table.damage_for(&"buster", 1), 1)


func test_immunity_is_not_the_same_as_resistance() -> void:
	var table := DamageTable.new()
	table.by_weapon = {&"spark": 1}
	table.immune_to = [&"spark"]
	assert_eq(table.damage_for(&"spark", 9), 0, "immunity wins over the table")


func test_health_clamps_rather_than_going_negative() -> void:
	var health := Health.new()
	health.max_hp = 4
	health.current = 4
	assert_eq(health.take(DamageInfo.new(10)), 4, "reports what it actually took")
	assert_eq(health.current, 0)
	assert_true(health.is_dead())
	health.free()


func test_healing_stops_at_full() -> void:
	var health := Health.new()
	health.max_hp = 28
	health.current = 26
	assert_eq(health.heal(10), 2, "only the missing 2")
	assert_eq(health.current, 28)
	health.free()


# --- Invulnerability ----------------------------------------------------------

func test_a_hit_lands_and_starts_the_iframes() -> void:
	var hitbox := _add_enemy_hitbox(3, player.global_position + Vector2(0.0, -40.0))
	await _frames(4)
	assert_eq(player.health.current, 25, "28 - 3")
	assert_true(player.health.is_invulnerable(), "i-frames start on the hit")
	assert_eq(player.state_machine.current_name(), &"Hurt", "knockback is a state")
	hitbox.queue_free()


## The reason i-frames exist: without them, contact damage applies every frame
## the boxes overlap and a single enemy empties the bar in well under a second.
func test_a_second_hit_during_iframes_is_refused() -> void:
	var hitbox := _add_enemy_hitbox(3, player.global_position + Vector2(0.0, -40.0))
	await _frames(4)
	var after_first := player.health.current
	hitbox.rearm()
	hitbox.global_position = player.global_position + Vector2(4.0, -40.0)
	await _frames(6)
	assert_eq(player.health.current, after_first, "still invulnerable")
	hitbox.queue_free()


func test_iframes_last_the_tuned_number_of_frames() -> void:
	assert_eq(player.health.invulnerable_frames, t.iframes)
	assert_eq(t.iframes, 90, "~1.5 s at 60 Hz")
	_add_enemy_hitbox(3, player.global_position + Vector2(0.0, -40.0))
	await _frames(3)
	var left := player.health.invulnerable_frames_left()
	await _frames(10)
	assert_eq(player.health.invulnerable_frames_left(), left - 10, "counts down once per frame")


## The flicker is the only feedback that i-frames are running, so it has to
## actually toggle -- a bug that left the sprite permanently visible would be
## invisible to every other test here.
func test_the_sprite_flickers_while_invulnerable() -> void:
	_add_enemy_hitbox(3, player.global_position + Vector2(0.0, -40.0))
	await _frames(4)
	var seen_visible := false
	var seen_hidden := false
	for i in 24:
		await tree.physics_frame
		if player.sprite.visible:
			seen_visible = true
		else:
			seen_hidden = true
	assert_true(seen_visible and seen_hidden, "sprite toggles during i-frames")


func test_the_sprite_is_left_visible_once_iframes_end() -> void:
	_add_enemy_hitbox(3, player.global_position + Vector2(0.0, -40.0))
	await _frames(t.iframes + 10)
	assert_false(player.health.is_invulnerable())
	assert_true(player.sprite.visible, "never left invisible")


# --- Knockback ----------------------------------------------------------------

## The acceptance test for M3: a hit you cannot steer out of is what makes a pit
## next to an enemy lethal. If knockback were steerable this would pass anyway,
## so the test holds the *opposite* direction and asserts it is ignored.
func test_knockback_pushes_away_from_the_source_and_ignores_input() -> void:
	var start := player.global_position.x
	_add_enemy_hitbox(3, player.global_position + Vector2(60.0, -40.0))
	await _frames(2)
	assert_eq(player.state_machine.current_name(), &"Hurt")
	Input.action_press(&"move_right")          # back towards what just hit us
	await _frames(6)
	Input.action_release(&"move_right")
	assert_true(player.global_position.x < start,
		"pushed left, away from a source on the right, despite holding right")


func test_knockback_releases_after_the_tuned_frames() -> void:
	_add_enemy_hitbox(3, player.global_position + Vector2(60.0, -40.0))
	await _frames(t.knockback_frames + 8)
	assert_ne(player.state_machine.current_name(), &"Hurt", "control comes back")


# --- The buster ---------------------------------------------------------------

func test_shooting_spawns_a_pellet_and_strikes_the_pose() -> void:
	await _press(&"shoot")
	Input.action_release(&"shoot")
	await _frames(2)
	assert_eq(player.live_shots(), 1)
	assert_true(player.is_shooting(), "the 16-frame shoot pose is held")


## Mega Man 3 has no charge shot; the cap on live pellets is what limits the
## buster's damage over time, so it is a mechanic and not an optimisation.
func test_no_more_than_three_pellets_are_live() -> void:
	for i in 6:
		await _press(&"shoot")
		Input.action_release(&"shoot")
		await _frames(2)
	assert_eq(player.live_shots(), t.max_buster_shots)
	assert_eq(t.max_buster_shots, 3)


func test_a_pellet_leaves_the_muzzle_facing_the_way_the_player_does() -> void:
	player.facing = -1
	await _press(&"shoot")
	Input.action_release(&"shoot")
	await _frames(1)
	var shot := _first_shot()
	assert_not_null(shot)
	assert_true(shot.global_position.x < player.global_position.x, "spawned to the left")
	var before := shot.global_position.x
	await _frames(5)
	assert_true(shot.global_position.x < before, "and travels left")


func test_the_muzzle_sits_on_the_character_not_at_its_feet() -> void:
	var muzzle := player.muzzle_position()
	var height := t.hitbox_size().y
	var above_feet := player.global_position.y - muzzle.y
	assert_between(above_feet, height * 0.4, height,
		"cannon is at chest height, not on the floor and not over the head")


## Sliding, knockback, death and the teleport-in all take the arm cannon away.
## Declared per state so adding a state means answering the question.
func test_states_out_of_the_players_control_cannot_shoot() -> void:
	for state_name in [&"Slide", &"Hurt", &"Dead", &"Teleport"]:
		var state: State = player.state_machine._states[state_name]
		assert_false(state.can_shoot, "%s must not fire" % state_name)
	for state_name in [&"Idle", &"Walk", &"Jump", &"Fall", &"Climb"]:
		var state: State = player.state_machine._states[state_name]
		assert_true(state.can_shoot, "%s should fire" % state_name)


func test_a_pellet_is_spent_on_the_wall_it_hits() -> void:
	# A wall just ahead of the muzzle; the pellet must not pass through it.
	_add_floor(Vector2(SPAWN.x + 100.0, FLOOR_TOP - 300.0), Vector2(40.0, 300.0))
	await _frames(2)
	await _press(&"shoot")
	Input.action_release(&"shoot")
	await _frames(30)
	assert_eq(player.live_shots(), 0, "stopped at the wall rather than flying on")


# --- Death --------------------------------------------------------------------

func test_running_out_of_health_kills_and_freezes() -> void:
	_add_enemy_hitbox(99, player.global_position + Vector2(0.0, -40.0))
	await _frames(6)
	assert_true(player.health.is_dead())
	assert_eq(player.state_machine.current_name(), &"Dead")


func test_a_dead_player_cannot_shoot() -> void:
	_add_enemy_hitbox(99, player.global_position + Vector2(0.0, -40.0))
	await _frames(6)
	assert_false(player.can_shoot())
	await _press(&"shoot")
	Input.action_release(&"shoot")
	await _frames(2)
	assert_eq(player.live_shots(), 0)


func test_respawn_restores_the_bar_and_grants_grace() -> void:
	_add_enemy_hitbox(99, player.global_position + Vector2(0.0, -40.0))
	await _frames(6)
	player.respawn_at(SPAWN)
	await _frames(2)
	assert_eq(player.health.current, 28, "full bar")
	assert_false(player.health.is_dead())
	assert_true(player.health.is_invulnerable(), "grace period, or you die again instantly")
	assert_eq(player.state_machine.current_name(), &"Idle")


# --- Helpers ------------------------------------------------------------------

## A stand-in for an enemy's contact-damage box: the layers an enemy will use,
## so this exercises the real masks rather than a convenient pair.
func _add_enemy_hitbox(amount: int, at: Vector2) -> Hitbox:
	var hitbox := Hitbox.new()
	hitbox.amount = amount
	hitbox.weapon_id = &"contact"
	hitbox.one_shot = true
	hitbox.collision_layer = Layers.bit(Layers.ENEMY_ATTACK)
	hitbox.collision_mask = Layers.bit(Layers.PLAYER_HURTBOX)
	hitbox.monitoring = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(48.0, 48.0)
	shape.shape = rect
	hitbox.add_child(shape)
	root.add_child(hitbox)
	hitbox.global_position = at
	return hitbox


# --- Weapon colour --------------------------------------------------------------

## The hue-rotation shader from SPRITES.md section 3. Its job is to make the
## equipped weapon visible on the character; its risk is dragging the outline
## and highlights with it, which is why the shader weights by saturation.
func test_the_player_wears_the_weapon_palette_shader() -> void:
	var material := player.sprite.material as ShaderMaterial
	assert_not_null(material, "the sprite has no shader material")
	assert_eq(material.shader, Player.WEAPON_PALETTE)


## The buster must be a no-op. The art was drawn in the buster's colours, so any
## shift at all means the default sprite is not the sprite the artist made.
func test_the_buster_does_not_recolour_the_player() -> void:
	assert_almost_eq(player.weapon_hue_shift(&"buster"), 0.0, 0.0001)


func test_an_unknown_weapon_leaves_the_colour_alone() -> void:
	assert_almost_eq(player.weapon_hue_shift(&"not_a_weapon"), 0.0, 0.0001)


## A weapon nobody can see they have equipped is a weapon they will forget they
## have. Both shipped weapons have to move the sprite somewhere visible.
func test_each_weapon_shifts_the_hue_somewhere_visible() -> void:
	var weapons := tree.root.get_node_or_null(^"WeaponManager")
	if weapons == null:
		return
	for id in [&"tide_crawler", &"arc_lance"]:
		if weapons.data_for(id) == null:
			continue
		var shift: float = absf(player.weapon_hue_shift(id))
		assert_true(shift > 0.05,
			"%s shifts the hue by only %.3f turns" % [id, shift])


func _first_shot() -> BusterShot:
	for child in root.get_children():
		if child is BusterShot:
			return child as BusterShot
	return null


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


func _press(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)


func _frames(count: int) -> void:
	for i in count:
		await tree.physics_frame


func _release_all() -> void:
	for action in [&"move_left", &"move_right", &"move_up", &"move_down", &"jump", &"shoot"]:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			Input.action_release(action)
