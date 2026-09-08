## Prism: the three answers, and the bound on the one that takes floor away.
##
## The bound is what this file exists for, the same way `tests/test_rust.gd`
## exists for Bloom's alternate columns. **A pattern that forbids a stretch of
## floor can be made unwinnable by making the stretch the whole arena**, and the
## guarantee that it cannot has to be checked across every column and every
## offset rather than trusted to the one case a fight happens to produce.
##
## The rest is the arithmetic the patterns stand on, checked against the real
## hitboxes rather than against the comments -- Breakers shipped a press whose
## comment was right and whose geometry was not, and the only thing that caught
## it was a test that measured `PlayerTuning` instead of reading prose.
extends TestCase

const PrismScript := preload("res://scenes/actors/bosses/prism.gd")
const Beam := preload("res://scenes/actors/projectiles/prism_beam.gd")
const Spot := preload("res://scenes/actors/projectiles/focus_spot.gd")
const Mirror := preload("res://scenes/actors/projectiles/facet_mirror.gd")

var root: Node2D
var prism: Prism


func is_async() -> bool:
	return true


func before_each_async() -> void:
	root = Node2D.new()
	tree.root.add_child(root)
	prism = PrismScript.new() as Prism
	root.add_child(prism)
	prism.seed_rng(7)
	await tree.physics_frame


func after_each_async() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


# --- The bound on Facets ----------------------------------------------------------

## **Three columns are always outside the corridor**, whatever the pattern picks.
## Walked over every column the player could be standing in and every offset the
## boss could roll, rather than sampled.
func test_a_facet_corridor_never_covers_the_arena() -> void:
	var clear := PrismScript.FACET_COLUMNS - PrismScript.FACET_SPAN
	assert_true(clear >= 3,
		"a corridor leaves only %d columns clear; the fight can be cornered" % clear)
	for column in PrismScript.FACET_COLUMNS:
		for offset in [1, 2]:
			var span := PrismScript.facet_columns(column, offset)
			var inside := span.y - span.x + 1
			assert_eq(inside, PrismScript.FACET_SPAN,
				"column %d offset %d gave a %d-column corridor" % [column, offset, inside])
			assert_true(span.x >= 0 and span.y < PrismScript.FACET_COLUMNS,
				"column %d offset %d put a mirror outside the arena" % [column, offset])
			assert_eq(PrismScript.FACET_COLUMNS - inside, clear,
				"column %d offset %d left the wrong amount of floor" % [column, offset])


## And the corridor is drawn **round the player**, not away from them. Aiming at
## is the same fairness argument Arc's Curtain and Rust's Bloom are built on: the
## ask is to leave a place you can see, not to guess which half is safe.
func test_a_facet_corridor_contains_the_player_unless_they_are_in_a_corner() -> void:
	for column in PrismScript.FACET_COLUMNS:
		for offset in [1, 2]:
			var span := PrismScript.facet_columns(column, offset)
			# The clamp is what breaks this at the two ends, and it has to: a
			# corridor that hung off the arena would put a mirror in the wall.
			# Everywhere else the player starts inside it.
			if column < offset or column > PrismScript.FACET_COLUMNS - PrismScript.FACET_SPAN + offset:
				continue
			assert_true(column >= span.x and column <= span.y,
				"column %d offset %d built a corridor at %s that the player is not in"
					% [column, offset, span])


# --- The split, and why the halves cannot arrive together -------------------------

