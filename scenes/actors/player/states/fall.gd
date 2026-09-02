## Descending, whether from a jump or by walking off a ledge.
extends State


func physics_update(delta: float) -> StringName:
	var player: Player = host
	player.apply_gravity(delta)
	player.apply_walk()
	if player.on_ladder() and (Input.is_action_pressed(&"move_up")
			or Input.is_action_pressed(&"move_down")):
		return &"Climb"
	if player.is_on_floor():
		# A jump buffered just before landing fires on the landing frame.
		if player.jump_requested():
			return &"Jump"
		return &"Idle" if player.input_direction() == 0 else &"Walk"
	return &""
