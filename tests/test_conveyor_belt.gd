## The conveyor's three fairness rules, driven against a real player on a real
## floor -- because two of the three are about what the *player* does on it, and
## "carries a standing player, ignores an airborne one" is invisible to anything
## that only reads the belt's own state.
extends TestCase

const PLAYER_SCENE := preload("res://scenes/actors/player/player.tscn")
const BeltScript := preload("res://scenes/level/conveyor_belt.gd")

const FLOOR_TOP := 700.0
const SPAWN := Vector2(400.0, FLOOR_TOP)

var root: Node2D
var player: Player
var belt: ConveyorBelt


func is_async() -> bool:
	return true


func before_each_async() -> void:
	root = Node2D.new()
	tree.root.add_child(root)
	_add_floor()
	player = PLAYER_SCENE.instantiate()
	player.position = SPAWN
	root.add_child(player)
	belt = BeltScript.new() as ConveyorBelt
	belt.width_tiles = 20.0
	belt.position = Vector2(0.0, FLOOR_TOP)
	root.add_child(belt)
	await _frames(8)


func after_each_async() -> void:
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


# --- The three rules ------------------------------------------------------------

## **Rule 1: you can always walk against it**, and by enough to be worth doing.
##
## Measured against `PlayerTuning` rather than against the number in the belt,
## so retuning the walk re-checks the belt instead of quietly outdating it. This
## is the rule stage 5 learned the expensive way: "under the walk speed" alone
## permits a belt that leaves the player 3% of their speed, which is a wall that
## looks like a floor.
func test_a_player_can_always_walk_against_the_belt() -> void:
	var t := PlayerTuning.new()
	assert_true(belt.speed_pf < t.walk_speed_pf,
		"a %.2f px/frame belt against a %.2f px/frame walk is a wall"
			% [belt.speed_pf, t.walk_speed_pf])
	var left := (t.walk_speed_pf - belt.speed_pf) / t.walk_speed_pf
	assert_true(left > 0.5,
		"walking upstream leaves %.0f%% of the player's speed" % [left * 100.0])


## And measured on a real player, not only in arithmetic: upstream must be slower
## than downstream and must still be forward progress.
func test_upstream_is_slower_than_downstream_and_still_moves() -> void:
	belt.direction = 1
	var with_it := await _walk_distance(&"move_right")
	var into_it := await _walk_distance(&"move_left")
	assert_true(with_it > into_it,
		"downwind %.1f px, upstream %.1f px -- the belt is not being felt"
			% [with_it, into_it])
	assert_true(into_it > 1.0, "the belt stopped the player dead")


## **Rule 2: it never touches a jump.** The push applies only on the floor, so a
## belt changes a run-up and never an arc.
##
## This is the rule that makes belts safe next to holes at all. Stage 5's wind
## reaches the air, and a full-gust headwind cut a two-cell crossing below the
## reach it needs -- a fault no retuning could have fixed. A belt structurally
## cannot do that, and this is what says so.
func test_an_airborne_player_is_not_carried() -> void:
	belt.direction = 1
	player.global_position = Vector2(400.0, FLOOR_TOP - 300.0)
	player.velocity = Vector2.ZERO
	await _frames(2)
	var before := player.global_position.x
	await _frames(18)
	assert_false(player.is_on_floor(), "the player landed before the test ran")
	assert_almost_eq(player.global_position.x, before, 2.0,
		"an airborne player drifted %.1f px over a running belt"
			% [player.global_position.x - before])


## **Rule 3: it carries a player who is not walking.** This is the difference
## between machinery and weather -- `WindZone` deliberately does not do it, and
## it is what makes a belt running at a hole a decision rather than scenery.
func test_a_standing_player_is_carried() -> void:
	belt.direction = 1
	player.global_position = SPAWN
	player.velocity = Vector2.ZERO
	await _frames(6)
	assert_true(player.is_on_floor(), "the player is not on the floor")
	var before := player.global_position.x
	await _frames(30)
	assert_true(player.global_position.x > before + 4.0,
		"a standing player moved %.1f px on a running belt"
			% [player.global_position.x - before])


## Both ways, so a reversed belt cannot be broken while the forward one works.
func test_the_belt_runs_both_ways() -> void:
	belt.direction = -1
	player.global_position = SPAWN
	player.velocity = Vector2.ZERO
	await _frames(6)
	var before := player.global_position.x
	await _frames(30)
	assert_true(player.global_position.x < before - 4.0,
		"a leftward belt moved the player %.1f px"
			% [player.global_position.x - before])
	assert_true(belt.drift_pf() < 0.0, "drift_pf did not follow the direction")


## Stepping off ends the carry on the next frame, with nothing having to
## remember to switch it off -- the contract the drift field exists for.
func test_leaving_the_belt_ends_the_carry() -> void:
	belt.direction = 1
	await _frames(6)
	assert_true(belt.has_rider(), "the belt never saw the player")
	player.global_position = Vector2(SPAWN.x + 4000.0, SPAWN.y)
	await _frames(4)
	assert_false(belt.has_rider(), "the belt still thinks it has a rider")
	assert_almost_eq(player.carry_drift_pf, 0.0, 0.001,
		"the carry was left written after the player left")


## It is a constant. No cycle, no tell, no reversal -- the whole reason stage 6
## is not stage 5, written as a check so a later "improvement" has to argue with
## it rather than slip past.
func test_the_belt_has_no_cycle() -> void:
	belt.direction = 1
	var first := belt.drift_pf()
	await _frames(240)
	assert_almost_eq(belt.drift_pf(), first, 0.0001,
		"the belt's drift changed over four seconds; it is supposed to be a constant")


# --- Helpers ---------------------------------------------------------------------

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


func _frames(count: int) -> void:
	for _i in count:
		await tree.physics_frame


func _add_floor() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = Layers.bit(Layers.WORLD)
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(6000.0, 200.0)
	shape.shape = rect
	shape.position = Vector2(1500.0, FLOOR_TOP + 100.0)
	body.add_child(shape)
	root.add_child(body)
