## The bottomless pit, and the one frame after a respawn.
##
## `KillPlane` is the only thing in the game that kills through i-frames -- a
## pit that could be survived is a soft lock, so it calls `Health.kill()`
## directly and nothing may soften it. That makes it the one place where being
## *wrongly* inside the volume costs a life with no mercy at all, which is why
## it gets a test of its own.
extends TestCase

const PLAYER_SCENE := preload("res://scenes/actors/player/player.tscn")

## Well clear of the plane below, and of the plane's own half-height.
const SAFE_Y := 200.0
const PLANE_TOP := 1500.0

var root: Node2D
var player: Player
var plane: KillPlane


func is_async() -> bool:
	return true


func before_each_async() -> void:
	root = Node2D.new()
	tree.root.add_child(root)
	plane = KillPlane.new()
	plane.size_tiles = Vector2(40.0, 24.0)
	# `position` is the volume's centre; the constant names its top edge.
	plane.position = Vector2(0.0, PLANE_TOP + 12.0 * _tile())
	root.add_child(plane)
	player = PLAYER_SCENE.instantiate()
	player.position = Vector2(0.0, SAFE_Y)
	root.add_child(player)
	await _frames(8)


func after_each_async() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


func test_a_player_inside_the_plane_dies() -> void:
	player.global_position = Vector2(0.0, PLANE_TOP + 200.0)
	await _frames(4)
	assert_true(player.health.is_dead(), "the pit did not kill")


func test_the_plane_kills_through_iframes() -> void:
	# The whole reason it is not a Hazard. A player still flickering from a
	# contact hit falls through a merciful pit forever.
	player.health.grant_invulnerability(120)
	player.global_position = Vector2(0.0, PLANE_TOP + 200.0)
	await _frames(4)
	assert_true(player.health.is_dead(), "i-frames carried the player through a pit")


func test_a_player_outside_the_plane_is_untouched() -> void:
	await _frames(30)
	assert_false(player.health.is_dead(), "killed while nowhere near the pit")


## The regression this file was written for.
##
## Falling in used to cost **two** lives, every time. `KillPlane` re-checks
## `get_overlapping_bodies()` every frame as a belt to go with the depth brace,
## and that list is the physics server's answer from the *previous* step. A
## respawn teleports the player out of the volume in one assignment, so on the
## next frame the list still holds them -- and because a pit is the one thing
## that ignores i-frames, the grace period a respawn grants cannot stop it. The
## player reappeared at the checkpoint, alive, and died again immediately.
##
## It stayed invisible because nothing in the game reads *why* something died;
## it surfaced the day a playtest ledger started printing the cause and the
## place, and showed eight pit deaths at coordinates a hundred rows above the
## nearest pit.
func test_a_respawn_out_of_the_plane_is_not_killed_by_the_stale_overlap() -> void:
	player.global_position = Vector2(0.0, PLANE_TOP + 200.0)
	await _frames(4)
	assert_true(player.health.is_dead(), "setup: the pit should have killed")

	# Exactly what Player.respawn_at does: move clear, refill, grant grace.
	player.respawn_at(Vector2(0.0, SAFE_Y))
	assert_false(player.health.is_dead(), "setup: the respawn should have healed")
	await _frames(1)
	assert_false(player.health.is_dead(),
		"the pit killed the player again on the frame after the respawn")
	await _frames(10)
	assert_false(player.health.is_dead(), "the pit killed the player after the respawn")


## From the resource rather than from the Tuning autoload, which is not resolvable
## from a `--script` entry point (docs/PLAN.md M3). Same number either way: the
## plane falls back to the same default when it cannot reach the autoload.
func _tile() -> float:
	return PlayerTuning.new().tile_size()


func _frames(count: int) -> void:
	for i in count:
		await tree.physics_frame
