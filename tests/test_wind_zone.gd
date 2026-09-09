## Turbine Row's wind: the cycle, and the three rules that keep it fair.
##
## Driven against a real player on a real floor, because two of the three rules
## are about what the push does to a body rather than about what the zone
## reports -- and the one that matters most, "it never touches a walking
## player", is invisible to anything that only reads the zone's own state.
extends TestCase

## How much further than the widest authored gap a full-gust jump has to reach.
##
## The player lands on the far lip rather than arriving at its edge, and a rule
## satisfied exactly is a rule that fails on the first room built at the limit.
const MIN_GUST_HEADROOM := 1.2

const PLAYER_SCENE := preload("res://scenes/actors/player/player.tscn")

const FLOOR_TOP := 500.0
const SPAWN := Vector2(400.0, FLOOR_TOP)

var root: Node2D
var player: Player
var zone: WindZone


func is_async() -> bool:
	return true


func before_each_async() -> void:
	root = Node2D.new()
	tree.root.add_child(root)
	_add_floor(Vector2(-1000.0, FLOOR_TOP), Vector2(4000.0, 200.0))
	player = PLAYER_SCENE.instantiate()
	player.position = SPAWN
	root.add_child(player)

	zone = WindZone.new()
	zone.width_tiles = 40.0
	zone.height_tiles = 20.0
	zone.position = Vector2(-200.0, FLOOR_TOP - 900.0)
	root.add_child(zone)
	await _frames(6)


func after_each_async() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


# --- The three rules ------------------------------------------------------------

## **Rule two: the wind is weaker than the player.** Flying into it must be slow
## and never impossible, so the drift has to stay under the speed the player
## moves at -- which is the same in the air as on the ground, because air control
## here is full strength.
func test_the_wind_is_weaker_than_the_player_can_walk() -> void:
	var t := PlayerTuning.new()
	assert_true(zone.speed_pf < t.walk_speed_pf,
		"a %.2f px/frame wind against a %.2f px/frame player is a wall, not weather"
			% [zone.speed_pf, t.walk_speed_pf])


## **Rule two, the half of it that actually bites: a full-gust jump still clears
## the widest gap a stage may author.**
##
## The test above is true and nearly useless on its own, and it shipped a wind
## that made every two-cell hole in the game uncrossable. "Weaker than a walk"
## bounds the drift against the *speed* the player moves at; what a crossing
## needs bounded is the **distance** a jump covers, and the drift is subtracted
## from that for every one of its forty frames. At 0.9 px/frame -- two thirds of
## the walk speed, and comfortably inside the old rule -- a headwind jump reached
## 1.2 tiles against gaps the level grammar allows to be 2.
##
## Measured against `PlayerTuning` and `AuthoredStage.MAX_GAP_TILES` rather than
## against numbers, so retuning the jump, the walk or the grammar's widest gap
## re-checks the wind instead of quietly outdating it.
func test_a_full_gust_jump_still_clears_the_widest_gap() -> void:
	var t := PlayerTuning.new()
	var airborne := _jump_airtime_frames(t)
	var still := t.walk_speed_pf * airborne
	var into_it := (t.walk_speed_pf - zone.speed_pf) * airborne
	var needed := float(AuthoredStage.MAX_GAP_TILES) * PlayerTuning.NES_TILE
	# Headroom rather than to the pixel: the player has to *land* on the far lip,
	# not arrive at its edge, and a bound met exactly is a bound that fails on
	# the first room authored at the limit.
	assert_true(into_it >= needed * MIN_GUST_HEADROOM,
		"a full-gust jump reaches %.1f px (%.1f in still air) against a %.0f px gap"
			% [into_it, still, needed])


## Frames a full jump keeps the player off the ground, integrated a frame at a
## time for the reason `PlayerTuning.jump_apex_nes_px` gives: the engine steps,
## and the continuous `2v/g` differs by about half a frame's velocity.
func _jump_airtime_frames(t: PlayerTuning) -> float:
	var v := -t.jump_velocity_pf
	var y := 0.0
	var frames := 0
	while true:
		v += t.gravity_pf
		y += v
		frames += 1
		if y >= 0.0:
			break
	return float(frames)


## **Rule three: the lull outlasts a jump.** A jump is airborne
## `2 * jump_velocity_pf / gravity_pf` frames -- the same derivation
## `PhaseBlock.BEAT_FRAMES` is built on -- so a lull longer than that means every
## crossing in the stage can be made in still air by a player who waits. The gust
## is a tax on impatience, not a gate.
func test_the_lull_outlasts_a_full_jump() -> void:
	var t := PlayerTuning.new()
	var airborne := 2.0 * t.jump_velocity_pf / t.gravity_pf
	assert_true(float(zone.lull_frames) >= airborne,
		"a %d-frame lull against %.1f frames of airtime leaves no still crossing"
			% [zone.lull_frames, airborne])


## **Rule one, first half: a player who is not moving is not moved.**
##
## The push scales movement rather than creating it, so standing still in a gust
## keeps you exactly where you are. Without this a gust would slide an idle
## player into a pit while they were not touching the controls, which is a
## different mechanic from a headwind and not one anybody asked for.
func test_a_standing_player_is_not_pushed() -> void:
	zone.phase_frames = zone.lull_frames + zone.tell_frames  # start in the gust
	await _frames(2)
	assert_true(zone.is_blowing(), "the zone is not in its gust")
	assert_true(player.is_on_floor(), "the player is not on the floor")

	var before := player.global_position.x
	await _frames(30)
	assert_true(player.is_on_floor(), "the player left the floor")
	assert_almost_eq(player.global_position.x, before, 1.0,
		"a standing player drifted %.1f px in a gust"
			% [player.global_position.x - before])