## The pattern is unanswerable if they arrive together. One has to be jumped and
## the other has to be stood under, and no player is both at one instant.
##
## **The separation must not depend on where the player is standing**, which is
## what this failed on first. The halves used to differ in speed, and a speed
## difference buys `d/v_high - d/v_low` frames -- 33 at close range against a
## 40-frame jump, so a player near the wall was still airborne from the low beam
## when the high one reached them. Slowing the high half enough to fix the near
## case left it barely outpacing a walk. It is a fixed delay at the wall now, and
## a constant is the same everywhere.
func test_the_two_halves_of_a_split_arrive_apart() -> void:
	var tuning := PlayerTuning.new()
	var airtime := 2.0 * tuning.jump_velocity_pf / tuning.gravity_pf
	assert_true(float(Beam.HIGH_DELAY_FRAMES) >= airtime,
		"the high half sets off %d frames behind the low one and a jump is airborne %.0f"
			% [Beam.HIGH_DELAY_FRAMES, airtime])
	# Same speed, so nothing about the separation varies with distance.
	assert_true(Beam.SPLIT_SPEED_PF > tuning.walk_speed_pf,
		"a half of a split at %.1f can be outwalked, so neither of them asks anything"
			% Beam.SPLIT_SPEED_PF)


## **Standing is the answer to exactly one of them.** Measured against the real
## hitboxes: the low beam catches a standing player and a sliding one, and the
## high beam misses a standing one and catches anybody in the air.
func test_the_low_beam_must_be_jumped_and_the_high_one_must_not() -> void:
	var tuning := PlayerTuning.new()
	var half := Beam.BEAM_NES.y * 0.5
	var standing := tuning.NES_HITBOX.y
	var sliding := tuning.NES_SLIDE_HITBOX.y

	# The low beam has to overlap **both** postures, so leaving the ground is the
	# only answer. Its box runs from `LOW_HEIGHT_NES - half` to `+ half` above the
	# floor, and a player's box runs from the floor up to their height -- so the
	# test is that the beam's underside is below the shorter of the two.
	var low_bottom := Beam.LOW_HEIGHT_NES - half
	assert_true(low_bottom < sliding,
		"the low beam's underside is at %.1f and a slide is %.1f tall: it can be slid under"
			% [low_bottom, sliding])
	assert_true(low_bottom < standing,
		"the low beam's underside is at %.1f and a standing player is %.1f tall"
			% [low_bottom, standing])
	assert_true(Beam.LOW_HEIGHT_NES + half < tuning.jump_apex_nes_px(),
		"the low beam reaches %.1f and the jump only clears %.1f"
			% [Beam.LOW_HEIGHT_NES + half, tuning.jump_apex_nes_px()])

	var high_bottom := Beam.HIGH_HEIGHT_NES - half
	assert_true(high_bottom > standing,
		"the high beam's underside is at %.1f and a standing player is %.1f"
			% [high_bottom, standing])
	assert_true(high_bottom < tuning.jump_apex_nes_px(),
		"the high beam is above the jump at %.1f, so it can never catch anybody"
			% high_bottom)


## The outbound cast leaves both answers open, which is what makes the return the
## thing that takes one away.
func test_the_outbound_cast_can_be_slid_under() -> void:
	var tuning := PlayerTuning.new()
	var underside := PrismScript.CAST_HEIGHT_NES - Beam.BEAM_NES.y * 0.5
	assert_true(underside > tuning.NES_SLIDE_HITBOX.y,
		"the cast's underside is at %.1f and a slide is %.1f: it cannot be slid under"
			% [underside, tuning.NES_SLIDE_HITBOX.y])
	assert_true(underside < tuning.NES_HITBOX.y,
		"the cast's underside is at %.1f and a standing player is %.1f: it can be walked under"
			% [underside, tuning.NES_HITBOX.y])


## An arm of a split may not split again, or one cast fills the arena.
func test_a_split_half_cannot_split() -> void:
	var beam := Beam.new() as PrismBeam
	beam.launch(Vector2.ZERO, Vector2.RIGHT, Beam.SPLIT_SPEED_PF, 3, PlayerTuning.new())
	beam.aim(Vector2(-100.0, 100.0), Beam.OnEdge.EXPIRE, 0, 0.0)
	root.add_child(beam)
	await tree.physics_frame
	assert_eq(beam.on_edge, Beam.OnEdge.EXPIRE,
		"a half of a split is not set to expire, so the pattern is exponential")


# --- Sweep ------------------------------------------------------------------------

