## Gale: the three fairness bounds, checked against the tuning rather than the
## prose.
##
## Each of Gale's patterns is survivable only because of one inequality, and all
## three inequalities are between a boss constant and a *player* constant. That
## is the dangerous shape: retuning the jump or the walk is a change nobody would
## think to make against a boss file, and it can silently make a pattern
## unwinnable. So none of these numbers is written down here.
##
##   * **Downdraft** takes the whole floor, and is survivable only because the
##     slab is live for less time than a jump lasts.
##   * **Crosswind** pushes, and is answerable only because the push is weaker
##     than a walk -- `WindZone`'s first fairness rule, restated for the boss.
##   * **Rotor** throws a train along a lane, and is clearable only because the
##     two lanes are far enough apart that a standing player fits between the
##     floor and the high one.
extends TestCase

const GaleScript := preload("res://scenes/actors/bosses/gale.gd")
const Blade := preload("res://scenes/actors/projectiles/gale_blade.gd")
const Slab := preload("res://scenes/actors/projectiles/downdraft.gd")
const PLAYER_SCENE := preload("res://scenes/actors/player/player.tscn")
const DAMAGE_TABLE := preload("res://resources/damage_tables/gale.tres")

var root: Node2D
var gale: Gale
var tuning: PlayerTuning


func is_async() -> bool:
	return true


func before_each_async() -> void:
	tuning = PlayerTuning.new()
	root = Node2D.new()
	tree.root.add_child(root)
	gale = GaleScript.new() as Gale
	root.add_child(gale)
	gale.seed_rng(7)
	await tree.physics_frame


func after_each_async() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


## Frames a full jump keeps the player off the ground.
##
## Integrated a frame at a time rather than taken from the continuous
## `2v/g`, for the reason `PlayerTuning.jump_apex_nes_px` gives: the engine and
## the NES both step, and the two answers differ by about half a frame's
## velocity -- which here is the difference between a bound holding and not.
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


# --- Downdraft: the floor comes back before the player has to land ---------------

## **The bound the whole pattern rests on.** The slab covers the entire arena, so
## a player who is on the ground at any point while it is live is hit -- there is
## nowhere else to be. It is fair only because it lifts before a jump ends.
func test_the_downdraft_lifts_before_a_jump_ends() -> void:
	var airtime := _jump_airtime_frames()
	assert_true(float(Slab.SLAB_FRAMES) < airtime,
		"the slab is live for %d frames and a jump lasts %.1f; there is no answer"
			% [Slab.SLAB_FRAMES, airtime])
	# And with room to spare, not to the frame: a player who leaves the ground on
	# the frame it lands should not have to have done it on that exact frame.
	assert_true(airtime - float(Slab.SLAB_FRAMES) >= 6.0,
		"only %.1f frames of slack between the slab and a jump" % [airtime - float(Slab.SLAB_FRAMES)])


## The live band catches a standing player and a sliding one alike -- sliding
## must not be a second, easier answer -- and is nowhere near the jump apex.
func test_the_downdraft_band_is_above_a_slide_and_under_the_apex() -> void:
	var apex := tuning.jump_apex_nes_px()
	assert_true(Slab.BAND_HEIGHT_NES > float(PlayerTuning.NES_SLIDE_HITBOX.y),
		"a slide (%d px) fits under a %.0f px band" % [
			int(PlayerTuning.NES_SLIDE_HITBOX.y), Slab.BAND_HEIGHT_NES])
	assert_true(Slab.BAND_HEIGHT_NES > float(PlayerTuning.NES_HITBOX.y) * 0.8,
		"the band is short enough to stand up in")
	assert_true(Slab.BAND_HEIGHT_NES < apex,
		"the band (%.0f px) reaches the jump apex (%.0f px)" % [Slab.BAND_HEIGHT_NES, apex])


## It is harmless on the way down. The cue is a falling object, and a cue that
## hurt on approach would be a cue nobody could watch.
func test_a_falling_slab_is_not_dangerous_yet() -> void:
	var slab := Slab.new() as Downdraft
	slab.drop(Vector2(0.0, 400.0), 500.0, 100.0, 3, tuning)
	root.add_child(slab)
	await tree.physics_frame
	assert_false(slab.is_landed(), "the slab landed on the frame it spawned")
	assert_false(slab.monitoring, "a falling slab is already dangerous")
	slab.queue_free()


# --- Crosswind: the push never beats a walk --------------------------------------

## `WindZone`'s first fairness rule, restated for the boss: a wind at or above
## the walk speed can hold a player still, and a player who cannot get where they
## are going has no answer to give.
func test_the_crosswind_is_weaker_than_the_player_can_walk() -> void:
	assert_true(GaleScript.CROSSWIND_DRIFT_PF < tuning.walk_speed_pf,
		"the crosswind pushes at %.2f and the player walks at %.2f"
			% [GaleScript.CROSSWIND_DRIFT_PF, tuning.walk_speed_pf])


