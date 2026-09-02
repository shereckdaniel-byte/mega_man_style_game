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