## **Backing away has to be a losing move**, or the pattern is Rust's Press with
## a light on it. The spot outruns a walk; Prism, behind it, does not outrun the
## spot.
func test_the_spot_outruns_a_walk_and_prism_does_not_outrun_the_spot() -> void:
	var tuning := PlayerTuning.new()
	assert_true(Spot.SPEED_PF > tuning.walk_speed_pf,
		"the spot moves at %.2f and a walk is %.3f, so retreating works forever"
			% [Spot.SPEED_PF, tuning.walk_speed_pf])
	assert_true(PrismScript.SWEEP_FOLLOW_PF < Spot.SPEED_PF,
		"Prism follows at %.2f against the spot's %.2f, so it overtakes the thing it drives"
			% [PrismScript.SWEEP_FOLLOW_PF, Spot.SPEED_PF])


## And going through it has to be an ordinary hop, since it is the only way out.
func test_the_spot_can_be_jumped() -> void:
	var tuning := PlayerTuning.new()
	assert_true(float(Spot.HEIGHT_NES) < tuning.jump_apex_nes_px() * 0.5,
		"the spot is %.0f tall against a %.1f jump: clearing it is not an ordinary hop"
			% [Spot.HEIGHT_NES, tuning.jump_apex_nes_px()])


## It damages rather than kills. A hazard that removes floor during a boss fight
## and kills on contact is two games at once -- `CorrosionPatch`'s argument.
func test_the_spot_damages_rather_than_kills() -> void:
	assert_true(PrismScript.SWEEP_DAMAGE > 0
			and PrismScript.SWEEP_DAMAGE < Boss.BOSS_HP,
		"the sweep does %d damage" % PrismScript.SWEEP_DAMAGE)


# --- The patterns -----------------------------------------------------------------

func test_every_pattern_tells_before_it_acts() -> void:
	# BossPattern's shape guarantees the order; what is checked here is that no
	# tell is so short it cannot be read. Half a second is the floor.
	for pattern in prism.build_patterns():
		assert_true(pattern.tell_frames >= 30,
			"%s tells for only %d frames" % [pattern.id, pattern.tell_frames])
		assert_true(pattern.recover_frames >= 30,
			"%s recovers for only %d frames, so there is no counterplay"
				% [pattern.id, pattern.recover_frames])


## The mirrors have to outlive the beam that uses them, or the corridor vanishes
## with the thing still bouncing in it -- which is the same fault as an invisible
## corridor, arrived at from the other end.
func test_the_mirrors_outlive_the_beam_they_are_for() -> void:
	var facets: BossPattern = null
	for pattern in prism.build_patterns():
		if pattern.id == &"facets":
			facets = pattern
	assert_true(facets != null, "Prism has no facets pattern")
	var life := facets.act_frames + facets.recover_frames \
		+ PrismScript.FACET_LINGER_FRAMES
	assert_true(life > facets.act_frames + facets.recover_frames,
		"the mirrors are taken away on the frame the pattern ends")
	assert_true(PrismScript.FACET_LINGER_FRAMES > Mirror.RAISE_FRAMES,
		"the mirrors linger for less time than they take to come up")


func test_prism_is_the_fourth_boss_and_drops_its_own_weapon() -> void:
	assert_eq(PrismScript.INDEX, 3)
	assert_eq(prism.weapon_id, &"prism_ray")
	assert_eq(prism.display_name, "Prism")


## The table is the design. Prism is weak to Gale Cutter, which does not exist
## yet, and resists the weapon it drops -- the property PLAN section 4 requires
## of every boss.
func test_prism_is_weak_to_gale_and_not_to_its_own_weapon() -> void:
	var table: DamageTable = preload("res://resources/damage_tables/prism.tres")
	assert_eq(table.entity_id, &"prism")
	assert_eq(table.damage_for(&"gale_cutter", 1), 4)
	assert_true(table.damage_for(&"prism_ray", 1) < 4,
		"Prism is weak to the weapon it drops")
	assert_true(table.damage_for(&"buster", 1) >= 1,
		"the buster cannot hurt Prism, so the stage cannot be cleared first")
