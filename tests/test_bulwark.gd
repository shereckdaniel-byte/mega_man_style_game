## Bulwark: the two-form final boss.
##
## **The form change is the part the bot cannot check.** Its best run took the
## shell to 1 HP and died there, so nothing in a playthrough has ever seen the
## second form -- which makes this file the only thing standing behind half the
## last fight in the game.
extends TestCase

const BulwarkScript := preload("res://scenes/actors/bosses/bulwark.gd")

const FLOOR_TOP := 600.0
const INTRO_FRAMES := 60

var root: Node2D
var boss: Bulwark


func is_async() -> bool:
	return true


func before_each_async() -> void:
	root = Node2D.new()
	tree.root.add_child(root)
	_add_floor(Vector2(-2000.0, FLOOR_TOP), Vector2(6000.0, 200.0))
	boss = BulwarkScript.new() as Bulwark
	boss.position = Vector2(600.0, FLOOR_TOP)
	root.add_child(boss)
	await _frames(2)


func after_each_async() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


func _fight() -> void:
	boss.begin_intro(Vector2(600.0, FLOOR_TOP), null)
	await _frames(INTRO_FRAMES)
	boss.begin_fight()


## Drives the current form to zero, one legal hit at a time.
func _empty_the_bar() -> void:
	var guard := 0
	while boss.health.current > 0 and guard < 200:
		boss.health.grant_invulnerability(0)
		boss.health.take(DamageInfo.new(4, Vector2.ZERO, &"buster"))
		guard += 1
		await tree.physics_frame


# --- What it is ------------------------------------------------------------------

func test_it_is_not_a_ninth_master_and_awards_nothing() -> void:
	assert_eq(boss.boss_index, -1)
	assert_eq(boss.weapon_id, &"")
	assert_eq(boss.display_name, "Bulwark")


func test_it_has_two_forms_and_starts_on_the_first() -> void:
	assert_eq(boss.forms(), 2)
	assert_eq(boss.form(), Bulwark.FORM_SHELL)


## **The two forms are different fights**, not one fight with a refilled bar.
## `build_patterns` reads `form()`, so this is where that becomes true.
func test_the_forms_have_different_patterns() -> void:
	var shell: Array[StringName] = []
	for pattern in boss.patterns():
		shell.append(pattern.id)
	assert_eq(shell, [&"surge", &"collapse", &"spread"] as Array[StringName],
		"the shell fights with %s" % str(shell))

	await _fight()
	await _empty_the_bar()
	var core: Array[StringName] = []
	for pattern in boss.patterns():
		core.append(pattern.id)
	assert_eq(core, [&"volley", &"dive", &"sweep"] as Array[StringName],
		"the core fights with %s" % str(core))


## Both forms still telegraph. The last fight in the game is not where the rule
## `BossPattern` exists to enforce gets to lapse.
func test_every_pattern_of_both_forms_telegraphs() -> void:
	for pattern in boss.patterns():
		assert_true(pattern.tell_frames >= 20,
			"shell/%s telegraphs for %d frames" % [pattern.id, pattern.tell_frames])
		assert_true(pattern.recover_frames > 0,
			"shell/%s never recovers" % pattern.id)
	await _fight()
	await _empty_the_bar()
	for pattern in boss.patterns():
		assert_true(pattern.tell_frames >= 20,
			"core/%s telegraphs for %d frames" % [pattern.id, pattern.tell_frames])
		assert_true(pattern.recover_frames > 0,
			"core/%s never recovers" % pattern.id)


# --- The change ---------------------------------------------------------------------

## **Emptying the first bar is not a death.** The boss does not explode, the
## arena is not told the fight is over, and the bar comes back full.
func test_the_first_form_does_not_die() -> void:
	await _fight()
	var over: Array[int] = []
	boss.defeated.connect(func(_b: Boss) -> void: over.append(1))
	var forms: Array[int] = []
	boss.form_changed.connect(func(i: int) -> void: forms.append(i))

	await _empty_the_bar()
	assert_eq(over.size(), 0, "the arena was told the fight was over")
	assert_eq(forms, [Bulwark.FORM_CORE] as Array[int], "form_changed said %s" % str(forms))
	assert_eq(boss.form(), Bulwark.FORM_CORE)
	assert_eq(boss.health.current, boss.health.max_hp,
		"the bar came back at %d of %d" % [boss.health.current, boss.health.max_hp])
	assert_false(boss.is_dead(), "the shell died")


## **Emptying the second bar is.** There is nothing after the core.
func test_the_second_form_dies() -> void:
	await _fight()
	await _empty_the_bar()          # shell -> core
	assert_eq(boss.form(), Bulwark.FORM_CORE)
	await _frames(Boss.FORM_PAUSE_FRAMES + 2)

	var over: Array[int] = []
	boss.defeated.connect(func(_b: Boss) -> void: over.append(1))
	await _empty_the_bar()
	assert_true(boss.is_dead(), "the core survived an empty bar")
	await _frames(Boss.DEATH_FRAMES + 4)
	assert_eq(over.size(), 1, "the arena was told %d times" % over.size())


