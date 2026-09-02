## The regression net for game feel.
##
## These simulate the player the way the engine will and assert the result in
## pixels. If a refactor changes how velocity is integrated, these break before
## anyone has to notice by playing.
extends TestCase

const DT := 1.0 / PlayerTuning.FPS

var t: PlayerTuning


func before_each() -> void:
	t = PlayerTuning.new()


## The whole point of authoring in px/frame: converting to px/s and integrating
## with delta must land on exactly the same pixels.
func test_per_second_conversion_round_trips() -> void:
	assert_almost_eq(t.px_s(t.walk_speed_pf) * DT, t.walk_speed_pf,
		0.0001, "walk speed survives the px/s round trip")
	assert_almost_eq(t.px_s2(t.gravity_pf) * DT * DT, t.gravity_pf,
		0.0001, "gravity survives the px/s^2 round trip")


## Simulates a full-height jump in px/s units, as the controller will, and
## checks it against the tuning's own derived apex.
func test_simulated_jump_apex_matches_derived() -> void:
	var v := -t.px_s(t.jump_velocity_pf)
	var g := t.px_s2(t.gravity_pf)
	var y := 0.0
	var apex := 0.0
	var frames := 0
	while v < 0.0 and frames < 600:
		v += g * DT
		y += v * DT
		apex = minf(apex, y)
		frames += 1
	assert_almost_eq(absf(apex), t.jump_apex_px(), 0.01,
		"simulated apex matches PlayerTuning.jump_apex_px()")
	assert_between(float(frames), 18.0, 22.0, "apex is reached in about 20 frames")


## Locks the actual number in. 46.3 px is 2.9 tiles: a 2-tile ledge is
## comfortable, a 3-tile ledge is a miss. Change this only on purpose.
func test_jump_apex_is_just_under_three_tiles() -> void:
	assert_between(t.jump_apex_px(), 46.0, 47.0, "discrete apex, in pixels")
	assert_true(t.jump_apex_px() < 48.0, "does not clear a 3-tile (48 px) ledge")


## The continuous v^2/2g figure overstates the apex by about v/2 -- here 2.46 px,
## a sixth of a tile. Not exactly v/2: the apex lands between frames unless
## v/g is a half-integer, so the true gap is v/2 give or take half a gravity
## step. Asserted rather than left as a comment because designing a ledge
## against the wrong one of these two numbers makes it unclearable.
func test_continuous_formula_overstates_apex() -> void:
	var gap := t.jump_apex_continuous_px() - t.jump_apex_px()
	assert_true(gap > 0.0, "the continuous formula always overstates")
	assert_almost_eq(gap, t.jump_velocity_pf / 2.0, t.gravity_pf / 2.0,
		"the gap is v/2, within the half-frame the apex falls between")


func test_slide_covers_four_tiles() -> void:
	assert_almost_eq(t.slide_distance_px(), 65.0, 0.001)
	assert_true(t.slide_distance_px() > t.jump_apex_px(),
		"a slide goes further horizontally than a jump goes up")


func test_terminal_velocity_is_reached_in_28_frames() -> void:
	assert_almost_eq(t.frames_to_terminal(), 28.0, 0.001)


## Falling must clamp, or a long drop tunnels through the floor.
func test_fall_clamps_at_terminal_velocity() -> void:
	var v := 0.0
	var g := t.px_s2(t.gravity_pf)
	var cap := t.px_s(t.terminal_velocity_pf)
	for i in 300:
		v = minf(v + g * DT, cap)
	assert_almost_eq(v, cap, 0.001, "velocity is clamped, not unbounded")
	assert_true(cap * DT < 8.0,
		"a single frame of falling moves less than half a 16 px tile, so " +
		"collision cannot be tunnelled through")


## Mega Man 3 has no charge shot; the 3-pellet cap is what limits buster DPS.
func test_buster_shot_cap_is_three() -> void:
	assert_eq(t.max_buster_shots, 3)


## The original had neither. Buffering is invisible; coyote time is not.
func test_forgiveness_settings_match_the_documented_decision() -> void:
	assert_eq(t.coyote_frames, 0, "no coyote time -- see PLAN.md section 6")
	assert_eq(t.jump_buffer_frames, 4)
