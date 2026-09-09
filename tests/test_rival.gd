## Ward: the duel that cannot be won and cannot be lost.
##
## Two of these tests are the encounter's entire reason to exist -- he never
## reaches zero and neither does the player -- and both of them are the sort of
## property that is true when a fight is written and false the first time a
## number moves. The rest of the file is the plumbing that makes the encounter
## end: it has to finish whether the player fights, hides, or stands still.
extends TestCase

const RivalScript := preload("res://scenes/actors/bosses/rival.gd")

const FLOOR_TOP := 600.0
## The whistle, then the beam, then the landing pause. 60 covers the beam and
## the pause; the whistle is on top of it.
const INTRO_FRAMES := 60

var root: Node2D
var ward: Rival


func is_async() -> bool:
	return true


func before_each_async() -> void:
	root = Node2D.new()
	tree.root.add_child(root)
	_add_floor(Vector2(-2000.0, FLOOR_TOP), Vector2(6000.0, 200.0))
	ward = RivalScript.new() as Rival
	ward.position = Vector2(600.0, FLOOR_TOP)
	root.add_child(ward)
	await _frames(2)


func after_each_async() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


func _enter_the_fight() -> void:
	ward.begin_intro(Vector2(600.0, FLOOR_TOP), null)
	await _frames(Rival.WHISTLE_FRAMES + INTRO_FRAMES)
	ward.begin_fight()


# --- What he is ------------------------------------------------------------------

## He is not one of the eight and he drops nothing, so beating him records
## nothing. A rival you can kill is a ninth Robot Master with no weapon behind
## it.
func test_he_is_not_one_of_the_eight_and_awards_nothing() -> void:
	assert_eq(ward.boss_index, -1)
	assert_eq(ward.weapon_id, &"")
	assert_eq(ward.display_name, "Ward")


## **He fights the way you do.** Shoot, jump, slide -- the player's three verbs
## and nothing the player has not had since M1. The characterisation is that
## every attack is one of yours.
func test_his_patterns_are_the_players_own_moves() -> void:
	var ids: Array[StringName] = []
	for pattern in ward.patterns():
		ids.append(pattern.id)
	assert_eq(ids, [&"shoot", &"leap", &"slide"] as Array[StringName],
		"his kit is %s" % str(ids))


## And he still telegraphs, which is not a courtesy the duel could skip: the
## whole point of a fight with no stake is that the player gets to *read* it.
func test_he_telegraphs_like_any_other_boss() -> void:
	for pattern in ward.patterns():
		assert_true(pattern.tell_frames >= 20,
			"%s telegraphs for only %d frames" % [pattern.id, pattern.tell_frames])
		assert_true(pattern.recover_frames > 0,
			"%s never recovers" % pattern.id)


# --- Unbeatable ------------------------------------------------------------------

## **He stops rather than dying.** Damage him past the floor and he withdraws:
## no explosion, health never at zero, nothing awarded.
func test_he_withdraws_instead_of_dying() -> void:
	await _enter_the_fight()
	var said: Array[StringName] = []
	ward.withdrew.connect(func(r: StringName) -> void: said.append(r))

	# Hit him down past the surrender line, one legal hit at a time.
	while ward.health.current > Rival.SURRENDER_HP and not ward.is_leaving():
		ward.health.grant_invulnerability(0)
		ward.health.take(DamageInfo.new(4, Vector2.ZERO, &"buster"))
		await tree.physics_frame

	assert_true(ward.is_leaving(), "he did not withdraw")
	assert_eq(said, [&"beaten"] as Array[StringName], "said %s" % str(said))
	assert_true(ward.health.current > 0,
		"his health reached %d" % ward.health.current)


## **He can never be taken to zero**, whatever lands on him. The withdrawal is
## checked on a health value that has already been reduced, so the floor has to
## be further above zero than the biggest single hit in the game -- and if it
## were not, the last hit would fire `died` and explode him like a Robot Master.
func test_the_surrender_line_is_above_the_biggest_hit_in_the_game() -> void:
	# A weakness multiplier tops out at 4x a buster pellet, the sword does 3 and
	# a full charge does 3. Four is the ceiling; the floor allows for more.
	assert_true(Rival.SURRENDER_HP > 6,
		"a %d-point floor is inside reach of one hit" % Rival.SURRENDER_HP)
	assert_true(Rival.SURRENDER_HP < Boss.BOSS_HP,
		"he surrenders before the fight starts")


## And once he is leaving he cannot be hit again, so a shot already in the air
## cannot finish him after he has stopped.
func test_a_withdrawing_rival_takes_no_more_damage() -> void:
	await _enter_the_fight()
	ward.health.current = Rival.SURRENDER_HP + 1
	ward.health.grant_invulnerability(0)
	ward.health.take(DamageInfo.new(2, Vector2.ZERO, &"buster"))
	await tree.physics_frame
	assert_true(ward.is_leaving())
	var left := ward.health.current
	ward.health.grant_invulnerability(0)
	assert_eq(ward.health.take(DamageInfo.new(99, Vector2.ZERO, &"buster")), 0)
	assert_eq(ward.health.current, left)


# --- Non-lethal ------------------------------------------------------------------

