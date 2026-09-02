## Spawner: fixed, releases small drones on a cycle.
##
## The pressure archetype. A walker is dodged once; a spawner keeps asking the
## question until the player deals with the source, which is what turns a
## corridor into a "kill it or run past it" decision.
##
## It caps its own brood. Without a cap a spawner left alone fills the room, and
## the player who comes back to a corridor they skipped meets a wall of drones
## rather than a fight -- and the frame rate goes with it.
class_name Spawner
extends Enemy

@export var period_frames: int = 150
## Live drones this spawner will allow at once.
@export var max_brood: int = 3
@export var drone_scene: PackedScene
## Where drones appear, relative to the spawner, in tiles.
@export var drone_offset_tiles := Vector2(0.0, -0.5)
## Launch direction for drones that are projectiles rather than walkers.
@export var drone_direction := Vector2.LEFT

var _frames := 0
var _brood: Array[Node] = []


func setup() -> void:
	affected_by_gravity = false
	var size := body_size()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position.y = -size.y * 0.5
	add_child(shape)


func behave(_delta: float) -> void:
	velocity = Vector2.ZERO
	_prune()
	_frames += 1
	if _frames < period_frames:
		return
	_frames = 0
	if _brood.size() < max_brood:
		_release()


## Live drones right now. The array is pruned first, because a freed reference
## compares equal to null on Godot 4.7 and would otherwise be counted forever.
func brood_size() -> int:
	_prune()
	return _brood.size()


func _prune() -> void:
	var alive: Array[Node] = []
	for drone in _brood:
		if is_instance_valid(drone):
			alive.append(drone)
	_brood = alive


func _release() -> void:
	var level := get_parent()
	if level == null:
		return
	var at := global_position + drone_offset_tiles * tuning.tile_size()

	var drone: Node
	if drone_scene != null:
		drone = drone_scene.instantiate()
		if drone is Node2D:
			(drone as Node2D).global_position = at
		# A drone is NOT given a spawn_marker: it belongs to this spawner, and
		# handing it the spawner's marker would let a drone's death spend the
		# marker that owns the spawner itself.
	else:
		# No scene configured: a plain shot, so a spawner is useful before its
		# drone exists.
		var shot := EnemyShot.new()
		shot.launch(at, drone_direction, 1.5, contact_damage, tuning)
		drone = shot

	level.add_child(drone)
	_brood.append(drone)


func body_size() -> Vector2:
	var tile := tuning.tile_size()
	return Vector2(tile * 1.1, tile * 1.1)
