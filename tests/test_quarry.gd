## Quarry: the bounds its patterns rest on, and **the whole weakness chain**,
## which closes with this boss.
##
## The chain check lives here rather than in a file of its own because this is
## the stage that completes it: with Quarry built, both cycles are closed, no
## boss is weak to the weapon it drops, and all eight archetypes are used once.
## Those are four separate claims PLAN.md makes about the roster and none of
## them was checkable until now.
extends TestCase

const QuarryScript := preload("res://scenes/actors/bosses/quarry.gd")
const Strike := preload("res://scenes/actors/projectiles/bore_strike.gd")
const Chunk := preload("res://scenes/actors/projectiles/rubble.gd")
const Bore := preload("res://scenes/actors/projectiles/bore_shot.gd")
const PLAYER_SCENE := preload("res://scenes/actors/player/player.tscn")

var root: Node2D
var quarry: Quarry
var tuning: PlayerTuning


func is_async() -> bool:
	return true


func before_each_async() -> void:
	tuning = PlayerTuning.new()
	root = Node2D.new()
	tree.root.add_child(root)
	quarry = QuarryScript.new() as Quarry
	root.add_child(quarry)
	quarry.seed_rng(7)
	await tree.physics_frame


func after_each_async() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


# --- Bore: the tell is on the floor ----------------------------------------------

## **Too tall to jump, so reading it late is not an option.** That is what makes
## the crack worth looking away from the boss for -- a Bore a player could hop
## at the last moment would be a low attack with a decorative telegraph.
func test_the_bore_cannot_be_jumped() -> void:
	assert_true(Strike.HEIGHT_NES > tuning.jump_apex_nes_px(),
		"the drill is %.0f px tall and the jump reaches %.0f"
			% [Strike.HEIGHT_NES, tuning.jump_apex_nes_px()])
	# And narrow enough to walk out of, or the answer would not exist.
	var jump_reach := tuning.walk_speed_pf * _jump_airtime_frames()
	assert_true(Strike.WIDTH_NES < jump_reach,
		"the drill is %.0f px wide and a jump covers %.0f"
			% [Strike.WIDTH_NES, jump_reach])


## The crack is harmless for its whole arm, and the arm is long -- the pattern
## asks the player to notice something that is not where they are looking, so it
## has to be there long enough to find.
func test_the_crack_is_harmless_and_long_enough_to_notice() -> void:
	var strike := Strike.new() as BoreStrike
	strike.mark(Vector2(0.0, 400.0), 4, tuning)
	root.add_child(strike)
	await tree.physics_frame
	assert_false(strike.is_up(), "the drill came up on the frame it was marked")
	assert_false(strike.monitoring, "the crack is dangerous")
	# Above the reaction slack PhaseBlock's beat is built on: a jump lasts about
	# 40 frames and 12 more is roughly a fifth of a second to decide in.
	assert_true(Strike.ARM_FRAMES > 40,
		"a %d-frame arm is not long enough to find a tell you are not looking at"
			% Strike.ARM_FRAMES)
	strike.queue_free()


## **The two strikes are aimed at different moments.** The first goes where the
## player was when the tell began and the second where they are when it lands,
## so standing still answers one and running answers the other -- and neither
## answers both.
func test_the_two_strikes_are_aimed_at_different_moments() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await tree.physics_frame
	quarry.target = player
	quarry.set_arena_span(0.0, 4000.0)

	player.global_position = Vector2(800.0, 0.0)
	quarry.tell(BossPattern.new(&"bore", 1, 1, 1, 1.0), 0)
	assert_almost_eq(quarry.bore_aim(), 800.0, 1.0, "the tell did not latch")

	player.global_position = Vector2(2600.0, 0.0)
	quarry.tell(BossPattern.new(&"bore", 1, 1, 1, 1.0), 9)
	assert_almost_eq(quarry.bore_aim(), 800.0, 0.001,
		"the latched aim followed the player")
	assert_eq(QuarryScript.BORE_STRIKES.size(), 2,
		"the pattern needs both a latched strike and a live one")


# --- Cave-In: the attack that leaves something ------------------------------------

## Rubble lands as a platform, which is what makes Cave-In the only boss attack
## in the game that gives the player anything -- and it has to, because the Bore
## cannot be jumped from the floor.
func test_rubble_becomes_a_platform() -> void:
	var chunk := Chunk.new() as Rubble
	chunk.drop(Vector2(500.0, 100.0), 300.0, tuning)
	root.add_child(chunk)
	# Long enough to fall 200 px under gravity.
	for _i in 90:
		await tree.physics_frame
	var steps := 0
	for child in root.get_children():
		if child is OneWayPlatform:
			steps += 1
	assert_true(steps > 0, "the rubble landed and left nothing to stand on")


## And it is spread rather than aimed, because debris that always landed on the
## player would always land where they could not use it.
func test_the_cave_in_is_spread_rather_than_aimed() -> void:
	assert_eq(QuarryScript.RUBBLE_FRAMES.size(), QuarryScript.RUBBLE_BLOCKS,
		"every block needs a frame to fall on")
	# Spaced in time, so the pattern is a collapse rather than a volley.
	var frames: Array = QuarryScript.RUBBLE_FRAMES
	for i in range(1, frames.size()):
		assert_true(int(frames[i]) - int(frames[i - 1]) >= 8,
			"two blocks fall %d frames apart; that is one wide obstacle"
				% [int(frames[i]) - int(frames[i - 1])])


