## Rising. Releasing jump cuts upward velocity to zero outright, which is what
## produces the original's distinctive short hop.
extends State


func enter(_msg: Dictionary = {}) -> void:
	var player: Player = host
	player.consume_jump_request()
	player.start_jump()


func physics_update(delta: float) -> StringName:
	var player: Player = host
	# Never cut on the launch frame: with the state machine running a state on
	# the frame it is entered, a quick tap would otherwise zero the velocity
	# before the player has moved at all. One frame of rise is the floor.
	if player.state_machine.frames_in_state > 0 and not Input.is_action_pressed(&"jump"):
		player.cut_jump()
	player.apply_gravity(delta)
	# Air control is full strength: you can change direction mid-jump.
	player.apply_walk()
	if player.on_ladder() and Input.is_action_pressed(&"move_up"):
		return &"Climb"
	if player.velocity.y >= 0.0:
		return &"Fall"
	return &""
