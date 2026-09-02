## GameState and WeaponManager, instantiated directly rather than through the
## autoload singletons so the tests do not depend on runner boot order.
extends TestCase

const GameStateScript := preload("res://scripts/autoload/game_state.gd")
const WeaponManagerScript := preload("res://scripts/autoload/weapon_manager.gd")

var state: Node
var weapons: Node


func before_each() -> void:
	state = GameStateScript.new()
	weapons = WeaponManagerScript.new()
	weapons.reset()


func after_each() -> void:
	state.free()
	weapons.free()


func test_boss_flags_are_independent_bits() -> void:
	state.mark_boss_defeated(0)
	state.mark_boss_defeated(7)
	assert_true(state.is_boss_defeated(0))
	assert_true(state.is_boss_defeated(7))
	for i in range(1, 7):
		assert_false(state.is_boss_defeated(i), "boss %d should be untouched" % i)


func test_marking_the_same_boss_twice_emits_once() -> void:
	var count := [0]
	state.boss_defeated.connect(func(_i: int) -> void: count[0] += 1)
	state.mark_boss_defeated(3)
	state.mark_boss_defeated(3)
	assert_eq(count[0], 1)


func test_progress_survives_a_save_round_trip() -> void:
	state.mark_boss_defeated(2)
	state.mark_boss_defeated(5)
	state.unlock_item(state.Item.JET)
	state.add_etank()
	state.add_etank()
	var restored: Node = GameStateScript.new()
	restored.from_dict(state.to_dict())
	assert_eq(restored.bosses_defeated, state.bosses_defeated)
	assert_true(restored.has_item(restored.Item.JET))
	assert_false(restored.has_item(restored.Item.COIL))
	assert_eq(restored.etanks, 2)
	restored.free()


func test_etanks_cap_and_floor() -> void:
	for i in 20:
		state.add_etank()
	assert_eq(state.etanks, state.MAX_ETANKS)
	for i in 20:
		state.consume_etank()
	assert_eq(state.etanks, 0)
	assert_false(state.consume_etank(), "consuming from empty must fail, not go negative")


func test_buster_is_always_available_and_never_runs_dry() -> void:
	assert_true(weapons.is_unlocked(weapons.BUSTER))
	assert_true(weapons.consume(weapons.BUSTER, 1))
	assert_eq(weapons.get_ammo(weapons.BUSTER), weapons.AMMO_MAX)


func test_locked_weapons_cannot_be_selected() -> void:
	assert_false(weapons.select(&"needle"))
	assert_eq(weapons.current, weapons.BUSTER)
	weapons.unlock(&"needle")
	assert_true(weapons.select(&"needle"))


func test_ammo_drains_and_refuses_to_go_negative() -> void:
	weapons.unlock(&"needle")
	assert_true(weapons.consume(&"needle", weapons.AMMO_MAX))
	assert_eq(weapons.get_ammo(&"needle"), 0)
	assert_false(weapons.consume(&"needle", 1), "empty weapon must not fire")
	assert_eq(weapons.get_ammo(&"needle"), 0)


## A partially failed consume must spend nothing at all.
func test_insufficient_ammo_spends_nothing() -> void:
	weapons.unlock(&"needle")
	weapons.consume(&"needle", 26)
	assert_eq(weapons.get_ammo(&"needle"), 2)
	assert_false(weapons.consume(&"needle", 5))
	assert_eq(weapons.get_ammo(&"needle"), 2)


func test_cycling_wraps_over_unlocked_weapons_only() -> void:
	weapons.unlock(&"needle")
	weapons.unlock(&"spark")
	assert_eq(weapons.unlocked().size(), 3)
	weapons.select(weapons.BUSTER)
	weapons.cycle(-1)
	assert_eq(weapons.current, &"spark", "cycling back from the buster wraps to the end")
	weapons.cycle(1)
	assert_eq(weapons.current, weapons.BUSTER)


func test_refill_respects_the_cap() -> void:
	weapons.unlock(&"needle")
	weapons.consume(&"needle", 10)
	weapons.refill(&"needle", 100)
	assert_eq(weapons.get_ammo(&"needle"), weapons.AMMO_MAX)
