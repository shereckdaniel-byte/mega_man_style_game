## The boss framework: the pattern loop, the entrance, and the arena sequence.
##
## Built in a real scene tree with a real floor, because the bug that cost the
## most time in M5 was invisible to any test that did not stand the boss on
## something: `Enemy` leaves the body collider to its subclasses, `Boss` did not
## build one, and a boss with no collider falls through the stage while its
## patterns keep running. Every symptom pointed at the projectiles.
extends TestCase

const TideScript := preload("res://scenes/actors/bosses/tide.gd")
const PLAYER_SCENE := preload("res://scenes/actors/player/player.tscn")

const FLOOR_TOP := 600.0
## Frames the entrance needs: 160/8 NES px of descent is 20 frames, plus the
## 20-frame landing pause. 60 is that with room to spare, and no more -- these
## waits are real seconds in a running engine, and a generous one here costs
## four seconds every time the suite runs.
const INTRO_FRAMES := 60

var root: Node2D
var boss: Boss


func is_async() -> bool:
	return true


func before_each_async() -> void:
	root = Node2D.new()
	tree.root.add_child(root)
	_add_floor(Vector2(-2000.0, FLOOR_TOP), Vector2(6000.0, 200.0))
	boss = TideScript.new() as Boss
	boss.position = Vector2(600.0, FLOOR_TOP)
	root.add_child(boss)
	await _frames(2)


func after_each_async() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


# --- The body ---------------------------------------------------------------------

## The one that mattered. A CharacterBody2D with no CollisionShape2D does not
## land on the floor, it passes through it, and nothing errors on the way down.
func test_a_boss_has_a_body_collider() -> void:
	var shapes := 0
	for child in boss.get_children():
		if child is CollisionShape2D:
			shapes += 1
	assert_true(shapes >= 1, "the boss body has no collision shape")


func test_a_boss_lands_on_the_floor_rather_than_through_it() -> void:
	boss.begin_intro(Vector2(600.0, FLOOR_TOP), null)
	await _frames(INTRO_FRAMES)
	assert_almost_eq(boss.global_position.y, FLOOR_TOP, 4.0,
		"boss ended at y=%.0f, floor is %.0f" % [boss.global_position.y, FLOOR_TOP])


## The boss must face the player from the first frame of the entrance, not from
## the first frame of the fight.
##
## Sprites are authored right-facing and `_face_target` only ran in FIGHTING, so
## a boss spent its beam, its landing and the whole bar fill turned away from a
## player who -- in every arena in the game -- arrives from the left. Several
## seconds of the one moment the boss is meant to be looked at.
func test_a_boss_faces_the_player_through_its_entrance() -> void:
	var watcher := Node2D.new()
	root.add_child(watcher)
	# To the boss's left, which is where the arena door is.
	watcher.global_position = Vector2(boss.global_position.x - 400.0, FLOOR_TOP)
	boss.begin_intro(Vector2(600.0, FLOOR_TOP), watcher)
	assert_eq(boss.facing(), -1, "the boss starts its entrance facing away")
	await _frames(4)
	assert_eq(boss.facing(), -1, "the boss turned away during the beam")
	await _frames(INTRO_FRAMES)
	assert_eq(boss.facing(), -1, "the boss turned away while the bar filled")

	# And it tracks: a player who crosses during the pose is still faced.
	watcher.global_position = Vector2(boss.global_position.x + 400.0, FLOOR_TOP)
	await _frames(2)
	assert_eq(boss.facing(), 1, "the boss did not follow the player past it")


## Tide fought through the whole of M5 as an invisible box, because nothing
## assigned its sprite frames and nothing checked. The fight worked, the tests
## passed and the playthrough won -- a boss with no art is not a broken boss to
## anything except a person looking at the screen.
func test_a_boss_brings_its_own_art() -> void:
	assert_not_null(boss.sprite_frames, "the boss was given no sprite frames")
	assert_not_null(boss.sprite, "the boss built no sprite node")
	assert_true(boss.sprite.sprite_frames.get_animation_names().size() > 0)


