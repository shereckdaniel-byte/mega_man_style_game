## The playtest ledger: does it attribute a run correctly?
##
## This is the instrument stage 1's difficulty question is going to be answered
## with, by a person playing rather than by a bot counting, so it has to be right
## about the two things a reader will act on: *which room* cost the health, and
## *what* took it. A ledger that quietly mislabels a drowning as a buster hit --
## which is exactly what it did before KillPlane and RisingTide named their kills
## -- sends the reader to tune the wrong thing.
extends TestCase

const PLAYER_SCENE := preload("res://scenes/actors/player/player.tscn")

const FLOOR_TOP := 700.0

var root: Node2D
var player: Player
var log_node: PlaytestLog


func is_async() -> bool:
	return true


func before_each_async() -> void:
	root = Node2D.new()
	tree.root.add_child(root)
	player = PLAYER_SCENE.instantiate()
	player.position = Vector2(0.0, FLOOR_TOP)
	root.add_child(player)
	# The player carries 90 i-frames from PlayerTuning, which would refuse every
	# second hit these tests deliver back to back. Switched off here so a test
	# that means to land two hits lands two; the one test that is *about*
	# i-frames turns them back on.
	player.health.invulnerable_frames = 0
	log_node = PlaytestLog.new()
	root.add_child(log_node)
	log_node.watch(player)
	await _frames(2)


func after_each_async() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


func test_a_clean_run_costs_nothing() -> void:
	await _frames(10)
	assert_eq(log_node.hp_lost(), 0)
	assert_eq(log_node.deaths, 0)
	assert_true(log_node.events.is_empty())


func test_a_hit_is_recorded_with_its_cause() -> void:
	player.health.take(DamageInfo.new(3, Vector2.ZERO, &"enemy_shot"))
	assert_eq(log_node.hp_lost(), 3)
	assert_eq(log_node.deaths, 0)
	assert_eq(int(log_node.by_cause().get(&"enemy_shot", 0)), 3)


func test_hits_refused_by_iframes_cost_nothing() -> void:
	# The ledger must count what actually landed. Counting attempts would make
	# a room full of harmless shots look like the most expensive in the stage.
	player.health.invulnerable_frames = 60
	player.health.take(DamageInfo.new(3, Vector2.ZERO, &"enemy_shot"))
	player.health.take(DamageInfo.new(3, Vector2.ZERO, &"enemy_shot"))
	assert_eq(log_node.hp_lost(), 3, "the second hit landed during i-frames")


## The number a death costs is the health it removed, not the damage its source
## nominally deals. A spike carries 9999 and `Health.kill()` carries a full bar;
## adding either to a run's total produces a figure about the implementation.
func test_a_death_costs_the_health_that_was_left() -> void:
	player.health.take(DamageInfo.new(20, Vector2.ZERO, &"enemy_shot"))
	assert_eq(player.health.current, 8)
	player.health.take(DamageInfo.new(9999, Vector2.ZERO, &"hazard"))
	assert_eq(log_node.deaths, 1)
	assert_eq(log_node.hp_lost(), 28, "a 28 HP run should cost 28 HP, not 10019")
	assert_eq(int(log_node.by_cause().get(&"hazard", 0)), 8)


## Same again for a kill that never went through a hit, which is how a pit, the
## tide and a crusher all work.
func test_an_outright_kill_costs_the_health_that_was_left() -> void:
	player.health.take(DamageInfo.new(6, Vector2.ZERO, &"contact"))
	player.health.kill(DamageInfo.new(9999, Vector2.ZERO, &"pit"))
	assert_eq(log_node.deaths, 1)
	assert_eq(log_node.hp_lost(), 28)
	assert_eq(int(log_node.by_cause().get(&"pit", 0)), 22)
	assert_eq(int(log_node.deaths_by_cause().get(&"pit", 0)), 1)


## A fatal blow arrives at `damaged` *and* at `died`. Counting both would
## double every death in the report.
func test_a_fatal_hit_is_counted_once() -> void:
	player.health.take(DamageInfo.new(28, Vector2.ZERO, &"hazard"))
	assert_eq(log_node.events.size(), 1)
	assert_eq(log_node.hp_lost(), 28)


func test_a_run_survives_a_respawn() -> void:
	player.health.kill(DamageInfo.new(9999, Vector2.ZERO, &"pit"))
	player.respawn_at(Vector2(0.0, FLOOR_TOP))
	# Past the respawn's grace period, which is granted in frames rather than as
	# a Health setting and so outlives invulnerable_frames being zero.
	await _frames(player.tuning.iframes + 2)
	player.health.take(DamageInfo.new(2, Vector2.ZERO, &"contact"))
	assert_eq(log_node.deaths, 1)
	assert_eq(log_node.hp_lost(), 30, "28 for the death, 2 for the hit after it")


## Health lost per room is the whole point: "the stage cost 12 HP" is a number
## nobody can act on, and "8 of it in Under East" is one they can.
func test_health_is_attributed_to_the_room_it_was_lost_in() -> void:
	var stage := Stage.new()
	root.add_child(stage)
	var ledger := PlaytestLog.new()
	root.add_child(ledger)
	ledger.watch(player, stage)

	stage.room_changed.emit(_room(&"Arrival"))
	player.health.take(DamageInfo.new(2, Vector2.ZERO, &"contact"))
	stage.room_changed.emit(_room(&"Pilings"))
	player.health.take(DamageInfo.new(5, Vector2.ZERO, &"enemy_shot"))
	player.health.take(DamageInfo.new(9999, Vector2.ZERO, &"pit"))

	assert_eq(ledger.hp_lost_in(&"Arrival"), 2)
	assert_eq(ledger.hp_lost_in(&"Pilings"), 26, "5 for the shot, 21 for the fall")
	assert_eq(ledger.deaths_in(&"Arrival"), 0)
	assert_eq(ledger.deaths_in(&"Pilings"), 1)
	assert_eq(ledger.stays().size(), 2)


## Re-entering a room is a separate entry on the same row, not a second row. A
## room entered four times is a room the player kept dying at the end of.
func test_re_entering_a_room_counts_as_another_entry() -> void:
	var stage := Stage.new()
	root.add_child(stage)
	var ledger := PlaytestLog.new()
	root.add_child(ledger)
	ledger.watch(player, stage)

	var pilings := _room(&"Pilings")
	stage.room_changed.emit(pilings)
	stage.room_changed.emit(_room(&"Descent"))
	stage.room_changed.emit(pilings)

	assert_eq(ledger.stays().size(), 2)
	assert_eq(ledger.stays()[0].entries, 2)
	assert_eq(ledger.stays()[0].name, &"Pilings")


func test_the_report_names_every_death() -> void:
	player.health.kill(DamageInfo.new(9999, Vector2.ZERO, &"tide"))
	var text := "\n".join(log_node.report())
	assert_true(text.contains("tide"), "the report does not name the cause")
	assert_true(text.contains("1 death"), "the report does not count the death")


func test_the_summary_line_is_greppable() -> void:
	player.health.take(DamageInfo.new(4, Vector2.ZERO, &"contact"))
	assert_eq(log_node.summary_line(),
		"SUMMARY hp_lost=4 deaths=0 frames=%d rooms=0" % log_node.frames)


func _room(name: StringName) -> Room:
	var room := Room.new()
	room.name = String(name)
	root.add_child(room)
	return room


func _frames(count: int) -> void:
	for i in count:
		await tree.physics_frame
