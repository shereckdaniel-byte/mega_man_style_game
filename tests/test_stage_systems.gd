## Hazards, checkpoints, the death sequence and the energy bar.
##
## The death loop is the part of M3 that is easiest to get subtly wrong and
## hardest to notice: a respawn that silently drops the player at the world
## origin, or a checkpoint placed over a pit, both look like the game working
## until you die in the wrong place.
extends TestCase

const PLAYER_SCENE := preload("res://scenes/actors/player/player.tscn")
const GameStateScript := preload("res://scripts/autoload/game_state.gd")

const FLOOR_TOP := 400.0
const SPAWN := Vector2(200.0, FLOOR_TOP)
const SETTLE_FRAMES := 12

var root: Node2D
var player: Player
var t: PlayerTuning
## The live autoload, saved and restored: these tests move the checkpoint and
## spend lives, and leaving that behind would make later tests order-dependent.
var _saved_checkpoint: Vector2
var _saved_checkpoint_set: bool
var _saved_lives: int


func is_async() -> bool:
	return true


func before_each_async() -> void:
	var state := _game_state()
	if state != null:
		_saved_checkpoint = state.checkpoint
		_saved_checkpoint_set = state.checkpoint_set
		_saved_lives = state.lives
		state.clear_checkpoint()
		state.lives = 3

	root = Node2D.new()
	tree.root.add_child(root)
	_add_floor(Vector2(-1000.0, FLOOR_TOP), Vector2(4000.0, 200.0))
	player = PLAYER_SCENE.instantiate()
	player.position = SPAWN
	root.add_child(player)
	t = player.tuning
	await _frames(SETTLE_FRAMES)


func after_each_async() -> void:
	var state := _game_state()
	if state != null:
		state.checkpoint = _saved_checkpoint
		state.checkpoint_set = _saved_checkpoint_set
		state.lives = _saved_lives
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


# --- Hazards ------------------------------------------------------------------

## A spike kills a full-health player outright. That is what makes a spike
## corridor a precision section rather than a damage race.
func test_a_hazard_kills_outright_from_full_health() -> void:
	assert_eq(player.health.current, 28)
	_add_hazard(player.global_position + Vector2(0.0, -40.0))
	await _frames(6)
	assert_true(player.health.is_dead(), "instant death, not a chunk of damage")
	assert_eq(player.state_machine.current_name(), &"Dead")


## The respawn grace period has to cover hazards too, or respawning anywhere
## near the thing that killed you is an instant second death.
func test_a_hazard_cannot_kill_during_respawn_grace() -> void:
	var hazard := _add_hazard(SPAWN + Vector2(0.0, -40.0))
	await _frames(6)
	assert_true(player.health.is_dead())
	player.respawn_at(SPAWN)
	await _frames(6)
	assert_false(player.health.is_dead(), "grace period holds the hazard off")
	assert_true(player.health.is_invulnerable())
	hazard.queue_free()


# --- Checkpoints --------------------------------------------------------------

func test_crossing_a_checkpoint_records_it() -> void:
	var state := _game_state()
	if state == null:
		return
	assert_false(state.checkpoint_set, "nothing recorded yet")
	var checkpoint := Checkpoint.new()
	checkpoint.position = SPAWN
	root.add_child(checkpoint)
	await _frames(6)
	assert_true(state.checkpoint_set)
	assert_almost_eq(state.checkpoint.x, SPAWN.x, 1.0)


## Vector2.ZERO is a legitimate world position, so it cannot double as "no
## checkpoint". A stage that never places one must still respawn somewhere
## sensible rather than at the world origin.
func test_no_checkpoint_falls_back_to_where_the_player_entered() -> void:
	var state := GameStateScript.new()
	assert_false(state.checkpoint_set)
	assert_eq(state.respawn_position(Vector2(900.0, 40.0)), Vector2(900.0, 40.0))
	state.set_checkpoint(Vector2(1200.0, 80.0))
	assert_eq(state.respawn_position(Vector2(900.0, 40.0)), Vector2(1200.0, 80.0))
	state.free()


# --- The death sequence -------------------------------------------------------

func test_death_hides_the_player_and_bursts() -> void:
	_add_hazard(player.global_position + Vector2(0.0, -40.0))
	await _frames(4)
	assert_eq(player.state_machine.current_name(), &"Dead")
	assert_false(player.sprite.visible, "the burst stands in for the character")
	var bursts := 0
	for child in root.get_children():
		if child is DeathExplosion:
			bursts += 1
	assert_eq(bursts, 1)