## The flash is the only feedback on the boss itself that a hit landed; the bar
## is in the corner while the player is looking at the fight.
func test_a_hit_flashes_the_boss() -> void:
	boss.begin_intro(Vector2(600.0, FLOOR_TOP), null)
	await _frames(INTRO_FRAMES)
	boss.begin_fight()
	await _frames(2)
	boss.health.take(DamageInfo.new(1, Vector2.ZERO, &"buster"))
	var flashed := false
	for i in Boss.HIT_INVULNERABLE_FRAMES:
		await tree.physics_frame
		if boss.sprite != null and boss.sprite.modulate != Color.WHITE:
			flashed = true
			break
	assert_true(flashed, "the boss never flashed after taking a hit")


func test_a_boss_carries_the_same_28_tick_bar_as_the_player() -> void:
	assert_eq(boss.health.max_hp, Health.BAR_TICKS)
	assert_eq(boss.health.max_hp, 28)


# --- The entrance -------------------------------------------------------------------

func test_a_dormant_boss_is_invisible_and_untouchable() -> void:
	assert_eq(boss.phase, Boss.Phase.DORMANT)
	assert_false(boss.visible)
	assert_true(boss.health.immune)


## The beam starts above the landing point and descends to it. A boss that began
## at the floor would have no entrance at all.
func test_the_entrance_starts_above_the_landing_point() -> void:
	boss.begin_intro(Vector2(600.0, FLOOR_TOP), null)
	assert_true(boss.visible)
	assert_eq(boss.phase, Boss.Phase.ENTERING)
	assert_true(boss.global_position.y < FLOOR_TOP - 100.0,
		"the beam started at y=%.0f, which is not above the floor" % boss.global_position.y)


func test_the_entrance_reports_when_it_has_landed() -> void:
	var landed := [false]
	boss.intro_landed.connect(func() -> void: landed[0] = true)
	boss.begin_intro(Vector2(600.0, FLOOR_TOP), null)
	await _frames(INTRO_FRAMES)
	assert_true(landed[0], "intro_landed never fired")
	assert_eq(boss.phase, Boss.Phase.POSING)


## Posing is after the landing and before the fight: the bar is filling and the
## player is still frozen, so a boss that could hurt them here would be hitting
## someone who cannot move.
func test_a_posing_boss_is_still_immune_and_still_harmless() -> void:
	boss.begin_intro(Vector2(600.0, FLOOR_TOP), null)
	await _frames(INTRO_FRAMES)
	assert_eq(boss.phase, Boss.Phase.POSING)
	assert_true(boss.health.immune)
	assert_false(boss.contact.monitoring)


func test_the_fight_makes_the_boss_damageable() -> void:
	boss.begin_intro(Vector2(600.0, FLOOR_TOP), null)
	await _frames(INTRO_FRAMES)
	boss.begin_fight()
	assert_eq(boss.phase, Boss.Phase.FIGHTING)
	assert_false(boss.health.immune)
	assert_true(boss.contact.monitoring)
	assert_true(boss.is_fighting())


# --- Patterns --------------------------------------------------------------------

func test_tide_has_three_patterns() -> void:
	assert_eq(boss.patterns().size(), 3)


## The rule the whole BossPattern class exists to keep: no attack without a
## windup the player can read.
func test_every_pattern_telegraphs_before_it_acts() -> void:
	for pattern in boss.patterns():
		assert_true(pattern.tell_frames > 0,
			"%s attacks with no tell" % pattern.id)
		assert_true(pattern.tell_frames >= 20,
			"%s telegraphs for only %d frames" % [pattern.id, pattern.tell_frames])


## Recovery is where the player gets to shoot back. A pattern with none is a
## boss that is never open.
func test_every_pattern_leaves_an_opening() -> void:
	for pattern in boss.patterns():
		assert_true(pattern.recover_frames > 0,
			"%s never recovers" % pattern.id)


# --- Aggression -------------------------------------------------------------------

