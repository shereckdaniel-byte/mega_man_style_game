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
	assert_almost_eq(t.px_s(t.walk_speed_pf) * DT, t.walk_speed_pf * t.world_scale,
		0.0001, "walk speed survives the px/s round trip")
	assert_almost_eq(t.px_s2(t.gravity_pf) * DT * DT, t.gravity_pf * t.world_scale,
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
	assert_between(t.jump_apex_nes_px(), 46.0, 47.0, "discrete apex, in NES pixels")
	assert_between(t.jump_apex_tiles(), 2.85, 2.95, "apex in tiles -- scale-invariant")
	assert_true(t.jump_apex_tiles() < 3.0, "must not clear a 3-tile ledge")
	assert_true(t.jump_apex_tiles() > 2.0, "must comfortably clear a 2-tile ledge")


## World scale must not change the tile-relative geometry -- that is the whole
## reason the constants are authored in NES units and converted on the way out.
func test_geometry_is_scale_invariant() -> void:
	var apex_tiles := t.jump_apex_tiles()
	var slide_tiles := t.slide_distance_tiles()
	for scale in [1.0, 2.0, 3.0, 4.5]:
		t.world_scale = scale
		assert_almost_eq(t.jump_apex_tiles(), apex_tiles, 0.0001,
			"apex in tiles at %fx" % scale)
		assert_almost_eq(t.slide_distance_tiles(), slide_tiles, 0.0001,
			"slide in tiles at %fx" % scale)
		assert_almost_eq(t.jump_apex_px(), apex_tiles * t.tile_size(), 0.01,
			"world apex tracks tile size at %fx" % scale)


## The HD art is minified to reach the character height, which is why the
## project filters linearly rather than nearest.
func test_sprite_scale_minifies_the_source_art() -> void:
	var factor := t.sprite_scale(177.0)
	assert_between(factor, 0.55, 0.70, "177 px art drawn at %.0f px" % t.character_height())
	assert_almost_eq(177.0 * factor, t.character_height(), 0.01)
	assert_true(factor < 1.0, "minification, not magnification")


func test_world_metrics() -> void:
	assert_almost_eq(t.world_scale, 4.5)
	assert_almost_eq(t.tile_size(), 72.0)
	assert_almost_eq(t.character_height(), 108.0)
	assert_eq(t.hitbox_size(), Vector2(72.0, 108.0))
	assert_eq(t.slide_hitbox_size(), Vector2(72.0, 63.0))


## The continuous v^2/2g figure overstates the apex by about v/2 -- here 2.46 px,
## a sixth of a tile. Not exactly v/2: the apex lands between frames unless
## v/g is a half-integer, so the true gap is v/2 give or take half a gravity
## step. Asserted rather than left as a comment because designing a ledge
## against the wrong one of these two numbers makes it unclearable.
func test_continuous_formula_overstates_apex() -> void:
	var gap := t.jump_apex_continuous_nes_px() - t.jump_apex_nes_px()
	assert_true(gap > 0.0, "the continuous formula always overstates")
	assert_almost_eq(gap, t.jump_velocity_pf / 2.0, t.gravity_pf / 2.0,
		"the gap is v/2, within the half-frame the apex falls between")


func test_slide_covers_four_tiles() -> void:
	assert_almost_eq(t.slide_distance_nes_px(), 65.0, 0.001)
	assert_between(t.slide_distance_tiles(), 4.0, 4.2)
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
	assert_true(cap * DT < t.tile_size() * 0.5,
		"a single frame of falling (%.1f px) moves less than half a tile (%.1f px), "
			% [cap * DT, t.tile_size() * 0.5] +
		"so collision cannot be tunnelled through")


## Mega Man 3 has no charge shot; the 3-pellet cap is what limits buster DPS.
func test_buster_shot_cap_is_three() -> void:
	assert_eq(t.max_buster_shots, 3)


## The original had neither. Buffering is invisible; coyote time is not.
func test_forgiveness_settings_match_the_documented_decision() -> void:
	assert_eq(t.coyote_frames, 0, "no coyote time -- see PLAN.md section 6")
	assert_eq(t.jump_buffer_frames, 4)