func test_the_burst_is_eight_bolts() -> void:
	assert_eq(DeathExplosion.COUNT, 8, "the count is the recognisable part")


func test_death_spends_a_life_and_returns_to_the_checkpoint() -> void:
	var state := _game_state()
	if state == null:
		return
	state.set_checkpoint(Vector2(1000.0, FLOOR_TOP))
	state.lives = 3
	_add_hazard(player.global_position + Vector2(0.0, -40.0))
	await _frames(4)
	await _frames(DeadStateDelay() + 6)
	assert_eq(state.lives, 2, "one life spent")
	assert_almost_eq(player.global_position.x, 1000.0, 2.0, "back at the checkpoint")
	assert_eq(player.health.current, 28, "and at full health")
	# Not `visible` on a single frame: a respawn grants i-frames, so the sprite
	# is mid-flicker and off half the time. The property that matters is that
	# the Dead state did not leave it hidden for good.
	var seen := false
	for i in 8:
		await tree.physics_frame
		seen = seen or player.sprite.visible
	assert_true(seen, "sprite comes back rather than staying hidden")


func test_the_last_life_reports_a_game_over_instead_of_respawning() -> void:
	var state := _game_state()
	if state == null:
		return
	state.lives = 0
	var over := [false]
	player.game_over.connect(func() -> void: over[0] = true)
	_add_hazard(player.global_position + Vector2(0.0, -40.0))
	await _frames(4)
	await _frames(DeadStateDelay() + 6)
	assert_true(over[0], "game over is reported, not silently respawned")


# --- The energy bar -----------------------------------------------------------

func test_the_bar_has_one_segment_per_hit_point() -> void:
	var bar := EnergyBar.new()
	root.add_child(bar)
	bar.track(player.health)
	assert_eq(bar.ticks, 28, "one segment is one HP, so the HUD needs no maths")
	bar.queue_free()


## "Drains and refills tick-by-tick" is the M3 acceptance wording, and it means
## the bar must NOT jump straight to the new value.
func test_the_bar_moves_one_tick_at_a_time_rather_than_jumping() -> void:
	var bar := EnergyBar.new()
	root.add_child(bar)
	bar.track(player.health)
	await _frames(2)
	bar.set_value(20)
	await tree.physics_frame
	assert_ne(bar.shown_value(), 20, "does not snap to the new value")
	assert_true(bar.shown_value() > 20, "still on its way down")
	await _frames(28 * EnergyBar.DRAIN_FRAMES_PER_TICK + 4)
	assert_eq(bar.shown_value(), 20, "and arrives")
	bar.queue_free()


## A full drain has to finish inside the death sequence, or the bar is still
## visibly emptying after the player has respawned.
func test_a_full_drain_fits_inside_the_death_sequence() -> void:
	var drain_frames := Health.BAR_TICKS * EnergyBar.DRAIN_FRAMES_PER_TICK
	assert_true(drain_frames <= DeadStateDelay(),
		"%d frames to drain must fit in the %d-frame death" % [drain_frames, DeadStateDelay()])


## Refilling is deliberately slower than draining: the pause is part of the
## pacing, not a delay to be optimised away.
func test_refilling_is_slower_than_draining() -> void:
	assert_true(EnergyBar.FILL_FRAMES_PER_TICK > EnergyBar.DRAIN_FRAMES_PER_TICK)


func test_a_respawn_snaps_the_bar_rather_than_animating_it() -> void:
	var hud := Hud.new()
	root.add_child(hud)
	hud.track(player)
	await _frames(2)
	player.health.take(DamageInfo.new(10))
	await _frames(4)
	player.respawn_at(SPAWN)
	await tree.physics_frame
	assert_eq(hud.energy.shown_value(), 28, "already full when the player reappears")
	hud.queue_free()


# --- Helpers ------------------------------------------------------------------

func DeadStateDelay() -> int:
	var state: State = player.state_machine._states[&"Dead"]
	return state.RESPAWN_DELAY_FRAMES


func _game_state() -> Node:
	return tree.root.get_node_or_null(^"/root/GameState")


func _add_hazard(at: Vector2) -> Hazard:
	var hazard := Hazard.new()
	hazard.size_tiles = Vector2(1.0, 1.0)
	root.add_child(hazard)
	hazard.global_position = at
	return hazard


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
