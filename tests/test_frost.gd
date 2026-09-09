## Frost: the composition, and the bounds each pattern rests on.
##
## The composition is what this file mostly exists for. Frost is the only boss
## in the roster whose patterns depend on each other -- Rime is a harmless setup
## and Lock can only reach a player standing on what Rime left -- and the first
## version of the boss **described that in its docstring and did not implement
## it**: `act()` fired Lock unconditionally, which made it a third independent
## pattern. A prose-only design decision is one that quietly stops being true, so
## the gate is checked here.
extends TestCase

const FrostScript := preload("res://scenes/actors/bosses/frost.gd")
const Block := preload("res://scenes/actors/projectiles/ice_block.gd")
const PLAYER_SCENE := preload("res://scenes/actors/player/player.tscn")
const DAMAGE_TABLE := preload("res://resources/damage_tables/frost.tres")

var root: Node2D
var frost: Frost
var tuning: PlayerTuning


func is_async() -> bool:
	return true


func before_each_async() -> void:
	tuning = PlayerTuning.new()
	root = Node2D.new()
	tree.root.add_child(root)
	frost = FrostScript.new() as Frost
	root.add_child(frost)
	frost.seed_rng(7)
	await tree.physics_frame


func after_each_async() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


# --- The composition ------------------------------------------------------------

## **Lock is a wasted turn against a player on bare deck.** That is the whole
## structure of the fight: the answer to Lock is the answer to Rime, one pattern
## later.
func test_lock_does_nothing_to_a_player_who_is_not_on_ice() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await tree.physics_frame
	frost.target = player
	player.global_position = Vector2(400.0, 0.0)

	assert_false(frost.target_is_on_ice(),
		"the player is on ice before Rime has run")
	var before := root.get_child_count()
	frost.act(BossPattern.new(&"lock", 1, 1, 1, 1.0), 0)
	await tree.physics_frame
	assert_eq(root.get_child_count(), before,
		"Lock fired at a player standing on bare deck")


## And it does fire once Rime has put ice under them -- otherwise the gate would
## be satisfied by a pattern that never works at all.
func test_lock_fires_at_a_player_standing_on_rime() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await tree.physics_frame
	frost.target = player
	frost.set_arena_span(0.0, 3000.0)
	player.global_position = Vector2(1500.0, 0.0)

	frost.act(BossPattern.new(&"rime", 1, 1, 1, 1.0), 0)
	await tree.physics_frame
	assert_true(frost.sheets().size() > 0, "Rime laid no ice")
	assert_true(frost.target_is_on_ice(),
		"Rime is aimed at the player and did not reach them")

	var before := root.get_child_count()
	frost.act(BossPattern.new(&"lock", 1, 1, 1, 1.0), 0)
	await tree.physics_frame
	assert_true(root.get_child_count() > before, "Lock did not fire at an iced player")


## **Rime can never cover the arena.** The same bound Rust's alternate columns
## and Prism's facet span are built on: whatever it does, there is floor left to
## claim, or the pattern's answer does not exist.
func test_rime_always_leaves_floor_to_stand_on() -> void:
	var covered := float(FrostScript.RIME_SHEETS) * FrostScript.RIME_WIDTH_TILES
	# An arena is a room wide, and a room is ROOM_WIDTH tiles.
	assert_true(covered < float(AuthoredStage.ROOM_WIDTH) * 0.75,
		"%.0f tiles of ice in a %d-tile arena leaves almost nowhere"
			% [covered, AuthoredStage.ROOM_WIDTH])


# --- The bounds ------------------------------------------------------------------

## **It never takes the controls away.** A boss that can stop the player's
## inputs is a boss that can kill them while they watch, and every fairness rule
## in the roster exists so the player always has an answer available. Lock
## degrades grip instead -- every input still works and they all arrive late.
func test_lock_degrades_grip_rather_than_removing_control() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await tree.physics_frame
	player.slip(FrostScript.LOCK_SLIP_FRAMES, FrostScript.LOCK_SLIP_GRIP)
	assert_true(player.is_slipping(), "the coat did not take")
	assert_false(player.is_frozen() if player.has_method("is_frozen") else false,
		"Lock froze the player")
	assert_true(FrostScript.LOCK_SLIP_GRIP > 0.0,
		"a grip of zero is a floor the player can never stop on")