## **Aggression shortens recovery and nothing else.** This is the rule the whole
## knob rests on: the tell is the fairness contract (`BossPattern` exists to
## make it part of the shape of an attack) and the act is what the attack *is*,
## so a reprise at 2.0 has to be the same fight with half the openings rather
## than a different fight wearing the first one's sprite.
func test_aggression_shortens_recovery_and_leaves_the_tell_alone() -> void:
	var calm := TideScript.new() as Boss
	var keen := TideScript.new() as Boss
	keen.aggression = 2.0
	root.add_child(calm)
	root.add_child(keen)
	await _frames(1)

	var slow := calm.patterns()
	var fast := keen.patterns()
	assert_eq(slow.size(), fast.size())
	for i in slow.size():
		assert_eq(fast[i].tell_frames, slow[i].tell_frames,
			"%s: aggression moved the tell" % slow[i].id)
		assert_eq(fast[i].act_frames, slow[i].act_frames,
			"%s: aggression moved the act" % slow[i].id)
		assert_true(fast[i].recover_frames < slow[i].recover_frames,
			"%s: aggression did not shorten the recovery" % slow[i].id)


## An untouched boss is bit-identical to one that declares 1.0, so the eight can
## go on writing their numbers once at the speed they were designed at.
func test_the_default_aggression_changes_nothing() -> void:
	var plain := TideScript.new() as Boss
	var declared := TideScript.new() as Boss
	declared.aggression = 1.0
	root.add_child(plain)
	root.add_child(declared)
	await _frames(1)
	for i in plain.patterns().size():
		assert_eq(declared.patterns()[i].recover_frames,
			plain.patterns()[i].recover_frames)


## **No aggression can close the opening entirely.** A recovery of zero is a
## boss with no counterplay, and there would then be no way to hurt it at all.
func test_no_aggression_leaves_a_boss_with_no_opening() -> void:
	for factor in [2.0, 8.0, 100.0]:
		var frantic := TideScript.new() as Boss
		frantic.aggression = factor
		root.add_child(frantic)
		await _frames(1)
		for pattern in frantic.patterns():
			assert_true(pattern.recover_frames >= Boss.MIN_RECOVER_FRAMES,
				"aggression %.1f left %s with %d frames of recovery"
					% [factor, pattern.id, pattern.recover_frames])
		frantic.queue_free()
		await tree.physics_frame


## A nonsensical aggression is ignored rather than obeyed: zero or negative
## would divide the recovery into something meaningless, and the safe reading of
## "I do not know how fast this should be" is the speed it was written at.
func test_a_nonsense_aggression_is_ignored() -> void:
	for factor in [0.0, -1.0]:
		var odd := TideScript.new() as Boss
		odd.aggression = factor
		root.add_child(odd)
		await _frames(1)
		for i in odd.patterns().size():
			assert_eq(odd.patterns()[i].recover_frames,
				boss.patterns()[i].recover_frames,
				"aggression %.1f was obeyed" % factor)
		odd.queue_free()
		await tree.physics_frame


## **Setting aggression twice does not compound.** The arena builds a boss and
## the stage then configures it, so this happens on every fortress fight: a
## reprise set to 2.0 and then to 2.0 again has to come out at 2.0, not 4.0,
## and nothing on screen would have said otherwise.
func test_setting_aggression_twice_lands_on_the_same_numbers() -> void:
	var once := TideScript.new() as Boss
	var twice := TideScript.new() as Boss
	root.add_child(once)
	root.add_child(twice)
	await _frames(1)
	once.aggression = 2.0
	twice.aggression = 2.0
	twice.aggression = 2.0
	for i in once.patterns().size():
		assert_eq(twice.patterns()[i].recover_frames,
			once.patterns()[i].recover_frames,
			"%s compounded" % once.patterns()[i].id)


## And it can be set back: aggression is a knob, not a one-way door, so a boss
## returned to 1.0 is the boss its author wrote.
func test_aggression_can_be_turned_back_down() -> void:
	var keen := TideScript.new() as Boss
	root.add_child(keen)
	await _frames(1)
	keen.aggression = 3.0
	keen.aggression = 1.0
	for i in keen.patterns().size():
		assert_eq(keen.patterns()[i].recover_frames,
			boss.patterns()[i].recover_frames,
			"%s did not come back" % keen.patterns()[i].id)