## **Everything he touches carries the flag.** Set on the hitbox rather than
## remembered at each call site: a flag that has to be added to every attack is
## the flag that is missing from the one added last.
func test_his_contact_damage_cannot_kill() -> void:
	assert_true(ward.contact.flags & DamageInfo.NON_LETHAL != 0,
		"his contact damage can kill")


func test_his_shots_cannot_kill() -> void:
	await _enter_the_fight()
	# Drive him to the shooting pattern's act phase and catch what comes out.
	var fired: Array[Node] = []
	for _i in 600:
		await tree.physics_frame
		for child in root.get_children():
			if child is EnemyShot and not fired.has(child):
				fired.append(child)
		if not fired.is_empty():
			break
	assert_false(fired.is_empty(), "he never fired anything in ten seconds")
	for shot in fired:
		assert_true((shot as EnemyShot).flags & DamageInfo.NON_LETHAL != 0,
			"a rival shot can kill")


# --- It ends -----------------------------------------------------------------------

## **A player who hides still gets to leave.** Without a clock the encounter is
## a wall for anyone who does not want to fight it, and the one fight in the
## game with no reward is the worst possible place to put a wall.
func test_the_duel_ends_even_if_nobody_lands_a_hit() -> void:
	await _enter_the_fight()
	var said: Array[StringName] = []
	ward.withdrew.connect(func(r: StringName) -> void: said.append(r))
	assert_true(Rival.DUEL_FRAMES <= 1800,
		"a %d-frame duel is half a minute of a fight with no stake"
			% Rival.DUEL_FRAMES)
	# Long enough to cover the clock, and no longer: these are real seconds.
	for _i in Rival.DUEL_FRAMES + 4:
		if ward.is_leaving():
			break
		await tree.physics_frame
	assert_true(ward.is_leaving(), "the duel never ended")
	assert_eq(said, [&"bored"] as Array[StringName], "said %s" % str(said))


## And he reports being finished the same way any boss does, so the arena that
## sealed the room knows to open it again.
func test_the_arena_hears_the_same_signal_it_would_from_a_dead_boss() -> void:
	await _enter_the_fight()
	# An Array, not an int: GDScript lambdas capture locals **by value**, so a
	# counter incremented inside one is invisible outside it and the test passes
	# or fails on nothing.
	var done: Array[int] = []
	ward.defeated.connect(func(_b: Boss) -> void: done.append(1))
	ward.health.grant_invulnerability(0)
	ward.health.current = 1
	ward.health.take(DamageInfo.new(1, Vector2.ZERO, &"buster"))
	for _i in Rival.EXIT_FRAMES + 8:
		await tree.physics_frame
	assert_eq(done.size(), 1, "the arena was told %d times" % done.size())


## He leaves upward. It has to look unlike a death, because it is not one.
func test_he_leaves_by_going_up() -> void:
	await _enter_the_fight()
	var was := ward.global_position.y
	ward.health.grant_invulnerability(0)
	ward.health.current = 1
	ward.health.take(DamageInfo.new(1, Vector2.ZERO, &"buster"))
	await _frames(Rival.EXIT_FRAMES - 4)
	assert_true(ward.global_position.y < was - 40.0,
		"he went from %.0f to %.0f" % [was, ward.global_position.y])


# --- The whistle -------------------------------------------------------------------

## **The room holds, empty, before anything is on screen.** That pause is the
## trick, and the cue is emitted as a signal so that adding the sound at M8 is
## one `connect` and no change to this file.
func test_he_whistles_before_he_arrives() -> void:
	var heard: Array[int] = []
	ward.whistled.connect(func() -> void: heard.append(1))
	ward.begin_intro(Vector2(600.0, FLOOR_TOP), null)
	assert_eq(heard.size(), 1, "no whistle")
	assert_true(ward.is_whistling())
	assert_false(ward.visible, "he is on screen during his own cue")
	await _frames(10)
	assert_false(ward.visible, "he appeared %d frames into a %d-frame hold"
		% [10, Rival.WHISTLE_FRAMES])
	await _frames(Rival.WHISTLE_FRAMES)
	assert_false(ward.is_whistling())
	assert_true(ward.visible, "he never appeared")


## The hold is long enough to notice and short enough not to read as a hang.
func test_the_hold_is_a_beat_and_not_a_hang() -> void:
	assert_true(Rival.WHISTLE_FRAMES >= 45, "half a second is not a pause")
	assert_true(Rival.WHISTLE_FRAMES <= 150, "two and a half seconds is a hang")


## And the whistle does not eat into the fight: the bar fill is timed from the
## landing, so a longer hold does not shorten the duel.
func test_the_whistle_delays_the_landing_rather_than_the_fight() -> void:
	var landed: Array[int] = []
	ward.intro_landed.connect(func() -> void: landed.append(1))
	ward.begin_intro(Vector2(600.0, FLOOR_TOP), null)
	await _frames(Rival.WHISTLE_FRAMES - 10)
	assert_eq(landed.size(), 0, "he landed during his own whistle")
	await _frames(INTRO_FRAMES + 10)
	assert_eq(landed.size(), 1, "he never landed")


# --- Plumbing -----------------------------------------------------------------------

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