## And it is written onto the player rather than latched, so nothing about the
## boss can leave the player permanently blown sideways.
func test_the_crosswind_writes_the_players_drift() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await tree.physics_frame
	gale.target = player
	gale.act(BossPattern.new(&"crosswind", 1, 1, 1, 1.0), 0)
	assert_almost_eq(absf(player.wind_drift_pf), GaleScript.CROSSWIND_DRIFT_PF, 0.001,
		"the crosswind did not reach the player")


# --- Rotor: the lanes leave a body-sized gap -------------------------------------

## Two lanes, not four, and this is the arithmetic that says why. A standing
## player is `NES_HITBOX.y` tall and a blade is `GaleBlade.BLADE_NES.y`; a player
## can only be *under* the high lane if the clearance beats their height.
func test_a_standing_player_fits_under_the_high_rotor_lane() -> void:
	var blade_half := GaleBlade.BLADE_NES.y * 0.5
	var clearance := GaleScript.ROTOR_LANE_HIGH_NES - blade_half
	assert_true(clearance > float(PlayerTuning.NES_HITBOX.y),
		"a standing player (%d px) does not fit under the high lane (%.1f px)"
			% [int(PlayerTuning.NES_HITBOX.y), clearance])


## And the low lane is one a jump clears outright -- the other half of the same
## pattern, and the reason there is no third lane between them.
func test_a_jump_clears_the_low_rotor_lane() -> void:
	var apex := tuning.jump_apex_nes_px()
	var top := GaleScript.ROTOR_LANE_LOW_NES + GaleBlade.BLADE_NES.y * 0.5
	assert_true(top < apex,
		"the low lane tops out at %.1f px and the jump reaches %.1f" % [top, apex])


## The train has to be taken in one posture. Blades closer together than a jump
## arc means a player who hops the first is still airborne for the second, which
## is the ask; spaced further apart it is three separate hops and a different
## pattern.
func test_the_rotor_train_outlasts_a_single_jump() -> void:
	var train := float((GaleScript.ROTOR_BLADES - 1) * GaleScript.ROTOR_SPACING_FRAMES)
	assert_true(train > _jump_airtime_frames(),
		"the train passes in %.0f frames and a jump lasts %.1f" % [train, _jump_airtime_frames()])


# --- The tell is the boss's own position -----------------------------------------

## Two of the three patterns telegraph with the hover, so the hover is the thing
## a test has to watch. Rotor holds the lane it is about to throw down; Downdraft
## hangs above the jump apex, out of the player's way while they are busy not
## being on the ground; and every recovery is a landing.
func test_the_hover_matches_the_pattern() -> void:
	assert_almost_eq(gale.hover_height(), -1.0, 0.001,
		"a boss with no pattern is not on the floor")
	var apex := tuning.jump_apex_nes_px()
	assert_true(GaleScript.DOWNDRAFT_HOVER_NES > apex,
		"Gale hovers at %.0f px, inside the player's jump apex of %.0f"
			% [GaleScript.DOWNDRAFT_HOVER_NES, apex])
	assert_true(GaleScript.DOWNDRAFT_START_NES > GaleScript.DOWNDRAFT_HOVER_NES,
		"the slab starts below the boss that drops it")


## Gale is one of the three patterns it builds, and no more -- a pattern list
## that grew a fourth silently would change the fight's density.
func test_gale_builds_its_three_patterns() -> void:
	var ids: Array[StringName] = []
	for pattern in gale.patterns():
		ids.append(pattern.id)
	assert_eq(ids.size(), 3, "Gale built %d patterns" % ids.size())
	for wanted in [&"crosswind", &"rotor", &"downdraft"]:
		assert_has(ids, wanted, "Gale has no %s" % wanted)


# --- The weakness chain ------------------------------------------------------------

## No boss is weak to the weapon it drops, and Gale's weakness is Tide Crawler --
## which the player can have, because stage 1 is the buster-only stage.
func test_gale_is_weak_to_tide_and_not_to_its_own_cutter() -> void:
	var cutter := DAMAGE_TABLE.damage_for(&"gale_cutter", 1)
	var crawler := DAMAGE_TABLE.damage_for(&"tide_crawler", 1)
	assert_true(crawler > cutter, "Gale is meant to be weak to Tide Crawler")
	assert_true(crawler >= 2 and crawler <= 4, "weakness damage stays inside the 2-4x rule")


## And the Cutter closes the one dangling row in the chain: Prism's table has
## pointed at `gale_cutter` since stage 4 and the weapon did not exist.
func test_the_cutter_now_exists_for_prisms_weakness() -> void:
	var weapon := load("res://resources/weapons/gale_cutter.tres") as WeaponData
	assert_not_null(weapon, "gale_cutter.tres does not load")
	assert_eq(weapon.id, &"gale_cutter", "the resource carries the wrong id")
	assert_not_null(weapon.projectile_script, "the Gale Cutter fires nothing")
	var prism := load("res://resources/damage_tables/prism.tres") as DamageTable
	assert_true(prism.damage_for(&"gale_cutter", 1) > prism.damage_for(&"prism_ray", 1),
		"Prism is meant to be weak to the weapon that now exists")