# --- Flood: the recalibration ------------------------------------------------------

## Flood cannot hurt anybody, which is what lets it cover the whole arena. A
## pattern the player can stand beside is a pattern they never have to re-aim
## inside, and re-aiming is the whole of it.
func test_the_flood_is_harmless() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await tree.physics_frame
	quarry.target = player
	quarry.set_arena_span(0.0, 3000.0)
	var before := player.health.current
	quarry.act(BossPattern.new(&"flood", 1, 1, 1, 1.0), 0)
	for _i in 30:
		await tree.physics_frame
	assert_eq(player.health.current, before, "the flood did damage")
	var pools := 0
	for child in root.get_children():
		if child is WaterVolume:
			pools += 1
	assert_true(pools > 0, "the flood raised no water")


func test_quarry_builds_its_three_patterns() -> void:
	var ids: Array[StringName] = []
	for pattern in quarry.patterns():
		ids.append(pattern.id)
	assert_eq(ids.size(), 3, "Quarry built %d patterns" % ids.size())
	for wanted in [&"bore", &"cavein", &"flood"]:
		assert_has(ids, wanted, "Quarry has no %s" % wanted)


# --- The Bore weapon ---------------------------------------------------------------

## Piercing, and **capped** -- an uncapped piercing shot is strictly better than
## the buster in every situation, which makes choosing it not a choice.
func test_the_bore_pierces_and_is_capped() -> void:
	var weapon := load("res://resources/weapons/quarry_bore.tres") as WeaponData
	assert_not_null(weapon, "quarry_bore.tres does not load")
	assert_eq(weapon.id, &"quarry_bore")
	assert_true(weapon.flags & DamageInfo.PIERCE,
		"the Quarry Bore does not carry the flag that does its whole job")
	var cap := int(weapon.get_number(&"pierce", 0.0))
	assert_true(cap >= 2 and cap <= 5,
		"a %d-target bore is either not piercing or not a choice" % cap)


# --- The chain, which closes here --------------------------------------------------

## **Every boss is weak to exactly one weapon, and it is never their own.**
func test_no_boss_is_weak_to_the_weapon_it_drops() -> void:
	for row in StageRoster.ENTRIES:
		var id := _weapon_id(String(row["weapon"]))
		var table := _table(String(row["boss"]))
		assert_not_null(table, "%s has no damage table" % row["boss"])
		if table == null:
			continue
		var own := table.damage_for(id, 1)
		assert_eq(own, 1,
			"%s takes %d from its own %s; a boss's own weapon is its worst"
				% [row["boss"], own, row["weapon"]])


## **Both cycles close.** PLAN.md section 4 specifies a 5-cycle over bosses 1-5
## and a 3-cycle over 6-8; this walks the weakness graph and checks it is
## exactly those two loops with nothing dangling.
func test_the_weakness_chain_is_two_closed_cycles() -> void:
	var weak_to := {}
	for row in StageRoster.ENTRIES:
		var table := _table(String(row["boss"]))
		if table == null:
			continue
		var found := ""
		for weapon: StringName in table.by_weapon:
			if int(table.by_weapon[weapon]) == 4:
				assert_eq(found, "",
					"%s is weak to more than one weapon" % row["boss"])
				found = String(weapon)
		assert_true(found != "", "%s is weak to nothing" % row["boss"])
		weak_to[String(row["boss"])] = found

	# Walk from each boss to whoever drops the weapon it fears.
	var drops := {}
	for row in StageRoster.ENTRIES:
		drops[_weapon_id(String(row["weapon"]))] = String(row["boss"])

	var lengths: Array[int] = []
	var seen := {}
	for row in StageRoster.ENTRIES:
		var start := String(row["boss"])
		if seen.has(start):
			continue
		var at := start
		var length := 0
		while not seen.has(at):
			seen[at] = true
			length += 1
			var next: String = drops.get(weak_to[at], "")
			assert_true(next != "",
				"%s is weak to %s, which nothing drops" % [at, weak_to[at]])
			at = next
		assert_eq(at, start,
			"the walk from %s ended at %s rather than closing" % [start, at])
		lengths.append(length)
	lengths.sort()
	assert_eq(lengths, [3, 5] as Array[int],
		"the chain is %s and PLAN.md specifies a 3-cycle and a 5-cycle" % str(lengths))


## **All eight archetypes, used once each.** Checked as eight distinct weapon
## resources that all exist and all load -- the weakest form of the claim that
## can actually be tested, and it is the one that catches a stage shipping
## without its weapon.
func test_every_boss_drops_a_weapon_that_exists() -> void:
	var ids := {}
	for row in StageRoster.ENTRIES:
		var id := _weapon_id(String(row["weapon"]))
		var path := "res://resources/weapons/%s.tres" % id
		assert_true(ResourceLoader.exists(path),
			"%s drops %s and there is no such weapon" % [row["boss"], row["weapon"]])
		assert_false(ids.has(id), "two bosses drop %s" % id)
		ids[id] = true
	assert_eq(ids.size(), 8, "%d weapons for eight bosses" % ids.size())


# --- Helpers ---------------------------------------------------------------------

func _weapon_id(display: String) -> StringName:
	return StringName(display.to_snake_case())


func _table(boss: String) -> DamageTable:
	var path := "res://resources/damage_tables/%s.tres" % boss.to_lower()
	if not ResourceLoader.exists(path):
		return null
	return load(path) as DamageTable


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
