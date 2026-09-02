## The Mega Man 3 signature move: a fixed-duration, fixed-speed low dash.
##
## Duration is counted in physics frames rather than seconds so it is exactly
## `slide_frames` long regardless of frame timing. Direction is locked at entry;
## steering mid-slide is not a thing in the original.
extends State

var _direction := 1


func enter(_msg: Dictionary = {}) -> void:
	var player: Player = host
	player.consume_jump_request()
	_direction = player.input_direction()
	if _direction == 0:
		_direction = player.facing
	player.facing = _direction
	player.use_slide_hitbox(true)


func exit() -> void:
	(host as Player).use_slide_hitbox(false)


func physics_update(delta: float) -> StringName:
	var player: Player = host
	player.velocity.x = float(_direction) * player.tuning.px_s(player.tuning.slide_speed_pf)
	player.apply_gravity(delta)

	if not player.is_on_floor():
		return &"Fall"
	# Cancelling a slide with jump is a skill expression the speedrun crowd
	# expects; PLAN.md section 6 keeps it deliberately.
	if player.jump_requested() and player.has_headroom():
		return &"Jump"
	# Hitting a wall ends the slide early.
	if player.is_on_wall():
		return &"Idle"
	var machine: StateMachine = player.state_machine
	if machine.frames_in_state >= player.tuning.slide_frames:
		# Stay low until there is room to stand, which is what makes low tunnels
		# traversable.
		if not player.has_headroom():
			return &""
		return &"Idle" if player.input_direction() == 0 else &"Walk"
	return &""