## **Aggression below 1.0 changes nothing.** It is a knob for making a boss
## harder; letting it hand a boss a *longer* opening than its author gave it
## would be a difficulty setting hiding inside a reprise knob, and the place to
## make the game easier is not here.
func test_aggression_below_one_does_not_soften_a_boss() -> void:
	var mild := TideScript.new() as Boss
	root.add_child(mild)
	await _frames(1)
	mild.aggression = 0.25
	for i in mild.patterns().size():
		assert_eq(mild.patterns()[i].recover_frames,
			boss.patterns()[i].recover_frames,
			"%s was softened" % mild.patterns()[i].id)


func test_a_fighting_boss_picks_a_pattern_and_runs_it_in_order() -> void:
	boss.begin_intro(Vector2(600.0, FLOOR_TOP), null)
	await _frames(INTRO_FRAMES)
	boss.begin_fight()
	assert_not_null(boss.current_pattern())
	assert_eq(boss.pattern_step(), 0, "a pattern must start on its tell")
	var pattern := boss.current_pattern()
	await _frames(pattern.tell_frames + 1)
	assert_true(boss.pattern_step() >= 1, "the tell never handed over to the act")


## Back-to-back repeats are what make a random fight read as a broken one.
func test_the_same_pattern_is_not_chosen_twice_running() -> void:
	boss.seed_rng(12345)
	boss.begin_intro(Vector2(600.0, FLOOR_TOP), null)
	await _frames(INTRO_FRAMES)
	boss.begin_fight()
	var seen: Array[StringName] = []
	boss.pattern_started.connect(func(id: StringName) -> void: seen.append(id))
	await _frames(500)
	assert_true(seen.size() >= 3, "only %d patterns ran in 500 frames" % seen.size())
	for i in range(1, seen.size()):
		assert_ne(seen[i], seen[i - 1],
			"%s ran twice in a row at index %d" % [seen[i], i])


## The property `tools/playthrough.gd -- seed=<n>` rests on: the same seed gives
## the same fight.
##
## `Boss._rng` calls `randomize()` in `_ready`, so unseeded the bot samples a
## different fight every run -- Breakers came back 18 HP / 0 deaths and then
## 28 / 1 within the hour on identical code. That spread is real and the bot
## still shows it by default. A seed is for the other job: comparing two builds
## that should behave the same, which is only meaningful if a seed actually pins
## the sequence.
func test_the_same_seed_gives_the_same_pattern_order() -> void:
	var first := await _pattern_order(boss, 4242)
	# Freed before the second runs, or it keeps fighting through the second's
	# window and its list grows past the one being compared to it.
	boss.queue_free()
	await tree.physics_frame

	var second_boss := TideScript.new() as Boss
	second_boss.position = Vector2(600.0, FLOOR_TOP)
	root.add_child(second_boss)
	await _frames(2)
	var second := await _pattern_order(second_boss, 4242)

	assert_true(first.size() >= 2, "only %d patterns ran" % first.size())
	assert_eq(first, second, "same seed, different fight: %s then %s"
		% [str(first), str(second)])


## The patterns one seeded boss runs, in order.
func _pattern_order(subject: Boss, seed_value: int) -> Array[StringName]:
	var seen: Array[StringName] = []
	subject.pattern_started.connect(func(id: StringName) -> void: seen.append(id))
	subject.seed_rng(seed_value)
	subject.begin_fight()
	await _frames(300)
	return seen


# --- Defeat ---------------------------------------------------------------------

