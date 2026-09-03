## Turret: fixed in place, fires on a fixed cycle.
##
## The archetype that makes a corridor a timing puzzle rather than a walk. It
## does not chase, does not move, and does not react — the player learns the
## period and walks through the gap in it. That is why the cycle is in whole
## physics frames and never randomised: a turret you cannot time is just damage.
##
## Aiming is one of two modes, and the difference matters for level design.
## `tracks_player` off means it fires along a fixed axis forever and can be
## walked around; on means it fires at wherever the player is when the shot
## leaves, which makes cover the answer instead of position.
class_name Turret
extends Enemy

## Frames between shots. 90 is a second and a half, which is enough to cross a
## two-tile gap at walking speed.
@export var period_frames: int = 90
## Frames of visible wind-up before the shot leaves. The tell is what makes a
## turret fair; without it the shot is unreactable even when the period is known.
@export var telegraph_frames: int = 18
@export var shot_speed_pf := 2.0
@export var shot_damage: int = 2
## Fires at the player's position at the moment of firing rather than along
## `aim`.
@export var tracks_player: bool = false
## Fixed firing direction when not tracking. Left, by default, because a marker
## faces left by default.
@export var aim := Vector2.LEFT

var _frames := 0


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
	_frames += 1
	if _frames >= period_frames:
		_frames = 0
		_fire()


## Frames until the next shot, for a subclass or a test that wants to know where
## in the cycle this turret is.
func frames_until_shot() -> int:
	return maxi(0, period_frames - _frames)


## True during the wind-up, so the sprite can show the tell.
func is_telegraphing() -> bool:
	return frames_until_shot() <= telegraph_frames


func _fire() -> void:
	var level := get_parent()
	if level == null:
		return
	var shot := EnemyShot.new()
	var muzzle := global_position + Vector2(0.0, -body_size().y * 0.5)
	shot.launch(muzzle, _direction(), shot_speed_pf, shot_damage, tuning)
	level.add_child(shot)


func _direction() -> Vector2:
	if not tracks_player:
		return aim
	var player := _find_player()
	if player == null:
		return aim
	return (player.global_position + Vector2(0.0, -tuning.tile_size() * 0.5)) \
		- global_position


func _find_player() -> Node2D:
	for node in get_tree().get_nodes_in_group(&"player"):
		if node is Node2D:
			return node as Node2D
	# Not in a group yet: fall back to a sibling search, which is cheap because
	# a room holds tens of nodes rather than thousands.
	var parent := get_parent()
	if parent != null:
		for child in parent.get_children():
			if child is Player:
				return child as Player
	return null
