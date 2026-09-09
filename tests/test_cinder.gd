## Cinder: the bounds each pattern rests on, checked against the tuning rather
## than the prose.
##
## The dangerous shape, restated from `tests/test_gale.gd`: every one of these
## inequalities is between a boss constant and a *player* constant, and retuning
## the jump or the walk is a change nobody would think to make against a boss
## file. So none of the numbers is written down here.
extends TestCase

const CinderScript := preload("res://scenes/actors/bosses/cinder.gd")
const Ember := preload("res://scenes/actors/projectiles/ash_ember.gd")
const Wall := preload("res://scenes/actors/projectiles/flame_wall.gd")
const PLAYER_SCENE := preload("res://scenes/actors/player/player.tscn")
const DAMAGE_TABLE := preload("res://resources/damage_tables/cinder.tres")

var root: Node2D
var cinder: Cinder
var tuning: PlayerTuning


func is_async() -> bool:
	return true


func before_each_async() -> void:
	tuning = PlayerTuning.new()
	root = Node2D.new()
	tree.root.add_child(root)
	cinder = CinderScript.new() as Cinder
	root.add_child(cinder)
	cinder.seed_rng(7)
	await tree.physics_frame


func after_each_async() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


# --- Ashfall: the pattern has to be baitable ------------------------------------

## **The aim is latched at the tell and never updated.** That is the whole of
## what makes baiting the answer: if the fan tracked the player it would be a
## thing to dodge, and dodging is answered fifteen times already.
func test_the_ashfall_aim_is_locked_when_the_tell_begins() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await tree.physics_frame
	cinder.target = player

	player.global_position = Vector2(500.0, 0.0)
	cinder.tell(BossPattern.new(&"ashfall", 1, 1, 1, 1.0), 0)
	var locked := cinder.ash_aim()
	assert_almost_eq(locked, 500.0, 1.0, "the tell did not latch the player's x")

	# The player leaves. The aim must not follow.
	player.global_position = Vector2(1400.0, 0.0)
	cinder.tell(BossPattern.new(&"ashfall", 1, 1, 1, 1.0), 8)
	assert_almost_eq(cinder.ash_aim(), locked, 0.001,
		"the aim tracked the player, so the pattern cannot be baited")


## **The fan is wider than the player and narrower than a walk out of it.**
##
## The first half is what makes it a pattern rather than a thing to stand
## inside; the second is what makes baiting an answer rather than luck. Both are
## measured against the real hitbox and the real jump.
func test_the_ash_fan_cannot_be_stood_in_and_can_be_walked_out_of() -> void:
	assert_true(CinderScript.ASH_SPREAD_NES > PlayerTuning.NES_HITBOX.x,
		"a %.0f px fan does not cover a %.0f px player"
			% [CinderScript.ASH_SPREAD_NES, PlayerTuning.NES_HITBOX.x])
	# A jump covers about 3.4 tiles at walk speed; the fan must be inside that,
	# or leaving the aim point is not something a player can actually do.
	var jump_reach := tuning.walk_speed_pf * _jump_airtime_frames()
	assert_true(CinderScript.ASH_SPREAD_NES < jump_reach,
		"the fan is %.0f px wide and a jump covers %.0f"
			% [CinderScript.ASH_SPREAD_NES, jump_reach])


## An ember is harmless until it lands. The pattern is about the floor it takes
## away, not about the thing in the air, and being hit on the way up would make
## the arc unreadable.
func test_an_ember_in_flight_is_not_dangerous() -> void:
	var ember := Ember.new() as AshEmber
	ember.throw(Vector2(0.0, 0.0), Vector2(40.0, -400.0), 900.0, 3, tuning)
	root.add_child(ember)
	await tree.physics_frame
	assert_false(ember.is_landed(), "the ember landed on the frame it spawned")
	assert_false(ember.monitoring, "an ember in flight is already dangerous")
	ember.queue_free()


# --- Flue: a constant the player can refuse -------------------------------------

## The rule `ConveyorBelt` and `WindZone` are both held to. A drag at or above
## the walk speed is a room the player cannot leave, which is not a pattern.
func test_the_flue_pull_leaves_more_than_half_the_walk() -> void:
	assert_true(CinderScript.FLUE_PULL_PF < tuning.walk_speed_pf,
		"the flue pulls at %.2f and the player walks at %.2f"
			% [CinderScript.FLUE_PULL_PF, tuning.walk_speed_pf])
	var left := (tuning.walk_speed_pf - CinderScript.FLUE_PULL_PF) / tuning.walk_speed_pf
	assert_true(left > 0.5,
		"walking out of the flue leaves %.0f%% of the player's speed" % [left * 100.0])