## Death is a sequence, not a free(). A boss that vanished on the frame its last
## point of damage landed would take the explosion with it.
func test_a_killed_boss_dies_slowly() -> void:
	boss.begin_intro(Vector2(600.0, FLOOR_TOP), null)
	await _frames(INTRO_FRAMES)
	boss.begin_fight()
	boss.health.kill()
	assert_eq(boss.phase, Boss.Phase.DYING)
	assert_true(is_instance_valid(boss), "the boss was freed on the frame it died")
	assert_true(boss.is_dead())
	assert_true(boss.health.immune, "a dying boss can still be shot")
	assert_false(boss.contact.monitoring, "a dying boss can still hurt the player")


func test_the_defeat_finishes_and_reports_once() -> void:
	boss.begin_intro(Vector2(600.0, FLOOR_TOP), null)
	await _frames(INTRO_FRAMES)
	boss.begin_fight()
	var count := [0]
	boss.defeated.connect(func(_b: Boss) -> void: count[0] += 1)
	boss.health.kill()
	await _frames(Boss.DEATH_FRAMES + 20)
	assert_eq(count[0], 1, "defeated fired %d times" % count[0])


## A boss that jumps out of its own arena is not a boss the player can fight.
##
## Tide did exactly that: apex scales with the square of the launch velocity, so
## a value picked to look "a bit more than the player's" was an 11.6-tile leap
## into an 11-tile room. Nothing failed -- it fought on from above the ceiling.
func test_tides_leap_stays_inside_the_arena() -> void:
	var t := PlayerTuning.new()
	# Same discrete integration the engine does, per ARCHITECTURE section 3.
	var v: float = Tide.SPOUT_JUMP_PF
	var y := 0.0
	var apex := 0.0
	while v > 0.0:
		y += v
		v -= t.gravity_pf
		apex = maxf(apex, y)
	var tiles := apex / PlayerTuning.NES_TILE
	# The arena is one screen tall and the deck sits 11 tiles below its top
	# (DawnBoardwalk.ROOM_TOP). Leave a tile of headroom so the sprite is
	# visible at the peak rather than clipped by the edge.
	assert_true(tiles <= 10.0,
		"Tide leaps %.1f tiles; the room is 11 above the deck" % tiles)
	# And high enough to read as a leap rather than a hop.
	assert_true(tiles >= t.jump_apex_tiles(),
		"Tide's leap (%.1f tiles) is shorter than the player's jump (%.1f)"
			% [tiles, t.jump_apex_tiles()])


func test_tide_awards_its_own_weapon() -> void:
	assert_eq(boss.weapon_id, &"tide_crawler")
	assert_eq(boss.boss_index, 0)


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
	for i in count:
		await tree.physics_frame


## Every animation draws at the actor's own height, not at whatever size the
## clip happened to be generated at.
##
## AutoSprite frames each clip independently, so a boss's opaque height varies
## from clip to clip -- Rust's by 1.28x across six animations. `_build_sprite`
## used to measure only the starting animation and keep that scale forever, and
## a playtester's note was that "the stage 3 boss size changes depending on what
## he is doing". Arc's 1.07x spread is why they only noticed it on one of them.
func test_every_animation_draws_at_the_same_height() -> void:
	for path in ["res://scenes/actors/bosses/tide.gd",
			"res://scenes/actors/bosses/arc.gd",
			"res://scenes/actors/bosses/rust.gd"]:
		var boss := (load(path) as GDScript).new() as Boss
		root.add_child(boss)
		await tree.physics_frame
		assert_not_null(boss.sprite, "%s built no sprite" % path)

		var drawn: Array[float] = []
		for anim in boss.sprite.sprite_frames.get_animation_names():
			if boss.sprite.sprite_frames.get_frame_count(anim) <= 0:
				continue
			boss.sprite.animation = StringName(anim)
			boss.fit_art()
			var height: float = boss.sprite.scale.y * boss._measure_art_height(
				StringName(anim))
			drawn.append(height)
		assert_true(drawn.size() >= 2, "%s: nothing to compare" % path)
		var lo: float = drawn.min()
		var hi: float = drawn.max()
		assert_almost_eq(hi, lo, 1.0,
			"%s draws between %.1f and %.1f px depending on the animation"
				% [path, lo, hi])
		boss.queue_free()
		await tree.physics_frame
