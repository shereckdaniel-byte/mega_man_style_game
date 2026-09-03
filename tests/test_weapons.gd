## The weapon catalogue, ammo bookkeeping, and the weakness table.
##
## The catalogue is loaded from `resources/weapons/` rather than stubbed,
## because the thing most likely to break here is a `.tres` -- a mistyped id, a
## projectile script that is not a WeaponShot, an ammo cost of 0 on a weapon
## that should charge. A stub would pass while the shipped resource was wrong.
extends TestCase

const WeaponManagerScript := preload("res://scripts/autoload/weapon_manager.gd")
const TIDE_TABLE := preload("res://resources/damage_tables/tide.tres")

var weapons: Node


func before_each() -> void:
	weapons = WeaponManagerScript.new()
	weapons.load_catalogue()
	weapons.reset()


func after_each() -> void:
	weapons.free()


# --- The catalogue --------------------------------------------------------------

func test_the_shipped_weapons_all_load() -> void:
	assert_true(weapons.catalogue.size() >= 3,
		"expected at least buster, tide_crawler and arc_lance, got %d"
			% weapons.catalogue.size())
	for id in [&"buster", &"tide_crawler", &"arc_lance"]:
		assert_not_null(weapons.data_for(id), "%s is missing from the catalogue" % id)


## A resource whose `id` does not match its own key would be unreachable: the
## manager files it under the id in the file, and every damage table looks it up
## by that same id, so a mismatch is a weapon that silently does nothing.
func test_every_weapon_is_filed_under_its_own_id() -> void:
	for id: StringName in weapons.catalogue:
		var data: WeaponData = weapons.catalogue[id]
		assert_eq(data.id, id, "%s is filed under the wrong key" % data.display_name)


func test_every_weapon_has_a_projectile_that_is_a_weapon_shot() -> void:
	for id: StringName in weapons.catalogue:
		var data: WeaponData = weapons.catalogue[id]
		assert_not_null(data.projectile_script, "%s has no projectile" % id)
		var shot: Object = data.projectile_script.new()
		assert_true(shot is WeaponShot, "%s does not fire a WeaponShot" % id)
		(shot as Node).free()


func test_every_weapon_is_named() -> void:
	for id: StringName in weapons.catalogue:
		var data: WeaponData = weapons.catalogue[id]
		assert_ne(data.display_name, "", "%s has no display name" % id)


# --- Ammo -----------------------------------------------------------------------

## The buster is the floor the player can never fall through. If it ever cost
## ammo, a player who ran everything dry would have no attack at all.
func test_the_buster_is_free_and_never_runs_dry() -> void:
	assert_eq(weapons.cost_of(&"buster"), 0)
	assert_true(weapons.can_fire(&"buster"))
	for i in 100:
		assert_true(weapons.consume(&"buster"), "buster refused shot %d" % i)
	assert_true(weapons.can_fire(&"buster"))


func test_an_unlocked_weapon_starts_full() -> void:
	weapons.unlock(&"tide_crawler")
	assert_eq(weapons.get_ammo(&"tide_crawler"), weapons.max_ammo(&"tide_crawler"))
	assert_eq(weapons.max_ammo(&"tide_crawler"), Health.BAR_TICKS)


func test_firing_drains_the_weapons_own_cost() -> void:
	weapons.unlock(&"tide_crawler")
	var cost: int = weapons.cost_of(&"tide_crawler")
	assert_true(cost > 0, "a real weapon has to cost something")
	var before: int = weapons.get_ammo(&"tide_crawler")
	assert_true(weapons.consume(&"tide_crawler"))
	assert_eq(weapons.get_ammo(&"tide_crawler"), before - cost)


## A refused shot must spend nothing. The bug this guards is a consume() that
## decrements first and checks afterwards, which leaves the bar at -1.
func test_an_empty_weapon_refuses_and_spends_nothing() -> void:
	weapons.unlock(&"tide_crawler")
	while weapons.can_fire(&"tide_crawler"):
		weapons.consume(&"tide_crawler")
	assert_eq(weapons.get_ammo(&"tide_crawler"), 0)
	assert_false(weapons.consume(&"tide_crawler"))
	assert_eq(weapons.get_ammo(&"tide_crawler"), 0)


func test_a_refill_stops_at_the_weapons_maximum() -> void:
	weapons.unlock(&"arc_lance")
	weapons.consume(&"arc_lance")
	weapons.refill(&"arc_lance", 999)
	assert_eq(weapons.get_ammo(&"arc_lance"), weapons.max_ammo(&"arc_lance"))


func test_a_locked_weapon_has_no_ammo_and_cannot_be_selected() -> void:
	assert_false(weapons.is_unlocked(&"arc_lance"))
	assert_eq(weapons.get_ammo(&"arc_lance"), 0)
	assert_false(weapons.select(&"arc_lance"))
	assert_eq(weapons.current, weapons.BUSTER)


# --- The weakness table ----------------------------------------------------------

## The roster's rule (docs/PLAN.md section 4): a boss takes 2-4x the buster's
## damage from the weapon it is weak to. Tide's weakness is the Arc Lance.
func test_tide_takes_weakness_damage_from_the_arc_lance() -> void:
	var buster_damage := TIDE_TABLE.damage_for(&"buster", 1)
	var lance_damage := TIDE_TABLE.damage_for(&"arc_lance", 2)
	assert_eq(buster_damage, 1)
	assert_eq(lance_damage, 4)
	assert_between(float(lance_damage) / float(buster_damage), 2.0, 4.0,
		"a weakness is worth 2-4x the buster")


## "No boss is weak to a weapon you get from it" -- otherwise the reward for
## beating a boss is the ability to beat the boss you already beat.
func test_tide_is_not_weak_to_its_own_weapon() -> void:
	var own := TIDE_TABLE.damage_for(&"tide_crawler", 2)
	var buster := TIDE_TABLE.damage_for(&"buster", 1)
	assert_true(own <= buster,
		"Tide Crawler does %d to Tide, buster does %d" % [own, buster])


## Tide has to be beatable with nothing, so the buster must actually hurt it.
func test_the_buster_hurts_tide() -> void:
	assert_true(TIDE_TABLE.damage_for(&"buster", 1) > 0)
	assert_false(TIDE_TABLE.is_immune(&"buster"))