## **Rule one, second half: a walking player is slowed and sped.**
##
## The wind used to apply only in the air, which made it something you could not
## feel for most of a room. Both directions are measured in the same gust so the
## test cannot pass by the wind being broken in one of them.
func test_a_headwind_slows_a_walk_and_a_tailwind_speeds_it() -> void:
	zone.phase_frames = zone.lull_frames + zone.tell_frames  # start in the gust
	zone.direction = 1
	await _frames(2)
	assert_true(zone.is_blowing(), "the zone is not in its gust")

	var with_it := await _walk_distance(&"move_right")
	var into_it := await _walk_distance(&"move_left")
	assert_true(with_it > into_it,
		"downwind covered %.1f px and upwind %.1f; the wind is not being felt"
			% [with_it, into_it])


## **And a headwind never stops one.** With the push on the ground this is the
## rule that keeps a gusting room crossable at all -- a wind at or above the
## walk speed would hold the player still or walk them backwards.
##
## Measured as a fraction of the same walk in still air rather than against a
## number, and required to keep over half of it: "not quite zero" is not a
## playable amount of headway.
func test_a_headwind_leaves_more_than_half_the_walk() -> void:
	var t := PlayerTuning.new()
	assert_true(zone.speed_pf < t.walk_speed_pf * 0.5,
		"a %.2f px/frame wind against a %.2f px/frame walk leaves %.0f%% of it"
			% [zone.speed_pf, t.walk_speed_pf,
				100.0 * (t.walk_speed_pf - zone.speed_pf) / t.walk_speed_pf])

	# And the same thing measured on a real player rather than in arithmetic.
	zone.phase_frames = zone.lull_frames + zone.tell_frames
	zone.direction = 1
	await _frames(2)
	var into_it := await _walk_distance(&"move_left")
	assert_true(into_it > 1.0, "a headwind stopped the player dead")


## Distance covered walking one way for 30 frames, from a standing start on the
## floor. Returns an absolute distance, so the two directions compare directly.
func _walk_distance(action: StringName) -> float:
	player.global_position = SPAWN
	player.velocity = Vector2.ZERO
	await _frames(6)
	var before := player.global_position.x
	Input.action_press(action)
	await _frames(30)
	Input.action_release(action)
	await _frames(1)
	return absf(player.global_position.x - before)


# --- The push itself ------------------------------------------------------------

## And it does push, once the player is off the ground -- otherwise rule one
## would be satisfied by a gimmick that does nothing at all.
func test_an_airborne_player_is_pushed_the_way_the_wind_blows() -> void:
	zone.phase_frames = zone.lull_frames + zone.tell_frames
	zone.direction = 1
	await _frames(2)

	player.global_position = Vector2(400.0, FLOOR_TOP - 300.0)
	player.velocity = Vector2.ZERO
	var before := player.global_position.x
	await _frames(20)
	assert_false(player.is_on_floor(), "the player landed before the test ran")
	assert_true(player.global_position.x > before + 4.0,
		"an airborne player moved %.1f px in a rightward gust"
			% [player.global_position.x - before])


func test_the_wind_blows_both_ways() -> void:
	zone.phase_frames = zone.lull_frames + zone.tell_frames
	zone.direction = -1
	await _frames(2)

	player.global_position = Vector2(400.0, FLOOR_TOP - 300.0)
	player.velocity = Vector2.ZERO
	var before := player.global_position.x
	await _frames(20)
	assert_true(player.global_position.x < before - 4.0,
		"a leftward gust moved the player %.1f px"
			% [player.global_position.x - before])


## Nothing pushes during the lull, which is what makes the lull mean something.
func test_nothing_is_pushed_during_the_lull() -> void:
	zone.phase_frames = 0
	await _frames(2)
	assert_eq(zone.phase(), WindZone.Phase.LULL)
	assert_almost_eq(zone.drift_pf(), 0.0, 0.001)

	player.global_position = Vector2(400.0, FLOOR_TOP - 300.0)
	player.velocity = Vector2.ZERO
	var before := player.global_position.x
	await _frames(20)
	assert_almost_eq(player.global_position.x, before, 2.0,
		"the player drifted %.1f px in still air"
			% [player.global_position.x - before])


## The tell is time to react in, so it must not push either.
func test_the_tell_does_not_push_yet() -> void:
	zone.phase_frames = zone.lull_frames + 2
	await _frames(2)
	assert_eq(zone.phase(), WindZone.Phase.TELL)
	assert_almost_eq(zone.drift_pf(), 0.0, 0.001,
		"the tell is pushing, so there is nothing to react to")


## The push is written every frame rather than latched, so a player who leaves
## the zone stops being pushed with nothing having to remember to stop.
func test_leaving_the_zone_ends_the_push() -> void:
	zone.phase_frames = zone.lull_frames + zone.tell_frames
	await _frames(2)
	player.global_position = Vector2(400.0, FLOOR_TOP - 300.0)
	await _frames(4)

	# Out of the box entirely.
	player.global_position = Vector2(400.0, FLOOR_TOP - 5000.0)
	await _frames(4)
	assert_almost_eq(player.wind_drift_pf, 0.0, 0.001,
		"the player is still carrying a push after leaving the zone")


func test_the_cycle_covers_every_phase_and_returns() -> void:
	zone.phase_frames = 0
	var seen := {}
	for i in zone.cycle_frames() + 4:
		seen[zone.phase()] = true
		await tree.physics_frame
	assert_eq(seen.size(), 3, "the cycle does not reach all three phases")


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