## **It uses the conveyor's channel, not the wind's**, and that is deliberate:
## the belt rule is "never touches a jump", so the pull can never shorten a leap
## out of the arena. Stage 5's headwind could, and it made authored gaps
## uncrossable.
func test_the_flue_pulls_through_the_carry_channel() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await tree.physics_frame
	cinder.target = player
	player.wind_drift_pf = 0.0
	player.carry_drift_pf = 0.0
	cinder.act(BossPattern.new(&"flue", 1, 1, 1, 1.0), 4)
	assert_almost_eq(absf(player.carry_drift_pf), CinderScript.FLUE_PULL_PF, 0.001,
		"the flue did not reach the player's carry")
	assert_almost_eq(player.wind_drift_pf, 0.0, 0.001,
		"the flue wrote the wind channel, which would let it shorten a jump")


# --- Backdraft: the tell is the opening -----------------------------------------

## **The longest tell in the fight**, because the tell is what the pattern is
## for. A player who spends it attacking is taking the fight's best offer, and a
## short window would make Backdraft a thing to run from instead.
func test_the_backdraft_tell_is_the_longest_in_the_fight() -> void:
	var backdraft := 0
	var longest_other := 0
	for pattern in cinder.patterns():
		if pattern.id == &"backdraft":
			backdraft = pattern.tell_frames
		else:
			longest_other = maxi(longest_other, pattern.tell_frames)
	assert_true(backdraft > 0, "Cinder has no backdraft")
	assert_true(backdraft > longest_other,
		"the backdraft tell is %d frames and another pattern tells for %d"
			% [backdraft, longest_other])
	# And long enough to be worth using: several buster shots, not one.
	assert_true(backdraft >= 48,
		"a %d-frame window is not a damage window" % backdraft)


## And the breath itself is jumpable, which is the one out left for a player who
## spent the tell attacking and is still standing in front of it.
func test_the_breath_can_be_jumped() -> void:
	assert_true(CinderScript.BREATH_NES.y < tuning.jump_apex_nes_px(),
		"the breath is %.0f px tall and the jump reaches %.0f"
			% [CinderScript.BREATH_NES.y, tuning.jump_apex_nes_px()])
	# But not duckable: sliding must not be a second, easier answer.
	assert_true(CinderScript.BREATH_NES.y > PlayerTuning.NES_SLIDE_HITBOX.y,
		"a slide fits under the breath")


func test_cinder_builds_its_three_patterns() -> void:
	var ids: Array[StringName] = []
	for pattern in cinder.patterns():
		ids.append(pattern.id)
	assert_eq(ids.size(), 3, "Cinder built %d patterns" % ids.size())
	for wanted in [&"ashfall", &"flue", &"backdraft"]:
		assert_has(ids, wanted, "Cinder has no %s" % wanted)


# --- The weakness chain ------------------------------------------------------------

func test_cinder_is_weak_to_frost_and_not_to_its_own_spray() -> void:
	var spray := DAMAGE_TABLE.damage_for(&"cinder_spray", 1)
	var lock := DAMAGE_TABLE.damage_for(&"frost_lock", 1)
	assert_true(lock > spray, "Cinder is meant to be weak to Frost Lock")
	assert_true(lock >= 2 and lock <= 4, "weakness damage stays inside the 2-4x rule")


## And the Spray exists, so every shipped boss can be hit with it.
func test_the_spray_exists_and_every_table_prices_it() -> void:
	var weapon := load("res://resources/weapons/cinder_spray.tres") as WeaponData
	assert_not_null(weapon, "cinder_spray.tres does not load")
	assert_eq(weapon.id, &"cinder_spray")
	assert_not_null(weapon.projectile_script, "the Cinder Spray fires nothing")
	for name in ["tide", "arc", "rust", "prism", "gale"]:
		var table := load("res://resources/damage_tables/%s.tres" % name) as DamageTable
		assert_true(table.by_weapon.has(&"cinder_spray"),
			"%s has no price for the Cinder Spray" % name)


func _jump_airtime_frames() -> float:
	var v := -tuning.jump_velocity_pf
	var y := 0.0
	var frames := 0
	while true:
		v += tuning.gravity_pf
		y += v
		frames += 1
		if y >= 0.0:
			break
	return float(frames)