## The freeze front is jumpable, which is what makes it the fight's floor rather
## than its ceiling.
func test_the_freeze_front_can_be_jumped() -> void:
	assert_true(FrostScript.WAVE_NES.y < tuning.jump_apex_nes_px(),
		"the front is %.0f px tall and the jump reaches %.0f"
			% [FrostScript.WAVE_NES.y, tuning.jump_apex_nes_px()])
	# And slower than the player, so backing off buys time even though it is not
	# a solution on its own.
	assert_true(FrostScript.WAVE_SPEED_PF < tuning.walk_speed_pf * 3.0,
		"the front outruns any reading of it")


## A block is destructible and cheap enough that the buster alone is a real
## answer -- which it has to be, because this is the pattern whose whole point
## is that the fire button is the dodge.
func test_a_block_dies_to_a_handful_of_buster_pellets() -> void:
	assert_true(Block.BLOCK_HP >= 2 and Block.BLOCK_HP <= 4,
		"a %d-HP block is either free or not worth shooting" % Block.BLOCK_HP)


func test_frost_builds_its_three_patterns() -> void:
	var ids: Array[StringName] = []
	for pattern in frost.patterns():
		ids.append(pattern.id)
	assert_eq(ids.size(), 3, "Frost built %d patterns" % ids.size())
	for wanted in [&"rime", &"calving", &"lock"]:
		assert_has(ids, wanted, "Frost has no %s" % wanted)


# --- The stun, and the weapon that carries it -------------------------------------

## `DamageInfo.STUN` was defined at M0 and consumed by nothing for six stages.
## Archetype 7 is the whole reason it exists, so this checks the wiring rather
## than the weapon: any hit carrying the flag freezes, whoever threw it.
func test_a_stunning_hit_freezes_an_enemy() -> void:
	var walker := preload("res://scenes/actors/enemies/walker.gd").new() as Enemy
	root.add_child(walker)
	await tree.physics_frame
	assert_false(walker.is_frozen(), "the enemy started frozen")
	walker.health.take(DamageInfo.new(1, Vector2.ZERO, &"frost_lock", DamageInfo.STUN))
	await tree.physics_frame
	assert_true(walker.is_frozen(), "a STUN hit did not freeze")
	# It refreshes rather than stacking: two hits a frame apart must not mean
	# twice as long, or the weapon's real output is the player's fire rate.
	var first := walker.frozen_frames()
	walker.freeze(Enemy.STUN_FRAMES)
	assert_true(walker.frozen_frames() <= first + 1, "freezes stacked")
	walker.queue_free()


## An ordinary hit does not freeze, or the flag means nothing.
func test_an_ordinary_hit_does_not_freeze() -> void:
	var walker := preload("res://scenes/actors/enemies/walker.gd").new() as Enemy
	root.add_child(walker)
	await tree.physics_frame
	walker.health.take(DamageInfo.new(1, Vector2.ZERO, &"buster", DamageInfo.NONE))
	await tree.physics_frame
	assert_false(walker.is_frozen(), "a plain buster pellet froze an enemy")
	walker.queue_free()


func test_the_lock_carries_the_stun_flag() -> void:
	var weapon := load("res://resources/weapons/frost_lock.tres") as WeaponData
	assert_not_null(weapon, "frost_lock.tres does not load")
	assert_eq(weapon.id, &"frost_lock")
	assert_true(weapon.flags & DamageInfo.STUN,
		"the Frost Lock does not carry the flag that does its whole job")
	# And it does damage, which is not a taste: a zero-damage hit is refused
	# before `Health.damaged` fires, and the freeze rides on that signal.
	assert_true(weapon.damage > 0,
		"a zero-damage bolt never reaches the signal the freeze rides on")


# --- The weakness chain ------------------------------------------------------------

func test_frost_is_weak_to_quarry_and_not_to_its_own_lock() -> void:
	var lock := DAMAGE_TABLE.damage_for(&"frost_lock", 1)
	var bore := DAMAGE_TABLE.damage_for(&"quarry_bore", 1)
	assert_true(bore > lock, "Frost is meant to be weak to Quarry Bore")
	assert_true(bore >= 2 and bore <= 4, "weakness damage stays inside the 2-4x rule")


func test_every_shipped_table_prices_the_lock() -> void:
	for name in ["tide", "arc", "rust", "prism", "gale", "cinder"]:
		var table := load("res://resources/damage_tables/%s.tres" % name) as DamageTable
		assert_true(table.by_weapon.has(&"frost_lock"),
			"%s has no price for the Frost Lock" % name)
