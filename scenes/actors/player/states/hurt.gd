## Knocked back, control locked. This is what makes pits lethal near enemies:
## you cannot steer out of a knockback, so a hit over a gap is a death.
extends State

var _knockback_direction := -1


func enter(msg: Dictionary = {}) -> void:
	var player: Player = host
	var source: Vector2 = msg.get("source_position", player.global_position)
	# Pushed away from whatever hit you.
	_knockback_direction = -1 if source.x > player.global_position.x else 1
	player.velocity.x = float(_knockback_direction) \
		* player.tuning.px_s(player.tuning.knockback_speed_pf)
	player.velocity.y = 0.0


func physics_update(delta: float) -> StringName:
	var player: Player = host
	player.velocity.x = float(_knockback_direction) \
		* player.tuning.px_s(player.tuning.knockback_speed_pf)
	player.apply_gravity(delta)
	var machine: StateMachine = player.state_machine
	if machine.frames_in_state < player.tuning.knockback_frames:
		return &""
	if not player.is_on_floor():
		return &"Fall"
	return &"Idle"