## **Nobody gets a free hit during the change**, in either direction: the boss
## cannot be damaged and cannot damage. A pause where either was possible would
## be a pause the player learns to stand in or to fear.
func test_the_change_is_a_beat_where_nothing_lands() -> void:
	await _fight()
	await _empty_the_bar()
	assert_true(boss.is_changing_form(), "the change was instant")
	assert_true(boss.health.immune, "the boss can be hit mid-change")
	assert_false(boss.contact.monitoring, "the boss can hit back mid-change")

	var was := boss.health.current
	boss.health.grant_invulnerability(0)
	assert_eq(boss.health.take(DamageInfo.new(9, Vector2.ZERO, &"buster")), 0)
	assert_eq(boss.health.current, was)

	await _frames(Boss.FORM_PAUSE_FRAMES + 2)
	assert_false(boss.is_changing_form(), "the change never ended")
	assert_false(boss.health.immune, "the core is still immune")
	assert_true(boss.contact.monitoring, "the core is harmless")


## And the hold is a beat rather than a wait -- long enough to read as "that was
## not the end of it", short enough that nobody goes looking for a door.
func test_the_hold_is_a_beat_and_not_a_wait() -> void:
	assert_true(Boss.FORM_PAUSE_FRAMES >= 40, "under two thirds of a second")
	assert_true(Boss.FORM_PAUSE_FRAMES <= 150, "over two and a half seconds")


# --- The tables ------------------------------------------------------------------------

## **The shell is weak to the bore.** The piercing drill against the armoured
## wall is the one weakness in the game a player could guess from the fiction
## rather than from a chart.
func test_the_shell_is_weak_to_the_bore() -> void:
	var table := boss.damage_table
	assert_not_null(table)
	var bore := table.damage_for(&"quarry_bore", 1)
	assert_true(bore >= 4, "the bore does %d to the wall" % bore)
	for other in [&"tide_crawler", &"gale_cutter", &"frost_lock"]:
		assert_true(table.damage_for(other, 1) < bore,
			"%s matches the bore against the shell" % other)


## **The core is weak to nothing, so the last blow of the game is always the
## buster.** That is worth more than one more weakness: nobody arrives at the
## end of the fortress dry and stuck, and the weapon the player has had since
## the first frame is the one that finishes it.
func test_the_core_has_no_weakness_and_the_buster_still_works() -> void:
	await _fight()
	await _empty_the_bar()
	var table := boss.damage_table
	assert_not_null(table)
	for id in [&"quarry_bore", &"tide_crawler", &"arc_lance", &"rust_bloom",
			&"prism_ray", &"gale_cutter", &"cinder_spray", &"frost_lock"]:
		assert_eq(table.damage_for(id, 1), 1,
			"%s is special against the core" % id)
		assert_false(table.is_immune(id), "the core is immune to %s" % id)
	# And a plain pellet lands, which is the whole point -- once the change is
	# over. During it nothing lands at all, which the test above is for.
	await _frames(Boss.FORM_PAUSE_FRAMES + 2)
	boss.health.grant_invulnerability(0)
	assert_eq(boss.health.take(DamageInfo.new(1, Vector2.ZERO, &"buster")), 1)


# --- The shapes ------------------------------------------------------------------------

## The shell is a wall: it never leaves the ground and never chases. The core
## never touches the ground at all. That opposition is the fight.
func test_the_shell_stands_and_the_core_flies() -> void:
	await _fight()
	assert_true(boss.affected_by_gravity, "the wall is airborne")
	var was := boss.global_position.x
	await _frames(200)
	assert_almost_eq(boss.global_position.x, was, 1.0,
		"the wall moved %.1f px" % absf(boss.global_position.x - was))

	await _empty_the_bar()
	assert_false(boss.affected_by_gravity, "the core is still on the floor")


## The body shrinks with the boss. A hitbox left at the shell's size would be a
## small fast target that is still hit like a wall.
func test_the_body_shrinks_with_the_form() -> void:
	var wall := boss.body_size()
	await _fight()
	await _empty_the_bar()
	var core := boss.body_size()
	assert_true(core.x < wall.x and core.y < wall.y,
		"the wall is %s and the core is %s" % [str(wall), str(core)])
	for child in boss.get_children():
		if child is CollisionShape2D and child.name == "Body":
			var rect := (child as CollisionShape2D).shape as RectangleShape2D
			assert_almost_eq(rect.size.x, core.x, 0.5,
				"the collider is still the wall's size")


# --- Plumbing ---------------------------------------------------------------------------

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
	for _i in count:
		await tree.physics_frame
